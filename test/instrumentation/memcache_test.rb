# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

# FIXME: Since memcache is loaded late, the instrumentation
# loaded out of order.  Here we force inject instrumentation
require 'memcache'
if defined?(::TraceView::Inst)
  ::MemCache.class_eval do
    include TraceView::Inst::MemCache
  end
end

describe "Memcache" do
  before do
    clear_all_traces
    @mc = ::MemCache.new('127.0.0.1')

    # These are standard entry/exit KVs that are passed up with all mongo operations
    @entry_kvs = {
      'Layer' => 'memcache',
      'Label' => 'entry' }

    @info_kvs = {
      'Layer' => 'memcache',
      'Label' => 'info' }

    @exit_kvs = { 'Layer' => 'memcache', 'Label' => 'exit' }
    @collect_backtraces = TraceView::Config[:memcache][:collect_backtraces]
  end

  after do
    TraceView::Config[:memcache][:collect_backtraces] = @collect_backtraces
  end

  it 'Stock MemCache should be loaded, defined and ready' do
    defined?(::MemCache).wont_match nil
  end

  it 'MemCache should have traceview methods defined' do
    TraceView::API::Memcache::MEMCACHE_OPS.each do |m|
      if ::MemCache.method_defined?(m)
        ::MemCache.method_defined?("#{m}_with_traceview").must_equal true
      end
      ::MemCache.method_defined?(:request_setup_with_traceview).must_equal true
      ::MemCache.method_defined?(:cache_get_with_traceview).must_equal true
      ::MemCache.method_defined?(:get_multi_with_traceview).must_equal true
    end
  end

  it "should trace set" do
    TraceView::API.start_trace('memcache_test', '', {}) do
      @mc.set('msg', 'blah')
    end

    traces = get_all_traces

    traces.count.must_equal 5
    validate_outer_layers(traces, 'memcache_test')

    validate_event_keys(traces[1], @entry_kvs)

    traces[1]['KVOp'].must_equal "set"
    traces[1].has_key?('Backtrace').must_equal TraceView::Config[:memcache][:collect_backtraces]

    validate_event_keys(traces[2], @info_kvs)
    traces[2]['KVKey'].must_equal "msg"
    traces[2].has_key?('Backtrace').must_equal TraceView::Config[:memcache][:collect_backtraces]

    validate_event_keys(traces[3], @exit_kvs)
  end

  it "should trace get" do
    TraceView::API.start_trace('memcache_test', '', {}) do
      @mc.get('msg')
    end

    traces = get_all_traces

    traces.count.must_equal 6
    validate_outer_layers(traces, 'memcache_test')

    validate_event_keys(traces[1], @entry_kvs)

    traces[1]['KVOp'].must_equal "get"
    traces[1].has_key?('Backtrace').must_equal TraceView::Config[:memcache][:collect_backtraces]

    validate_event_keys(traces[2], @info_kvs)
    traces[2]['KVKey'].must_equal "msg"
    traces[2]['RemoteHost'].must_equal "127.0.0.1"
    traces[2].has_key?('Backtrace').must_equal TraceView::Config[:memcache][:collect_backtraces]

    traces[3].has_key?('KVHit').must_equal true
    traces[3].has_key?('Backtrace').must_equal TraceView::Config[:memcache][:collect_backtraces]

    validate_event_keys(traces[4], @exit_kvs)
  end

  it "should trace get_multi" do
    TraceView::API.start_trace('memcache_test', '', {}) do
      @mc.get_multi(['one', 'two', 'three', 'four', 'five', 'six'])
    end

    traces = get_all_traces

    traces.count.must_equal 5
    validate_outer_layers(traces, 'memcache_test')

    validate_event_keys(traces[1], @entry_kvs)

    traces[1]['KVOp'].must_equal "get_multi"

    validate_event_keys(traces[2], @info_kvs)
    traces[2]['KVKeyCount'].must_equal 6
    traces[2].has_key?('KVHitCount').must_equal true
    traces[2].has_key?('Backtrace').must_equal TraceView::Config[:memcache][:collect_backtraces]

    validate_event_keys(traces[3], @exit_kvs)
  end

  it "should trace add for existing key" do
    @mc.set('testKey', 'x', 1200)
    TraceView::API.start_trace('memcache_test', '', {}) do
      @mc.add('testKey', 'x', 1200)
    end

    traces = get_all_traces

    traces.count.must_equal 5
    validate_outer_layers(traces, 'memcache_test')

    validate_event_keys(traces[1], @entry_kvs)

    traces[1]['KVOp'].must_equal "add"
    traces[1].has_key?('Backtrace').must_equal TraceView::Config[:memcache][:collect_backtraces]

    validate_event_keys(traces[2], @info_kvs)
    traces[2]['KVKey'].must_equal "testKey"

    validate_event_keys(traces[3], @exit_kvs)
  end

  it "should trace append" do
    @mc.set('rawKey', "Peanut Butter ", 600, :raw => true)
    TraceView::API.start_trace('memcache_test', '', {}) do
      @mc.append('rawKey', "Jelly")
    end

    traces = get_all_traces

    traces.count.must_equal 5
    validate_outer_layers(traces, 'memcache_test')

    validate_event_keys(traces[1], @entry_kvs)

    traces[1]['KVOp'].must_equal "append"
    traces[1].has_key?('Backtrace').must_equal TraceView::Config[:memcache][:collect_backtraces]

    validate_event_keys(traces[2], @info_kvs)

    traces[2]['KVKey'].must_equal "rawKey"
    traces[2].has_key?('Backtrace').must_equal TraceView::Config[:memcache][:collect_backtraces]

    validate_event_keys(traces[3], @exit_kvs)
  end

  it "should trace decrement" do
    TraceView::API.start_trace('memcache_test', '', {}) do
      @mc.decr('memcache_key_counter', 1)
    end

    traces = get_all_traces

    traces.count.must_equal 5
    validate_outer_layers(traces, 'memcache_test')

    validate_event_keys(traces[1], @entry_kvs)

    traces[1]['KVOp'].must_equal "decr"
    traces[1].has_key?('Backtrace').must_equal TraceView::Config[:memcache][:collect_backtraces]

    traces[2]['KVKey'].must_equal "memcache_key_counter"
    traces[2].has_key?('Backtrace').must_equal TraceView::Config[:memcache][:collect_backtraces]

    validate_event_keys(traces[3], @exit_kvs)
  end

  it "should trace increment" do
    TraceView::API.start_trace('memcache_test', '', {}) do
      @mc.incr("memcache_key_counter", 1)
    end

    traces = get_all_traces

    traces.count.must_equal 5
    validate_outer_layers(traces, 'memcache_test')

    validate_event_keys(traces[1], @entry_kvs)
    traces[1]['KVOp'].must_equal "incr"
    validate_event_keys(traces[2], @info_kvs)
    traces[2]['KVKey'].must_equal "memcache_key_counter"
    validate_event_keys(traces[3], @exit_kvs)
  end

  it "should trace replace" do
    @mc.set("some_key", "blah")
    TraceView::API.start_trace('memcache_test', '', {}) do
      @mc.replace("some_key", "woop")
    end

    traces = get_all_traces

    traces.count.must_equal 5
    validate_outer_layers(traces, 'memcache_test')

    validate_event_keys(traces[1], @entry_kvs)
    traces[1]['KVOp'].must_equal "replace"
    traces[2]['KVKey'].must_equal "some_key"
    validate_event_keys(traces[2], @info_kvs)
    validate_event_keys(traces[3], @exit_kvs)
  end

  it "should trace delete" do
    TraceView::API.start_trace('memcache_test', '', {}) do
      @mc.delete("some_key")
    end

    traces = get_all_traces

    traces.count.must_equal 5
    validate_outer_layers(traces, 'memcache_test')

    validate_event_keys(traces[1], @entry_kvs)
    traces[1]['KVOp'].must_equal "delete"
    traces[2]['KVKey'].must_equal "some_key"
    validate_event_keys(traces[2], @info_kvs)
    validate_event_keys(traces[3], @exit_kvs)
  end

  it "should obey :collect_backtraces setting when true" do
    TraceView::Config[:memcache][:collect_backtraces] = true

    TraceView::API.start_trace('memcache_test', '', {}) do
      @mc.set('some_key', 1)
    end

    traces = get_all_traces
    layer_has_key(traces, 'memcache', 'Backtrace')
  end

  it "should obey :collect_backtraces setting when false" do
    TraceView::Config[:memcache][:collect_backtraces] = false

    TraceView::API.start_trace('memcache_test', '', {}) do
      @mc.set('some_key', 1)
    end

    traces = get_all_traces
    layer_doesnt_have_key(traces, 'memcache', 'Backtrace')
  end
end
