require 'minitest_helper'

if RUBY_VERSION >= '1.9.3'
  ENV['PORT'] = '12345'
  GC::Profiler.enable

  include Unicorn

  class TestHandler
    def call(env)
      while env['rack.input'].read(4096)
      end
      [200, { 'Content-Type' => 'text/plain' }, ['hello!\n']]
    rescue Unicorn::ClientShutdown, Unicorn::HttpParserError => e
      $stderr.syswrite("#{e.class}: #{e.message} #{e.backtrace.empty?}\n")
      raise e
    end
  end

  describe Oboe::Collector do
    before do
      clear_all_traces

      # Spawn a Unicorn webserver listener so we can validate metrics collection
      @server = HttpServer.new(TestHandler.new, :listeners => [ '127.0.0.1:' + ENV['PORT'] ] )
      @server.start
      sleep 2
    end

    after do
      @server.stop(false)
    end

    it 'should be loaded, defined, instantiated and ready' do
      defined?(::Oboe::Collector).wont_match nil
      Oboe.collector.wont_match nil
    end

    it 'should have correct default Oboe::Config values' do
      Oboe::Config[:collector][:enabled].must_equal true
      Oboe::Config[:collector][:sleep_interval].must_equal 60
    end

    it 'should generate metric traces' do
      Oboe.collector.start

      # Allow the thread to spawn, collect and report
      # metrics
      sleep 2

      traces = get_all_traces
      traces.count.must_equal 3

      validate_outer_layers(traces, 'RubyMetrics')

      traces[1]['Layer'].must_equal "RubyMetrics"
      traces[1]['Label'].must_equal "metrics"

      # Break GC KVs down by Ruby version
      # https://gist.github.com/pglombardo/4157752068c0f5a8c7a8#metrics-to-be-added-to-host-metrics-1
      if RUBY_VERSION >= '1.9.3'
        traces[1].has_key?('count').must_equal true
      end

      if RUBY_VERSION >= '2.0'
        traces[1].has_key?('total_allocated_object').must_equal true
        traces[1].has_key?('total_freed_object').must_equal true
      end

      if RUBY_VERSION >= '2.1'
        traces[1].has_key?('minor_gc_count').must_equal true
        traces[1].has_key?('major_gc_count').must_equal true
        traces[1].has_key?('heap_live_slot').must_equal true
        traces[1].has_key?('heap_free_slot').must_equal true
      end

      # Process, memory and Ruby version KVs
      traces[1]['RubyVersion'].must_equal RUBY_VERSION
      traces[1].has_key?('ThreadCount').must_equal true
      traces[1].has_key?('VmRSS').must_equal true

      # Unicorn KVs
      traces[1]['listener0_addr'].must_equal '127.0.0.1:12345'
      traces[1]['listener0_queued'].must_equal '0'
      traces[1]['listener0_active'].must_equal '0'


      Oboe.collector.stop
    end
  end
end
