class ApplicationController < ActionController::Base
  
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  class NotAuthenticatedError < StandardError; end
  class AuthenticationExpiredError < StandardError; end
  class AuthenticationSharedError < StandardError; end
  class AuthenticationRevokedError < StandardError; end
  class ForbiddenError < StandardError; end

  rescue_from NotAuthenticatedError do
    render json: { error: 'Not Authorized' }, status: :unauthorized
  end
  rescue_from ForbiddenError do
    render json: { error: 'Forbidden' }, status: 403
  end
  rescue_from AuthenticationExpiredError do
    render json: { error: 'Auth token is expired' }, status: 419 # unofficial timeout status code
  end
  rescue_from AuthenticationSharedError do
    render json: { error: 'Another session was created for this user' }, status: 409 # unofficial account sharing status code
  end
  rescue_from AuthenticationRevokedError do
    render json: {'error' => 'Authorization revoked'}, status: 418 # unofficial authorization revoked status code
  end

  rescue_from Throttler::LimitExceeded do
    render json: { error: 'Rate Limit Exceeded' }, status: 429
  end

  def ping
    render :json => {success: true}
  end

  def default_url_options
    # the allowed parameters to pass around the app
    allowed_params = %w(
                      ad_source
                      utm_source
                      utm_medium
                      utm_campaign
                      creative
                      )

    query_parameters = request.query_parameters

    query_parameters.slice(*allowed_params)
  end
  
  private
  
  # Based on the user_id inside the token payload, find the user.
  def set_current_user
    if decoded_auth_token
      @current_user ||= User.find(decoded_auth_token[:user_id])
      @current_user.touch(:last_active)
    end
  end

  # Check to make sure the current user was set and the token is not expired
  def authenticate_request
    if auth_token_expired?
      fail AuthenticationExpiredError
    elsif auth_token_shared? && @current_user.try(:account_id).to_i > 1
      fail AuthenticationSharedError
    elsif !@current_user
      fail NotAuthenticatedError
    elsif @current_user.access_revoked?
      fail AuthenticationRevokedError
    end
  end

  def authenticate_storewide_sdk_request
    user = User.find(decoded_auth_token[:user_id])
    account = Account.find(user.account_id)

    if !account || !account.can_view_storewide_sdks
      fail ForbiddenError
    end
  end

  def authenticate_admin
    user = User.find(decoded_auth_token[:user_id])
    account = Account.find(user.account_id)

    if !user.is_admin? && !account.is_admin_account?
      fail ForbiddenError
    end
  end

  def logged_into_admin_account?
    user = User.find(decoded_auth_token[:user_id])
    account = Account.find(user.account_id)
    account.is_admin_account?
  end

  def authenticate_admin_account
    if !logged_into_admin_account?
      fail ForbiddenError
    end
  end

  def authenticate_export_request
    user = User.find(decoded_auth_token[:user_id])
    account = Account.find(user.account_id)

    if !account || !account.can_view_exports
      fail ForbiddenError
    end
  end

  def authenticate_ad_intelligence
    user = User.find(decoded_auth_token[:user_id])
    account = Account.find(user.account_id)

    if !account || !account.can_view_ad_spend
      fail ForbiddenError
    end
  end

  def authenticate_ios_live_scan
    user = User.find(decoded_auth_token[:user_id])
    account = Account.find(user.account_id)

    if !account || !account.can_view_ios_live_scan
      fail ForbiddenError
    end
  end

  def decoded_auth_token
    @decoded_auth_token ||= AuthToken.decode(http_auth_header_content)
    @decoded_auth_token ||= AuthToken.decode(params[:access_token])
  end

  def auth_token_expired?
    decoded_auth_token && decoded_auth_token.expired?
  end

  def auth_token_shared?
    decoded_auth_token && decoded_auth_token.is_second_session?
  end

  # JWT's are stored in the Authorization header using this format:
  # Bearer somerandomstring.encoded-payload.anotherrandomstring
  def http_auth_header_content
    return @http_auth_header_content if defined? @http_auth_header_content
    @http_auth_header_content = begin
      if request.headers['Authorization'].present?
        request.headers['Authorization'].split(' ').last
      else
        nil
      end
    end
  end

  # In Rails 4.2, custom headers are upcased, have their hyphens replaced with underscores, and prepended by HTTP
  # https://github.com/rails/rails/blob/4-2-stable/actionpack/lib/action_dispatch/http/headers.rb
  def authenticate_client_api_request
    header_key = 'HTTP_MIGHTYSIGNAL_TOKEN'
    key = request.headers[header_key]

    @http_client_api_auth_token = ApiToken.find_by(token: key, active: true) if key.present?
    raise NotAuthenticatedError if @http_client_api_auth_token.blank?
  end

  # both authenticates and ensures not exceeded given rate limit
  def limit_client_api_call
    authenticate_client_api_request
    token = @http_client_api_auth_token
    Throttler.new(token.token, token.rate_limit, token.period).increment
  end

  def bill_api_request
    begin
      ApiBillingLogger.new(request, @http_client_api_auth_token).send!
    rescue => e
      Bugsnag.notify(e)
    end
  end

  def append_info_to_payload(payload)
    super
    payload[:request_id] = request.uuid
    payload[:headers] = request.headers.env.select{|k, _| k.in?(ActionDispatch::Http::Headers::CGI_VARIABLES) || k =~ /^HTTP_/}

    payload[:headers].delete('HTTP_COOKIE')
    payload[:headers].delete('HTTP_VERSION')
    payload[:headers].delete('SERVER_PROTOCOL')
    payload[:headers].delete('CONTENT_LENGTH')
    payload[:headers].delete('HTTP_CONNECTION')
    payload[:headers].delete('HTTP_X_AMZN_TRACE_ID')
  end
  
  def get_sdk(platform, sdk_id)
    "#{platform.capitalize}Sdk".constantize.find(sdk_id)
  rescue ActiveRecord::RecordNotFound
    flash[:error] = "Sorry, that SDK was not found"
    redirect_to root_path
  end
end
