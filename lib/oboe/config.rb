# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  ##
  # This module exposes a nested configuration hash that can be used to
  # configure and/or modify the functionality of the oboe gem.
  #
  # Use Oboe::Config.show to view the entire nested hash.
  #
  module Config
    @@config = {}

    @@instrumentation = [:action_controller, :action_view, :active_record,
                         :cassandra, :dalli, :em_http_request, :eventmachine,
                         :faraday, :grape, :nethttp, :memcached, :memcache,
                         :mongo, :moped, :rack, :redis, :resque, :sequel,
                         :typhoeus]
    ##
    # Return the raw nested hash.
    #
    def self.show
      @@config
    end

    def self.initialize(_data = {})
      # Setup default instrumentation values
      @@instrumentation.each do |k|
        @@config[k] = {}
        @@config[k][:enabled] = true
        @@config[k][:collect_backtraces] = false
        @@config[k][:log_args] = true
      end

      # Beta instrumentation disabled by default
      Oboe::Config[:em_http_request][:enabled] = false
      Oboe::Config[:eventmachine][:enabled] = false

      # Set collect_backtraces defaults
      Oboe::Config[:action_controller][:collect_backtraces] = true
      Oboe::Config[:active_record][:collect_backtraces] = true
      Oboe::Config[:action_view][:collect_backtraces] = true
      Oboe::Config[:cassandra][:collect_backtraces] = true
      Oboe::Config[:dalli][:collect_backtraces] = false
      Oboe::Config[:faraday][:collect_backtraces] = false
      Oboe::Config[:grape][:collect_backtraces] = true
      Oboe::Config[:em_http_request][:collect_backtraces] = false
      Oboe::Config[:eventmachine][:collect_backtraces] = false
      Oboe::Config[:memcache][:collect_backtraces] = false
      Oboe::Config[:memcached][:collect_backtraces] = false
      Oboe::Config[:mongo][:collect_backtraces] = true
      Oboe::Config[:moped][:collect_backtraces] = true
      Oboe::Config[:nethttp][:collect_backtraces] = true
      Oboe::Config[:redis][:collect_backtraces] = false
      Oboe::Config[:resque][:collect_backtraces] = true
      Oboe::Config[:sequel][:collect_backtraces] = true
      Oboe::Config[:typhoeus][:collect_backtraces] = false

      # Special instrument specific flags
      #
      # :link_workers - associates enqueue operations with the jobs they queue by piggybacking
      #                 an additional argument that is stripped prior to job proecessing
      #                 !!Note: Make sure both the queue side and the Resque workers are instrumented
      #                 or jobs will fail
      #                 (Default: false)
      @@config[:resque][:link_workers] = false

      # Setup an empty host blacklist (see: Oboe::API::Util.blacklisted?)
      @@config[:blacklist] = []

      # Access Key is empty until loaded from config file or env var
      @@config[:access_key] = ''

      # The oboe Ruby client has the ability to sanitize query literals
      # from SQL statements.  By default this is disabled.  Enable to
      # avoid collecting and reporting query literals to TraceView.
      @@config[:sanitize_sql] = false

      # Do Not Trace
      # These two values allow you to configure specific URL patterns to
      # never be traced.  By default, this is set to common static file
      # extensions but you may want to customize this list for your needs.
      #
      # dnt_regexp and dnt_opts is passed to Regexp.new to create
      # a regular expression object.  That is then used to match against
      # the incoming request path.
      #
      # The path string originates from the rack layer and is retrieved
      # as follows:
      #
      #   req = ::Rack::Request.new(env)
      #   path = URI.unescape(req.path)
      #
      # Usage:
      #   Oboe::Config[:dnt_regexp] = "lobster$"
      #   Oboe::Config[:dnt_opts]   = Regexp::IGNORECASE
      #
      # This will ignore all requests that end with the string lobster
      # regardless of case
      #
      # Requests with positive matches (non nil) will not be traced.
      # See lib/oboe/util.rb: Oboe::Util.static_asset?
      #
      @@config[:dnt_regexp] = "\.(jpg|jpeg|gif|png|ico|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|bmp|rtf|js|flv|swf|ttf|woff|svg|less)$"
      @@config[:dnt_opts]   = Regexp::IGNORECASE

      if ENV.key?('OPENSHIFT_TRACEVIEW_TLYZER_IP')
        # We're running on OpenShift
        @@config[:tracing_mode] = 'always'
        @@config[:reporter_host] = ENV['OPENSHIFT_TRACEVIEW_TLYZER_IP']
        @@config[:reporter_port] = ENV['OPENSHIFT_TRACEVIEW_TLYZER_PORT']
      else
        # The default configuration
        @@config[:tracing_mode] = 'through'
        @@config[:reporter_host] = '127.0.0.1'
        @@config[:reporter_port] = '7831'
      end

      @@config[:verbose] = ENV.key?('OBOE_GEM_VERBOSE') ? true : false
    end

    def self.update!(data)
      data.each do |key, value|
        self[key] = value
      end
    end

    def self.merge!(data)
      self.update!(data)
    end

    def self.[](key)
      @@config[key.to_sym]
    end

    def self.[]=(key, value)
      @@config[key.to_sym] = value

      if key == :sampling_rate
        Oboe.logger.warn 'sampling_rate is not a supported setting for Oboe::Config.  ' \
                         'Please use :sample_rate.'
      end

      if key == :sample_rate
        unless value.is_a?(Integer) || value.is_a?(Float)
          fail 'oboe :sample_rate must be a number between 1 and 1000000 (1m)'
        end

        # Validate :sample_rate value
        unless value.between?(1, 1e6)
          fail 'oboe :sample_rate must be between 1 and 1000000 (1m)'
        end

        # Assure value is an integer
        @@config[key.to_sym] = value.to_i

        Oboe.set_sample_rate(value) if Oboe.loaded
      end

      # Update liboboe if updating :tracing_mode
      if key == :tracing_mode
        Oboe.set_tracing_mode(value) if Oboe.loaded
      end
    end

    def self.instrumentation_list
      @@instrumentation
    end

    def self.method_missing(sym, *args)
      if sym.to_s =~ /(.+)=$/
        self[$1] = args.first
      else
        unless @@config.key?(sym)
          Oboe.logger.warn "[oboe/warn] Unknown method call on Oboe::Config: #{sym}"
        end
        self[sym]
      end
    end
  end
end

Oboe::Config.initialize
