[![Gem Version](https://badge.fury.io/rb/active_record_extended.svg)](https://badge.fury.io/rb/active_record_extended)
[![Build Status](https://github.com/GeorgeKaraszi/ActiveRecordExtended/actions/workflows/test.yml/badge.svg?branch=master)](https://github.com/GeorgeKaraszi/ActiveRecordExtended/actions/workflows/test.yml?query=branch%3Amaster+)
[![Maintainability](https://api.codeclimate.com/v1/badges/98ecffc0239417098cbc/maintainability)](https://codeclimate.com/github/GeorgeKaraszi/active_record_extended/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/f22154211bb3a8feb89f/test_coverage)](https://codeclimate.com/github/GeorgeKaraszi/ActiveRecordExtended/test_coverage)
## Index
- [Description and history](#description-and-history)
- [Compatibility](#compatibility)
- [Installation](#installation)
- [Usage](#usage)
  - [Predicate Query Methods](#predicate-query-methods)
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
  - [Common Table Expressions (CTE)](#common-table-expressions-cte)
    - [Subquery CTE Gotchas](#subquery-cte-gotchas)
  - [JSON Query Methods](#json-query-methods)
    - [Row To JSON](#row-to-json)
    - [JSON/B Build Object](#jsonb-build-object)
    - [JSON/B Build Literal](#jsonb-build-literal)
  - [Unionization](#unionization)
    - [Union](#union)
    - [Union ALL](#union-all)
    - [Union Except](#union-except)
    - [Union Intersect](#union-intersect)
    - [Union As](#union-as)
    - [Union Order](#union-order)
    - [Union Reorder](#union-reorder)
  - [Window Functions](#window-functions)
    - [Define Window](#define-window)
    - [Select Window](#select-window)

## Description and History

Active Record Extended is the continuation of maintaining and improving the work done by **Dan McClain**, the original author of [postgres_ext](https://github.com/DavyJonesLocker/postgres_ext).

Overtime the lack of updating to support the latest versions of ActiveRecord 5.x has caused quite a bit of users forking off the project to create their own patches jobs to maintain compatibility.
The only problem is that this has created a wild west of environments of sorts. The problem has grown to the point no one is attempting to directly contribute to the original source. And forked repositories are finding themselves as equally as dead with little to no activity.

Active Record Extended is essentially providing users with the other half of Postgreses querying abilities. Due to Rails/ActiveRecord/Arel being designed to be DB agnostic, there are a lot of left out features; Either by choice or the simple lack of supporting API's for other databases. However some features are not exactly PG explicit. Some are just helper methods to express an idea much more easily.

## Compatibility

This package is designed align and work with any officially supported Ruby and Rails versions.
 - Minimum Ruby Version: 2.5.x **(EOL warning!)**
 - Minimum Rails Version: 5.2.x **(EOL warning!)**
 - Minimum Postgres Version: 10.x **(EOL warning!)**
 - Latest Ruby supported: 3.1.x
 - Latest Rails supported: 7.0.x
 - Postgres: 10-current(14) (probably works with most older versions to a certain point)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'active_record_extended'
```

And then execute:

    $ bundle

## Usage

### Predicate Query Methods

#### Any
[Postgres 'ANY' expression](https://www.postgresql.org/docs/10/static/functions-comparisons.html#id-1.5.8.28.16)

In Postgres the `ANY` expression is used for gather record's that have an Array column type that contain a single matchable value within its array.

```ruby
alice = User.create!(tags: [1])
bob   = User.create!(tags: [1, 2])
randy = User.create!(tags: [3])

User.where.any(tags: 1) #=> [alice, bob]

```

This only accepts a single value. So querying for example multiple tag numbers `[1,2]` will return nothing.


#### All
[Postgres 'ALL' expression](https://www.postgresql.org/docs/10/static/functions-comparisons.html#id-1.5.8.28.17)

In Postgres the `ALL` expression is used for gather record's that have an Array column type that contains only a **single** and matchable element.

```ruby
alice = User.create!(tags: [1])
bob   = User.create!(tags: [1, 2])
randy = User.create!(tags: [3])

User.where.all(tags: 1) #=> [alice]

```

This only accepts a single value to a given attribute. So querying for example multiple tag numbers `[1,2]` will return nothing.

#### Contains
[Postgres '@>' (Array type) Contains expression](https://www.postgresql.org/docs/10/static/functions-array.html)

[Postgres '@>' (JSONB/HSTORE type) Contains expression](https://www.postgresql.org/docs/10/static/functions-json.html#FUNCTIONS-JSONB-OP-TABLE)


The `contains/1` method is used for finding any elements in an `Array`, `JSONB`, or `HSTORE` column type.
That contains all of the provided values.

Array Type:
```ruby
alice = User.create!(tags: [1, 4])
bob   = User.create!(tags: [3, 1])
randy = User.create!(tags: [4, 1])

User.where.contains(tags: [1, 4]) #=> [alice, randy]
```

HSTORE / JSONB Type:
```ruby
alice = User.create!(data: { nickname: "ARExtend" })
bob   = User.create!(data: { nickname: "ARExtended" })
randy = User.create!(data: { nickname: "ARExtended" })

User.where.contains(data: { nickname: "ARExtended" }) #=> [bob, randy]
```

#### Overlap
[Postgres && (overlap) Expression](https://www.postgresql.org/docs/10/static/functions-array.html)

The `overlap/1` method will match an Array column type that contains any of the provided values within its column.

```ruby
alice = User.create!(tags: [1, 4])
bob   = User.create!(tags: [3, 4])
randy = User.create!(tags: [4, 8])

User.where.overlap(tags: [4]) #=> [alice, bob, randy]
User.where.overlap(tags: [1, 8]) #=> [alice, randy]
User.where.overlap(tags: [1, 3, 8]) #=> [alice, bob, randy]

```

#### Inet / IP Address
##### Inet Contains
[Postgres >> (contains) Network Expression](https://www.postgresql.org/docs/current/static/functions-net.html)

The `inet_contains` method works by taking a column(inet type) that has a submask prepended to it.
And tries to find related records that fall within a given IP's range.

```ruby
alice = User.create!(ip: "127.0.0.1/16")
bob   = User.create!(ip: "192.168.0.1/16")

User.where.inet_contains(ip: "127.0.0.254") #=> [alice]
User.where.inet_contains(ip: "192.168.20.44") #=> [bob]
User.where.inet_contains(ip: "192.255.1.1") #=> []
```

##### Inet Contains or Equals
[Postgres >>= (contains or equals) Network Expression](https://www.postgresql.org/docs/current/static/functions-net.html)

The `inet_contains_or_equals` method works much like the [Inet Contains](#inet-contains) method, but will also accept a submask range.

```ruby
alice = User.create!(ip: "127.0.0.1/10")
bob   = User.create!(ip: "127.0.0.44/24")

User.where.inet_contains_or_equals(ip: "127.0.0.1/16") #=> [alice]
User.where.inet_contains_or_equals(ip: "127.0.0.1/10") #=> [alice]
User.where.inet_contains_or_equals(ip: "127.0.0.1/32") #=> [alice, bob]
```

##### Inet Contained Within
[Postgres << (contained by) Network Expression](https://www.postgresql.org/docs/current/static/functions-net.html)

For the `inet_contained_within` method, we try to find IP's that fall within a submasking range we provide.

```ruby
alice = User.create!(ip: "127.0.0.1")
bob   = User.create!(ip: "127.0.0.44")
randy = User.create!(ip: "127.0.55.20")

User.where.inet_contained_within(ip: "127.0.0.1/24") #=> [alice, bob]
User.where.inet_contained_within(ip: "127.0.0.1/16") #=> [alice, bob, randy]
```

##### Inet Contained Within or Equals
[Postgres <<= (contained by or equals) Network Expression](https://www.postgresql.org/docs/current/static/functions-net.html)

The `inet_contained_within_or_equals` method works much like the [Inet Contained Within](#inet-contained-within) method, but will also accept a submask range.

```ruby
alice = User.create!(ip: "127.0.0.1/10")
bob   = User.create!(ip: "127.0.0.44/32")
randy = User.create!(ip: "127.0.99.1")

User.where.inet_contained_within_or_equals(ip: "127.0.0.44/32") #=> [bob]
User.where.inet_contained_within_or_equals(ip: "127.0.0.1/16") #=> [bob, randy]
User.where.inet_contained_within_or_equals(ip: "127.0.0.44/8") #=> [alice, bob, randy]
```

##### Inet Contains or Contained Within
[Postgres && (contains or is contained by) Network Expression](https://www.postgresql.org/docs/current/static/functions-net.html)

The `inet_contains_or_contained_within` method is a combination of [Inet Contains](#inet-contains) and [Inet Contained Within](#inet-contained-within).
It essentially (the database) tries to use both methods to find as many records as possible that match either condition on both sides.

```ruby
alice = User.create!(ip: "127.0.0.1/24")
bob   = User.create!(ip: "127.0.22.44/8")
randy = User.create!(ip: "127.0.99.1")

User.where.inet_contains_or_is_contained_within(ip: "127.0.255.80") #=> [bob]
User.where.inet_contains_or_is_contained_within(ip: "127.0.0.80") #=> [alice, bob]
User.where.inet_contains_or_is_contained_within(ip: "127.0.0.80/8") #=> [alice, bob, randy]
```

### Conditional Methods
#### Any_of / None_of
 `any_of/1` simplifies the process of finding records that require multiple `or` conditions.

 `none_of/1` is the inverse of `any_of/1`. It'll find records where none of the contains are matched.

 Both accepts An array of: ActiveRecord Objects, Query Strings, and basic attribute names.

 Querying With Attributes:
 ```ruby
alice = User.create!(uid: 1)
bob   = User.create!(uid: 2)
randy = User.create!(uid: 3)

User.where.any_of({ uid: 1 }, { uid: 2 }) #=> [alice, bob]
```

Querying With ActiveRecord Objects:
```ruby
alice = User.create!(uid: 1)
bob   = User.create!(uid: 2)
randy = User.create!(uid: 3)

uid_one = User.where(uid: 1)
uid_two = User.where(uid: 2)

User.where.any_of(uid_one, uid_two) #=> [alice, bob]
```

Querying with Joined Relationships:
```ruby
alice     = User.create!(uid: 1)
bob       = User.create!(uid: 2)
randy     = User.create!(uid: 3)
tag_alice = Tag.create!(user_id: alice.id)
tag_bob   = Tag.create!(user_id: bob.id)
tag_randy = Tag.create!(user_id: randy.id)

bob_tag_query   = Tag.where(users: { id: bob.id }).includes(:user)
randy_tag_query = Tag.where(users: { id: randy.id }).joins(:user)

Tag.joins(:user).where.any_of(bob_tag_query, randy_tag_query) #=> [tag_bob, tag_randy] (with users table joined)
```

#### Either Join

The `#either_join/2` method is a base ActiveRecord querying method that will joins records based on a set of conditionally joinable tables.

```ruby
class User < ActiveRecord::Base
  has_one :profile_l, class: "ProfileL"
  has_one :profile_r, class: "ProfileR"

  scope :completed_profile, -> { either_joins(:profile_l, :profile_r) }
end

alice = User.create!
bob   = User.create!
randy = User.create! # Does not have a single completed profile type
ProfileL.create!(user_id: alice.id)
ProfileR.create!(user_id: bob.id)

User.completed_profile #=> [alice, bob]
# alternatively
User.either_joins(:profile_l, :profile_r) #=> [alice, bob]
```

#### Either Order

The `#either_order/3` method is a base ActiveRecord querying method that will order a set of columns that may or may not exist for each record.
This works similar to how [Either Join](#either-join) works. This does not however exclude records that do not have relationships.

```ruby
alice = User.create!
bob   = User.create!
ProfileL.create!(user_id: alice.id, left_turns: 100)
ProfileR.create!(user_id: bob.id, right_turns: 50)

User.either_order(:asc, profile_l: :left_turns, profile_r: :right_turns) #=> [bob, alice]
User.either_order(:desc, profile_l: :left_turns, profile_r: :right_turns) #=> [alice, bob]

randy = User.create!
User.either_order(:asc, profile_l: :left_turns, profile_r: :right_turns) #=> [bob, alice, randy]
User.either_order(:desc, profile_l: :left_turns, profile_r: :right_turns) #=> [randy, alice, bob]
```

### Common Table Expressions (CTE)
[Postgres WITH (CTE) Statement](https://www.postgresql.org/docs/current/static/queries-with.html)

The `.with/1` method is a base ActiveRecord querying method that will aid in creating complex queries.

```ruby
alice = User.create!
bob   = User.create!
randy = User.create!
ProfileL.create!(user_id: alice.id, likes: 200)
ProfileL.create!(user_id: bob.id,   likes: 400)
ProfileL.create!(user_id: randy.id, likes: 600)

User.with(highly_liked: ProfileL.where("likes > 300"))
    .joins("JOIN highly_liked ON highly_liked.user_id = users.id") #=> [bob, randy]
```

Query output:

```sql
WITH "highly_liked" AS (SELECT "profile_ls".* FROM "profile_ls" WHERE (likes >= 300))
SELECT "users".*
FROM "users"
JOIN highly_liked ON highly_liked.user_id = users.id
```

You can also chain or provide additional arguments to the `with/1` method for it to merge into a single, `WITH` statement.

```ruby
User.with(highly_liked: ProfileL.where("likes > 300"), less_liked: ProfileL.where("likes <= 200"))
    .joins("JOIN highly_liked ON highly_liked.user_id = users.id")
    .joins("JOIN less_liked ON less_liked.user_id = users.id")

# OR

User.with(highly_liked: ProfileL.where("likes > 300"))
    .with(less_liked: ProfileL.where("likes <= 200"))
    .joins("JOIN highly_liked ON highly_liked.user_id = users.id")
    .joins("JOIN less_liked ON less_liked.user_id = users.id")
```

Query output:

```sql
WITH "highly_liked" AS (SELECT "profile_ls".* FROM "profile_ls" WHERE (likes > 300)),
     "less_liked" AS (SELECT "profile_ls".* FROM "profile_ls" WHERE (likes <= 200))
SELECT "users".*
FROM "users"
JOIN highly_liked ON highly_liked.user_id = users.id
JOIN less_liked ON less_liked.user_id = users.id
```

There are three methods you can chain to the `with/1` to add modifiers to the query.
#### `recursive`

```ruby
User.with.recursive(highly_liked: ProfileL.where("likes > 300"))
    .joins("JOIN highly_liked ON highly_liked.user_id = users.id")
```

Query output:

```sql
WITH RECURSIVE "highly_liked" AS (SELECT "profile_ls".* FROM "profile_ls" WHERE (likes >= 300))
SELECT "users".*
FROM "users"
JOIN highly_liked ON highly_liked.user_id = users.id
```
#### `materialized` (**Note**: MATERIALIZED modifier is only available in [PG versions 12+](https://www.postgresql.org/docs/release/12.0/).)


```ruby
User.with.materialized(highly_liked: ProfileL.where("likes > 300"))
    .joins("JOIN highly_liked ON highly_liked.user_id = users.id")
```

Query output:

```sql
WITH "highly_liked" AS MATERIALIZED (SELECT "profile_ls".* FROM "profile_ls" WHERE (likes >= 300))
SELECT "users".*
FROM "users"
JOIN highly_liked ON highly_liked.user_id = users.id
```
#### `not_materialized` (**Note**: NOT MATERIALIZED modifier is only available in [PG versions 12+](https://www.postgresql.org/docs/release/12.0/).)

```ruby
User.with.not_materialized(highly_liked: ProfileL.where("likes > 300"))
    .joins("JOIN highly_liked ON highly_liked.user_id = users.id")
```

Query output:

```sql
WITH "highly_liked" AS NOT MATERIALIZED (SELECT "profile_ls".* FROM "profile_ls" WHERE (likes >= 300))
SELECT "users".*
FROM "users"
JOIN highly_liked ON highly_liked.user_id = users.id
```

#### Subquery CTE Gotchas
 In order keep queries PG valid, subquery explicit methods (like Unions and JSON methods)
 will be subject to "Piping" the CTE clauses up to the parents query level.

 This also means there's potential for having duplicate CTE names.
 In order to combat duplicate CTE references with the same name, **piping will favor the parents CTE over the nested sub-queries**.

 This also means that this is a "First come First Served" implementation.
 So if you have a parent with no CTE's but two sub-queries with the same CTE name but with different querying statements.
 It will process and favor the one that comes first.

 Example:
 ```ruby
    sub_query      = Person.with(dupped_cte: Person.where(id: 1)).select("dup_cte.id").from(:dup_cte)
    other_subquery = Person.with(unique_cte: Person.where(id: 5)).select("unique_cte.id").from(:unique_cte)

    # Will favor this CTE below, over the `sub_query`'s CTE
    Person.with(dupped_cte: Person.where.not(id: 1..4)).union(sub_query, other_subquery)
```

Query Output
```sql
WITH "unique_cte" AS (
  SELECT "people".*
  FROM "people"
  WHERE "people"."id" = 5
), "dupped_cte" AS (
  SELECT "people".*
  FROM "people"
  WHERE NOT ("people"."id" BETWEEN 1 AND 4)
)
  SELECT "people".*
  FROM (( (
    SELECT dup_cte.id
    FROM dup_cte
  ) UNION (
    SELECT unique_cte.id
    FROM unique_cte
  ) )) people
```


### JSON Query Methods
If any or all of your json sub-queries include a CTE, read the [Subquery CTE Gotchas](#subquery-cte-gotchas) warnings.

#### Row To JSON
[Postgres 'ROW_TO_JSON' function](https://www.postgresql.org/docs/current/functions-json.html#FUNCTIONS-JSON-CREATION-TABLE)

The implementation of the`.select_row_to_json/2` method is designed to be used with sub-queries. As a means for taking complex
query logic and transform them into a single or multiple json responses. These responses are required to be assigned
to an aliased column on the parent(callee) level.

While quite the mouthful of an explanation. The implementation of combining unrelated or semi-related queries is quite smooth(imo).

**Arguments:**
  - `from` [String, Arel, or ActiveRecord::Relation]: A subquery that can be nested into a `ROW_TO_JSON` clause

**Options:**
  - `as` [Symbol or String] (default="results"): What the column will be aliased to
  - `key` [Symbol or String] (default=[random letter]): Internal query alias name.
    * This is useful if you would like to add additional mid-level predicate clauses
  - `cast_with` [Symbol or Array\<Symbol>]:
    * `:to_jsonb`
    * `:array`
    * `:array_agg`
    * `:distinct`  (auto applies `:array_agg` & `:to_jsonb`)
  - `order_by` [Symbol or Hash]: Applies an ordering operation (similar to ActiveRecord #order)
    * **Note**: this option will be ignored if you need to order a DISTINCT Aggregated Array.

```ruby
    physical_cat  = Category.create!(name: "Physical")
    products      = 3.times.map { Product.create! }
    products.each { |product|  100.times { Variant.create!(product: product, category: physical_cat) } }

    # Since we plan to nest this query, you have access top level information. (I.E categories table)
    item_query = Variant.select(:name, :id, :category_id, :product_id).where("categories.id = variants.category_id")

    # You can provide addition scopes that will be applied to the nested query (but will not effect the actual inner query)
    # This is ideal if you are dealing with but not limited to, CTE's being applied multiple times and require additional constraints
    product_query  =
    Product.select(:id)
            .joins(:items)
            .select_row_to_json(item_query, key: :outer_items, as: :items, cast_with: :array) do |item_scope|
              item_scope.where("outer_items.product_id = products.id")
                # Results to:
                #  SELECT ..., ARRAY(SELECT ROW_TO_JSON("outer_items")
                #   FROM ([:item_query:]) outer_items
                #   WHERE outer_items.product_id = products.id
                # ) AS items
            end

    # Not defining a key will automatically generate a random key between a-z
    category_query = Category.select(:name, :id).select_row_to_json(product_query, as: :products, cast_with: :array)
    Category.json_build_object(:physical_category, category_query.where(id: physical_cat.id)).results
    #=> {
    #        "physical_category" => {
    #            "name" => "Physical",
    #            "id" => 1,
    #            "products" => [
    #              {
    #                "id" => 2,
    #                "items" => [{"name" => "Bojangels", "id" => 3, "category_id" => 1, "product_id" => 2}, ...]
    #              },
    #              ...
    #            ]
    #        }
    #  }
    #
```

Query Output
```sql
SELECT (JSON_BUILD_OBJECT('physical_category', "physical_category")) AS "results"
FROM (
     SELECT "categories"."name", "categories"."id", (ARRAY(
         SELECT ROW_TO_JSON("j")
         FROM (
              SELECT "products"."id", (ARRAY(
                  SELECT ROW_TO_JSON("outer_item")
                  FROM (
                       SELECT "variants"."name", "variants"."id", "variants"."category_id", "variants"."product_id"
                       FROM "variants"
                       WHERE (categories.id = variants.category_id)
                       ) outer_items
                  WHERE (outer_items.product_id = products.id)
                )) AS "items"
              FROM "products"
              INNER JOIN "items" ON "products"."id" = "items"."product_id"
              ) j
       )) AS "products"
     FROM "categories"
     WHERE "categories"."id" = 1
     ) AS "physical_category"
```


#### JSON/B Build Object
[Postgres 'json(b)_build_object' function](https://www.postgresql.org/docs/current/functions-json.html#FUNCTIONS-JSON-CREATION-TABLE)

The implementation of the`.json_build_object/2` and `.jsonb_build_object/2` methods are designed to be used with sub-queries.
As a means for taking complex  query logic and transform them into a single or multiple json responses.

**Arguments:**
  - `key`: [Symbol or String]: What should this response return as
  - `from`: [String, Arel, or ActiveRecord::Relation] : A subquery that can be nested into the top-level from clause

**Options:**
   - `as`: [Symbol or String] (defaults to `"results"`): What the column will be aliased to
   - `value`: [Symbol or String] (defaults to `key` argument): How the response should handel the json value return

See the included example on [Row To JSON](#row-to-json) to see it in action.

#### JSON/B Build Literal
[Postgres 'json(b)_build_object' function](https://www.postgresql.org/docs/current/functions-json.html#FUNCTIONS-JSON-CREATION-TABLE)

The implementation of the`.json_build_literal/1` and `.jsonb_build_literal/1` is designed for creating static json objects
 that don't require subquery interfacing.

**Arguments:**
 - Requires an Array or Hash set of values

**Options:**
 - `as`: [Symbol or String] (defaults to `"results"`): What the column will be aliased to

```ruby
    User.json_build_literal(number: 1, last_name: "json", pi: 3.14).take.results
     #=> { "number" => 1, "last_name" => "json", "pi" => 3.14 }

    # Or as array elements
    User.json_build_literal(:number, 1, :last_name, "json", :pi, 3.14).take.results
      #=> { "number" => 1, "last_name" => "json", "pi" => 3.14 }

```

Query Output
```sql
SELECT (JSON_BUILD_OBJECT('number', 1, 'last_name', 'json', 'pi', 3.14)) AS "results"
  FROM "users"
```


### Unionization
If any or all of your union queries include a CTE, read the [Subquery CTE Gotchas](#subquery-cte-gotchas) warnings.

#### SQL-Query Helpers
 - `.to_union_sql` : Will return a string of the constructed union query without being nested in the `from` clause.
 - `.to_nice_union_sql`(requires [NiceQL Gem](https://github.com/alekseyl/niceql) to be install): A formatted `.to_union_sql`


#### Known issue
There's an issue with providing a single union clause and chaining it with a different union clause.
This is due to requirements of grouping SQL statements. The issue is being working on, but with no ETA.

This issue only applies to the first initial set of unions and is recommended that you union two relations right off the bat.
Afterwords you can union/chain single relations.

Example

```ruby

Person.union(Person.where(id: 1..4)).union_except(Person.where(id: 3..4)).union(Person.where(id: 4))
#=> Will include all people with an ID between 1 & 3 (throwing the except on ID 4)

# This can be fixed by doing something like

Person.union_except(Person.where(id: 1..4), Person.where(id: 3..4)).union(Person.where(id: 4))
#=> Will include people with the ids of 1, 2, and 4 (properly excluding the user with the ID of 3)
```

Problem Query Output
```sql
( ( (
  SELECT "people".*
  FROM "people"
  WHERE "people"."id" BETWEEN 1 AND 4
) UNION (
  SELECT "people".*
  FROM "people"
  WHERE "people"."id" BETWEEN 3 AND 4
) ) EXCEPT (
  SELECT "people".*
  FROM "people"
  WHERE "people"."id" = 4
) )
```


#### Union
[Postgres 'UNION' combination](https://www.postgresql.org/docs/current/queries-union.html)

```ruby
user_1 = Person.where(id: 1)
user_2 = Person.where(id: 2)
users  = Person.where(id: 1..3)

Person.union(user_1, user_2, users) #=> [#<Person id: 1, ..>, #<Person id: 2,..>, #<Person id: 3,..>]

# You can also chain union's
Person.union(user_1).union(user_2).union(users)
```

Query Output
```sql
SELECT "people".*
  FROM (( ( (
    SELECT "people".*
    FROM "people"
    WHERE "people"."id" = 1
  ) UNION (
    SELECT "people".*
    FROM "people"
    WHERE "people"."id" = 2
  ) ) UNION (
    SELECT "people".*
    FROM "people"
    WHERE "people"."id" BETWEEN 1 AND 3
  ) )) people
```


#### Union ALL
[Postgres 'UNION ALL' combination](https://www.postgresql.org/docs/current/queries-union.html)

```ruby
user_1 = Person.where(id: 1)
user_2 = Person.where(id: 2)
users  = Person.where(id: 1..3)

Person.union_all(user_1, user_2, users)
  #=> [#<Person id: 1, ..>, #<Person id: 2,..>, #<Person id: 1, ..>, #<Person id: 2,..>, #<Person id: 3,..>]

# You can also chain union's
Person.union_all(user_1).union_all(user_2).union_all(users)
# Or
Person.union.all(user1, user_2).union.all(users)
```

Query Output
```sql
SELECT "people".*
  FROM (( ( (
    SELECT "people".*
    FROM "people"
    WHERE "people"."id" = 1
  ) UNION ALL (
    SELECT "people".*
    FROM "people"
    WHERE "people"."id" = 2
  ) ) UNION ALL (
    SELECT "people".*
    FROM "people"
    WHERE "people"."id" BETWEEN 1 AND 3
  ) )) people
```

#### Union Except
[Postgres 'EXCEPT' combination](https://www.postgresql.org/docs/current/queries-union.html)

```ruby
users               = Person.where(id: 1..5)
except_these_users  = Person.where(id: 2..4)

Person.union_except(users, except_these_users) #=> [#<Person id: 1, ..>, #<Person id: 5,..>]

# You can also chain union's
Person.union.except(users, except_these_users).union(Person.where(id: 20))
```

Query Output
```sql
SELECT "people".*
  FROM (( ( (
    SELECT "people".*
    FROM "people"
    WHERE "people"."id" BETWEEN 1 AND 5
  ) EXCEPT (
    SELECT "people".*
    FROM "people"
    WHERE "people"."id" BETWEEN 2 AND 4
  )) people
```

#### Union Intersect
[Postgres 'INTERSECT' combination](https://www.postgresql.org/docs/current/queries-union.html)

```ruby
randy = Person.create!
alice = Person.create!
ProfileL.create!(person: randy, likes: 100)
ProfileL.create!(person: alice, likes: 120)

likes_100           = Person.select(:id, "profile_ls.likes").joins(:profile_l).where(profile_ls: { likes: 100 })
likes_less_than_150 = Person.select(:id, "profile_ls.likes").joins(:profile_l).where("profile_ls.likes < 150")
Person.union_intersect(likes_100, likes_less_than_150) #=> [randy]



# You can also chain union's
Person.union_intersect(likes_100).union_intersect(likes_less_than_150) #=> [randy]
# Or
Person.union.intersect(likes_100, likes_less_than_150) #=> [randy]

```

Query Output
```sql
SELECT "people".*
  FROM (( (
    SELECT "people"."id", profile_ls.likes
    FROM "people"
    INNER JOIN "profile_ls" ON "profile_ls"."person_id" = "people"."id"
    WHERE "profile_ls"."likes" = 100
  ) INTERSECT (
    SELECT "people"."id", profile_ls.likes
    FROM "people"
    INNER JOIN "profile_ls" ON "profile_ls"."person_id" = "people"."id"
    WHERE (profile_ls.likes < 150)
  ) )) people
```

#### Union As

By default unions are nested in the from clause and are aliased to the parents table name.
We can change this behavior by chaining the method `.union_as/1`

```ruby
Person.select("good_people.id").union(Person.where(id: 1), Person.where(id: 2)).union_as(:good_people)
```

Query Output
```sql
SELECT good_people.id
  FROM (( (
    SELECT "people".*
    FROM "people"
    WHERE "people"."id" = 1
  ) UNION (
    SELECT "people".*
    FROM "people"
    WHERE "people"."id" = 2
  ) )) good_people
```


#### Union Order

Unions allow for a final outside `ORDER BY` clause. This will ensure that all the results that come back are ordered in an expected return.

```ruby
query_1 = Person.where(id: 1..3)
query_2 = Person.where(id: 3)
query_3 = Person.where(id: 3..10)
Person.union_except(query_1, query_2).union(query_3).order_union(:id, tags: :desc)
```

Query Output
```sql
SELECT "people".*
  FROM (( ( (
    SELECT "people".*
    FROM "people"
    WHERE "people"."id" BETWEEN 1 AND 3
  ) EXCEPT (
    SELECT "people".*
    FROM "people"
    WHERE "people"."id" = 3
  ) ) UNION (
    SELECT "people".*
    FROM "people"
    WHERE "people"."id" BETWEEN 3 AND 10
  ) ) ORDER BY id ASC, tags DESC) people
```

#### Union Reorder

much like Rails `.reorder`; `.reorder_union/1`  will clear the previous order in a new instance and/or apply a new ordering scheme
```ruby
query_1     = Person.where(id: 1..3)
query_2     = Person.where(id: 3)
query_3     = Person.where(id: 3..10)
union_query = Person.union_except(query_1, query_2).union(query_3).order_union(:id, tags: :desc)
union_query.reorder_union(personal_id: :desc, id: :desc)
```

Query Output
```sql
SELECT "people".*
  FROM (( ( (
    SELECT "people".*
    FROM "people"
    WHERE "people"."id" BETWEEN 1 AND 3
  ) EXCEPT (
    SELECT "people".*
    FROM "people"
    WHERE "people"."id" = 3
  ) ) UNION (
    SELECT "people".*
    FROM "people"
    WHERE "people"."id" BETWEEN 3 AND 10
  ) ) ORDER BY personal_id DESC, id DESC) people
```

#### Window Functions
[Postgres Window Functions](https://www.postgresql.org/docs/current/tutorial-window.html)

Let's address the elephant in the room. Arel has had, for a long time now, window function capabilities;
However they've never seen the lime light in ActiveRecord's query logic.
The following brings the dormant Arel methods up to the ActiveRecord Querying level.

#### Define Window

To set up a window function, we first must establish the window and we do this by using the `.define_window/1` method.
This method also requires you to call chain `.partition_by/2`

`.define_window/1` - Establishes the name of the window you'll reference later on in [.select_window](#select-window)
   - Aliased name of window

`.partition_by/2`  - Establishes the windows operations a [pre-defined window function](https://www.postgresql.org/docs/current/functions-window.html) will leverage.
   - column name being partitioned against
   - (**optional**) `order_by`: Processes how the window should be ordered

```ruby
User
.define_window(:number_window).partition_by(:number, order_by: { id: :desc })
.define_window(:name_window).partition_by(:name, order_by: :id)
.define_window(:no_order_name).partition_by(:name)
```

Query Output
```sql
SELECT *
FROM users
WINDOW number_window AS (PARTITION BY number ORDER BY id DESC),
       name_window   AS (PARTITION BY name ORDER BY id),
       no_order_name AS (PARTITION BY name)
```

#### Select Window

Once you've define a window, the next step to to utilize it on one of the many provided postgres window functions.

`.select_window/3`
  - [window function name](https://www.postgresql.org/docs/current/functions-window.html)
  - (**optional**) Window function arguments (treated as a splatted array)
  - (**optional**) `as:` : Alias name of the final result
  - `over:` : name of [defined window](#define-window)

```ruby
User.create!(name: "Alice", number: 100) #=> id: 1
User.create!(name: "Randy", number: 100) #=> id: 2
User.create!(name: "Bob", number: 300)   #=> id: 3

User
.define_window(:number_window).partition_by(:number, order_by: { id: :desc })
.select(:id, :name)
.select_window(:row_number, over: :number_window, as: :row_id)
.select_window(:first_value, :name, over: :number_window, as: :first_value_name)
#=> [
 #  { id: 1, name: "Alice", row_id: 2, first_value_name: "Randy" }
 #  { id: 2, name: "Randy", row_id: 1, first_value_name: "Randy" }
 #  { id: 3, name: "Bob",   row_id: 1, first_value_name: "Bob" }
 # ]
 #

```

Query Output
```sql
SELECT "users"."id",
        "users"."name",
        (ROW_NUMBER() OVER number_window)      AS "row_id",
        (FIRST_VALUE(name) OVER number_window) AS "first_value_name"
FROM "users"
WINDOW number_window AS (PARTITION BY number ORDER BY id DESC)
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
