# fluent-bit-lua-filter-elastic-data-types

Fluent Bit LUA Filter to force proper data types to send to Elastic Search Database.

This Lua script provides callback function "cb_field_type_check", for use by the fluent-bit lua filter.
It will check fields for allowed data types, and change and/or rename them if not correct.
Note: the check is only done for the "top-level" of fields. Any nested json logs are not inspected.
However, by default, the nested json will be flattened to a single string field. You need to explicitly
enable nested json to leave it in (unchecked). We do this for the kubernetes plugin field values.

Why this filter? Because elastic search is quite picky about trying to cast data to it's required storage format.
For example the "response" field is used mainly for numeric http status codes, but occasionally some other
service uses it for a text response. Elastic will reject the full record, if a non numeric field is send to
be stored in a numeric field. So let's rename them out of the way in those cases.

The flatening of nested json to a single string field is done for two reasons: it removes the need for checking
all nested levels, and it prevents an unlimited number of fields to be generated in elastic. Some of our
deployments add the request headers and request cookies as nested json, and the cookies might use random names
or part of customer data in the name. If too many fieldnames are created in elastic, it runs into indexing issues.

We know it would be much better to ask all developers to hold themselves to some log standard, instead
of having it to filter like this. But... we have over 100 developers, and I do NOT think that we can keep them
all in line (takes too much time), and we definitely do NOT want any developer to be able to make our
log collector crash! The system should be very very robust, and self healing, without losing log data.

20/6/2019 Thijs Kaper.

