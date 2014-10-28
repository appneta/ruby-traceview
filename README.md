# Welcome to the TraceView Ruby Gem
## AKA The oboe gem
[![Gitter](https://badges.gitter.im/Join Chat.svg)](https://gitter.im/appneta/oboe-ruby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

The oboe gem provides AppNeta [TraceView](http://www.appneta.com/application-performance-management/) instrumentation for Ruby.

![Ruby TraceView](https://s3.amazonaws.com/pglombardo/oboe-ruby-header.png)

It has the ability to report performance metrics on an array of libraries, databases and frameworks such as Rails, Mongo, Memcache, ActiveRecord, Cassandra, Rack, Resque [and more](https://support.appneta.com/cloud/ruby-instrumentation-release-notes)

It requires a [TraceView](http://www.appneta.com/products/traceview/) account to view metrics.  Get yours, [it's free](http://www.appneta.com/products/traceview-free-account/).

[![Gem Version](https://badge.fury.io/rb/oboe.png)](http://badge.fury.io/rb/oboe)
[![Build Status](https://travis-ci.org/appneta/oboe-ruby.png?branch=master)](https://travis-ci.org/appneta/oboe-ruby)
[![Code Climate](https://codeclimate.com/github/appneta/oboe-ruby.png)](https://codeclimate.com/github/appneta/oboe-ruby)

# Installation

The oboe gem is [available on Rubygems](https://rubygems.org/gems/oboe) and can be installed with:

```bash
gem install oboe
```

or added to _the end_ of your bundle Gemfile and running `bundle install`:

```ruby
gem 'oboe'
```

On Heroku?  Use the `oboe-heroku` gem instead.  It wraps some additional functionality specialized for Heroku.

# Running

## Rails

No special steps are needed to instrument Ruby on Rails.  Once part of the bundle, the oboe gem will automatically detect Rails and instrument on stack initialization.

*Note: Unless you are Heroku, you will still need to decide on your `tracing_mode` depending on whether you are running with an instrumented Apache or nginx in front of your Rails stack.  See below for more details.*

### The Install Generator

The oboe gem provides a Rails generator used to seed an oboe initializer where you can configure and control `tracing_mode`, `sample_rate` and [other options](https://support.appneta.com/cloud/configuring-ruby-instrumentation)

To run the install generator run:

```bash
bundle exec rails generate oboe:install
```

After the prompts, this will create an initializer: `config/initializers/oboe.rb`.

## Sinatra

You can instrument your Sinatra application by adding the following code to your `config.ru` Rackup file:

```ruby
# If you're not using Bundler.require.  Make sure this is done
# after the Sinatra require directive.
require 'oboe'

# When traces should be initiated for incoming requests. Valid options are
# "always", "through" (when the request is initiated with a tracing header
# from upstream) and "never". You must set this directive to "always" in
# order to initiate tracing.
Oboe::Config[:tracing_mode] = 'through'

# You may want to replace the Oboe.logger with whichever logger you are using
# Oboe.logger = Sinatra.logger
```

Note: If you're on Heroku, you don't need to set `tracing_mode` - it will be automatically configured.

Make sure that the oboe gem is loaded _after_ Sinatra either by listing `gem 'oboe'` after Sinatra in your Gemfile or calling the `require 'oboe'` directive after Sinatra is loaded.

With this, the oboe gem will automatically detect Sinatra on boot and instrument key components.

## Padrino

As long as the oboe gem is in your `Gemfile` (inserted after the `gem 'padrino'` directive) and you are calling `Bundler.require`, the oboe gem will automatically instrument Padrino applications.

If you need to set `Oboe::Config` values on stack boot, you can do so by adding the following
to your `config/boot.rb` file:

```ruby
Padrino.before_load do
  # When traces should be initiated for incoming requests. Valid options are
  # "always", "through" (when the request is initiated with a tracing header
  # from upstream) and "never". You must set this directive to "always" in
  # order to initiate tracing.
  Oboe::Config[:tracing_mode] = 'always'
end
```

Note: If you're on Heroku, you don't need to set `tracing_mode` - it will be automatically configured.

## Grape

You can instrument your Grape application by adding the following code to your `config.ru` Rackup file:

```ruby
    # If you're not using Bundler.require.  Make sure this is done
    # after the Grape require directive.
    require 'oboe'
    
    # When traces should be initiated for incoming requests. Valid options are
    # "always", "through" (when the request is initiated with a tracing header 
    # from upstream) and "never". You must set this directive to "always" in 
    # order to initiate tracing.
    Oboe::Config[:tracing_mode] = 'through'
    
    ...

    class App < Grape::API
      use Oboe::Rack
    end
```

Note: If you're on Heroku, you don't need to set `tracing_mode` - it will be automatically configured.

Make sure that the oboe gem is loaded _after_ Grape either by listing `gem 'oboe'` after Grape in your Gemfile or calling the `require 'oboe'` directive after Grape is loaded.

You must explicitly tell your Grape application to use Oboe::Rack for tracing to occur.

## Custom Ruby Scripts & Applications

The oboe gem has the ability to instrument any arbitrary Ruby application or script.  Only the `tracing_mode` needs to be set to tell the oboe gem to initiate performance metric collection.

```ruby
require 'rubygems'
require 'bundler'

Bundler.require

require 'oboe'

# Tracing mode can be 'never', 'through' (to follow upstream) or 'always'
Oboe::Config[:tracing_mode] = 'always'
```

From here, you can use the Tracing API to instrument areas of code using `Oboe::API.start_trace` (see below).  If you prefer to instead dive directly into code, take a look at [this example](https://gist.github.com/pglombardo/8550713) of an instrumented Ruby script.

Once inside of the `Oboe::API.start_trace` block, performance metrics will be automatically collected for all supported libraries and gems (Redis, Mongo, ActiveRecord etc..).

## Other

You can send deploy notifications to TraceView and have the events show up on your dashboard.  See: [Capistrano Deploy Notifications with tlog](https://support.appneta.com/cloud/capistrano-deploy-notifications-tlog)

# Custom Tracing

## The Tracing API

You can instrument any arbitrary block of code using `Oboe::API.trace`:

```ruby
# layer_name will show up in the TraceView app dashboard
layer_name = 'subsystemX'

# report_kvs are a set of information Key/Value pairs that are sent to
# TraceView dashboard along with the performance metrics.  These KV
# pairs are used to report request, environment and/or client specific
# information.

report_kvs = {}
report_kvs[:mykey] = @client.id

Oboe::API.trace(layer_name, report_kvs) do
  # the block of code to be traced
end
```

`Oboe::API.trace` is used within the context of a request.  It will follow the upstream state of the request being traced.  i.e. the block of code will only be traced when the parent request is being traced.

This tracing state of a request can also be queried by using `Oboe.tracing?`.

If you need to instrument code outside the context of a request (such as a cron job, background job or an arbitrary ruby script), use `Oboe::API.start_trace` instead which will initiate new traces based on configuration and probability (based on the sample rate).

Find more details in the [RubyDoc page](http://rdoc.info/gems/oboe/Oboe/API/Tracing) or in [this example](https://gist.github.com/pglombardo/8550713) on how to use the Tracing API in an independent Ruby script.

## Tracing Methods

By using class level declarations, it's possible to automatically have certain methods on that class instrumented and reported to your TraceView dashboard automatically.

The pattern for Method Profiling is as follows:

```ruby
# 'profile_name' is similar to a layer name.
# It identifies this custom trace in your dashboard.
#
class Engine
    include OboeMethodProfiling

    def processor()
        # body of method
    end

    # call syntax: profile_method <method>, <profile_name>
    profile_method :processor, 'processor'
end
```

This example demonstrates method profiling of instance methods.  Class methods are profiled slightly differently.  See the TraceView [documentation portal](https://support.appneta.com/cloud/ruby-custom) for full details.

# Support

If you find a bug or would like to request an enhancement, feel free to file an issue.  For all other support requests, see our [support portal](https://support.appneta.com/cloud) or on IRC @ #appneta on [Freenode](http://freenode.net/).

# Contributing

You are obviously a person of great sense and intelligence.  We happily appreciate all contributions to the oboe gem whether it is documentation, a bug fix, new instrumentation for a library or framework or anything else we haven't thought of.

We welcome you to send us PRs.  We also humbly request that any new instrumentation submissions have corresponding tests that accompany them.  This way we don't break any of your additions when we (and others) make changes after the fact.

## Developer Resources

We at AppNeta have made a large effort to expose as much technical information as possible to assist developers wishing to contribute to the oboe gem.  Below are the three major sources for information and help for developers:

* The [TraceView blog](http://www.appneta.com/blog) has a constant stream of great technical articles.  (See [A Gentle X-Trace Introduction](http://www.appneta.com/blog/x-trace-introduction/) for details on the basic methodology that TraceView uses to gather structured performance data across hosts and stacks.)

* The [TraceView Knowledge Base](https://support.tv.appneta.com) has a large collection of technical articles or, if needed, you can submit a support request directly to the team.

* You can also reach the TraceView team on our IRC channel #appneta on freenode.

If you have any questions or ideas, don't hesitate to contact us anytime.

## Layout of the Gem

The oboe gem uses a standard gem layout.  Here are the notable directories.

    lib/oboe/inst               # Auto load directory for various instrumented libraries
    lib/oboe/frameworks         # Framework instrumentation directory
    lib/oboe/frameworks/rails   # Files specific to Rails instrumentation
    lib/rails                   # A Rails required directory for the Rails install generator
    lib/api                     # The TraceView Tracing API: layers, logging, profiling and tracing
    ext/oboe_metal              # The Ruby c extension that links against the system liboboe library

## Building the Gem

The oboe gem is built with the standard `gem build` command passing in the gemspec:

```bash
gem build oboe.gemspec
```

## Writing Custom Instrumentation

Custom instrumentation for a library, database or other service can be authored fairly easily.  Generally, instrumentation of a library is done by wrapping select operations of that library and timing their execution using the Oboe Tracing API which then reports the metrics to the users' TraceView dashboard.

Here, I'll use a stripped down version of the Dalli instrumentation (`lib/oboe/inst/dalli.rb`) as a quick example of how to instrument a client library (the dalli gem).

The Dalli gem nicely routes all memcache operations through a single `perform` operation.  Wrapping this method allows us to capture all Dalli operations called by an application.

First, we define a module (Oboe::Inst::Dalli) and our own custom `perform_with_oboe` method that we will use as a wrapper around Dalli's `perform` method.  We also declare an `included` method which automatically gets called when this module is included by another.  See ['included' Ruby reference documentation](http://apidock.com/ruby/Module/included).

```ruby
module Oboe
  module Inst
    module Dalli
      include Oboe::API::Memcache

      def self.included(cls)
        cls.class_eval do
          if ::Dalli::Client.private_method_defined? :perform
            alias perform_without_oboe perform
            alias perform perform_with_oboe
          end
        end
      end

      def perform_with_oboe(*all_args, &blk)
        op, key, *args = *all_args

        if Oboe.tracing?
          opts = {}
          opts[:KVOp] = op
          opts[:KVKey] = key

          Oboe::API.trace('memcache', opts || {}) do
            result = perform_without_oboe(*all_args, &blk)
            if op == :get and key.class == String
                Oboe::API.log('memcache', 'info', { :KVHit => memcache_hit?(result) })
            end
            result
          end
        else
          perform_without_oboe(*all_args, &blk)
        end
      end
    end
  end
end
```

Second, we tail onto the end of the instrumentation file a simple `::Dalli::Client.module_eval` call to tell the Dalli module to include our newly defined instrumentation module.  Doing this will invoke our previously defined `included` method.

```ruby
if defined?(Dalli) and Oboe::Config[:dalli][:enabled]
  ::Dalli::Client.module_eval do
    include Oboe::Inst::Dalli
  end
end
```

Third, in our wrapper method, we capture the arguments passed in, collect the operation and key information into a local hash and then invoke the `Oboe::API.trace` method to time the execution of the original operation.

The `Oboe::API.trace` method calls Dalli's native operation and reports the timing metrics and your custom `report_kvs` up to TraceView servers to be shown on the user's dashboard.

That is a very quick example of a simple instrumentation implementation.  If you have any questions, visit us on IRC in #appneta on Freenode.

Some other tips and guidelines:

* You can point your Gemfile directly at your cloned oboe source by using `gem 'oboe', :path => '/path/to/oboe-ruby'`

* If instrumenting a library, database or service, place your new instrumentation file into the `lib/oboe/inst/` directory.  From there, the oboe gem will detect it and automatically load the instrumentation file.

* If instrumenting a new framework, place your instrumentation file in `lib/oboe/frameworks`.  Refer to the Rails instrumentation for on ideas on how to load the oboe gem correctly in your framework.

* Review other existing instrumentation similar to the one you wish to author.  `lib/oboe/inst/` is a great place to start.

* Depending on the configured `:sample_rate`, not all requests will be traced.  Use `Oboe.tracing?` to determine of this is a request that is being traced.

* Performance is paramount.  Make sure that your wrapped methods don't slow down users applications.

* Include tests with your instrumentation.  See `test/instrumentation/` for some examples of existing instrumentation tests.

## Compiling the C extension

The oboe gem utilizes a C extension to interface with the system `liboboe.so` library.  This system library is installed with the TraceView host packages (tracelyzer, liboboe0, liboboe-dev) and is used to report [host](http://www.appneta.com/blog/app-host-metrics/) and performance metrics from multiple sources (Ruby, Apache, Python etc.) back to TraceView servers.

C extensions are usually built on `gem install` but when working out of a local git repository, it's required that you manually build this C extension for the gem to function.

To make this simpler, we've included a few rake tasks to automate this process:

```bash
rake compile             # Build the gem's c extension
rake distclean           # Remove all built files and extensions
rake recompile           # Rebuild the gem's c extension
```

Note: Make sure you have the development package `liboboe0-dev` installed before attempting to compile the C extension.

```bash
>$ dpkg -l | grep liboboe
ii  liboboe-dev    1.1.1-precise1    Tracelytics common library -- development files
ii  liboboe0       1.1.1-precise1    Tracelytics common library
```

See [Installing Base Packages on Debian and Ubuntu](https://support.appneta.com/cloud/installing-traceview) in the Knowledge Base for details.  Our hacker extraordinaire [Rob Salmond](https://github.com/rsalmond) from the support team has even gotten these packages to [run on Gentoo](http://www.appneta.com/blog/unsupported-doesnt-work/)!

To see the code related to the C extension, take a look at `ext/oboe_metal/extconf.rb` for details.

You can read more about Ruby gems with C extensions in the [Rubygems Guides](http://guides.rubygems.org/gems-with-extensions/).

## Running the Tests

The tests bundled with the gem are implemented using [Minitest](https://github.com/seattlerb/minitest).  The tests are currently used to validate the sanity of the traces generated and basic gem functionality.

After a bundle install, the tests can be run as:

```bash
bundle exec rake test
```

This will run a full end-to-end test suite that covers all supported libraries and databases.  Note that this requires all of the supported software (Cassandra, Memcache, Mongo etc.) to be installed, configured and available.

Since this is overly burdensome for casual users, you can run just the tests that you're interested in.

To run just the tests for the dalli gem trace validation:

```bash
bundle exec rake test TEST=test/instrumentation/dalli_test.rb
```

We humbly request that any submitted instrumentation is delivered with corresponding test coverage.

# License

Copyright (c) 2014 Appneta

Released under the [AppNeta Open License](http://www.appneta.com/appneta-license), Version 1.0

