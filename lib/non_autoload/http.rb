require 'net/protocol'
require 'uri'

module Net

  class HTTP < Protocol

  	def begin_transport(req)

  	  if defined?(@socket.closed?)

	      if @socket.closed?
	        connect
	      elsif @last_communicated && @last_communicated + @keep_alive_timeout < Time.now
	        D 'Conn close because of keep_alive_timeout'
	        @socket.close
	        connect
	      end

	      if not req.response_body_permitted? and @close_on_empty_response
	        req['connection'] ||= 'close'
	      end

	      host = req['host'] || address
	      host = $1 if host =~ /(.*):\d+$/
	      req.update_uri host, port, use_ssl?

	      req['host'] ||= addr_port()
	  else

	  	  raise "@socket.closed? was not defined for some reason"

	  end

    end

  end

end