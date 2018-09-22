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

