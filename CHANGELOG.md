# Master - (Unreleased)

Deprecations:
- Dropping support for Ruby v2.3.x
- Dropping support for Rails 5.0.x
- Dropping support for `cast_as_array` option for json queries.
  - Same operation can be performed with `cast_with: :array`

# 1.4.0 - November 6th 2019

Performance tweaks:
 - [#33](https://github.com/GeorgeKaraszi/ActiveRecordExtended/pull/33) Reduce object creations when using the ruby shorthand `&method()`.

# 1.3.1 - October 2nd 2019

Bug fix:
 - Prevent STI models from appending where clauses to `select_row_to_json(b)` method scopes

# 1.3.0 - September 9th 2019

- Add [Postgres Window Functions](https://www.postgresql.org/docs/current/functions-window.html) to ActiveRecord querying level.
  - introduces two new methods that are used in conjunction: `.define_window` & `.select_window`
### `define_window/1` && `partition_by/2`
 Defines one or many windows that will be place at the bottom of your query. 
 This will also require you to define a partition via `.parition_by(:column)/2`.
 
 - `partition_by/2` arguments:
    - column name being partitioned
    - `order_by` Processes how the window should be orders
    
Example:
 
 - `User.define_window(:w).partition_by(:name, order_by: :join_date)`
 
###  `select_window/4`

Arguments:

- [Window Function Name](https://www.postgresql.org/docs/current/functions-window.html)
- Function's arguments \*optional\* 
- `over:`
    - The window name given when constructing `.define_window`
- `as:` \*optional\*
    - Alias name to give the final result
    
Overall Examples: 
   - `User.define_window(:w).partition_by(:name).select_window(:row_number, over: :w, as: :r_id)`
   - `User.define_window(:w).partition_by(:name).select_window(:first_value, :id,  over: :w, as: :first_id)`

# 1.2.0 - August 11th 2019

## Changes
- Introduce `.foster_select` a helper for select statements that can handel aliasing and provides casting options for many common aggregate functions.
Supports any aggregate that does not require multiple arguments (`COUNT`, `AVG`, `MAX`, `ARRAY_AGG`, etc..): [Aggregate Functions](https://www.postgresql.org/docs/current/functions-aggregate.html)
  - Supports Aggregate `DISTINCT` and `ORDER BY` inner expressions.
- Reduced the code foot-print for declaring new Arel functions
- Introduce new `Arel::Nodes::AggregateFunctionName` for dealing with inline-ing `ORDER BY` (will be expanded to handel `FILTER` next)
- Code cleanup and some minor performance tweaks

##### Changes to `.select_row_to_json`
- Argument-less scoped blocks (inner-block argument is now optional)
- `cast_with:` 
  - Supported options: `true` (array), `:array`, `:array_agg`, `distinct`, and `:to_jsonb`
- `order_by:` : Accepts ActiveRecord like options for ordering responses from an array or aggregated array

### Bugfixes
- [#26](https://github.com/GeorgeKaraszi/ActiveRecordExtended/pull/26) Support for class namespace for `inet_contains` [@znakaska](https://github.com/znakaska)
- [#27](https://github.com/GeorgeKaraszi/ActiveRecordExtended/pull/27) Fixed `TO_JSONB` class name typo that would cause an exception
  
### 2.0 Deprecation Warning
- In order to keep options standardized, `.select_row_to_json` will be dropping `cast_to_array` in favor of the `cast_with` option;
  Furthermore, the default `true` for `cast_with` option will be deprecated as well in favor of more verbose `:array` option
    
# 1.1.0 - May 4th 2019
- ActiveRecord/Rails 6.0 support
- Allow for any pg gem version below v2.0

# 1.0.1 - Match 29th 2019
- Increased the required PG gem version range to accept `1.1.x`

# 1.0.0 - March 23rd 2019
Add support for Postgres Union types and refactor Arel building process into a single module

## Union Query Commands
- `.union`  (UNION)
- `.union_all`  (UNION ALL)
  - or `.union.all` 
- `union_except`  (EXCEPT)
  - or `.union.except`
- `.union_intersect`  (INTERSECT)
  - or `.union.intersect`
- `union_as`  (From clause alias name) (defaults to calling class table name)
  - or `.union.as`
- `order_union` (ORDER BY)
  - or `.union.order`
- `.reorder_union` (overides previously set `.order_union`)
  - or `union.reorder`
  
## JSON Query Commands
- `.select_row_to_json` (ROW_TO_JSON)
- `.json_build_object` (JSON_BUILD_OBJECT)
- `.jsonb_build_object` (JSONB_BUILD_OBJECT)
- `.json_build_literal` (JSON_BUILD_OBJECT) (static hash / array implementation)
- `.jsonb_build_literal` (JSONB_BUILD_OBJECT) (static hash / array implementation)

# 0.7.0 - September 22nd 2018

Add support for Postgres Commend Table Expression (CTE) methods.

- `.with/1`
- `.with.recursive/1`

# 0.6.0 - July 25th 2018

Reduced Gem file allocation. We only care about stuff in the lib directory.

# 0.5.1 - June 3rd 2018

Relaxed PG gem requirement for allowing version 1 to be used.

# 0.5.0 - May 31st 2018

Released non-marked beta version.

# 0.5.0.beta3 - May 28th 2018

Added `inet_contains_or_contained_within/1` method

# 0.5.0.beta2 - May 27th 2018

Renamed inet functions to hopefully give a clearer understanding to what these methods are used for.

Added support for Postgres Inet functions. View the readme for more details on the following:

- `#inet_contained_within/1`
- `#inet_contained_within_or_equals/1`
- `#inet_contains_or_equals/1`
- `#inet_contains/1`

### Deprecation Warnings
The following will be dropped upon v1.0 release. In favor of their prefixed counterparts.

- `#contained_within/1`
- `#contained_within_or_equals/1`
- `#contains_or_equals/1`

# 0.5.0.beta1 - May 26th 2018

Added support for Rails 5.0.x

### Warning for Rails 5.0.x Projects
The proposed changes to this could cause unintended behavior in existing Rails 5.0.x applications. 
This is due to the overwrite needed to be done on its internal Predicate builder. 
Rails projects above 5.0.x should not experience any unforeseen issues since they contain the necessary structure required.

**Use with caution.** And always make sure you have good tests to verify everything in your application.

# 0.4.0 - May 9th 2018

- Use Arel's `or` for grouping queries when using `#any_of` or `#none_of`
- Added Plural aliases for `.either_join` : `.either_joins` and `.either_order` : `.either_orders`

# 0.3.0 - May 9th 2018

- Fixed ActiveRecord QueryMethod constant load error.

# 0.2.1 - May 6th 2018

Changed how where clause is required. This is to hopefully future proof the next minior update to ActiveRecord.

# 0.2.0 - May 6th 2018

Added ActiveRecord Where Chain Functionality
- .where.any_of
- .where.none_of

Major thanks to [Olivier El Mekki author of ActiveRecord AnyOf](https://github.com/oelmekki/activerecord_any_of)

# 0.1.1 - May 2nd 2018

Added ActiveRecord Where Chain Functionality:
- .where.overlap
- .where.contained_within
- .where.contained_within_or_equals
- .where.contains_or_equals
- .where.any/1
- .where.all/1

Major thanks to [Dan McClain author of Postgres Ext](https://github.com/dockyard/postgres_ext)

Added ActiveRecord Base Extentions
- .either_order/2
- .either_join/2

