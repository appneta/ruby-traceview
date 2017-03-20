#!/usr/bin/env rake

require 'rubygems'
require 'bundler/setup'
require 'rake/testtask'
require 'traceview/test'

Rake::TestTask.new do |t|
  t.verbose = false
  t.warning = false
  t.ruby_opts = []
  t.libs << 'test'

  # Since we support so many libraries and frameworks, tests
  # runs are segmented into gemfiles that have different
  # sets and versions of gems (libraries and frameworks).
  #
  # Here we detect the Gemfile the tests are being run against
  # and load the appropriate tests.
  #
  case TraceView::Test.gemfile
  when /delayed_job/
    require 'delayed/tasks'
    t.test_files = FileList["test/queues/delayed_job*_test.rb"]
  when /rails/
    # Pre-load rails to get the major version number
    require 'rails'

    if Rails::VERSION::MAJOR == 5
      t.test_files = FileList["test/frameworks/rails#{Rails::VERSION::MAJOR}x_test.rb"] +
                     FileList["test/frameworks/rails#{Rails::VERSION::MAJOR}x_api_test.rb"]
    else
      t.test_files = FileList["test/frameworks/rails#{Rails::VERSION::MAJOR}x_test.rb"]
    end

  when /frameworks/
    t.test_files = FileList['test/frameworks/sinatra*_test.rb'] +
                   FileList['test/frameworks/padrino*_test.rb'] +
                   FileList['test/frameworks/grape*_test.rb']
  when /libraries/
    t.test_files = FileList['test/support/*_test.rb'] +
                   FileList['test/reporter/*_test.rb'] +
                   FileList['test/instrumentation/*_test.rb'] +
                   FileList['test/profiling/*_test.rb']
  end

  if defined?(JRUBY_VERSION)
    t.ruby_opts << ['-J-javaagent:/usr/local/tracelytics/tracelyticsagent.jar']
  end
end

desc "Build the gem's c extension"
task :compile do
  if !defined?(JRUBY_VERSION)
    puts "== Building the c extension against Ruby #{RUBY_VERSION}"

    pwd     = Dir.pwd
    ext_dir = File.expand_path('ext/oboe_metal')
    lib_dir = File.expand_path('lib')
    symlink = File.expand_path('lib/oboe_metal.so')
    so_file = File.expand_path('ext/oboe_metal/oboe_metal.so')

    Dir.chdir ext_dir
    cmd = [ Gem.ruby, 'extconf.rb']
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
      puts '!! See http://docs.traceview.solarwinds.com/TraceView/install-instrumentation.html'
    end
  else
    puts '== Nothing to do under JRuby.'
  end
end

desc 'Clean up extension build files'
task :clean do
  if !defined?(JRUBY_VERSION)
    pwd     = Dir.pwd
    ext_dir = File.expand_path('ext/oboe_metal')
    symlink = File.expand_path('lib/oboe_metal.so')

    File.delete symlink if File.exist? symlink
    Dir.chdir ext_dir
    sh '/usr/bin/env make clean'

    Dir.chdir pwd
  else
    puts '== Nothing to do under JRuby.'
  end
end

desc 'Remove all built files and extensions'
task :distclean do
  if !defined?(JRUBY_VERSION)
    pwd     = Dir.pwd
    ext_dir = File.expand_path('ext/oboe_metal')
    symlink = File.expand_path('lib/oboe_metal.so')
    mkmf_log = File.expand_path('ext/oboe_metal/mkmf.log')

    if File.exist? mkmf_log
      File.delete symlink if File.exist? symlink
      Dir.chdir ext_dir
      sh '/usr/bin/env make distclean'

      Dir.chdir pwd
    else
      puts 'Nothing to distclean. (nothing built yet?)'
    end
  else
    puts '== Nothing to do under JRuby.'
  end
end

desc "Rebuild the gem's c extension"
task :recompile => [:distclean, :compile]

task :environment do
  ENV['TRACEVIEW_GEM_VERBOSE'] = 'true'

  Bundler.require(:default, :development)
  TraceView::Config[:tracing_mode] = :always
  TV::Test.load_extras

  if TV::Test.gemfile?(:delayed_job)
    require 'delayed/tasks'
  end
end

task :console => :environment do
  ARGV.clear
  if TV::Test.gemfile?(:delayed_job)
    require './test/servers/delayed_job'
  end
  ENV['RACK_ENV'] = 'development'
  Pry.start
end

# Used when testing Resque locally
task 'resque:setup' => :environment do
  require 'resque/tasks'
end
