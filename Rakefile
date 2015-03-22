#!/usr/bin/env rake

require 'rubygems'
require 'bundler/setup'
require 'rake/testtask'

if RUBY_VERSION > '1.8.7'
  require 'appraisal'
end

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/**/*_test.rb']
  t.verbose = true
  if defined?(JRUBY_VERSION)
    t.ruby_opts = ['-J-javaagent:/usr/local/tracelytics/tracelyticsagent.jar']
  end
end

if !ENV['APPRAISAL_INITIALIZED'] && !ENV['TRAVIS']
  task :default => :appraisal
else
  task :default => :test
end

desc 'Build the gem\'s c extension'
task :compile do
  if defined?(JRUBY_VERSION)
    puts '== Nothing to do under JRuby.'
  else
    puts "== Building the c extension against Ruby #{RUBY_VERSION}"

    pwd     = Dir.pwd
    ext_dir = File.expand_path('ext/oboe_metal')
    lib_dir = File.expand_path('lib')
    symlink = File.expand_path('lib/oboe_metal.so')
    so_file = File.expand_path('ext/oboe_metal/oboe_metal.so')

    Dir.chdir ext_dir
    cmd = [Gem.ruby, 'extconf.rb']
    sh cmd.join(' ')
    sh '/usr/bin/env make'
    File.delete symlink if File.exist? symlink

    if File.exist? so_file
      File.symlink so_file, symlink
      Dir.chdir pwd
      puts "== Extension built and symlink'd to #{symlink}"
    else
      Dir.chdir pwd
      puts '!! Extension failed to build (see above).  Are the base TraceView packages installed?'
      puts '!! See https://support.appneta.com/cloud/installing-traceview'
    end
  end
end

desc 'Clean up extension build files'
task :clean do
  if defined?(JRUBY_VERSION)
    puts '== Nothing to do under JRuby.'
  else
    pwd     = Dir.pwd
    ext_dir = File.expand_path('ext/oboe_metal')
    lib_dir = File.expand_path('lib')
    symlink = File.expand_path('lib/oboe_metal.so')
    so_file = File.expand_path('ext/oboe_metal/oboe_metal.so')

    Dir.chdir ext_dir
    sh '/usr/bin/env make clean'

    Dir.chdir pwd
  end
end

desc 'Remove all built files and extensions'
task :distclean do
  if defined?(JRUBY_VERSION)
    puts '== Nothing to do under JRuby.'
  else
    pwd     = Dir.pwd
    ext_dir = File.expand_path('ext/oboe_metal')
    lib_dir = File.expand_path('lib')
    symlink = File.expand_path('lib/oboe_metal.so')
    so_file = File.expand_path('ext/oboe_metal/oboe_metal.so')
    mkmf_log = File.expand_path('ext/oboe_metal/mkmf.log')

    if File.exist? mkmf_log
      Dir.chdir ext_dir
      File.delete symlink if File.exist? symlink
      sh '/usr/bin/env make distclean'

      Dir.chdir pwd
    else
      puts 'Nothing to distclean. (nothing built yet?)'
    end
  end
end

desc 'Rebuild the gem\'s c extension'
task :recompile => [:distclean, :compile]

task :console do
  ENV['OBOE_GEM_VERBOSE'] = 'true'
  GC::Profiler.enable
  Bundler.require(:default, :development)
  Oboe::Config[:tracing_mode] = :always
  ARGV.clear
  Pry.start
end
