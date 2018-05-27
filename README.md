[![Build Status](https://travis-ci.com/GeorgeKaraszi/ActiveRecordExtended.svg?branch=master)](https://travis-ci.com/GeorgeKaraszi/ActiveRecordExtended) 
[![Maintainability](https://api.codeclimate.com/v1/badges/98ecffc0239417098cbc/maintainability)](https://codeclimate.com/github/GeorgeKaraszi/active_record_extended/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/f22154211bb3a8feb89f/test_coverage)](https://codeclimate.com/github/GeorgeKaraszi/ActiveRecordExtended/test_coverage)
## Index
- [Description and history](#description-and-history)
- [Installation](#installation)
- [Useage](#usage)
  - [Query Methods](#query-methods)
    - [Any](#any)
    - [All](#all)
    - [Contains](#contains)
    - [Overlap](#overlap)
    - [Inet / IP Address](#inet--ip-address)
      - [Inet Contains](#inet-contains)
      - [Inet Contains or Equals](#inet-contains-or-equals)
      - [Inet Contained Within](#inet-contained-within)
      - [Inet Contained Within or Equals](#inet-contained-within-or-equals)
      - [Inet Contains or Contained Within](#inet-contains-or-contained-within)
  - [Conditional Methods](#conditional-methods)
    - [Any_of / None_of](#any_of--none_of)
    - [Either Join](#either-join)
    - [Either Order](#either-order)

## Description and History

Active Record Extended is the continuation of maintaining and improving the work done by **Dan McClain**, the original author of [postgres_ext](https://github.com/DavyJonesLocker/postgres_ext).

Overtime the lack of updating to support the latest versions of ActiveRecord 5.x has caused quite a bit of users forking off the project to create their own patches jobs to maintain compatibility. 
The only problem is that this has created a wild west of environments of sorts. The problem has grown to the point no one is attempting to directly contribute to the original source. And forked repositories are finding themselves as equally as dead with little to no activity.

Active Record Extended is intended to be a supporting community that will maintain compatibility for the foreseeable future.


## Usage

### Query Methods

#### Any
[Postgres 'ANY' expression](https://www.postgresql.org/docs/10/static/functions-comparisons.html#id-1.5.8.28.16)

In Postgres the `ANY` expression is used for gather record's that have an Array column type that contain a single matchable value within its array. 

```ruby
alice = Person.create!(tags: [1])
bob   = Person.create!(tags: [1, 2])
randy = Person.create!(tags: [3])

Person.where.any(tags: 1) #=> [alice, bob] 

```

This only accepts a single value. So querying for example multiple tag numbers `[1,2]` will return nothing.


#### All
[Postgres 'ALL' expression](https://www.postgresql.org/docs/10/static/functions-comparisons.html#id-1.5.8.28.17)

In Postgres the `ALL` expression is used for gather record's that have an Array column type that contains only a **single** and matchable element. 

```ruby
alice = Person.create!(tags: [1])
bob   = Person.create!(tags: [1, 2])
randy = Person.create!(tags: [3])

Person.where.all(tags: 1) #=> [alice] 

```

This only accepts a single value to a given attribute. So querying for example multiple tag numbers `[1,2]` will return nothing.

#### Contains
[Postgres '@>' (Array type) Contains expression](https://www.postgresql.org/docs/10/static/functions-array.html)

[Postgres '@>' (JSONB/HSTORE type) Contains expression](https://www.postgresql.org/docs/10/static/functions-json.html#FUNCTIONS-JSONB-OP-TABLE)


The `contains/1` method is used for finding any elements in an `Array`, `JSONB`, or `HSTORE` column type. 
That contains all of the provided values.

Array Type:
```ruby
alice = Person.create!(tags: [1, 4])
bob   = Person.create!(tags: [3, 1])
randy = Person.create!(tags: [4, 1])

Person.where.contains(tags: [1, 4]) #=> [alice, randy]
```

HSTORE / JSONB Type:
```ruby
alice = Person.create!(data: { nickname: "ARExtend" })
bob   = Person.create!(data: { nickname: "ARExtended" })
randy = Person.create!(data: { nickname: "ARExtended" })

Person.where.contains(data: { nickname: "ARExtended" }) #=> [bob, randy]
```

#### Overlap
[Postgres && (overlap) Expression](https://www.postgresql.org/docs/10/static/functions-array.html)

The `overlap/1` method will match an Array column type that contains any of the provided values within its column.

```ruby
alice = Person.create!(tags: [1, 4])
bob   = Person.create!(tags: [3, 4])
randy = Person.create!(tags: [4, 8])

Person.where.overlap(tags: [4]) #=> [alice, bob, randy]
Person.where.overlap(tags: [1, 8]) #=> [alice, randy]
Person.where.overlap(tags: [1, 3, 8]) #=> [alice, bob, randy]

```

#### Inet / IP Address
##### Inet Contains
[Postgres >> (contains) Network Expression](https://www.postgresql.org/docs/current/static/functions-net.html)

The `inet_contains` method works by taking a column(inet type) that has a submask prepended to it. 
And tries to find related records that fall within a given IP's range.

```ruby
alice = Person.create!(ip: "127.0.0.1/16")
bob   = Person.create!(ip: "192.168.0.1/16")

Person.where.inet_contains(ip: "127.0.0.254") #=> [alice]
Person.where.inet_contains(ip: "192.168.20.44") #=> [bob]
Person.where.inet_contains(ip: "192.255.1.1") #=> []
```

##### Inet Contains or Equals
[Postgres >>= (contains or equals) Network Expression](https://www.postgresql.org/docs/current/static/functions-net.html)

The `inet_contains_or_equals` method works much like the [Inet Contains](#inet-contains) method, but will also accept a submask range.

```ruby
alice = Person.create!(ip: "127.0.0.1/10")
bob   = Person.create!(ip: "127.0.0.44/24")

Person.where.inet_contains_or_equals(ip: "127.0.0.1/16") #=> [alice]
Person.where.inet_contains_or_equals(ip: "127.0.0.1/10") #=> [alice]
Person.where.inet_contains_or_equals(ip: "127.0.0.1/32") #=> [alice, bob]
```

##### Inet Contained Within
[Postgres << (contained by) Network Expression](https://www.postgresql.org/docs/current/static/functions-net.html)

For the `inet_contained_within` method, we try to find IP's that fall within a submasking range we provide.

```ruby
alice = Person.create!(ip: "127.0.0.1")
bob   = Person.create!(ip: "127.0.0.44") 
randy = Person.create!(ip: "127.0.55.20")

Person.where.inet_contained_within(ip: "127.0.0.1/24") #=> [alice, bob]
Person.where.inet_contained_within(ip: "127.0.0.1/16") #=> [alice, bob, randy]
```

##### Inet Contained Within or Equals
[Postgres <<= (contained by or equals) Network Expression](https://www.postgresql.org/docs/current/static/functions-net.html)

The `inet_contained_within_or_equals` method works much like the [Inet Contained Within](#inet-contained-within) method, but will also accept a submask range.

```ruby
alice = Person.create!(ip: "127.0.0.1/10")
bob   = Person.create!(ip: "127.0.0.44/32")
randy = Person.create!(ip: "127.0.99.1")

Person.where.inet_contained_within_or_equals(ip: "127.0.0.44/32") #=> [bob]
Person.where.inet_contained_within_or_equals(ip: "127.0.0.1/16") #=> [bob, randy]
Person.where.inet_contained_within_or_equals(ip: "127.0.0.44/8") #=> [alice, bob, randy]
```

##### Inet Contains or Contained Within
[Postgres && (contains or is contained by) Network Expression](https://www.postgresql.org/docs/current/static/functions-net.html)

The `inet_contains_or_contained_within` method is a combination of [Inet Contains](#inet-contains) and [Inet Contained Within](#inet-contained-within).
It essentially (the database) tries to use both methods to find as many records as possible that match either condition on both sides.

```ruby
alice = Person.create!(ip: "127.0.0.1/24")
bob   = Person.create!(ip: "127.0.22.44/8")
randy = Person.create!(ip: "127.0.99.1")

Person.where.inet_contains_or_is_contained_within(ip: "127.0.255.80") #=> [bob]
Person.where.inet_contains_or_is_contained_within(ip: "127.0.0.80") #=> [alice, bob]
Person.where.inet_contains_or_is_contained_within(ip: "127.0.0.80/8") #=> [alice, bob, randy]
```

### Conditional Methods
#### Any_of / None_of
 `any_of/1` simplifies the process of finding records that require multiple `or` conditions.
 
 `none_of/1` is the inverse of `any_of/1`. It'll find records where none of the contains are matched.
 
 Both accepts An array of: ActiveRecord Objects, Query Strings, and basic attribute names.
 
 Querying With Attributes:
 ```ruby
alice = Person.create!(uid: 1)
bob   = Person.create!(uid: 2)
randy = Person.create!(uid: 3)

Person.where.any_of({ uid: 1 }, { uid: 2 }) #=> [alice, bob]
```

Querying With ActiveRecord Objects:
```ruby
alice = Person.create!(uid: 1)
bob   = Person.create!(uid: 2)
randy = Person.create!(uid: 3)

uid_one = Person.where(uid: 1)
uid_two = Person.where(uid: 2)

Person.where.any_of(uid_one, uid_two) #=> [alice, bob]
```

Querying with Joined Relationships:
```ruby
alice     = Person.create!(uid: 1)
bob       = Person.create!(uid: 2)
randy     = Person.create!(uid: 3)
tag_alice = Tag.create!(person_id: alice.id)
tag_bob   = Tag.create!(person_id: person_two.id)
tag_randy = Tag.create!(person_id: person_three.id)

bob_tag_query   = Tag.where(people: { id: two.id }).includes(:person)
randy_tag_query = Tag.where(people: { id: three.id }).joins(:person)

Tag.joins(:person).where.any_of(bob_tag_query, randy_tag_query) #=> [tag_bob, tag_randy] (with person table joined)
```

#### Either Join
#### Either Order

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
