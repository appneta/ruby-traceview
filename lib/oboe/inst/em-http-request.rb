module Oboe
  module Inst
    module EventMachine
      module HttpConnection
        def setup_request_with_oboe(*args, &block)
          report_kvs = {}
          context = Oboe::Context.toString
          blacklisted = Oboe::API.blacklisted?(@uri)

          begin
            report_kvs['IsService'] = 1
            report_kvs['RemoteURL'] = @uri
            report_kvs['HTTPMethod'] = args[0]
            report_kvs['Blacklisted'] = true if blacklisted

            if Oboe::Config[:em_http_request][:collect_backtraces]
              report_kvs[:Backtrace] = Oboe::API.backtrace
            end
          rescue => e
            Oboe.logger.debug "[oboe/debug] em-http-request KV error: #{e.inspect}"
          end

          ::Oboe::API.log_entry('em-http-request', report_kvs)
          client = setup_request_without_oboe(*args, &block)
          client.req.headers['X-Trace'] = context unless blacklisted
          client
        end
      end

      module HttpClient
        def parse_response_header_with_oboe(*args, &block)
          report_kvs = {}
          xtrace = nil
          blacklisted = Oboe::API.blacklisted?(@uri)

          begin
            report_kvs[:HTTPStatus] = args[2]
            report_kvs[:Async] = 1
          rescue => e
            Oboe.logger.debug "[oboe/debug] em-http-request KV error: #{e.inspect}"
          end

          parse_response_header_without_oboe(*args, &block)

          unless blacklisted
            headers = args[0]
            context = Oboe::Context.toString
            task_id = Oboe::XTrace.task_id(context)

            if headers.is_a?(Hash) && headers.key?('X-Trace')
              xtrace = headers['X-Trace']
            end

            if Oboe::XTrace.valid?(xtrace) && Oboe.tracing?

              # Assure that we received back a valid X-Trace with the same task_id
              if task_id == Oboe::XTrace.task_id(xtrace)
                Oboe::Context.fromString(xtrace)
              else
                Oboe.logger.debug "Mismatched returned X-Trace ID : #{xtrace}"
              end
            end

          end

          ::Oboe::API.log_exit('em-http-request', report_kvs)
        end
      end
    end
  end
end

if RUBY_VERSION >= '1.9'
  if defined?(::EventMachine::HttpConnection) && defined?(::EventMachine::HttpClient) && Oboe::Config[:em_http_request][:enabled]
    Oboe.logger.info "[oboe/loading] Instrumenting em-http-request"

    class ::EventMachine::HttpConnection
      include Oboe::Inst::EventMachine::HttpConnection

      if method_defined?(:setup_request)
        class_eval 'alias :setup_request_without_oboe :setup_request'
        class_eval 'alias :setup_request :setup_request_with_oboe'
      else
        Oboe.logger.warn '[oboe/loading] Couldn\'t properly instrument em-http-request (:setup_request).  Partial traces may occur.'
      end
    end

    class ::EventMachine::HttpClient
      include Oboe::Inst::EventMachine::HttpClient

      if method_defined?(:parse_response_header)
        class_eval 'alias :parse_response_header_without_oboe :parse_response_header'
        class_eval 'alias :parse_response_header :parse_response_header_with_oboe'
      else
        Oboe.logger.warn '[oboe/loading] Couldn\'t properly instrument em-http-request (:parse_response_header).  Partial traces may occur.'
      end
    end
  end
end
