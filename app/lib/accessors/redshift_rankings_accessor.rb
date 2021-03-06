class RedshiftRankingsAccessor
  include RankingsParamDenormalizer

  def initialize(connection: nil)
    @connection = connection || RedshiftDbConnection.new
  end

  def get_trending(platforms:[], countries:[], categories:[], rank_types:["free", "paid", "grossing"], size: 20, page_num: 1, sort_by: "weekly_change", desc: true, max_rank: 500)

    # Validate parameters

    validate_parameters(platforms: platforms, countries: countries, categories: categories, rank_types: rank_types, size: size, page_num: page_num)
    raise "Unsupported sort_by option" if !['weekly_change', 'monthly_change', 'rank'].include? sort_by

    # Denormalize necessary parameters

    denormalized_countries = generate_denormalized_countries(platforms, countries)
    denormalized_rank_types = generate_denormalized_rank_types(platforms, rank_types)

    # Perform queries

    where_clauses = build_where_clauses(platforms, denormalized_countries, categories, denormalized_rank_types, sort_by: sort_by, max_rank: max_rank)
    order_by_clause = desc ? "ORDER BY #{sort_by} DESC" : "ORDER BY #{sort_by} ASC"

    get_trending_query = "SELECT *, count(*) OVER() FROM daily_trends #{where_clauses} #{order_by_clause} OFFSET #{(page_num - 1) * size} LIMIT #{size}"
    raw_result = @connection.query(get_trending_query, expires: 30.minutes).fetch()
    counts_extracted = extract_count(raw_result)
    counts_extracted["apps"] = normalize_app_records(counts_extracted["apps"])
    counts_extracted
  end

  def get_newcomers(platforms:[], countries:[], categories:[], rank_types:["free", "paid", "grossing"], lookback_time: 14.days.ago, size: 20, page_num: 1, sort_by: "created_at", desc: true, max_rank: 500)

    # Validate parameters

    validate_parameters(platforms: platforms, countries: countries, categories: categories, rank_types: rank_types, size: size, page_num: page_num)
    raise "Unsupported sort_by option" if !['created_at', 'rank'].include? sort_by
    raise "Unsupported lookback_time option" if !lookback_time.is_a? ActiveSupport::TimeWithZone

    # Denormalize necessary parameters

    denormalized_countries = generate_denormalized_countries(platforms, countries)
    denormalized_rank_types = generate_denormalized_rank_types(platforms, rank_types)

    # Perform queries

    where_clauses = build_where_clauses(platforms, denormalized_countries, categories, denormalized_rank_types, lookback_time: lookback_time, max_rank: max_rank)
    order_by_clause = desc ? "ORDER BY #{sort_by} DESC" : "ORDER BY #{sort_by} ASC"

    get_newcomers_query = "SELECT *, count(*) OVER() FROM daily_newcomers #{where_clauses} #{order_by_clause} OFFSET #{(page_num - 1) * size} LIMIT #{size}"
    raw_result = @connection.query(get_newcomers_query, expires: 30.minutes).fetch()
    counts_extracted = extract_count(raw_result)
    counts_extracted["apps"] = normalize_app_records(counts_extracted["apps"])
    counts_extracted
  end

  def get_chart(platform:, country:, category:, rank_type:, size: 20, page_num: 1)

    # Validate parameters

    if !['ios', 'android'].include? platform
      raise "Unsupported platform option"
    end

    if !['free', 'paid', 'grossing'].include? rank_type
      raise "Unsupported rank_type option"
    end

    if !size.is_a? Integer
      raise "size must be an integer"
    end

    if !page_num.is_a? Integer
      raise "page_num must be an integer"
    end

    raise "Invalid country code." if country.length != 2
    raise "Invalid category" if category.include? "\"" or category.include? "'"

    # Denormalize necessary parameters

    denormalized_country = platform == 'ios' ? country_code_to_ios(country) : country
    denormalized_rank_type = platform == 'ios' ? rank_type_to_ios(rank_type) : rank_type_to_android(rank_type)

    # Perform queries

    get_chart_query = "SELECT *, count(*) OVER() FROM daily_raw_charts WHERE platform='#{platform}' AND country='#{denormalized_country}' AND category='#{category}' AND ranking_type='#{denormalized_rank_type}' ORDER BY rank ASC OFFSET #{(page_num - 1) * size} LIMIT #{size}"
    raw_result = @connection.query(get_chart_query, expires: 30.minutes).fetch()
    counts_extracted = extract_count(raw_result)
    counts_extracted["apps"] = normalize_app_records(counts_extracted["apps"])
    counts_extracted
  end

  def get_historical_app_rankings(app_identifier:, platform:, countries:[], categories:[], rank_types:[], min_date:, max_date:)

    # Validate parameters

    if !['ios', 'android'].include? platform
      raise "Unsupported platform option"
    end

    if (rank_types - ['free', 'paid', 'grossing']).any?
      raise "Unsupported rank_type option"
    end

    countries.each do |country|
      raise "Invalid country code." if country.length != 2
    end

    categories.each do |category|
      raise "Invalid category" if category.include? "\"" or category.include? "'"
    end

    begin
      Date.iso8601(min_date)
    rescue
      raise "Invalid min date"
    end

    begin
      Date.iso8601(max_date)
    rescue
      raise "Invalid max date"
    end

    # Denormalize necessary parameters

    denormalized_countries = generate_denormalized_countries([platform], countries)
    denormalized_rank_types = generate_denormalized_rank_types([platform], rank_types)

    # Perform queries

    where_clauses = build_where_clauses([platform], denormalized_countries, categories, denormalized_rank_types)
    query = "SELECT * from historical_rankings #{where_clauses}" +
      " AND app_identifier = '#{app_identifier}'" +
      " AND created_at BETWEEN '#{min_date}' AND '#{max_date}'" +
      " ORDER BY created_at"
    raw_results = @connection.query(query, expires: 30.minutes).fetch()
    normalize_app_records(raw_results)
  end

  def ios_countries
    storefront_ids = get_chart_param("country", "ios")
    storefront_ids.map { |storefront_id| ios_to_country_code(storefront_id) }.compact
  end

  def ios_categories
    get_chart_param("category", "ios")
  end

  def android_countries
    get_chart_param("country", "android")
  end

  def android_categories
    get_chart_param("category", "android")
  end

  def unique_newcomers(platform:, lookback_time:, page_size:, page_num:, count:false)
    if count
      return @connection.query("SELECT COUNT(DISTINCT app_identifier) FROM daily_newcomers_swap WHERE platform='#{platform}' AND created_at > '#{lookback_time.strftime("%Y-%m-%d")}'", expires: 1.minutes).fetch()[0]["count"]
    end

    return @connection.query("SELECT DISTINCT app_identifier FROM daily_newcomers_swap WHERE platform='#{platform}' AND created_at > '#{lookback_time.strftime("%Y-%m-%d")}' ORDER BY app_identifier OFFSET #{(page_num - 1) * page_size} LIMIT #{page_size}", expires: 1.minutes).fetch()
  end

