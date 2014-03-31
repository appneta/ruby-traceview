# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  module Util
    class << self
      ##
      # method_alias
      #
      # Centralized utility method to alias a method on an arbitrary
      # class or module.
      #
      def method_alias(cls, method, name=nil)
        # Attempt to infer a contextual name if not indicated
        #
        # For example:
        # ::ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter.to_s.split(/::/).last
        # => "AbstractMysqlAdapter"
        #
        begin
          name ||= cls.to_s.split(/::/).last 
        rescue
        end

        if cls.method_defined? method.to_sym or cls.private_method_defined? method.to_sym
          
          # Strip '!' or '?' from method if present
          safe_method_name = method.to_s.chop if method.to_s =~ /\?$|\!$/
          safe_method_name ||= method

          without_oboe = "#{safe_method_name}_without_oboe"
          with_oboe    = "#{safe_method_name}_with_oboe"
       
          # Only alias if we haven't done so already
          unless cls.method_defined? without_oboe.to_sym or 
            cls.private_method_defined? without_oboe.to_sym

            cls.class_eval do
              alias_method without_oboe, "#{method}"
              alias_method "#{method}", with_oboe
            end
          end
        else Oboe.logger.warn "[oboe/loading] Couldn't properly instrument #{name}.  Partial traces may occur."
        end
      end
  
      ##
      # send_include
      #
      # Centralized utility method to send a include call for an
      # arbitrary class
      def send_include(target_cls, cls)
        if defined?(target_cls)
          target_cls.send(:include, cls)
        end
      end

      ##
      # static_asset?
      #
      # Given a path, this method determines whether it is a static asset or not (based
      # solely on filename)
      #
      def static_asset?(path)
        return (path =~ /\.(jpg|jpeg|gif|png|ico|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|bmp|rtf|js|flv|swf|ttf|woff|svg|less)$/i)
      end
    end
  end
end

