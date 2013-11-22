require 'minitest_helper'
require 'net/http'

describe Oboe::Inst do
  before do
    clear_all_traces 
    @collect_backtraces = Oboe::Config[:nethttp][:collect_backtraces]
  end

  after do
    Oboe::Config[:nethttp][:collect_backtraces] = @collect_backtraces
  end

  it 'Net::HTTP should be defined and ready' do
    defined?(::Net::HTTP).wont_match nil 
  end

  it 'Net::HTTP should have oboe methods defined' do
    [ :request_with_oboe ].each do |m|
      ::Net::HTTP.method_defined?(m).must_equal true
    end
  end

  it "should trace a Net::HTTP request to an instr'd app" do
    Oboe::API.start_trace('net-http_test', '', {}) do
      uri = URI('https://www.appneta.com')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.get('/?q=test').read_body
    end

    traces = get_all_traces
    traces.count.must_equal 5
    
    validate_outer_layers(traces, 'net-http_test')

    traces[1]['Layer'].must_equal 'net-http'
    traces[2]['IsService'].must_equal "1"
    traces[2]['RemoteProtocol'].must_equal "HTTPS"
    traces[2]['RemoteHost'].must_equal "www.appneta.com"
    traces[2]['ServiceArg'].must_equal "/?q=test"
    traces[2]['HTTPMethod'].must_equal "GET"
    traces[2]['HTTPStatus'].must_equal "200"
    traces[2].has_key?('Backtrace').must_equal Oboe::Config[:nethttp][:collect_backtraces]
  end
  
  it "should trace a Net::HTTP request" do
    Oboe::API.start_trace('net-http_test', '', {}) do
      uri = URI('https://www.google.com')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.get('/?q=test').read_body
    end

    traces = get_all_traces
    traces.count.must_equal 5
    
    validate_outer_layers(traces, 'net-http_test')

    traces[1]['Layer'].must_equal 'net-http'
    traces[2]['IsService'].must_equal "1"
    traces[2]['RemoteProtocol'].must_equal "HTTPS"
    traces[2]['RemoteHost'].must_equal "www.google.com"
    traces[2]['ServiceArg'].must_equal "/?q=test"
    traces[2]['HTTPMethod'].must_equal "GET"
    traces[2]['HTTPStatus'].must_equal "200"
    traces[2].has_key?('Backtrace').must_equal Oboe::Config[:nethttp][:collect_backtraces]
  end
  
  it "should obey :collect_backtraces setting when true" do
    Oboe::Config[:nethttp][:collect_backtraces] = true

    Oboe::API.start_trace('nethttp_test', '', {}) do
      uri = URI('https://www.appneta.com')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.get('/?q=test').read_body
    end

    traces = get_all_traces
    layer_has_key(traces, 'net-http', 'Backtrace')
  end

  it "should obey :collect_backtraces setting when false" do
    Oboe::Config[:nethttp][:collect_backtraces] = false

    Oboe::API.start_trace('nethttp_test', '', {}) do
      uri = URI('https://www.appneta.com')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.get('/?q=test').read_body
    end

    traces = get_all_traces
    layer_doesnt_have_key(traces, 'net-http', 'Backtrace')
  end
end
