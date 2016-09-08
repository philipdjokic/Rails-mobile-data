class ProxyControl

  class << self
    def start_proxies
      toggle_proxies(activate: true)
    end

    def stop_proxies
      toggle_proxies(activate: false)
    end

    def toggle_proxies(activate:)
      activate ? activation_routine : deactivation_routine
    end

    def deactivation_routine
      MightyAws::InstanceControl.new.stop_temporary_proxies
    end

    def activation_routine
      puts 'Starting temporary proxies'
      MightyAws::InstanceControl.new.start_temporary_proxies
      puts 'Allowing 15s to start running'
      sleep 15 # let proxies spin up and start running
      puts 'Registering temporary proxies'
      MightyAws::Api.new.register_temp_proxies_with_proxy_lbs
      puts 'Allowing 45s for lbs to establish healthy connections with proxies'
      sleep 45 # register unregistered proxies. Health check is every 30 seconds
    end
  end
end
