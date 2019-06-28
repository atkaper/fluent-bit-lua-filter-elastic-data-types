#!/usr/bin/lua

-- This is a very crude and simple script to "simulate" a fluent-bit filter call.
-- You can run it using a standalone LUA interpreter.
--
-- It is not a "real" module test, as it does not assert or check any proper functioning.
-- It merely serves as a way to visually check the proper functioning, by showing the
-- input and output data of the filter action.

-- load the LUA filter script
dofile("filter-script.lua")

-- define helper function to display record
function show_data(record)
  print("\n-----------------------------------------")
  for k,v in pairs(record)
  do
     print(type(v), k, v)
  end
  print("-----------------------------------------\n")
end

-- setup input test record, containing some fields with proper data type, and
-- some with wrong data type. Also some nested dta.

rec = {}
rec["someboolean"] = "123x"
rec["someboolean2"] = true
rec["test"] = "223x"
rec["xyz"] = "323"
rec["log"] = "13x"
rec["b"] = true
rec["n"] = 1
rec["request_time"] = 12345
rec["ok"] = "999"
rec["nillval"] = nil
rec["thread"] = "blabla"
rec["token.type"] = "1.5"
rec["application-time"] = "blabla"

nested = {}
nested["abc"] = 1
nested["xyz"] = "xxx"

multinest = {}
multinest["hoi"] = "hallo"
multinest["joho"] = 423 
multinest["bool"] = true
nested["multi"] = multinest

rec["response"] = nested
rec["kubernetes"] = nested

-- show input record
show_data(rec)

-- run the filter
code,stamp,response = cb_field_type_check("tagtag",1234567,rec)

-- show output record 
print("code: ", code)
show_data(response)


