# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

# Backward compatibility for supported environment variables
ENV['TRACEVIEW_GEM_VERBOSE'] = ENV['OBOE_GEM_VERBOSE'] if ENV.key?('OBOE_GEM_VERBOSE')
ENV['TRACEVIEW_GEM_TEST']    = ENV['OBOE_GEM_TEST']    if ENV.key?('OBOE_GEM_TEST')

begin
  require 'traceview/version'
  require 'traceview/thread_local'
  require 'traceview/logger'
  require 'traceview/util'
  require 'traceview/xtrace'
  require 'traceview/support'
  require 'traceview/config'

  # If OboeHeroku is already defined then we are in a PaaS environment
  # with an alternate metal (see the oboe-heroku gem)
  unless defined?(OboeHeroku)
    require 'traceview/base'

    begin
      if RUBY_PLATFORM == 'java'
        require '/usr/local/tracelytics/tracelyticsagent.jar'
        require 'joboe_metal'
      else
        require "oboe_metal.so"
        require "oboe_metal.rb"
      end
    rescue LoadError
      TraceView.loaded = false

      unless ENV['RAILS_GROUP'] == 'assets' or ENV['IGNORE_TRACEVIEW_WARNING']
        $stderr.puts '=============================================================='
        $stderr.puts 'Missing or outdated TraceView libraries.  Tracing disabled.'
        $stderr.puts 'See: http://bit.ly/1DaNOjw'
        $stderr.puts '=============================================================='
      end
    end
  end

  require 'traceview/loading'
  require 'traceview/legacy_method_profiling'
  require 'traceview/method_profiling'

  if TraceView.loaded
    require 'traceview/instrumentation'

    # Frameworks
    require 'traceview/frameworks/rails'
    require 'traceview/frameworks/sinatra'
    require 'traceview/frameworks/padrino'
    require 'traceview/frameworks/grape'
  end

  # Load Ruby module last.  If there is no framework detected,
  # it will load all of the Ruby instrumentation
  require 'traceview/ruby'
  require 'oboe/backward_compatibility'

  require 'traceview/test' if ENV['TRACEVIEW_GEM_TEST']
rescue => e
  $stderr.puts "[traceview/error] Problem loading: #{e.inspect}"
  $stderr.puts e.backtrace
end
