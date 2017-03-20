# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

class TracingModeTest  < Minitest::Test
  def setup
    TraceView::Config[:tracing_mode] = :always
  end

  def test_dont_start_trace_when_through
    # JRuby tracing mode is handled by tracelyticsagent.json
    # so these tests won't work there.
    skip if defined?(JRUBY_VERSION)

    TraceView::Config[:tracing_mode] = :through

    TV::API.start_trace(:test_through) do
      TraceView.tracing?.must_equal false
    end
  end

  def test_trace_when_always
    TraceView::Config[:tracing_mode] = :always

    TV::API.start_trace(:test_always) do
      TraceView.tracing?.must_equal true
    end
  end

  def test_dont_trace_when_never
    # JRuby tracing mode is handled by tracelyticsagent.json
    # so these tests won't work there.
    skip if defined?(JRUBY_VERSION)

    TraceView::Config[:tracing_mode] = :never

    TV::API.start_trace(:test_never) do
      TraceView.tracing?.must_equal false
    end

    TV::API.start_trace('asdf') do
      TraceView.tracing?.must_equal false
    end
  end
end
