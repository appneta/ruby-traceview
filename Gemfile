source 'https://rubygems.org'

# Import dependencies from oboe.gemspec
gemspec :name => 'oboe'

gem 'rake'

group :development, :test do
  gem 'minitest'
  gem 'minitest-reporters'
  gem 'rack-test'
  gem 'appraisal'
end

group :development do
  gem 'ruby-debug',   :platform => :mri_18
  gem 'ruby-debug19', :platform => :mri_19, :require => 'ruby-debug'
  gem 'debugger',     :platform => :mri_20 
  gem 'perftools.rb', :platform => :mri,    :require => 'perftools'
end

# Instrumented gems
gem 'dalli'
gem 'memcache-client'
gem 'memcached' if (RUBY_VERSION =~ /^1./) == 0
gem 'cassandra'
gem 'mongo'
gem 'bson_ext' # For Mongo, Yours Truly
gem 'moped' unless (RUBY_VERSION =~ /^1.8/) == 0
gem 'resque'
gem 'rack-test'

