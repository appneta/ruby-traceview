# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  module Inst
    module MemCache
      include Oboe::API::Memcache

      def self.included(cls)
        Oboe.logger.info "[oboe/loading] Instrumenting memcache"

        cls.class_eval do
          MEMCACHE_OPS.reject { |m| !method_defined?(m) }.each do |m|

            define_method("#{m}_with_oboe") do |*args|
              report_kvs = { :KVOp => m }
              report_kvs[:Backtrace] = Oboe::API.backtrace if Oboe::Config[:memcache][:collect_backtraces]

              if Oboe.tracing?
                Oboe::API.trace('memcache', report_kvs) do
                  send("#{m}_without_oboe", *args)
                end
              else
                send("#{m}_without_oboe", *args)
              end
            end

            class_eval "alias #{m}_without_oboe #{m}"
            class_eval "alias #{m} #{m}_with_oboe"
          end
        end

        [:request_setup, :cache_get, :get_multi].each do |m|
          if ::MemCache.method_defined? :request_setup
            cls.class_eval "alias #{m}_without_oboe #{m}"
            cls.class_eval "alias #{m} #{m}_with_oboe"
          else
            Oboe.logger.warn "[oboe/loading] Couldn't properly instrument Memcache: #{m}"
          end
        end
      end

      def get_multi_with_oboe(*args)
        return get_multi_without_oboe(args) unless Oboe.tracing?

        info_kvs = {}

        begin
          info_kvs[:Backtrace] = Oboe::API.backtrace if Oboe::Config[:memcache][:collect_backtraces]

          if args.last.is_a?(Hash) || args.last.nil?
            info_kvs[:KVKeyCount] = args.flatten.length - 1
          else
            info_kvs[:KVKeyCount] = args.flatten.length
          end
        rescue StandardError => e
          Oboe.logger.debug "[oboe/debug] Error collecting info keys: #{e.message}"
          Oboe.logger.debug e.backtrace
        end

        Oboe::API.trace('memcache', { :KVOp => :get_multi }, :get_multi) do
          values = get_multi_without_oboe(args)

          info_kvs[:KVHitCount] = values.length
          Oboe::API.log('memcache', 'info', info_kvs)

          values
        end
      end

      def request_setup_with_oboe(*args)
        if Oboe.tracing? && !Oboe.tracing_layer_op?(:get_multi)
          server, cache_key = request_setup_without_oboe(*args)

          info_kvs = { :KVKey => cache_key, :RemoteHost => server.host }
          info_kvs[:Backtrace] = Oboe::API.backtrace if Oboe::Config[:memcache][:collect_backtraces]
          Oboe::API.log('memcache', 'info', info_kvs)

          [server, cache_key]
        else
          request_setup_without_oboe(*args)
        end
      end

      def cache_get_with_oboe(server, cache_key)
        result = cache_get_without_oboe(server, cache_key)

        info_kvs = { :KVHit => memcache_hit?(result) }
        info_kvs[:Backtrace] = Oboe::API.backtrace if Oboe::Config[:memcache][:collect_backtraces]
        Oboe::API.log('memcache', 'info', info_kvs)

        result
      end
    end # module MemCache
  end # module Inst
end # module Oboe

if defined?(::MemCache) && Oboe::Config[:memcache][:enabled]
  ::MemCache.class_eval do
    include Oboe::Inst::MemCache
  end
end
