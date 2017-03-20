# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'thread'

# Disable docs and Camelcase warns since we're implementing
# an interface here.  See OboeBase for details.
# rubocop:disable Style/Documentation, Style/MethodName
module TraceView
  extend TraceViewBase
  include Oboe_metal

  class Reporter
    class << self
      ##
      # start
      #
      # Start the TraceView Reporter
      #
      def start
        return unless TraceView.loaded

        begin
          Oboe_metal::Context.init

          if ENV.key?('TRACEVIEW_GEM_TEST')
            TraceView.reporter = TraceView::FileReporter.new(TRACE_FILE)
          else
            TraceView.reporter = TraceView::UdpReporter.new(TraceView::Config[:reporter_host], TraceView::Config[:reporter_port])
          end

          # Only report __Init from here if we are not instrumenting a framework.
          # Otherwise, frameworks will handle reporting __Init after full initialization
          unless defined?(::Rails) || defined?(::Sinatra) || defined?(::Padrino) || defined?(::Grape)
            TraceView::API.report_init
          end

        rescue => e
          $stderr.puts e.message
          raise
        end
      end
      alias :restart :start

      ##
      # sendReport
      #
      # Send the report for the given event
      #
      def sendReport(evt)
        TraceView.reporter.sendReport(evt)
      end

      ##
      # clear_all_traces
      #
      # Truncates the trace output file to zero
      #
      def clear_all_traces
        File.truncate(TRACE_FILE, 0)
      end

      ##
      # get_all_traces
      #
      # Retrieves all traces written to the trace file
      #
      def get_all_traces
        io = File.open(TRACE_FILE, 'r')
        contents = io.readlines(nil)

        return contents if contents.empty?

        traces = []

        #
        # We use Gem.loaded_spec because older versions of the bson
        # gem didn't even have a version embedded in the gem.  If the
        # gem isn't in the bundle, it should rightfully error out
        # anyways.
        #
        if Gem.loaded_specs['bson'].version.to_s < '4.0'
          s = StringIO.new(contents[0])

          until s.eof?
            traces << if ::BSON.respond_to? :read_bson_document
                        BSON.read_bson_document(s)
                      else
                        BSON::Document.from_bson(s)
                      end
          end
        else
          bbb = BSON::ByteBuffer.new(contents[0])
          until bbb.length == 0
            traces << Hash.from_bson(bbb)
          end
        end

        traces
      end
    end
  end

  class Event
    def self.metadataString(evt)
      evt.metadataString
    end
  end

  class << self
    def sample?(opts = {})
      # Return false if no-op mode
      return false unless TraceView.loaded

      # Assure defaults since SWIG enforces Strings
      layer   = opts[:layer]      ? opts[:layer].to_s.strip.freeze : TV_STR_BLANK
      xtrace  = opts[:xtrace]     ? opts[:xtrace].to_s.strip       : TV_STR_BLANK
      tv_meta = opts['X-TV-Meta'] ? opts['X-TV-Meta'].to_s.strip   : TV_STR_BLANK

      flags = nil
      case TV::Config[:tracing_mode].to_sym
      when :always
        flags = OBOE_SETTINGS_FLAG_SAMPLE_START | OBOE_SETTINGS_FLAG_SAMPLE_THROUGH_ALWAYS | OBOE_SETTINGS_FLAG_SAMPLE_AVW_ALWAYS
      when :through
        flags = OBOE_SETTINGS_FLAG_SAMPLE_THROUGH_ALWAYS
      else
        flags = 0
      end

      TraceView::Config[:sample_rate] ||= -1
      url = opts[:URL] || opts[:JobName] || TV_STR_BLANK
      token = TraceView::Config[:app_token] ? TraceView::Config[:app_token] : TV_STR_BLANK

      # Instantiate a new tracing context with current settings (if it doesn't exist)
      TV.context[layer] ||= Oboe::Context.new(layer, token.to_s, flags, TraceView::Config[:sample_rate])
      kvstring = (tv_meta.empty? ? '' : "AVW=#{tv_meta}")

      # Ask liboboe if we should trace this run
      TraceView.context_settings = TV.context[layer].should_trace(xtrace, url, kvstring)

      # True if non-empty BSON string.  False otherwise
      (TV.context_settings.is_a?(String) && !TV.context_settings.empty?) ? true : false
    rescue StandardError => e
      TraceView.logger.debug "[oboe/error] sample? error: #{e.inspect}"
      TraceView.logger.debug e.backtrace.join('\n')
      false
    end
  end
end
# rubocop:enable Style/Documentation

if defined?(Oboe_metal::Context) && Oboe_metal::Context.respond_to?(:get_apptoken)
  # Load the app token from liboboe
  TraceView.app_token ||= Oboe_metal::Context.get_apptoken
  TraceView.loaded = true
else
  TraceView.loaded = false
end

TraceView.context = {}
TraceView.config_lock = Mutex.new
