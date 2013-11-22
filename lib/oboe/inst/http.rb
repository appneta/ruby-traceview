# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

require 'net/http'

if Oboe::Config[:nethttp][:enabled]

  Net::HTTP.class_eval do
    def request_with_oboe(*args, &block)
      unless started? 
        return request_without_oboe(*args, &block) 
      end

      # Avoid cross host tracing for blacklisted domains
      blacklisted = Oboe::API.blacklisted?(addr_port)

      Oboe::API.trace('net-http') do
        opts = {}
        context = Oboe::Context.toString()
        task_id = Oboe::XTrace.task_id(context)

        # Collect KVs to report in the info event
        if args.length and args[0]
          req = args[0]

          opts['IsService'] = 1
          opts['RemoteProtocol'] = use_ssl? ? 'HTTPS' : 'HTTP'
          opts['RemoteHost'] = addr_port
          opts['ServiceArg'] = req.path
          opts['HTTPMethod'] = req.method
          opts['Blacklisted'] = true if blacklisted
          opts['Backtrace'] = Oboe::API.backtrace if Oboe::Config[:nethttp][:collect_backtraces]

          req['X-Trace'] = context unless blacklisted
        end

        # The actual net::http call
        resp = request_without_oboe(*args, &block)

        # Re-attach net::http edge unless blacklisted and is a valid X-Trace ID
        unless blacklisted
          xtrace = resp.get_fields('X-Trace')
          xtrace = xtrace[0] if xtrace and xtrace.is_a?(Array)

          if Oboe::XTrace.valid?(xtrace) and Oboe.tracing? 

            # Assure that we received back a valid X-Trace with the same task_id
            if task_id == Oboe::XTrace.task_id(xtrace)
              Oboe::Context.fromString(xtrace)
            else
              Oboe.logger.debug "Mismatched returned X-Trace ID : #{xtrace}"
            end
          end
        end
        
        opts['HTTPStatus'] = resp.code

        # Log the info event with the KVs in opts
        Oboe::API.log('net-http', 'info', opts)

        next resp
      end
    end

    alias request_without_oboe request
    alias request request_with_oboe

    Oboe.logger.info "[oboe/loading] Instrumenting net/http" if Oboe::Config[:verbose]
  end
end
