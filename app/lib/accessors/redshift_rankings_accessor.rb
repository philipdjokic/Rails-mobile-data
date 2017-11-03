class RedshiftRankingsAccessor
  include RankingsParamDenormalizer

  def get_trending(platforms:[], countries:[], categories:[], rank_types:[], size: 20, page_num: 1, sort_by: "weekly_change", desc: true)
    
    # Validate parameters

    if (platforms - ['ios', 'android']).any?
      raise "Unsupported platform option"
    end

    if (rank_types - ['free', 'paid', 'grossing']).any?
      raise "Unsupported rank_type option"
    end

    if !['weekly_change', 'monthly_change'].include? sort_by
      raise "Unsupported sort_by option"
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

    # Denormalize necessary parameters

    denormalized_countries = []
    if platforms.include?  'ios'
      countries.each do |country_code|
        denormalized_countries.push(country_code_to_ios(country_code))
      end
    end
    denormalized_countries = denormalized_countries.compact + countries

    denormalized_rank_types = []
    rank_types.each do |rank_type|
      denormalized_rank_types.push(rank_type_to_ios(rank_type)) if platforms.include? 'ios'
      denormalized_rank_types.push(rank_type_to_android(rank_type)) if platforms.include? 'android'
    end

    # Perform queries

    where_clauses = build_where_clauses(platforms, denormalized_countries, categories, denormalized_rank_types, sort_by)
    order_by_clause = desc ? "ORDER BY #{sort_by} DESC" : "ORDER BY #{sort_by} ASC"

    get_trending_query = "SELECT * FROM daily_trends #{where_clauses} #{order_by_clause} OFFSET #{(page_num - 1) * size} LIMIT #{size}"
    get_total_query = "SELECT COUNT(app_identifier) FROM daily_trends #{where_clauses}"

    {
      "total" => RedshiftBase.query(get_total_query, expires: 30.minutes).fetch()[0]["count"],
      "apps" => RedshiftBase.query(get_trending_query, expires: 30.minutes).fetch(),  # Note: the returned entries will have denormalized country and rank type attributes.
    }
  end

  def get_newcomers(platforms:[], countries:[], categories:[], rank_types:[], lookback_time: 14.days.ago, size: 20, page_num: 1)
    nil # TODO
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

    query = "SELECT * FROM daily_raw_charts WHERE platform='#{platform}' AND country='#{denormalized_country}' AND category='#{category}' AND ranking_type='#{denormalized_rank_type}' ORDER BY rank ASC OFFSET #{(page_num - 1) * size} LIMIT #{size}"
    RedshiftBase.query(query, expires: 30.minutes).fetch()
  end

private

  def build_where_clauses(platforms, countries, categories, rank_types, sort_by)
    where_clauses = []
    where_clauses.push("platform IN ('#{platforms.join("','")}')") if platforms.any?
    where_clauses.push("country IN ('#{countries.join("','")}')") if countries.any?
    where_clauses.push("category IN ('#{categories.join("','")}')") if categories.any?
    where_clauses.push("ranking_type IN ('#{rank_types.join("','")}')") if rank_types.any?
    where_clauses.push("#{sort_by} IS NOT NULL")
    return where_clauses.any? ? " WHERE " + where_clauses.join(" AND ") : ""
  end

end