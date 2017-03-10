# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'mkmf'
require 'rbconfig'

ext_dir = File.expand_path(File.dirname(__FILE__))

# Check if we're running in JRuby
jruby = defined?(JRUBY_VERSION) ? true : false

# Set the mkmf lib paths so we have no issues linking to
# the TraceView libs.
tv_lib = File.join(ext_dir, 'lib')
tv_include = File.join(ext_dir, 'src')

# Create symlinks for the TraceView library
target = File.join(tv_lib, 'liboboe-1.0.so.1.6.0')
File.symlink(target, File.join(tv_lib, 'liboboe.so'))
File.symlink(target, File.join(tv_lib, 'liboboe-1.0.so.1'))

dir_config('oboe', tv_include, tv_lib)

if jruby || ENV.key?('TRACEVIEW_URL')
  # Build the noop extension under JRuby and Heroku.
  # The oboe-heroku gem builds it's own c extension which links to
  # libs specific to a Heroku dyno
  # FIXME: For JRuby we need to remove the c extension entirely
  create_makefile('oboe_noop', 'noop')

elsif have_library('oboe', 'oboe_config_get_revision', 'oboe.h')

  $libs = append_library($libs, 'oboe')
  $libs = append_library($libs, 'stdc++')

  $CFLAGS << " #{ENV['CFLAGS']}"
  $CPPFLAGS << " #{ENV['CPPFLAGS']}"
  $LIBS << " #{ENV['LIBS']}"
  $LDFLAGS << " #{ENV['LDFLAGS']} -Wl,-rpath=#{tv_lib}"

  if RUBY_VERSION < '1.9'
    cpp_command('g++')
    $CPPFLAGS << '-I./src/'
  end
  create_makefile('oboe_metal', 'src')

else
  if have_library('oboe')
    $stderr.puts 'Error: The oboe gem requires an updated liboboe.  Please update your liboboe packages.'
  end

  $stderr.puts 'Error: Could not find the base liboboe libraries.  No tracing will occur.'
  create_makefile('oboe_noop', 'noop')
end
