# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  ##
  # Provides utility methods for use while in the business
  # of instrumenting code
  module Util
    class << self
      def contextual_name(cls)
        # Attempt to infer a contextual name if not indicated
        #
        # For example:
        # ::ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter.to_s.split(/::/).last
        # => "AbstractMysqlAdapter"
        #
        cls.to_s.split(/::/).last
      rescue
        cls
      end

      ##
      # method_alias
      #
      # Centralized utility method to alias a method on an arbitrary
      # class or module.
      #
      def method_alias(cls, method, name = nil)
        name ||= contextual_name(cls)

        if cls.method_defined?(method.to_sym) || cls.private_method_defined?(method.to_sym)

          # Strip '!' or '?' from method if present
          safe_method_name = method.to_s.chop if method.to_s =~ /\?$|\!$/
          safe_method_name ||= method

          without_oboe = "#{safe_method_name}_without_oboe"
          with_oboe    = "#{safe_method_name}_with_oboe"

          # Only alias if we haven't done so already
          unless cls.method_defined?(without_oboe.to_sym) ||
            cls.private_method_defined?(without_oboe.to_sym)

            cls.class_eval do
              alias_method without_oboe, "#{method}"
              alias_method "#{method}", with_oboe
            end
          end
        else
          Oboe.logger.warn "[oboe/loading] Couldn't properly instrument #{name}.#{method}.  Partial traces may occur."
        end
      end

      ##
      # class_method_alias
      #
      # Centralized utility method to alias a class method on an arbitrary
      # class or module
      #
      def class_method_alias(cls, method, name = nil)
        name ||= contextual_name(cls)

        if cls.singleton_methods.include? method.to_sym

          # Strip '!' or '?' from method if present
          safe_method_name = method.to_s.chop if method.to_s =~ /\?$|\!$/
          safe_method_name ||= method

          without_oboe = "#{safe_method_name}_without_oboe"
          with_oboe    = "#{safe_method_name}_with_oboe"

          # Only alias if we haven't done so already
          unless cls.singleton_methods.include? without_oboe.to_sym
            cls.singleton_class.send(:alias_method, without_oboe, "#{method}")
            cls.singleton_class.send(:alias_method, "#{method}", with_oboe)
          end
        else Oboe.logger.warn "[oboe/loading] Couldn't properly instrument #{name}.  Partial traces may occur."
        end
      end

      ##
      # send_extend
      #
      # Centralized utility method to send an extend call for an
      # arbitrary class
      def send_extend(target_cls, cls)
        target_cls.send(:extend, cls) if defined?(target_cls)
      end

      ##
      # send_include
      #
      # Centralized utility method to send a include call for an
      # arbitrary class
      def send_include(target_cls, cls)
        target_cls.send(:include, cls) if defined?(target_cls)
      end

      ##
      # static_asset?
      #
      # Given a path, this method determines whether it is a static asset or not (based
      # solely on filename)
      #
      def static_asset?(path)
        (path =~ Regexp.new(Oboe::Config[:dnt_regexp], Oboe::Config[:dnt_opts]))
      end

      ##
      # prettify
      #
      # Even to my surprise, 'prettify' is a real word:
      # transitive v. To make pretty or prettier, especially in a superficial or insubstantial way.
      #   from The American Heritage Dictionary of the English Language, 4th Edition
      #
      # This method makes things 'purty' for reporting.
      def prettify(x)
        if (x.to_s =~ /^#</) == 0
          x.class.to_s
        else
          x.to_s
        end
      end

      ##
      # getaddr
      #
      # Attempt to get the address of the host and port.  Used
      # to detect which listeners are configured under Unicorn.
      # See oboe/collectors/unicorn.rb
      #
      # Taken from heroku/rack-queue-metrics
      def getaddr
        IPSocket.getaddress(Socket.gethostname).to_s + ':' + ENV['PORT']
      rescue SocketError
        nil
      end

      #  build_report
      #
      # Internal: Build a hash of KVs that reports on the status of the
      # running environment.  This is used on stack boot in __Init reporting
      # and for Oboe.support_report.
      def build_init_report
        platform_info = { '__Init' => 1 }

        begin
          platform_info['Force']                   = true
          platform_info['Ruby.Platform.Version']   = RUBY_PLATFORM
          platform_info['Ruby.Version']            = RUBY_VERSION
          platform_info['Ruby.Oboe.Version']       = ::Oboe::Version::STRING
          platform_info['RubyHeroku.Oboe.Version'] = ::OboeHeroku::Version::STRING if defined?(::OboeHeroku)

          # Report the framework in use
          if defined?(::RailsLts)
            platform_info['Ruby.RailsLts.Version'] = "RailsLts-#{::RailsLts::VERSION}"
          elsif defined?(::Rails)
            platform_info['Ruby.Rails.Version']    = "Rails-#{::Rails.version}"
          end
          platform_info['Ruby.Grape.Version']    = "Grape-#{::Grape::VERSION}" if defined?(::Grape)
          platform_info['Ruby.Cramp.Version']    = "Cramp-#{::Cramp::VERSION}" if defined?(::Cramp)

          if defined?(::Padrino)
            platform_info['Ruby.Padrino.Version'] = "Padrino-#{::Padrino::VERSION}"
          elsif defined?(::Sinatra)
            platform_info['Ruby.Sinatra.Version'] = "Sinatra-#{::Sinatra::VERSION}"
          end

          # Report the instrumented libraries
          platform_info['Ruby.Cassandra.Version'] = "Cassandra-#{::Cassandra.VERSION}" if defined?(::Cassandra)
          platform_info['Ruby.Dalli.Version']     = "Dalli-#{::Dalli::VERSION}"        if defined?(::Dalli)
          platform_info['Ruby.Faraday.Version']   = "Faraday-#{::Faraday::VERSION}"    if defined?(::Faraday)
          platform_info['Ruby.MemCache.Version']  = "MemCache-#{::MemCache::VERSION}"  if defined?(::MemCache)
          platform_info['Ruby.Moped.Version']     = "Moped-#{::Moped::VERSION}"        if defined?(::Moped)
          platform_info['Ruby.Redis.Version']     = "Redis-#{::Redis::VERSION}"        if defined?(::Redis)
          platform_info['Ruby.Resque.Version']    = "Resque-#{::Resque::VERSION}"      if defined?(::Resque)
          platform_info['Ruby.Typhoeus.Version']  = "Typhoeus-#{::Typhoeus::VERSION}"  if defined?(::Typhoeus::VERSION)

          # Special case since the Mongo 1.x driver doesn't embed the version number in the gem directly
          if ::Gem.loaded_specs.key?('mongo')
            platform_info['Ruby.Mongo.Version']     = "Mongo-#{::Gem.loaded_specs['mongo'].version}"
          end

          # Report the DB adapter in use
          platform_info['Ruby.Mysql.Version']   = Mysql::GemVersion::VERSION   if defined?(Mysql::GemVersion::VERSION)
          platform_info['Ruby.PG.Version']      = PG::VERSION                  if defined?(PG::VERSION)
          platform_info['Ruby.Mysql2.Version']  = Mysql2::VERSION              if defined?(Mysql2::VERSION)
          platform_info['Ruby.Sequel.Version']  = ::Sequel::VERSION            if defined?(::Sequel::VERSION)

          # Report the server in use (if possible)
          if defined?(::Unicorn)
            platform_info['Ruby.AppContainer.Version'] = "Unicorn-#{::Unicorn::Const::UNICORN_VERSION}"
          elsif defined?(::Puma)
            platform_info['Ruby.AppContainer.Version'] = "Puma-#{::Puma::Const::PUMA_VERSION} (#{::Puma::Const::CODE_NAME})"
          elsif defined?(::PhusionPassenger)
            platform_info['Ruby.AppContainer.Version'] = "#{::PhusionPassenger::PACKAGE_NAME}-#{::PhusionPassenger::VERSION_STRING}"
          elsif defined?(::Thin)
            platform_info['Ruby.AppContainer.Version'] = "Thin-#{::Thin::VERSION::STRING} (#{::Thin::VERSION::CODENAME})"
          elsif defined?(::Mongrel)
            platform_info['Ruby.AppContainer.Version'] = "Mongrel-#{::Mongrel::Const::MONGREL_VERSION}"
          elsif defined?(::Mongrel2)
            platform_info['Ruby.AppContainer.Version'] = "Mongrel2-#{::Mongrel2::VERSION}"
          elsif defined?(::Trinidad)
            platform_info['Ruby.AppContainer.Version'] = "Trinidad-#{::Trinidad::VERSION}"
          elsif defined?(::WEBrick)
            platform_info['Ruby.AppContainer.Version'] = "WEBrick-#{::WEBrick::VERSION}"
          else
            platform_info['Ruby.AppContainer.Version'] = File.basename($PROGRAM_NAME)
          end

        rescue StandardError, ScriptError => e
          # Also rescue ScriptError (aka SyntaxError) in case one of the expected
          # version defines don't exist

          platform_info['Error'] = "Error in build_report: #{e.message}"

          Oboe.logger.warn "[oboe/warn] Error in build_init_report: #{e.message}"
          Oboe.logger.debug e.backtrace
        end
        platform_info
      end
    end
  end
end
