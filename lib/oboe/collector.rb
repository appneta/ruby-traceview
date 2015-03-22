module Oboe
  ##
  # The Collector class is used to register blocks of code
  # that collect various metrics and run them in a dedicated
  # thread reporting the results to the TraceView dashboard.
  #
  class Collector
    extend ::Oboe::ThreadLocal

    attr_accessor :collectors
    attr_accessor :sleep_interval
    attr_accessor :time_to_exit
    thread_local  :thread_id

    def initialize
      @collectors = []
      @time_to_exit = false
      @sleep_interval = Oboe::Config[:collector][:sleep_interval]
    end

    ##
    # Load all of the collector files in lib/oboe/collectors
    #
    def load
      pattern = File.join(File.dirname(__FILE__), 'collectors', '*.rb')
      Dir.glob(pattern) do |f|
        begin
          require f
        rescue => e
          Oboe.logger.error "[oboe/loading] Error loading collector file '#{f}' : #{e}"
        end
      end
    end

    ##
    # Register a block of code to be periodically run in the
    # collector thread.  It should return a hash of key/values
    # that will then be sent to TraceView dashboard as metrics.
    #
    def register(work_proc = nil, &block)
      if block_given?
        collectors << block
      elsif proc
        collectors << proc
      else
        raise "[oboe/collector] Neither block or proc passed to register."
      end
    end

    ##
    # Start the collector thread with all of the registered collector blocks
    #
    def start
      kvs = {}

      raise "no collectors registered" if @collectors.empty?

      # Collector Thread
      @thread_id = Thread.new do
        loop do
          collectors.each do |b|
            begin
              kvs.merge! b.call
            rescue => e
              Oboe.logger.warn "[oboe/collector] #{e.inspect}"
            end
          end

          Oboe::API.start_trace('RubyMetrics', nil, { 'Force' => true, :ProcessName => Process.pid } ) do
            Oboe::API.log('RubyMetrics', 'metrics', kvs)
          end

          kvs.clear

          break if @time_to_exit
          sleep @sleep_interval
        end
      end
    rescue => e
      Oboe.logger.warn "[oboe/warn] Collector exiting on exception: #{e.message}"
      raise
    end

    def stop
      Thread.kill(@thread_id)
    end
  end
end

Oboe.collector = ::Oboe::Collector.new
