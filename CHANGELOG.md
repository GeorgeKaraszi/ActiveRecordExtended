# master (unreleased)
- Introduce `.foster_select` a helper for select statements that can handel aliasing and provides casting options for many common aggregate functions.
Supports any aggregate that does not require multiple arguments (`COUNT`, `AVG`, `MAX`, `ARRAY_AGG`, etc..): [Aggregate Functions](https://www.postgresql.org/docs/current/functions-aggregate.html)
  - Supports Aggregate `DISTINCT` and `ORDER BY` inner expressions.
- Reduced the code foot-print for declaring new Arel functions
- Introduce new `Arel::Nodes::AggregateFunctionName` for dealing with inline-ing `ORDER BY` (will be expanded to handel `FILTER` next)
- Introduce `cast_with:` for `.select_row_to_json`. 
  - Supported options: `true (array)`, `:array`, `array_agg`, `array_agg_distinct`
  
### 2.0 Deprecation Warning
- In order to keep options standardized, `.select_row_to_json` will be dropping `cast_to_array` in favor of the `cast_with` option.
    
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

