[![Build Status](https://travis-ci.com/GeorgeKaraszi/ActiveRecordExtended.svg?branch=master)](https://travis-ci.com/GeorgeKaraszi/ActiveRecordExtended) [![Maintainability](https://api.codeclimate.com/v1/badges/98ecffc0239417098cbc/maintainability)](https://codeclimate.com/github/GeorgeKaraszi/active_record_extended/maintainability)

# Active Record Extended

Active Record Extended is the continuation of maintaining and improving the work done by **Dan McClain**, the original author of [postgres_ext](https://github.com/DavyJonesLocker/postgres_ext).

Overtime the lack of updating to support the latest versions of ActiveRecord 5.x has caused quite a bit of users forking off the project to create their own patches jobs to maintain compatibility. 
The only problem is that this has created a wild west of environments of sorts. The problem has grown to the point no one is attempting to directly contribute to the original source. And forked repositories are finding themselves as equally as dead with little to no activity.

Active Record Extended is intended to be a supporting community that will maintain compatibility for the foreseeable future.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'active_record_extended'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install active_record_extended


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
