require 'minitest_helper'

describe Oboe::Config do
  after do
    # Set back to always trace mode
    Oboe::Config[:tracing_mode] = "always"
    Oboe::Config[:sample_rate] = 1000000
  end

  it 'should have the correct default values' do
    # Reset Oboe::Config to defaults
    Oboe::Config.initialize

    Oboe::Config[:verbose].must_equal false
    Oboe::Config[:tracing_mode].must_equal "through"
    Oboe::Config[:reporter_host].must_equal "127.0.0.1"
  end

  it 'should have the correct instrumentation defaults' do
    # Reset Oboe::Config to defaults
    Oboe::Config.initialize

    instrumentation = Oboe::Config.instrumentation_list

    # Verify the number of individual instrumentations
    instrumentation.count.must_equal 19

    Oboe::Config[:action_controller][:enabled].must_equal true
    Oboe::Config[:action_view][:enabled].must_equal true
    Oboe::Config[:active_record][:enabled].must_equal true
    Oboe::Config[:cassandra][:enabled].must_equal true
    Oboe::Config[:dalli][:enabled].must_equal true
    Oboe::Config[:em_http_request][:enabled].must_equal false
    Oboe::Config[:faraday][:enabled].must_equal true
    Oboe::Config[:grape][:enabled].must_equal true
    Oboe::Config[:nethttp][:enabled].must_equal true
    Oboe::Config[:memcached][:enabled].must_equal true
    Oboe::Config[:memcache][:enabled].must_equal true
    Oboe::Config[:mongo][:enabled].must_equal true
    Oboe::Config[:moped][:enabled].must_equal true
    Oboe::Config[:rack][:enabled].must_equal true
    Oboe::Config[:redis][:enabled].must_equal true
    Oboe::Config[:resque][:enabled].must_equal true

    Oboe::Config[:action_controller][:log_args].must_equal true
    Oboe::Config[:action_view][:log_args].must_equal true
    Oboe::Config[:active_record][:log_args].must_equal true
    Oboe::Config[:cassandra][:log_args].must_equal true
    Oboe::Config[:dalli][:log_args].must_equal true
    Oboe::Config[:em_http_request][:log_args].must_equal true
    Oboe::Config[:faraday][:log_args].must_equal true
    Oboe::Config[:grape][:log_args].must_equal true
    Oboe::Config[:nethttp][:log_args].must_equal true
    Oboe::Config[:memcached][:log_args].must_equal true
    Oboe::Config[:memcache][:log_args].must_equal true
    Oboe::Config[:mongo][:log_args].must_equal true
    Oboe::Config[:moped][:log_args].must_equal true
    Oboe::Config[:rack][:log_args].must_equal true
    Oboe::Config[:redis][:log_args].must_equal true
    Oboe::Config[:resque][:log_args].must_equal true

    Oboe::Config[:resque][:link_workers].must_equal false
    Oboe::Config[:blacklist].is_a?(Array).must_equal true

    Oboe::Config[:dnt_regexp].must_equal "\.(jpg|jpeg|gif|png|ico|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|bmp|rtf|js|flv|swf|ttf|woff|svg|less)$"
    Oboe::Config[:dnt_opts].must_equal Regexp::IGNORECASE
  end
end
