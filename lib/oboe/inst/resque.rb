# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

require 'socket'
require 'json'

module Oboe
  module Inst
    module Resque
      def self.included(base)
        base.send :extend, ::Resque
      end

      def extract_trace_details(op, klass, args)
        report_kvs = {}

        begin
          report_kvs[:Op] = op.to_s
          report_kvs[:Class] = klass.to_s if klass

          if Oboe::Config[:resque][:log_args]
            kv_args = args.to_json

            # Limit the argument json string to 1024 bytes
            if kv_args.length > 1024
              report_kvs[:Args] = kv_args[0..1023] + '...[snipped]'
            else
              report_kvs[:Args] = kv_args
            end
          end

          report_kvs[:Backtrace] = Oboe::API.backtrace if Oboe::Config[:resque][:collect_backtraces]
        rescue
        end

        report_kvs
      end

      def enqueue_with_oboe(klass, *args)
        if Oboe.tracing?
          report_kvs = extract_trace_details(:enqueue, klass, args)

          Oboe::API.trace('resque-client', report_kvs, :enqueue) do
            args.push(:parent_trace_id => Oboe::Context.toString) if Oboe::Config[:resque][:link_workers]
            enqueue_without_oboe(klass, *args)
          end
        else
          enqueue_without_oboe(klass, *args)
        end
      end

      def enqueue_to_with_oboe(queue, klass, *args)
        if Oboe.tracing? && !Oboe.tracing_layer_op?(:enqueue)
          report_kvs = extract_trace_details(:enqueue_to, klass, args)
          report_kvs[:Queue] = queue.to_s if queue

          Oboe::API.trace('resque-client', report_kvs) do
            args.push(:parent_trace_id => Oboe::Context.toString) if Oboe::Config[:resque][:link_workers]
            enqueue_to_without_oboe(queue, klass, *args)
          end
        else
          enqueue_to_without_oboe(queue, klass, *args)
        end
      end

      def dequeue_with_oboe(klass, *args)
        if Oboe.tracing?
          report_kvs = extract_trace_details(:dequeue, klass, args)

          Oboe::API.trace('resque-client', report_kvs) do
            dequeue_without_oboe(klass, *args)
          end
        else
          dequeue_without_oboe(klass, *args)
        end
      end
    end

    module ResqueWorker
      def perform_with_oboe(job)
        report_kvs = {}
        last_arg = nil

        begin
          report_kvs[:Op] = :perform

          # Set these keys for the ability to separate out
          # background tasks into a separate app on the server-side UI
          report_kvs[:Controller] = :Resque
          report_kvs[:Action] = :perform

          report_kvs['HTTP-Host'] = Socket.gethostname
          report_kvs[:URL] = '/resque/' + job.queue
          report_kvs[:Method] = 'NONE'
          report_kvs[:Queue] = job.queue

          report_kvs[:Class] = job.payload['class']

          if Oboe::Config[:resque][:log_args]
            kv_args = job.payload['args'].to_json

            # Limit the argument json string to 1024 bytes
            if kv_args.length > 1024
              report_kvs[:Args] = kv_args[0..1023] + '...[snipped]'
            else
              report_kvs[:Args] = kv_args
            end
          end

          last_arg = job.payload['args'].last
        rescue
        end

        if last_arg.is_a?(Hash) && last_arg.key?('parent_trace_id')
          begin
            # Since the enqueue was traced, we force trace the actual job execution and reference
            # the enqueue trace with ParentTraceID
            report_kvs[:ParentTraceID] = last_arg['parent_trace_id']
            job.payload['args'].pop

          rescue
          end

          # Force this trace regardless of sampling rate so that child trace can be
          # link to parent trace.
          Oboe::API.start_trace('resque-worker', nil, report_kvs.merge('Force' => true)) do
            perform_without_oboe(job)
          end

        else
          Oboe::API.start_trace('resque-worker', nil, report_kvs) do
            perform_without_oboe(job)
          end
        end
      end
    end

    module ResqueJob
      def fail_with_oboe(exception)
        if Oboe.tracing?
          Oboe::API.log_exception('resque', exception)
        end
        fail_without_oboe(exception)
      end
    end
  end
end

if defined?(::Resque)
  Oboe.logger.info "[oboe/loading] Instrumenting resque"

  ::Resque.module_eval do
    include Oboe::Inst::Resque

    [:enqueue, :enqueue_to, :dequeue].each do |m|
      if method_defined?(m)
        module_eval "alias #{m}_without_oboe #{m}"
        module_eval "alias #{m} #{m}_with_oboe"
      else
        Oboe.logger.warn "[oboe/loading] Couldn't properly instrument Resque (#{m}).  Partial traces may occur."
      end
    end
  end

  if defined?(::Resque::Worker)
    ::Resque::Worker.class_eval do
      include Oboe::Inst::ResqueWorker

      if method_defined?(:perform)
        alias perform_without_oboe perform
        alias perform perform_with_oboe
      elsif Oboe::Config[:verbose]
        Oboe.logger.warn '[oboe/loading] Couldn\'t properly instrument ResqueWorker (perform).  Partial traces may occur.'
      end
    end
  end

  if defined?(::Resque::Job)
    ::Resque::Job.class_eval do
      include Oboe::Inst::ResqueJob

      if method_defined?(:fail)
        alias fail_without_oboe fail
        alias fail fail_with_oboe
      elsif Oboe::Config[:verbose]
        Oboe.logger.warn '[oboe/loading] Couldn\'t properly instrument ResqueWorker (fail).  Partial traces may occur.'
      end
    end
  end
end


