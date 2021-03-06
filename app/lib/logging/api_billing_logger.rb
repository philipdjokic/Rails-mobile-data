class ApiBillingLogger
  attr_accessor :auth
  attr_reader :event

  def initialize(request, api_token)
    @request = request
    @api_token = api_token
    @event = {}
  end

  def send!
    build_event
    ApiBillingLoggerWorker.perform_async(@event)
    RedshiftLogger.new(records: [@event], table: 'varys_api_billing').send!
  end

  def build_event
    add_request_data
    add_user_data
  end

  def add_request_data
    set_info(:request_id, @request.uuid)
    set_info(:request_method, @request.request_method)
    set_info(:request_fullpath, @request.fullpath)
    set_info(:request_timestamp, DateTime.now.utc.iso8601)
  end

  def add_user_data
    account = Account.find(@api_token.account_id)
    set_info(:account_uuid, account.id) # TODO: change to uuid after migration
    set_info(:account_name, account.name)
  end

  def set_info(k, v)
    @event[k] = v
  end
end
