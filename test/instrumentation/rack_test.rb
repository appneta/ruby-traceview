require 'minitest_helper'
require 'rack/test'
require 'rack/lobster'
require 'oboe/inst/rack'

Oboe::Config[:tracing_mode] = 'always'
Oboe::Config[:sample_rate] = 1e6
    
class RackTestApp < Minitest::Test
  include Rack::Test::Methods

  def app
    @app = Rack::Builder.new {
      use Rack::CommonLogger
      use Rack::ShowExceptions
      use Oboe::Rack
      map "/lobster" do
        use Rack::Lint
        run Rack::Lobster.new
      end
    }
  end

  def test_get_the_lobster
    clear_all_traces 

    get "/lobster"

    traces = get_all_traces
    traces.count.must_equal 3

    validate_outer_layers(traces, 'rack')

    kvs = {} 
    kvs["Label"] = "entry"
    validate_event_keys(traces[0], kvs)

    kvs.clear
    kvs["Label"] = "info"
    kvs["Status"] = "200"
    kvs["SampleRate"] = "1000000"
    kvs["SampleSource"] = "1"
    kvs["HTTP-Host"] = "example.org"
    kvs["Port"] = "80"
    kvs["Proto"] = "http"
    kvs["URL"] = "/lobster"
    kvs["Method"] = "GET"
    kvs["ClientIP"] = "127.0.0.1"
    validate_event_keys(traces[1], kvs)

    assert last_response.ok?
    assert last_response['X-Trace']
  end
  
  def test_dont_trace_static_assets
    clear_all_traces 

    get "/assets/static_asset.png"

    traces = get_all_traces
    assert traces.empty?

    assert last_response.status == 404
  end
end

