# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module TraceView
  ##
  # This module exposes a nested configuration hash that can be used to
  # configure and/or modify the functionality of the traceview gem.
  #
  # Use TraceView::Config.show to view the entire nested hash.
  #
  module Config
    @@config = {}

    @@instrumentation = [:action_controller, :action_controller_api, :action_view,
                         :active_record, :bunnyclient, :bunnyconsumer, :cassandra, :curb,
                         :dalli, :delayed_jobclient, :delayed_jobworker,
                         :em_http_request, :excon, :faraday, :grape,
                         :httpclient, :nethttp, :memcached,
                         :memcache, :mongo, :moped, :rack, :redis,
                         :resqueclient, :resqueworker, :rest_client,
                         :sequel, :sidekiqclient, :sidekiqworker, :typhoeus]

    # Subgrouping of instrumentation
    @@http_clients = [:curb, :excon, :em_http_request, :faraday, :httpclient, :nethttp, :rest_client, :typhoeus]

    ##
    # Return the raw nested hash.
    #
    def self.show
      @@config
    end

    ##
    # initialize
    #
    # Initializer method to set everything up with a
    # default configuration.
    #
    # rubocop:disable Metrics/AbcSize
    def self.initialize(_data = {})
      # Setup default instrumentation values
      @@instrumentation.each do |k|
        @@config[k] = {}
        @@config[k][:enabled] = true
        @@config[k][:collect_backtraces] = false
        @@config[k][:log_args] = true
      end

      # Beta instrumentation disabled by default
      TraceView::Config[:em_http_request][:enabled] = false

      # Set collect_backtraces defaults
      TraceView::Config[:action_controller][:collect_backtraces] = false
      TraceView::Config[:action_controller_api][:collect_backtraces] = false
      TraceView::Config[:active_record][:collect_backtraces] = true
      TraceView::Config[:bunnyclient][:collect_backtraces] = false
      TraceView::Config[:bunnyconsumer][:collect_backtraces] = false
      TraceView::Config[:action_view][:collect_backtraces] = true
      TraceView::Config[:cassandra][:collect_backtraces] = true
      TraceView::Config[:curb][:collect_backtraces] = true
      TraceView::Config[:dalli][:collect_backtraces] = false
      TraceView::Config[:delayed_jobclient][:collect_backtraces] = false
      TraceView::Config[:delayed_jobworker][:collect_backtraces] = false
      TraceView::Config[:em_http_request][:collect_backtraces] = false
      TraceView::Config[:excon][:collect_backtraces] = true
      TraceView::Config[:faraday][:collect_backtraces] = false
      TraceView::Config[:grape][:collect_backtraces] = true
      TraceView::Config[:httpclient][:collect_backtraces] = true
      TraceView::Config[:memcache][:collect_backtraces] = false
      TraceView::Config[:memcached][:collect_backtraces] = false
      TraceView::Config[:mongo][:collect_backtraces] = true
      TraceView::Config[:moped][:collect_backtraces] = true
      TraceView::Config[:nethttp][:collect_backtraces] = true
      TraceView::Config[:rack][:collect_backtraces] = false
      TraceView::Config[:redis][:collect_backtraces] = false
      TraceView::Config[:resqueclient][:collect_backtraces] = true
      TraceView::Config[:resqueworker][:collect_backtraces] = false
      TraceView::Config[:rest_client][:collect_backtraces] = false
      TraceView::Config[:sequel][:collect_backtraces] = true
      TraceView::Config[:sidekiqclient][:collect_backtraces] = false
      TraceView::Config[:sidekiqworker][:collect_backtraces] = false
      TraceView::Config[:typhoeus][:collect_backtraces] = false

      # Legacy Resque config support.  To be removed in a future version
      @@config[:resque] = {}

      # Setup an empty host blacklist (see: TraceView::API::Util.blacklisted?)
      @@config[:blacklist] = []

      # Access Key is empty until loaded from config file or env var
      @@config[:access_key] = ''

      # Logging of outgoing HTTP query args
      #
      # This optionally disables the logging of query args of outgoing
      # HTTP clients such as Net::HTTP, excon, typhoeus and others.
      #
      # This flag is global to all HTTP client instrumentation.
      #
      # To configure this on a per instrumentation basis, set this
      # option to true and instead disable the instrumenstation specific
      # option <tt>log_args</tt>:
      #
      #   TraceView::Config[:nethttp][:log_args] = false
      #   TraceView::Config[:excon][:log_args] = false
      #   TraceView::Config[:typhoeus][:log_args] = true
      #
      @@config[:include_url_query_params] = true

      # Logging of incoming HTTP query args
      #
      # This optionally disables the logging of incoming URL request
      # query args.
      #
      # This flag is global and currently only affects the Rack
      # instrumentation which reports incoming request URLs and
      # query args by default.
      @@config[:include_remote_url_params] = true

      # The TraceView Ruby gem has the ability to sanitize query literals
      # from SQL statements.  By default this is disabled.  Enable to
      # avoid collecting and reporting query literals to TraceView.
      @@config[:sanitize_sql] = false

      # The regular expression used to sanitize SQL.
      @@config[:sanitize_sql_regexp] = '(\'[\s\S][^\']*\'|\d*\.\d+|\d+|NULL)'
      @@config[:sanitize_sql_opts]   = Regexp::IGNORECASE

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
      #   TraceView::Config[:dnt_regexp] = "lobster$"
      #   TraceView::Config[:dnt_opts]   = Regexp::IGNORECASE
      #
      # This will ignore all requests that end with the string lobster
      # regardless of case
      #
      # Requests with positive matches (non nil) will not be traced.
      # See lib/traceview/util.rb: TraceView::Util.static_asset?
      #
      @@config[:dnt_regexp] = '\.(jpg|jpeg|gif|png|ico|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|bmp|rtf|js|flv|swf|ttf|woff|svg|less)$'
      @@config[:dnt_opts]   = Regexp::IGNORECASE

      # In Rails, raised exceptions with rescue handlers via
      # <tt>rescue_from</tt> are not reported to the TraceView
      # dashboard by default.  Setting this value to true will
      # report all raised exception regardless.
      #
      @@config[:report_rescued_errors] = false

      # By default, the curb instrumentation will not link
      # outgoing requests with remotely instrumented
      # webservers (aka cross host tracing).  This is because the
      # instrumentation can't detect if the independent libcurl
      # instrumentation is in use or not.
      #
      # If you're sure that it's not in use/installed, then you can
      # enable cross host tracing for the curb HTTP client
      # here.  Set TraceView::Config[:curb][:cross_host] to true
      # to enable.
      #
      # Alternatively, if you would like to install the separate
      # libcurl instrumentation, see here:
      # http://docs.traceview.solarwinds.com/Instrumentation/other-instrumentation-modules.html#libcurl
      #
      @@config[:curb][:cross_host] = false

      # The bunny (Rabbitmq) instrumentation can optionally report
      # Controller and Action values to allow filtering of bunny
      # message handling in # the UI.  Use of Controller and Action
      # for filters is temporary until the UI is updated with
      # additional filters.
      #
      # These values identify which properties of
      # Bunny::MessageProperties to report as Controller
      # and Action.  The defaults are to report :app_id (as
      # Controller) and :type (as Action).  If these values
      # are not specified in the publish, then nothing
      # will be reported here.
      #
      @@config[:bunnyconsumer][:controller] = :app_id
      @@config[:bunnyconsumer][:action] = :type

      # Environment support for OpenShift.
      if ENV.key?('OPENSHIFT_TRACEVIEW_TLYZER_IP')
        # We're running on OpenShift
        @@config[:tracing_mode] = :always
        @@config[:reporter_host] = ENV['OPENSHIFT_TRACEVIEW_TLYZER_IP']
        @@config[:reporter_port] = ENV['OPENSHIFT_TRACEVIEW_TLYZER_PORT']
      else
        # The default configuration
        @@config[:tracing_mode] = :through
        @@config[:reporter_host] = '127.0.0.1'
        @@config[:reporter_port] = '7831'
      end

      @@config[:verbose] = ENV.key?('TRACEVIEW_GEM_VERBOSE') ? true : false
    end
    # rubocop:enable Metrics/AbcSize

    def self.update!(data)
      data.each do |key, value|
        self[key] = value
      end
    end

    def self.merge!(data)
      update!(data)
    end

    def self.[](key)
      if key == :resque
        TraceView.logger.warn '[traceview/warn] :resque config is deprecated.  It is now split into :resqueclient and :resqueworker.'
        TraceView.logger.warn "[traceview/warn] Called from #{Kernel.caller[0]}"
      end

      @@config[key.to_sym]
    end

    ##
    # []=
    #
    # Config variable assignment method.  Here we validate and store the
    # assigned value(s) and trigger any secondary action needed.
    #
    # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
    def self.[]=(key, value)
      @@config[key.to_sym] = value

      if key == :sampling_rate
        TraceView.logger.warn 'sampling_rate is not a supported setting for TraceView::Config.  ' \
                         'Please use :sample_rate.'

      elsif key == :sample_rate
        unless value.is_a?(Integer) || value.is_a?(Float)
          fail 'traceview :sample_rate must be a number between 1 and 1000000 (1m)'
        end

        # Validate :sample_rate value
        unless value.between?(-1, 1e6)
          fail 'traceview :sample_rate must be between 1 and 1000000 (1m)'
        end

        # Assure value is an integer
        @@config[key.to_sym] = value.to_i

      elsif key == :action_blacklist
        TraceView.logger.warn "[traceview/unsupported] :action_blacklist has been deprecated and no longer functions."

      elsif key == :resque
        TraceView.logger.warn "[traceview/warn] :resque config is deprecated.  It is now split into :resqueclient and :resqueworker."
        TraceView.logger.warn "[traceview/warn] Called from #{Kernel.caller[0]}"

      elsif key == :include_url_query_params
        # Obey the global flag and update all of the per instrumentation
        # <tt>:log_args</tt> values.
        @@config[:rack][:log_args] = value

      elsif key == :include_remote_url_params
        # Obey the global flag and update all of the per instrumentation
        # <tt>:log_args</tt> values.
        @@http_clients.each do |i|
          @@config[i][:log_args] = value
        end
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity

    def self.method_missing(sym, *args)
      class_var_name = "@@#{sym}"

      if sym.to_s =~ /(.+)=$/
        self[$1] = args.first
      else
        # Try part of the @@config hash first
        if @@config.key?(sym)
          self[sym]

        # Then try as a class variable
        elsif self.class_variable_defined?(class_var_name.to_sym)
          self.class_eval(class_var_name)

        # Congrats - You've won a brand new nil...
        else
          nil
        end
      end
    end
  end
end

TraceView::Config.initialize
