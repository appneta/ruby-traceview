# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'traceview'

begin
  r = TraceView::UdpReporter.new('127.0.0.1')
  TraceView::Context.init()
  e = TraceView::Context.createEvent()
  e.addInfo("TestKey", "TestValue")
  result = r.sendReport(e)

  if result
    puts "All appears well!"
  else
    puts "Reporter returned: #{result}"
  end
rescue => e
  $stderr.puts e.inspect
end

