[![Build Status](https://travis-ci.org/GeorgeKaraszi/postgres_extended.svg?branch=master)](https://travis-ci.org/GeorgeKaraszi/postgres_extended) [![Maintainability](https://api.codeclimate.com/v1/badges/9b5bb16d02df58c395f6/maintainability)](https://codeclimate.com/github/GeorgeKaraszi/postgres_extended/maintainability)

# PostgresExtended

Postgres Extended is the continuation of maintaining and improving the work done by **Dan McClain**, the original author of [postgres_ext](https://github.com/DavyJonesLocker/postgres_ext).

Overtime the lack of updating to support the latest versions of ActiveRecord 5.x has caused quite a bit of users forking off the project to create their own patches jobs to maintain compatibility. 
The only problem is that this has created a wild west of environments of sorts. The problem has grown to the point no one is attempting to directly contribute to the original source. And forked repositories are finding themselves as equally as dead with little to no activity.

Postgres Extended is intended to be a supporting community that will maintain compatibility for the foreseeable future.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'postgres_extended'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install postgres_extended


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/postgres_extended. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the PostgresExtended project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/postgres_extended/blob/master/CODE_OF_CONDUCT.md).
