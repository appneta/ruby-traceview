# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

# Constants from liboboe
OBOE_TRACE_NEVER   = 0
OBOE_TRACE_ALWAYS  = 1
OBOE_TRACE_THROUGH = 2

OBOE_SAMPLE_RATE_SOURCE_FILE                   = 1
OBOE_SAMPLE_RATE_SOURCE_DEFAULT                = 2
OBOE_SAMPLE_RATE_SOURCE_OBOE                   = 3
OBOE_SAMPLE_RATE_SOURCE_LAST_OBOE              = 4
OBOE_SAMPLE_RATE_SOURCE_DEFAULT_MISCONFIGURED  = 5
OBOE_SAMPLE_RATE_SOURCE_OBOE_DEFAULT           = 6

OBOE_SETTINGS_FLAG_OK                          = 0x0
OBOE_SETTINGS_FLAG_INVALID                     = 0x1
OBOE_SETTINGS_FLAG_OVERRIDE                    = 0x2
OBOE_SETTINGS_FLAG_SAMPLE_START                = 0x4
OBOE_SETTINGS_FLAG_SAMPLE_THROUGH              = 0x8
OBOE_SETTINGS_FLAG_SAMPLE_THROUGH_ALWAYS       = 0x10
OBOE_SETTINGS_FLAG_SAMPLE_AVW_ALWAYS           = 0x20
OBOE_SETTINGS_FLAG_SAMPLE_BUCKET_ENABLED       = 0x40

# Masks for bitwise ops
ZERO_MASK = 0b0000000000000000000000000000

SAMPLE_RATE_MASK   = 0b0000111111111111111111111111
SAMPLE_SOURCE_MASK = 0b1111000000000000000000000000

ZERO_SAMPLE_RATE_MASK   = 0b1111000000000000000000000000
ZERO_SAMPLE_SOURCE_MASK = 0b0000111111111111111111111111

TV_STR_BLANK = ''.freeze
TV_STR_LAYER = 'Layer'.freeze
TV_STR_LABEL = 'Label'.freeze

# Used in tests to store local trace data
TRACE_FILE = '/tmp/traceview_traces.bson'.freeze

