# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  module Inst
    module Memcached
      include Oboe::API::Memcache

      def self.included(cls)
        Oboe.logger.info "[oboe/loading] Instrumenting memcached"

        cls.class_eval do
          MEMCACHE_OPS.reject { |m| !method_defined?(m) }.each do |m|
            define_method("#{m}_with_oboe") do |*args|
              opts = { :KVOp => m }

              if args.length && !args[0].is_a?(Array)
                opts[:KVKey] = args[0].to_s
                rhost = remote_host(args[0].to_s)
                opts[:RemoteHost] = rhost if rhost
              end

              Oboe::API.trace('memcache', opts) do
                result = send("#{m}_without_oboe", *args)

                info_kvs = {}
                info_kvs[:KVHit] = memcache_hit?(result) if m == :get && args.length && args[0].class == String
                info_kvs[:Backtrace] = Oboe::API.backtrace if Oboe::Config[:memcached][:collect_backtraces]

                Oboe::API.log('memcache', 'info', info_kvs) unless info_kvs.empty?
                result
              end
            end

            class_eval "alias #{m}_without_oboe #{m}"
            class_eval "alias #{m} #{m}_with_oboe"
          end
        end
      end

    end # module Memcached

    module MemcachedRails
      def self.included(cls)
        cls.class_eval do
          if ::Memcached::Rails.method_defined? :get_multi
            alias get_multi_without_oboe get_multi
            alias get_multi get_multi_with_oboe
          else
            Oboe.logger.warn '[oboe/loading] Couldn\'t properly instrument Memcached (:get_multi).  Partial traces may occur.'
          end
        end
      end

      def get_multi_with_oboe(keys, raw = false)
        if Oboe.tracing?
          layer_kvs = {}
          layer_kvs[:KVOp] = :get_multi

          Oboe::API.trace('memcache', layer_kvs || {}, :get_multi) do
            begin
              info_kvs = {}
              info_kvs[:KVKeyCount] = keys.flatten.length

              values = get_multi_without_oboe(keys, raw)

              info_kvs[:KVHitCount] = values.length
              info_kvs[:Backtrace] = Oboe::API.backtrace if Oboe::Config[:memcached][:collect_backtraces]

              Oboe::API.log('memcache', 'info', info_kvs)
            rescue
              values = get_multi_without_oboe(keys, raw)
            end
            values
          end
        else
          get_multi_without_oboe(keys, raw)
        end
      end
    end # module MemcachedRails
  end # module Inst
end # module Oboe

if defined?(::Memcached) && Oboe::Config[:memcached][:enabled]
  ::Memcached.class_eval do
    include Oboe::Inst::Memcached
  end

  if defined?(::Memcached::Rails)
    ::Memcached::Rails.class_eval do
      include Oboe::Inst::MemcachedRails
    end
  end
end
