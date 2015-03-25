# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  module Inst
    module Dalli
      include Oboe::API::Memcache

      def self.included(cls)
        cls.class_eval do
          Oboe.logger.info "[oboe/loading] Instrumenting memcache (dalli)"

          if ::Dalli::Client.private_method_defined? :perform
            alias perform_without_oboe perform
            alias perform perform_with_oboe
          else Oboe.logger.warn '[oboe/loading] Couldn\'t properly instrument Memcache (Dalli).  Partial traces may occur.'
          end

          if ::Dalli::Client.method_defined? :get_multi
            alias get_multi_without_oboe get_multi
            alias get_multi get_multi_with_oboe
          end
        end
      end

      def perform_with_oboe(*all_args, &blk)
        op, key, *args = *all_args

        if Oboe.tracing? && !Oboe.tracing_layer_op?(:get_multi)
          Oboe::API.trace('memcache', { :KVOp => op, :KVKey => key }) do
            result = perform_without_oboe(*all_args, &blk)

            info_kvs = {}
            info_kvs[:KVHit] = memcache_hit?(result) if op == :get && key.class == String
            info_kvs[:Backtrace] = Oboe::API.backtrace if Oboe::Config[:dalli][:collect_backtraces]

            Oboe::API.log('memcache', 'info', info_kvs) unless info_kvs.empty?
            result
          end
        else
          perform_without_oboe(*all_args, &blk)
        end
      end

      def get_multi_with_oboe(*keys)
        return get_multi_without_oboe(keys) unless Oboe.tracing?

        info_kvs = {}

        begin
          info_kvs[:KVKeyCount] = keys.flatten.length
          info_kvs[:KVKeyCount] = (info_kvs[:KVKeyCount] - 1) if keys.last.is_a?(Hash) || keys.last.nil?
        rescue
          Oboe.logger.debug "[oboe/debug] Error collecting info keys: #{e.message}"
          Oboe.logger.debug e.backtrace
        end

        Oboe::API.trace('memcache', { :KVOp => :get_multi }, :get_multi) do
          values = get_multi_without_oboe(keys)

          info_kvs[:KVHitCount] = values.length
          info_kvs[:Backtrace] = Oboe::API.backtrace if Oboe::Config[:dalli][:collect_backtraces]
          Oboe::API.log('memcache', 'info', info_kvs)

          values
        end
      end
    end
  end
end

if defined?(Dalli) && Oboe::Config[:dalli][:enabled]
  ::Dalli::Client.module_eval do
    include Oboe::Inst::Dalli
  end
end
