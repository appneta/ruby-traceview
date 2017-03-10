$:.push File.expand_path("../lib", __FILE__)
require "traceview/version"

Gem::Specification.new do |s|
  s.name = %q{traceview}
  s.version = TraceView::Version::STRING
  s.date = Time.now.strftime('%Y-%m-%d')

  s.license = "Librato Open License, Version 1.0"

  s.authors = ["Peter Giacomo Lombardo", "Spiros Eliopoulos"]
  s.email = %q{traceviewsupport@solarwinds.com}
  s.homepage = %q{https://traceview.solarwinds.com/}
  s.summary = %q{TraceView performance instrumentation gem for Ruby}
  s.description = %q{The TraceView gem provides performance instrumentation for MRI Ruby, JRuby and related frameworks.}

  s.extra_rdoc_files = ["LICENSE"]
  s.files = `git ls-files`.split("\n")
  s.test_files  = Dir.glob("{test}/**/*.rb")

  s.platform   = defined?(JRUBY_VERSION) ? 'java' : Gem::Platform::CURRENT
  s.extensions = ['ext/oboe_metal/extconf.rb'] unless defined?(JRUBY_VERSION)

  s.add_runtime_dependency('json', '>= 0')

  # Development dependencies used in gem development & testing
  s.add_development_dependency('rake', '>= 0.9.0')

  unless defined?(JRUBY_VERSION)
    case RUBY_VERSION
    when /^1\.8/
      s.add_development_dependency('ruby-debug', '>= 0.10.1')
      s.add_development_dependency('pry', '>= 0.9.12.4')
    when /^1\.9/
      s.add_development_dependency('debugger', '>= 1.6.7')
      s.add_development_dependency('pry', '>= 0.10.0')
    when /^2\./
      s.add_development_dependency('byebug', '>= 8.0.0')
      s.add_development_dependency('pry', '>= 0.10.0')
      s.add_development_dependency('pry-byebug', '>= 3.0.0')
    end
  else
    s.add_development_dependency('pry', '>= 0.10.0')
  end

  s.required_ruby_version = '>= 1.8.6'
end