##
# This module is the base module for the various implementations of TraceView reporting.
# Current variations as of 2014-09-10 are a c-extension, JRuby (using TraceView Java
# instrumentation) and a Heroku c-extension (with embedded tracelyzer)
module TraceViewBase
  extend ::TraceView::ThreadLocal

  attr_accessor :reporter
  attr_accessor :loaded

  # We retrieve the app_token from liboboe once on boot and store it
  # here. It is then used when new traces are initiated.  See
  # lib/traceview/api/logging.rb
  attr_accessor :app_token

  # The instantiated Oboe::Context object created for the current
  # request. This is cleared everytime tracing completes (e.g. end
  # of a web request, end of a background job)
  thread_local :context

  # The Oboe::Context settings returned by the liboboe should_trace
  # method in the c extension.  This BSON string has values such as
  # tracing mode, sample rate from sample time etc...
  thread_local :context_settings

  # Used to track the active layer being traced
  thread_local :layer

  # Use to track the active operation being traced. Used for
  # instrumentation of operations that may be recursive.  We generally
  # shoot just to instrument the outermost layer.
  thread_local :layer_op

  # Semaphore used during the test suite to test
  # global config options.
  thread_local :config_lock

  # The following accessors indicate the incoming tracing state received
  # by the rack layer.  These are primarily used to identify state
  # between the Ruby and JTraceView instrumentation under JRuby.
  #
  # This is because that even though there may be an incoming
  # X-Trace request header, tracing may have already been started
  # by Joboe.  Such a scenario occurs when the application is being
  # hosted by a Java container (such as Tomcat or Glassfish) and
  # JTraceView has already initiated tracing.  In this case, we shouldn't
  # pickup the X-Trace context in the X-Trace header and we shouldn't
  # set the outgoing response X-Trace header or clear context.
  # Yeah I know.  Yuck.

  # Occurs only on Jruby.  Indicates that Joboe (the java instrumentation)
  # has already started tracing before it hit the JRuby instrumentation.
  thread_local :has_incoming_context

  # Indicates the existence of a valid X-Trace request header
  thread_local :has_xtrace_header

  # This indicates that this trace was continued from
  # an incoming X-Trace request header or in the case
  # of JRuby, a trace already started by JTraceView.
  thread_local :is_continued_trace

  ##
  # extended
  #
  # Invoked when this module is extended.
  # e.g. extend TraceViewBase
  #
  def self.extended(cls)
    cls.loaded = true

    # This gives us pretty accessors with questions marks at the end
    # e.g. is_continued_trace --> is_continued_trace?
    TraceView.methods.select { |m| m =~ /^is_|^has_/ }.each do |c|
      unless c =~ /\?$|=$/
        # TraceView.logger.debug "aliasing #{c}? to #{c}"
        alias_method "#{c}?", c
      end
    end
  end

  ##
  # pickup_context
  #
  # Determines whether we should pickup context
  # from an incoming X-Trace request header.  The answer
  # is generally yes but there are cases in JRuby under
  # Tomcat (or Glassfish etc.) where tracing may have
  # been already started by the Java instrumentation (Joboe)
  # in which case we don't want to do this.
  #
  def pickup_context?(xtrace)
    return false unless TraceView::XTrace.valid?(xtrace)

    if defined?(JRUBY_VERSION) && TraceView.tracing?
      return false
    else
      return true
    end
  end

  ##
  # tracing_layer?
  #
  # Queries the thread local variable about the current
  # layer being traced.  This is used in cases of recursive
  # operation tracing or one instrumented operation calling another.
  #
  def tracing_layer?(layer)
    TraceView.layer == layer.to_sym
  end

  ##
  # tracing_layer_op?
  #
  # Queries the thread local variable about the current
  # operation being traced.  This is used in cases of recursive
  # operation tracing or one instrumented operation calling another.
  #
  # <operation> can be a single symbol or an array of symbols that
  # will be checked against.
  #
  # In such cases, we only want to trace the outermost operation.
  #
  def tracing_layer_op?(operation)
    if operation.is_a?(Array)
      return operation.include?(TraceView.layer_op)
    else
      return TraceView.layer_op == operation.to_sym
    end
  end

  ##
  # entry_layer?
  #
  # Determines if the passed layer is an entry only
  # layer where we would want to use smart tracing.
  #
  # Entry only layers are layers that _only_ start traces
  # and doesn't directly receive incoming context such as
  # DelayedJob or Sidekiq workers.
  #
  def entry_layer?(layer)
    %w(delayed_job-worker sidekiq-worker resque-worker rabbitmq-consumer).include?(layer.to_s)
  end

  ##
  # Returns true if the tracing_mode is set to always.
  # False otherwise
  #
  def always?
    TraceView::Config[:tracing_mode].to_sym == :always
  end

  ##
  # Returns true if the tracing_mode is set to never.
  # False otherwise
  #
  def never?
    TraceView::Config[:tracing_mode].to_sym == :never
  end

  ##
  # Returns true if the tracing_mode is set to always or through.
  # False otherwise
  #
  def passthrough?
    [:always, :through].include?(TraceView::Config[:tracing_mode])
  end

  ##
  # Returns true if the tracing_mode is set to through.
  # False otherwise
  #
  def through?
    TraceView::Config[:tracing_mode].to_sym == :through
  end

  ##
  # Returns true if we are currently tracing a request
  # False otherwise
  #
  def tracing?
    return false if !TraceView.loaded || TraceView.never?
    TraceView::Context.isValid
  end

  def log(layer, label, options = {})
    # WARN: TraceView.log will be deprecated in a future release.  Please use TraceView::API.log instead.
    TraceView::API.log(layer, label, options)
  end

  def heroku?
    ENV.key?('TRACEVIEW_URL')
  end

  ##
  # Determines if we are running under a forking webserver
  #
  def forking_webserver?
    if (defined?(::Unicorn) && ($PROGRAM_NAME =~ /unicorn/i)) ||
       (defined?(::Puma) && ($PROGRAM_NAME =~ /puma/i))
      true
    else
      false
    end
  end

  ##
  # Debugging helper method
  #
  def pry!
    # Only valid for development or test environments
    env = ENV['RACK_ENV'] || ENV['RAILS_ENV']
    TV.logger.debug "env is #{env}"
    return unless %w(development test).include? env

    TV.logger.debug "ok doing the debugger thing"

    if RUBY_VERSION > '1.8.7'
      require 'pry-byebug'

      if defined?(PryByebug)
        Pry.commands.alias_command 'c', 'continue'
        Pry.commands.alias_command 's', 'step'
        Pry.commands.alias_command 'n', 'next'
        Pry.commands.alias_command 'f', 'finish'

        Pry::Commands.command(/^$/, 'repeat last command') do
          _pry_.run_command Pry.history.to_a.last
        end
      end

      binding.pry
    else
      require 'ruby-debug'; debugger
    end
  end

  ##
  # Indicates whether a supported framework is in use
  # or not
  #
  def framework?
    defined?(::Rails) || defined?(::Sinatra) || defined?(::Padrino) || defined?(::Grape)
  end

  ##
  # These methods should be implemented by the descendants
  # (Oboe_metal, JOboe_metal (JRuby), Heroku_metal)
  #
  def sample?(_opts = {})
    fail 'sample? should be implemented by metal layer.'
  end

  def log(_layer, _label, _options = {})
    fail 'log should be implemented by metal layer.'
  end
end

module TraceView
  extend TraceViewBase
end

# Setup an alias so we don't bug users
# about single letter capitalization
Traceview = TraceView
TV = TraceView