private

  def extract_count(results)
    return_info = {
      "total" => 0,
      "apps" => []
    }

    if results.any?
      return_info["total"] = results[0]["count"]
      return_info["apps"] = results.each { |result| result.delete("count") }
    end

    return_info
  end

  def get_chart_param(param, platform)
    query_result = @connection.query("SELECT DISTINCT #{param} FROM daily_raw_charts WHERE platform='#{platform}'", expires: 1.days).fetch()
    query_result.map { |row| row["#{param}"] }
  end

  def normalize_app_records(records)
    records.map do |record|
      if record["platform"] == "ios"
        record["country"] = ios_to_country_code(record["country"])
        record["ranking_type"] = ios_to_rank_type(record["ranking_type"])
      elsif record["platform"] == "android"
        record["ranking_type"] = android_to_rank_type(record["ranking_type"])
      end
      record
    end
  end

  def generate_denormalized_countries(platforms, countries)
    denormalized_countries = []
    if platforms.include?  'ios' or platforms.empty?
      countries.each do |country_code|
        denormalized_countries.push(country_code_to_ios(country_code))
      end
    end
    denormalized_countries.compact + countries
  end

  def generate_denormalized_rank_types(platforms, rank_types)
    denormalized_rank_types = []
    rank_types.each do |rank_type|
      denormalized_rank_types.push(rank_type_to_ios(rank_type)) if platforms.include? 'ios' or platforms.empty?
      denormalized_rank_types.push(rank_type_to_android(rank_type)) if platforms.include? 'android' or platforms.empty?
    end
    denormalized_rank_types
  end

  def validate_parameters(platforms:, countries:, categories:, rank_types:, size:, page_num:)
    if (platforms - ['ios', 'android']).any?
      raise "Unsupported platform option"
    end

    if (rank_types - ['free', 'paid', 'grossing']).any?
      raise "Unsupported rank_type option"
    end

    if !size.is_a? Integer
      raise "size must be an integer"
    end

    if !page_num.is_a? Integer
      raise "page_num must be an integer"
    end

    countries.each do |country|
      raise "Invalid country code." if country.length != 2
    end

    categories.each do |category|
      raise "Invalid category" if category.include? "\"" or category.include? "'"
    end
  end

  def build_where_clauses(platforms, countries, categories, rank_types, sort_by: nil, lookback_time: nil, max_rank: nil)
    where_clauses = []
    where_clauses.push("platform IN ('#{platforms.join("','")}')") if platforms.any?
    where_clauses.push("country IN ('#{countries.join("','")}')") if countries.any?
    where_clauses.push("category IN ('#{categories.join("','")}')") if categories.any?
    where_clauses.push("ranking_type IN ('#{rank_types.join("','")}')") if rank_types.any?
    where_clauses.push("#{sort_by} IS NOT NULL") if sort_by.present?
    where_clauses.push("created_at > '#{lookback_time.strftime("%Y-%m-%d")}'") if lookback_time.present?
    where_clauses.push("rank < #{max_rank}") if max_rank.present?
    return where_clauses.any? ? " WHERE " + where_clauses.join(" AND ") : ""
  end

end
