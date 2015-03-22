# Copyright (c) 2013 AppNeta, Inc.
# All rights reserved.

module Oboe
  ##
  # The Inst module holds all of the instrumentation extensions for various
  # libraries suchs as Redis, Dalli and Resque.
  module Inst
    def self.load_instrumentation
      # Load the general instrumentation
      pattern = File.join(File.dirname(__FILE__), 'inst', '*.rb')
      Dir.glob(pattern) do |f|
        begin
          require f
        rescue => e
          Oboe.logger.error "[oboe/loading] Error loading instrumentation file '#{f}' : #{e}"
        end
      end

      # Load and start the metrics collector thread
      Oboe.collector.load

      unless defined?(JRUBY_VERSION) or ENV.key?('OBOE_GEM_TEST')
        # Don't start the collector when running tests.
        # The test suite will boot the collector manually
        Oboe.collector.start
      end
    end
  end
end
