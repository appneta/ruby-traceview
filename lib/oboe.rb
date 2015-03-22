# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

begin
  require 'oboe/version'
  require 'oboe/thread_local'
  require 'oboe/logger'
  require 'oboe/util'
  require 'oboe/xtrace'
  require 'oboe/support'

  # If OboeHeroku is already defined then we are in a PaaS environment
  # with an alternate metal (see the oboe-heroku gem)
  unless defined?(OboeHeroku)
    require 'oboe/base'

    begin
      if RUBY_PLATFORM == 'java'
        require '/usr/local/tracelytics/tracelyticsagent.jar'
        require 'joboe_metal'
      else
        require "oboe_metal.so"
        require "oboe_metal.rb"
      end
    rescue LoadError
      Oboe.loaded = false

      unless ENV['RAILS_GROUP'] == 'assets' or ENV['IGNORE_TRACEVIEW_WARNING']
        $stderr.puts '=============================================================='
        $stderr.puts 'Missing TraceView libraries.  Tracing disabled.'
        $stderr.puts 'See: http://bit.ly/1DaNOjw'
        $stderr.puts '=============================================================='
      end
    end
  end

  require 'oboe/config'
  require 'oboe/loading'

  if Oboe.loaded
    require 'oboe/method_profiling'
    require 'oboe/collector'
    require 'oboe/instrumentation'

    # Frameworks
    require 'oboe/frameworks/rails'
    require 'oboe/frameworks/sinatra'
    require 'oboe/frameworks/padrino'
    require 'oboe/frameworks/grape'
  end

  # Load Ruby module last.  If there is no framework detected,
  # it will load all of the Ruby instrumentation
  require 'oboe/ruby'
rescue => e
  $stderr.puts "[oboe/error] Problem loading: #{e.inspect}"
  $stderr.puts e.backtrace
end
