# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

# Make sure Set is loaded if possible.
begin
  require 'set'
rescue LoadError
  class Set; end
end

module TraceView
  module API
    ##
    # This modules provides the X-Trace logging facilities.
    #
    module Logging
      ##
      # Public: Report an event in an active trace.
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +label+ - The label for the reported event. See API documentation for reserved labels and usage.
      # * +opts+ - A hash containing key/value pairs that will be reported along with this event (optional).
      #
      # ==== Example
      #
      #   TraceView::API.log('logical_layer', 'entry')
      #   TraceView::API.log('logical_layer', 'info', { :list_length => 20 })
      #   TraceView::API.log('logical_layer', 'exit')
      #
      # Returns nothing.
      def log(layer, label, opts = {})
        return unless TraceView.loaded

        log_event(layer, label, TraceView::Context.createEvent, opts)
      end

      ##
      # Public: Report an exception.
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +exn+ - The exception to report
      # * +kvs+ - Custom params if you want to log extra information
      #
      # ==== Example
      #
      #   begin
      #     my_iffy_method
      #   rescue Exception => e
      #     TraceView::API.log_exception('rails', e, { user: user_id })
      #     raise
      #   end
      #
      # Returns nothing.
      def log_exception(layer, exn, kvs = {})
        return if !TraceView.loaded || exn.instance_variable_get(:@oboe_logged)

        unless exn
          TV.logger.debug '[traceview/debug] log_exception called with nil exception'
          return
        end

        kvs.merge!(:ErrorClass => exn.class.name,
                   :ErrorMsg => exn.message,
                   :Backtrace => exn.backtrace.join("\r\n"))

        exn.instance_variable_set(:@oboe_logged, true)
        log(layer, :error, kvs)
      end

      ##
      # Public: Decide whether or not to start a trace, and report an event
      # appropriately.
      #
      # ==== Attributes
      #
      # * +layer+ - The layer the reported event belongs to
      # * +xtrace+ - An xtrace metadata string, or nil.  Used for cross-application tracing.
      # * +opts+ - A hash containing key/value pairs that will be reported along with this event (optional).
      #
      # ==== Example
      #
      #   TraceView::API.log_start(:layer_name, nil, { :id => @user.id })
      #
      def log_start(layer, xtrace = nil, opts = {})
        return if !TraceView.loaded || (opts.key?(:URL) && ::TraceView::Util.static_asset?(opts[:URL]))

        # For entry only layers (DelayedJob workers, Sidekiq workers), auto-set the tracing mode
        # Don't do this if tracing mode is already :always or :never
        if TraceView.through? && TraceView.entry_layer?(layer)
          TraceView.logger.debug "[traceview/debug] Detected #{layer}: auto-configuring tracing mode"
          TraceView::Config[:tracing_mode] = :always
        end

        # Used by JRuby/Java webservers such as Tomcat
        TraceView::Context.fromString(xtrace) if TraceView.pickup_context?(xtrace)

        if TraceView.tracing?
          # Pre-existing context.  Either we inherited context from an
          # incoming X-Trace request header or under JRuby, Joboe started
          # tracing before the JRuby code was called (e.g. Tomcat)
          TraceView.is_continued_trace = true

          if TraceView.has_xtrace_header
            opts[:TraceOrigin] = :continued_header
          elsif TraceView.has_incoming_context
            opts[:TraceOrigin] = :continued_context
          else
            opts[:TraceOrigin] = :continued
          end

          log_entry(layer, opts)

        elsif opts.key?('Force')
          # Forced tracing: used by __Init reporting
          opts[:TraceOrigin] = :forced
          log_event(layer, :entry, TraceView::Context.startTrace, opts)

        elsif TraceView.sample?(opts.merge(:layer => layer, :xtrace => xtrace))
          opts[:_SP]  = TraceView.context_settings
          opts[:App]  = TraceView.app_token
          opts[:AApp] = TraceView::Config[:app_token] if TraceView::Config[:app_token]
          log_event(layer, :entry, TraceView::Context.startTrace, opts)
        end
      end

      ##
      # Public: Report an exit event and potentially clear the tracing context.
      #
      # ==== Attributes
      #
      # * +layer+ - The layer the reported event belongs to
      # * +opts+ - A hash containing key/value pairs that will be reported along with this event (optional).
      #
      # ==== Example
      #
      #   TraceView::API.log_end(:layer_name, { :id => @user.id })
      #
      # Returns an xtrace metadata string
      def log_end(layer, opts = {})
        return unless TraceView.loaded

        log_event(layer, :exit, TraceView::Context.createEvent, opts)
        xtrace = TraceView::Context.toString

        # Conditionally clear tracing context and the context_settings data.
        unless TraceView.has_incoming_context?
          TraceView::Context.clear
          TraceView.context_settings = nil
        end

        xtrace
      end

      ##
      # Public: Log an entry event
      #
      # A helper method to create and log an entry event
      #
      # ==== Attributes
      #
      # * +layer+ - The layer the reported event belongs to
      # * +kvs+ - A hash containing key/value pairs that will be reported along with this event (optional).
      # * +op+ - To identify the current operation being traced.  Used to avoid double tracing recursive calls.
      #
      # ==== Example
      #
      #   TraceView::API.log_entry(:layer_name, { :id => @user.id })
      #
      # Returns an xtrace metadata string
      def log_entry(layer, kvs = {}, op = nil)
        return unless TraceView.loaded

        TraceView.layer_op = op.to_sym if op
        log_event(layer, :entry, TraceView::Context.createEvent, kvs)
      end

      ##
      # Public: Log an info event
      #
      # A helper method to create and log an info event
      #
      # ==== Attributes
      #
      # * +layer+ - The layer the reported event belongs to
      # * +kvs+ - A hash containing key/value pairs that will be reported along with this event (optional).
      #
      # ==== Example
      #
      #   TraceView::API.log_info(:layer_name, { :id => @user.id })
      #
      # Returns an xtrace metadata string
      def log_info(layer, kvs = {})
        return unless TraceView.loaded

        log_event(layer, :info, TraceView::Context.createEvent, kvs)
      end

      ##
      # Public: Log an exit event
      #
      # A helper method to create and log an exit event
      #
      # ==== Attributes
      #
      # * +layer+ - The layer the reported event belongs to
      # * +kvs+ - A hash containing key/value pairs that will be reported along with this event (optional).
      # * +op+ - To identify the current operation being traced.  Used to avoid double tracing recursive calls.
      #
      # ==== Example
      #
      #   TraceView::API.log_exit(:layer_name, { :id => @user.id })
      #
      # Returns an xtrace metadata string
      def log_exit(layer, kvs = {}, op = nil)
        return unless TraceView.loaded

        TraceView.layer_op = nil if op
        log_event(layer, :exit, TraceView::Context.createEvent, kvs)
      end

      ##
      # Internal: Report an event.
      #
      # ==== Attributes
      #
      # * +layer+ - The layer the reported event belongs to
      # * +label+ - The label for the reported event.  See API documentation for reserved labels and usage.
      # * +event+ - The pre-existing TraceView context event.  See TraceView::Context.createEvent
      # * +opts+ - A hash containing key/value pairs that will be reported along with this event (optional).
      #
      # ==== Example
      #
      #   entry = TraceView::Context.createEvent
      #   TraceView::API.log_event(:layer_name, 'entry',  entry_event, { :id => @user.id })
      #
      #   exit_event = TraceView::Context.createEvent
      #   exit_event.addEdge(entry.getMetadata)
      #   TraceView::API.log_event(:layer_name, 'exit',  exit_event, { :id => @user.id })
      #
      def log_event(layer, label, event, opts = {})
        return unless TraceView.loaded

        event.addInfo(TV_STR_LAYER, layer.to_s.freeze) if layer
        event.addInfo(TV_STR_LABEL, label.to_s.freeze)

        TraceView.layer = layer.to_sym if label == :entry
        TraceView.layer = nil          if label == :exit

        opts.each do |k, v|
          value = nil

          next unless valid_key? k

          if [Integer, Float, Fixnum, NilClass, String].include?(v.class)
            value = v
          elsif v.class == Set
            value = v.to_a.to_s
          else
            value = v.to_s if v.respond_to?(:to_s)
          end

          begin
            event.addInfo(k.to_s, value)
          rescue ArgumentError => e
            TraceView.logger.debug "[TraceView/debug] Couldn't add event KV: #{k} => #{v.class}"
            TraceView.logger.debug "[TraceView/debug] #{e.message}"
          end
        end if !opts.nil? && opts.any?

        TraceView::Reporter.sendReport(event)
      end
    end
  end
end
