source 'https://rubygems.org'

group :development, :test do
  gem 'rake'
  gem 'minitest'
  gem 'minitest-reporters', '< 1.0.18'
  gem 'minitest-debugger', :require => false
  gem 'rack-test'
  gem 'puma'
  if RUBY_VERSION < '1.9.3'
    gem 'bson', '<= 1.12.3'
  else
    gem 'bson'
  end
end

group :development do
  gem 'ruby-debug',   :platforms => [:mri_18, :jruby]
  gem 'debugger',     :platform  =>  :mri_19
  gem 'byebug',       :platforms => [:mri_20, :mri_21, :mri_22]
  #  gem 'perftools.rb', :platforms => [ :mri_20, :mri_21 ], :require => 'perftools'
  if RUBY_VERSION > '1.8.7'
    gem 'pry'
    gem 'pry-byebug', :platforms => [:mri_20, :mri_21, :mri_22]
  else
    gem 'pry', '0.9.12.4'
  end
end

if defined?(JRUBY_VERSION)
  gem 'sinatra', :require => false
else
  gem 'sinatra'
end

gemspec
