# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module Oboe_metal
  include_package 'com.tracelytics.joboe'
  java_import 'com.tracelytics.joboe.LayerUtil'
  java_import 'com.tracelytics.joboe.SettingsReader'
  java_import 'com.tracelytics.joboe.Context'
  java_import 'com.tracelytics.joboe.Event'
  java_import 'com.tracelytics.agent.Agent'

  class Context
    class << self
      def toString
        getMetadata.toHexString
      end

      def fromString(xtrace)
        Context.setMetadata(xtrace)
      end

      def clear
        clearMetadata
      end

      def get
        getMetadata
      end
    end
  end

  class Event
    def self.metadataString(evt)
      evt.getMetadata.toHexString
    end
  end

  def UdpReporter
    Java::ComTracelyticsJoboe
  end

  module Metadata
    Java::ComTracelyticsJoboeMetaData
  end

  module Reporter
    class << self
      ##
      # start
      #
      # Start the TraceView Reporter
      #
      def start
        return unless TraceView.loaded

        if ENV.key?('TRACEVIEW_GEM_TEST')
          TraceView.reporter = Java::ComTracelyticsJoboe::ReporterFactory.getInstance.buildTestReporter(false)
        else
          TraceView.reporter = Java::ComTracelyticsJoboe::ReporterFactory.getInstance.buildUdpReporter
        end

        begin
          # Import the tracing mode and sample rate settings
          # from the Java agent (user configured in
          # /usr/local/tracelytics/javaagent.json when under JRuby)
          cfg = LayerUtil.getLocalSampleRate(nil, nil)

          if cfg.hasSampleStartFlag
            TraceView::Config.tracing_mode = :always
          elsif cfg.hasSampleThroughFlag
            TraceView::Config.tracing_mode = :through
          else
            TraceView::Config.tracing_mode = :never
          end

          TraceView.sample_rate = cfg.getSampleRate
          TraceView::Config.sample_rate = cfg.sampleRate
          TraceView::Config.sample_source = cfg.sampleRateSourceValue
        rescue => e
          TraceView.logger.debug "[traceview/debug] Couldn't retrieve/acces joboe sampleRateCfg"
          TraceView.logger.debug "[traceview/debug] #{e.message}"
        end

        # Only report __Init from here if we are not instrumenting a framework.
        # Otherwise, frameworks will handle reporting __Init after full initialization
        unless defined?(::Rails) || defined?(::Sinatra) || defined?(::Padrino) || defined?(::Grape)
          TraceView::API.report_init unless ENV.key?('TRACEVIEW_GEM_TEST')
        end
      end

      ##
      # restart
      #
      # This is a nil method for TraceView under Java.  It is maintained only
      # for compability across interfaces.
      #
      def restart
        TraceView.logger.warn "[traceview/reporter] Reporter.restart isn't supported under JRuby"
      end

      ##
      # clear_all_traces
      #
      # Truncates the trace output file to zero
      #
      def clear_all_traces
        TraceView.reporter.reset if TraceView.loaded
      end

      ##
      # get_all_traces
      #
      # Retrieves all traces written to the trace file
      #
      def get_all_traces
        return [] unless TraceView.loaded

        # Joboe TestReporter returns a Java::ComTracelyticsExtEbson::DefaultDocument
        # document for traces which doesn't correctly support things like has_key? which
        # raises an unhandled exception on non-existent key (duh).  Here we convert
        # the Java::ComTracelyticsExtEbson::DefaultDocument doc to a pure array of Ruby
        # hashes
        traces = []
        TraceView.reporter.getSentEventsAsBsonDocument.to_a.each do |e|
          t = {}
          e.each_pair { |k, v|
            t[k] = v
          }
          traces << t
        end
        traces
      end

      def sendReport(evt)
        evt.report(TraceView.reporter)
      end
    end
  end
end

module TraceView
  extend TraceViewBase
  include Oboe_metal

  class << self
    def sample?(opts = {})
      begin
        # Return false if no-op mode
        return false unless TraceView.loaded

        # Validation to make Joboe happy.  Assure that we have the KVs and that they
        # are not empty strings.
        opts[:layer]  = nil      if opts[:layer].is_a?(String)      && opts[:layer].empty?
        opts[:xtrace] = nil      if opts[:xtrace].is_a?(String)     && opts[:xtrace].empty?
        opts['X-TV-Meta'] = nil  if opts['X-TV-Meta'].is_a?(String) && opts['X-TV-Meta'].empty?

        opts[:layer]      ||= nil
        opts[:xtrace]     ||= nil
        opts['X-TV-Meta'] ||= nil

        url = opts[:URL] || opts[:JobName] || nil

        TraceView.context_settings = Java::ComTracelyticsJoboe::LayerUtil.shouldTrace(opts[:layer].to_s, { 'X-Trace' => opts[:xtrace], 'X-TV-Meta' => opts['X-TV-Meta'] }, url)

        TV.context_settings.empty? ? false : true
      rescue => e
        TraceView.logger.debug "[traceview/debug] #{e.message}"
        false
      end
    end

    def set_tracing_mode(_mode)
      TraceView.logger.warn 'When using JRuby set the tracing mode in /usr/local/tracelytics/javaagent.json instead'
    end

    def set_sample_rate(_rate)
      # N/A
    end
  end
end

# Make sure that we have a joboe with new app token support
unless defined?(Java::ComTracelyticsJoboe::LayerUtil) &&
  Java::ComTracelyticsJoboe::LayerUtil.respond_to?(:shouldTrace)
  # LoadError will be captured by lib/traceview.rb and
  # the gem will be put in no-op mode
  raise LoadError
end

# Assure that the Joboe Java Agent was loaded via premain
case Java::ComTracelyticsAgent::Agent.getStatus
  when Java::ComTracelyticsAgent::Agent::AgentStatus::INITIALIZED_SUCCESSFUL
    TraceView.app_token = Java::ComTracelyticsJoboe::LiboboeUtil.getHostAppToken()
    TraceView.loaded = true

  when Java::ComTracelyticsAgent::Agent::AgentStatus::INITIALIZED_FAILED
    TraceView.loaded = false
    $stderr.puts '=============================================================='
    $stderr.puts 'TraceView Java Agent not initialized properly.'
    $stderr.puts 'Possibly misconfigured?  Going into no-op mode.'
    $stderr.puts 'http://docs.traceview.solarwinds.com/Instrumentation/other-instrumentation-modules.html#jruby'
    $stderr.puts '=============================================================='

  when Java::ComTracelyticsAgent::Agent::AgentStatus::UNINITIALIZED
    TraceView.loaded = false
    $stderr.puts '=============================================================='
    $stderr.puts 'TraceView Java Agent not loaded. Going into no-op mode.'
    $stderr.puts 'To preload the TraceView java agent see:'
    $stderr.puts 'http://docs.traceview.solarwinds.com/Instrumentation/other-instrumentation-modules.html#jruby'
    $stderr.puts '=============================================================='

  else
    TraceView.loaded = false
end
