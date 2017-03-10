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
          Oboe_metal::Context.init(ENV['TRACEVIEW_CUUID'].to_s)

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

      rv = TraceView::Context.sampleRequest(layer, xtrace, tv_meta)

      if rv == 0
        if ENV.key?('TRACEVIEW_GEM_TEST')
          # When in test, always trace and don't clear
          # the stored sample rate/source
          TraceView.sample_rate ||= -1
          TraceView.sample_source ||= -1
          true
        else
          TraceView.sample_rate = -1
          TraceView.sample_source = -1
          false
        end
      else
        # liboboe version > 1.3.1 returning a bit masked integer with SampleRate and
        # source embedded
        TraceView.sample_rate = (rv & SAMPLE_RATE_MASK)
        TraceView.sample_source = (rv & SAMPLE_SOURCE_MASK) >> 24
        true
      end
    rescue StandardError => e
      TraceView.logger.debug "[oboe/error] sample? error: #{e.inspect}"
      false
    end

    def set_tracing_mode(mode)
      return unless TraceView.loaded

      value = mode.to_sym

      case value
      when :never
        TraceView::Context.setTracingMode(OBOE_TRACE_NEVER)

      when :always
        TraceView::Context.setTracingMode(OBOE_TRACE_ALWAYS)

      when :through
        TraceView::Context.setTracingMode(OBOE_TRACE_THROUGH)

      else
        TraceView.logger.fatal "[oboe/error] Invalid tracing mode set: #{mode}"
        TraceView::Context.setTracingMode(OBOE_TRACE_THROUGH)
      end
    end

    def set_sample_rate(rate)
      return unless TraceView.loaded

      # Update liboboe with the new SampleRate value
      TraceView::Context.setDefaultSampleRate(rate.to_i)
    end
  end
end
# rubocop:enable Style/Documentation

TraceView.loaded = true
TraceView.config_lock = Mutex.new
