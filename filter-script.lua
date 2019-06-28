
--[[
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
--]]

-- Customize the next list to fit your environment.
-- Fields not mentioned in this list, will be regarded (and mapped) as string.
-- Supported data-types: table (= nested json), number, string, boolean.
field_data_type = {
   someboolean = "boolean",
   someboolean2 = "boolean",
   kubernetes = "table",
   response = "number",
   request_time = "number",
   status = "number",
   level_value = "number",
   ok = "number",
   pid = "number",
   process = "number",
   thread = "number",
   timestamp = "number",
   nanostamp = "number",
   took = "number",
   ["application-time"] = "number",
   ["token.type"] = "number",
}

-- simple helper function to right-trim a string.
function string.rtrim(s) return s:gsub("%s+$", "") end

-- recursive function, turn input value into string data, flatten nested tables if any.
function flatten_to_string(prefix, data)
   if type(data) == "table" then
      local result = ""
      for key,value in pairs(data) do
        if type(value) == "table" then
           result = result .. flatten_to_string(prefix .. key .. ".", value)
        else
           result = result .. prefix .. key .. ": " .. flatten_to_string(prefix .. key .. ".", value) .. "\n"
        end
      end
      return result
   else
      return tostring(data)
   end
end

-- rename field using postfix "_str" or "_obj" for non-tables or tables, and make value a (flattened) string.
function rename_and_flatten_to_string(record, key)
   local postfix = "_str"
   if type(record[key]) == "table" then
     postfix = "_obj"
   end
   record[key..postfix] = flatten_to_string("", record[key]):rtrim()
   record[key] = nil
end

-- the first # of records will be shown in the stdout of fluent-bit, can be removed (or set to 0).
debugcount=10

-- This is the "main" method, which will be called from the fluent-bit LUA filter.
-- It checks all fields for allowed field_data_type. If not OK, rename field / change data-type,
-- and set return "code" to 1, indicating record update.
function cb_field_type_check(tag, timestamp, record)
  if debugcount > 0 then print("---- tag: "..tostring(tag)) end

  local code = 0
  local response = {}
  for key,value in pairs(record) do
     -- copy data to a new (response) table (cheap, it's a copy of the "pointer/reference"), because changing the
     -- original record did have impact in the execution of the "pairs(record)" for loop (it started
     -- skipping fields).
     response[key] = record[key]
     local allowed_type = field_data_type[key] or "string"
     local current_type = type(value)
     if debugcount > 0 then print("#### "..key..": ("..current_type.."-->"..allowed_type..") "..tostring(value)) end

     -- if type not ok, handle it (otherwise ignore check)
     if allowed_type ~= current_type then
        code = 1
        if allowed_type == "number" then
           if tonumber(value) == nil then
              -- is non-numeric, move field out of the way.
              rename_and_flatten_to_string(response, key)
           elseif current_type == "string" then
              -- is actually numeric content, parse it / "strip quotes".
              response[key] = tonumber(value)
           end
        elseif allowed_type == "table" or allowed_type == "boolean" then
           rename_and_flatten_to_string(response, key)
        else
           -- any others will be converted to string (not renamed)
           response[key] = flatten_to_string("", response[key]):rtrim()
        end
     end
  end
  if debugcount > 0 then debugcount = debugcount - 1 end

  return code, timestamp, response
end


