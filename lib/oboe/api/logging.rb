# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  module API
    module Logging

      # Public: Report an event in an active trace.
      #
      # layer - The layer the reported event belongs to
      # label - The label for the reported event. See API documentation for
      #         reserved labels and usage.
      # opts - A hash containing key/value pairs that will be reported along
      #        with this event (optional).
      #
      # Example
      #
      #   log('logical_layer', 'entry')
      #   log('logical_layer', 'info', { :list_length => 20 })
      #   log('logical_layer', 'exit')
      #
      # Returns nothing.
      def log(layer, label, opts={})
        log_event(layer, label, Oboe::Context.createEvent, opts)
      end
  
      # Public: Report an exception.
      #
      # layer - The layer the reported event belongs to
      # exn - The exception to report
      #
      # Example
      #
      #   begin
      #     function_without_oboe()
      #   rescue Exception => e
      #     log_exception('rails', e)
      #     raise
      #   end
      #
      # Returns nothing.
      def log_exception(layer, exn)
        unless exn.instance_variable_get(:@oboe_logged)
          log(layer, 'error', {
            :ErrorClass => exn.class.name,
            :Message => exn.message,
            :Backtrace => exn.backtrace.join("\r\n")
          })
          exn.instance_variable_set(:@oboe_logged, true)
        end
      end
  
      # Public: Decide whether or not to start a trace, and report an event
      # appropriately.
      #
      # layer - The layer the reported event belongs to
      # xtrace - An xtrace metadata string, or nil.
      # opts - A hash containing key/value pairs that will be reported along
      #        with this event (optional).
      #
      # Returns nothing.
      def log_start(layer, xtrace, opts={})
        return if Oboe.never? or (opts.has_key?(:URL) and ::Oboe::Util.static_asset?(opts[:URL]))
  
        if xtrace
          Oboe::Context.fromString(xtrace)
        end
  
        if Oboe.tracing?
          log_entry(layer, opts)
        elsif Oboe.sample?(opts.merge(:layer => layer, :xtrace => xtrace)) or opts.has_key?('Force')
          log_event(layer, 'entry', Oboe::Context.startTrace, opts)
        end
      end
  
      # Public: Report an exit event.
      #
      # layer - The layer the reported event belongs to
      #
      # Returns an xtrace metadata string
      def log_end(layer, opts={})
        log_event(layer, 'exit', Oboe::Context.createEvent, opts)
        xtrace = Oboe::Context.toString
        Oboe::Context.clear
        xtrace
      end
  
      def log_entry(layer, opts={}, protect_op=nil)
        Oboe::Context.layer_op = protect_op if protect_op
        log_event(layer, 'entry', Oboe::Context.createEvent, opts)
      end

      def log_exit(layer, opts={}, protect_op=nil)
        Oboe::Context.layer_op = nil if protect_op
        log_event(layer, 'exit', Oboe::Context.createEvent, opts)
      end
  
      # Internal: Report an event.
      #
      # layer - The layer the reported event belongs to
      # label - The label for the reported event. See API documentation for
      #         reserved labels and usage.
      # opts - A hash containing key/value pairs that will be reported along
      #        with this event (optional).
      #
      # Examples
      #
      #   entry = Oboe::Context.createEvent
      #   log_event('rails', 'entry', exit, { :controller => 'user', :action => 'index' })
      #   exit = Oboe::Context.createEvent
      #   exit.addEdge(entry.getMetadata)
      #   log_event('rails', 'exit', exit)
      #
      # Returns nothing.
      def log_event(layer, label, event, opts={})
        if layer
            event.addInfo('Layer', layer.to_s)
        end
        event.addInfo('Label', label.to_s)
  
        opts.each do |k, v|
          event.addInfo(k.to_s, v.to_s) if valid_key? k
        end if !opts.nil? and opts.any?
 
        Oboe::Reporter.sendReport(event) if Oboe.loaded
      end
    end
  end 
end
