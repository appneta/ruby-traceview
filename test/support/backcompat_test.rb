# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe "BackwardCompatibility" do

  it 'should still export to Oboe::Ruby' do
    defined?(::Oboe::Ruby).must_equal "constant"
  end

  it 'should still respond to Oboe::Config' do
    @verbose = Oboe::Config[:verbose]
    @dalli_enabled = Oboe::Config[:dalli][:enabled]
    @tm = Oboe::Config[:tracing_mode]
    @sr = Oboe::Config[:sample_rate]

    Oboe::Config[:verbose] = true
    Oboe::Config[:verbose].must_equal true
    Oboe::Config.verbose.must_equal true
    TraceView::Config[:verbose].must_equal true
    TraceView::Config.verbose.must_equal true

    Oboe::Config[:dalli][:enabled] = false
    Oboe::Config[:dalli][:enabled].must_equal false
    TraceView::Config[:dalli][:enabled].must_equal false

    Oboe::Config[:sample_rate] = 8e5
    Oboe::Config.sample_rate.must_equal 8e5
    TraceView::Config.sample_rate.must_equal 8e5

    Oboe::Config[:tracing_mode] = 'always'
    Oboe::Config.tracing_mode.must_equal 'always'
    TraceView::Config.tracing_mode.must_equal 'always'

    Oboe::Config[:sample_rate] = @sr
    Oboe::Config[:tracing_mode] = @tm
    Oboe::Config[:dalli][:enabled] = @dalli_enabled
    Oboe::Config[:verbose] = @verbose
  end

  it 'should still support Oboe::API.log calls' do
    clear_all_traces

    Oboe::API.log_start('rack', nil, {})
    Oboe::API.log_end('rack')

    traces = get_all_traces
    traces.count.must_equal 2
  end

  it 'should still support Oboe::API.trace calls' do
    clear_all_traces

    Oboe::API.start_trace('api_test', '', {}) do
      sleep 1
    end

    traces = get_all_traces
    traces.count.must_equal 2

    validate_outer_layers(traces, 'api_test')
  end

  it 'should still support Oboe::API.profile'do
    clear_all_traces

    Oboe::API.start_trace('outer_profile_test') do
      Oboe::API.profile('profile_test', {}, false) do
        sleep 1
      end
   end

    traces = get_all_traces
    traces.count.must_equal 4
  end

  # Pasted in from test/profiling/method_test.rb
  # Modified to use OboeMethodProfiling
  describe "OboeMethodProfiling" do
    before do
      clear_all_traces
      # Conditionally Undefine TestWorker
      # http://stackoverflow.com/questions/11503558/how-to-undefine-class-in-ruby
      Object.send(:remove_const, :TestWorker) if defined?(TestWorker)
    end

    it 'should be loaded, defined and ready' do
      defined?(::OboeMethodProfiling).wont_match nil
    end

    it 'should trace Class methods' do
      class TestWorker
        def self.do_work
          sleep 1
        end

        class << self
          include OboeMethodProfiling
          profile_method :do_work, 'do_work'
        end
      end

      ::Oboe::API.start_trace('method_profiling', '', {}) do
        # Call the profiled class method
        TestWorker.do_work
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'method_profiling')

      kvs = {}
      kvs["Label"] = 'profile_entry'
      kvs["Language"] = "ruby"
      kvs["ProfileName"] = "do_work"
      kvs["FunctionName"] = "do_work"
      kvs["Class"] = "TestWorker"

      validate_event_keys(traces[1], kvs)

      traces[1].has_key?("Layer").must_equal false
      traces[1].has_key?("File").must_equal true
      traces[1].has_key?("LineNumber").must_equal true

      kvs.clear
      kvs["Label"] = "profile_exit"
      kvs["Language"] = "ruby"
      kvs["ProfileName"] = "do_work"

      validate_event_keys(traces[2], kvs)
      traces[2].has_key?("Layer").must_equal false
    end

    it 'should trace Instance methods' do
      class TestWorker
        def do_work
          sleep 1
        end

        include OboeMethodProfiling
        profile_method :do_work, 'do_work'
      end

      ::Oboe::API.start_trace('method_profiling', '', {}) do
        # Call the profiled class method
        tw = TestWorker.new
        tw.do_work
      end

      traces = get_all_traces
      traces.count.must_equal 4

      validate_outer_layers(traces, 'method_profiling')

      kvs = {}
      kvs["Label"] = 'profile_entry'
      kvs["Language"] = "ruby"
      kvs["ProfileName"] = "do_work"
      kvs["FunctionName"] = "do_work"
      kvs["Class"] = "TestWorker"

      validate_event_keys(traces[1], kvs)

      traces[1].has_key?("Layer").must_equal false
      traces[1].has_key?("File").must_equal true
      traces[1].has_key?("LineNumber").must_equal true

      kvs.clear
      kvs["Label"] = "profile_exit"
      kvs["Language"] = "ruby"
      kvs["ProfileName"] = "do_work"

      validate_event_keys(traces[2], kvs)
      traces[2].has_key?("Layer").must_equal false
    end

    it 'should trace Module class methods' do
      module TestWorker
        def self.do_work
          sleep 1
        end

        class << self
          include OboeMethodProfiling
          profile_method :do_work, 'do_work'
        end
      end

      ::Oboe::API.start_trace('method_profiling', '', {}) do
        # Call the profiled class method
        TestWorker.do_work
      end

      traces = get_all_traces
      traces.count.must_equal 4
      validate_outer_layers(traces, 'method_profiling')

      kvs = {}
      kvs["Label"] = 'profile_entry'
      kvs["Language"] = "ruby"
      kvs["ProfileName"] = "do_work"
      kvs["FunctionName"] = "do_work"
      kvs["Module"] = "TestWorker"

      validate_event_keys(traces[1], kvs)

      traces[1].has_key?("Layer").must_equal false
      traces[1].has_key?("File").must_equal true
      traces[1].has_key?("LineNumber").must_equal true

      kvs.clear
      kvs["Label"] = "profile_exit"
      kvs["Language"] = "ruby"
      kvs["ProfileName"] = "do_work"

      validate_event_keys(traces[2], kvs)
      traces[2].has_key?("Layer").must_equal false
    end

    it 'should not store arguments and return value by default' do
      class TestWorker
        def self.do_work(s, i, a, h)
          sleep 1
          return "the zebra is loose"
        end

        class << self
          include OboeMethodProfiling
          # Default call method
          profile_method :do_work, 'do_work'
        end
      end

      ::Oboe::API.start_trace('method_profiling', '', {}) do
        # Call the profiled class method
        TestWorker.do_work('String Argument', 203984, ["1", "2", 3], { :color => :black })
      end

      traces = get_all_traces
      traces.count.must_equal 4

      traces[1].has_key?("Args").must_equal false
      traces[2].has_key?("ReturnValue").must_equal false
    end

    it 'should store arguments and return value when asked' do
      class TestWorker
        def self.do_work(s, i, a, h)
          sleep 1
          return "the zebra is loose"
        end

        class << self
          include OboeMethodProfiling
          profile_method :do_work, 'do_work', true, true
        end
      end

      ::Oboe::API.start_trace('method_profiling', '', {}) do
        # Call the profiled class method
        TestWorker.do_work('String Argument', 203984, ["1", "2", 3], { :color => :black })
      end

      traces = get_all_traces
      traces.count.must_equal 4

      traces[1].has_key?("Args").must_equal true
      traces[1]["Args"].must_equal "\"String Argument\"\n203984\n[\"1\", \"2\", 3]\n{:color=>:black}\n"

      traces[2].has_key?("ReturnValue").must_equal true
      traces[2]["ReturnValue"].must_equal "\"the zebra is loose\"\n"
    end
  end
end
