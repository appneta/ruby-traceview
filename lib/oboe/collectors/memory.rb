# Copyright (c) 2014 AppNeta, Inc.
# All rights reserved.

Oboe.collector.register do
  report_kvs = {}

  report_kvs[:ThreadCount] = Thread.list.count

  filename = "/proc/#{Process.pid}/status"
  if File.readable?(filename)
    File.open(filename, "r").read_nonblock(4096) =~ /RSS:\s*(\d+) kB/i
    report_kvs[:VmRSS] = $1
  end

  report_kvs
end
