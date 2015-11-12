# Patch for 1.1.5
if defined?(ApkDownloader)

  ApkDownloader::Api.module_eval do

    LoginUri = URI('https://android.clients.google.com/auth')
    GoogleApiUri = URI('https://android.clients.google.com/fdfe')

    def log_in!(proxy_ip, proxy_port, apk_snap_id)

      snap = ApkSnapshot.find_by_id(apk_snap_id)

      return if snap.auth_token.present?

      headers = {
        'Accept-Encoding' => ''
      }

      ga = GoogleAccount.joins(apk_snapshots: :google_account).where('apk_snapshots.id = ?', apk_snap_id).first

      params = {
        'Email' => ga.email,
        'Passwd' => ga.password,
        'service' => 'androidmarket',
        'accountType' => 'HOSTED_OR_GOOGLE',
        'has_permission' => '1',
        'source' => 'android',
        'androidId' => ga.android_identifier,
        'app' => 'com.android.vending',
        'device_country' => 'us',
        'operatorCountry' => 'us',
        'lang' => 'en',
        'sdk_version' => '17'
      }

      response = res(type: :post, req: {:host => LoginUri.host, :path => LoginUri.path, :protocol => "https", :headers => headers}, params: params, proxy_ip: proxy_ip, proxy_port: proxy_port, apk_snap_id: apk_snap_id)

      if response.status != 200
        raise "Unable to connect with Google | status_code: #{response.status}"
      elsif response.body.include? "Auth="
        # @auth_token = response.body.scan(/Auth=(.*?)$/).flatten.first
        a = response.body.scan(/Auth=(.*?)$/).flatten.first
        snap.auth_token = a
        snap.save
      end

    end

    def details package, proxy_ip, proxy_port, apk_snap_id
      if @details_messages[package].nil?
        log_in!(proxy_ip, proxy_port, apk_snap_id)
        status_code, message = api_request apk_snap_id, proxy_ip, proxy_port, :get, '/details', :doc => package
        @details_messages[package] = message.payload
      end

      return @details_messages[package]
    end

    def fetch_apk_data package, apk_snap_id

      # mp = MicroProxy.transaction do

      #   p = MicroProxy.lock.order(last_used: :asc).where(active: true).first
      #   p.last_used = DateTime.now
      #   p.save

      #   p

      # end

      mp = MicroProxy.select(:private_ip).sample

      apk_snap = ApkSnapshot.find_by_id(apk_snap_id)
      apk_snap.micro_proxy_id = mp.id
      apk_snap.save
      
      proxy_ip = mp.private_ip
      proxy_port = "8888"

      log_in!(proxy_ip, proxy_port, apk_snap_id)

      doc = details(package, proxy_ip, proxy_port, apk_snap_id).detailsResponse.docV2
      version_code = doc.details.appDetails.versionCode
      offer_type = doc.offer[0].offerType

      status_code, message = api_request apk_snap_id, proxy_ip, proxy_port, :post, '/purchase', :ot => offer_type, :doc => package, :vc => version_code

      url = URI(message.payload.buyResponse.purchaseStatusResponse.appDeliveryData.downloadUrl)
      cookie = message.payload.buyResponse.purchaseStatusResponse.appDeliveryData.downloadAuthCookie[0]

      if url.blank? || cookie.blank? || proxy_ip.blank?
        snap = ApkSnapshot.find_by_id(apk_snap_id)
        snap.status = :no_response
        snap.save

        raise "Google did not return url or cookie | status_code: #{status_code}"

      end

      resp = recursive_apk_fetch(apk_snap_id, proxy_ip, proxy_port, url, cookie)

      return resp.body

    end

    private
    def recursive_apk_fetch apk_snap_id, proxy_ip, proxy_port, url, cookie, first = true

      headers = {
        'Accept-Encoding' => '',
        'User-Agent' => 'AndroidDownloadManager/4.1.1 (Linux; U; Android 5.1.1; Nexus 9 Build/LMY48M)'
      }

      cookies = [cookie.name, cookie.value].join('=')

      params = url.query.split('&').map{ |q| q.split('=') }

      response = res(type: :get, req: {:host => url.host, :path => url.path, :protocol => "https", :headers => headers, :cookies => cookies}, params: params, proxy_ip: proxy_ip, proxy_port: proxy_port, apk_snap_id: apk_snap_id)

      return recursive_apk_fetch(apk_snap_id, proxy_ip, proxy_port, URI(response['Location']), cookie, false) if first

      if response.blank?

        as = ApkSnapshot.find_by_id(apk_snap_id)
        as.status = :failure
        as.save

        raise "recursive_apk_fetch returned empty | status_code: #{response.status}"
        
      end

      response
        
    end

    def res(req:, params:, type:, proxy_ip:, proxy_port:, apk_snap_id:)

      proxy = "#{proxy_ip}:#{proxy_port}"

      proxy = '169.45.69.38:8888' if Rails.env.development?

      response = CurbFu.send(type, req, params) do |curb|
        curb.proxy_url = proxy
        curb.ssl_verify_peer = false
        curb.max_redirects = 3
        curb.timeout = 90
      end

      if [200,302].include? response.status

        return response

      else

        snap = ApkSnapshot.find_by_id(apk_snap_id)
        aa = snap.android_app

        if response.status == 403
          if response.body.include? "This item cannot be installed in your country"
            snap.status = :out_of_country
            aa.display_type = :foreign
          elsif response.body.include? "Your device is not compatible with this item"
            snap.status = :bad_device
            aa.display_type = :device_incompatible
          else
            snap.status = :forbidden
          end
        elsif response.status == 404
          aa.display_type = :taken_down
          snap.status = :taken_down
        elsif response.status == 500
          ga = snap.google_account
          ga.blocked = true
          ga.save
        end

        snap.save
        aa.save

        if response.status == 403
          raise "#{response.body}, status code #{response.status} from #{caller[0][/`.*'/][1..-2]} on #{proxy_ip} | status_code: #{response.status}"
        else
          raise "status code #{response.status} from #{caller[0][/`.*'/][1..-2]} on #{proxy_ip} | status_code: #{response.status}"
        end

      end

    end

    def api_request apk_snap_id, proxy_ip, proxy_port, type, path, data = {}

      ga = GoogleAccount.joins(apk_snapshots: :google_account).where('apk_snapshots.id = ?', apk_snap_id).first

      auth_token = ApkSnapshot.find_by_id(apk_snap_id).auth_token

      headers = {
        'Accept-Language' => 'en_US',
        'Authorization' => "GoogleLogin auth=#{auth_token}",
        'X-DFE-Enabled-Experiments' => 'cl:billing.select_add_instrument_by_default',
        'X-DFE-Unsupported-Experiments' => 'nocache:billing.use_charging_poller,market_emails,buyer_currency,prod_baseline,checkin.set_asset_paid_app_field,shekel_test,content_ratings,buyer_currency_in_app,nocache:encrypted_apk,recent_changes',
        'X-DFE-Device-Id' => ga.android_identifier,
        'X-DFE-Client-Id' => 'am-android-google',
        'User-Agent' => 'Android-Finsky/5.8.8 (api=3,versionCode=80380800,sdk=22,device=flounder,hardware=flounder,product=volantis,platformVersionRelease=5.1.1,model=Nexus%209,buildId=LMY48M,isWideScreen=1)',
        'X-DFE-SmallestScreenWidthDp' => '320',
        'X-DFE-Filter-Level' => '3',
        'Accept-Encoding' => '',
        'Host' => 'android.clients.google.com'
      }

      headers['Content-Type'] = 'application/x-www-form-urlencoded; charset=UTF-8' if type == :post

      uri = URI([GoogleApiUri,path.sub(/^\//,'')].join('/'))

      response = res(type: type, req: {:host => uri.host, :path => uri.path, :protocol => "https", :headers => headers}, params: data, proxy_ip: proxy_ip, proxy_port: proxy_port, apk_snap_id: apk_snap_id)

      return response.status, ApkDownloader::ProtocolBuffers::ResponseWrapper.new.parse(response.body)

    end

  end
end
