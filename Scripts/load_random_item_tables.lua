--[[
load_random_item_tables.lua
Author: GoAgainAH data tooling

Purpose:
  1. Parse the provided ItemRandomSuffix.csv and ItemRandomProperties.csv files.
  2. Import the minimal set of fields required by GoAgainAH into a MySQL schema.
     The script expects an "acore" MySQL account (user/pass: acore) and will
     connect to the local server (127.0.0.1) using the default port 3306.  The
     target database is also called "acore" – adjust the DB_NAME constant below
     if your schema differs.
  3. Two helper tables are created if they do not yet exist:
       - `item_random_suffix`     (id INT PRIMARY KEY, internal_name VARCHAR(64), name_ru VARCHAR(255))
       - `item_random_properties` (id INT PRIMARY KEY, internal_name VARCHAR(64), name_ru VARCHAR(255))

Only these three columns are inserted because ItemDB.lua and the UI only ever
need the variant identifier (`id`) and the visible Russian name; the
`internal_name` field is kept for completeness / potential future use.

Usage:
  $ lua Scripts/load_random_item_tables.lua

Dependencies:
  - LuaSQL-MySQL (`luasql.mysql` LuaRock)

]]

local luasql = require("luasql.mysql")
local env = assert(luasql.mysql())

---------------------------------------------------------------------
-- CONFIGURATION ----------------------------------------------------
---------------------------------------------------------------------
local DB_NAME   = "acore_world"
local DB_USER   = "acore"
local DB_PASS   = "acore"
local DB_HOST   = "127.0.0.1"
local DB_PORT   = 3306

local PATH_SUFFIX_CSV     = "ItemRandomSuffix.csv"
local PATH_PROPERTIES_CSV = "ItemRandomProperties.csv"

---------------------------------------------------------------------
-- HELPER : CSV parser (simple, honors quoted fields) --------------
---------------------------------------------------------------------
local function parseCSVLine(line)
  local res, pos, len = {}, 1, #line
  while pos <= len do
    -- handle quoted fields
    if line:sub(pos,pos) == '"' then
      local txt, c = {}, nil
      pos = pos + 1 -- skip opening quote
      repeat
        c = line:sub(pos,pos)
        -- escaped quote ? ("")
        if c == '"' and line:sub(pos+1,pos+1) == '"' then
          table.insert(txt, '"')
          pos = pos + 2 -- skip both quotes
        elseif c ~= '"' then
          table.insert(txt, c)
          pos = pos + 1
        end
      until c == '"' or pos > len
      table.insert(res, table.concat(txt))
      -- skip trailing comma if present
      if line:sub(pos,pos) == '"' then pos = pos + 1 end
      if line:sub(pos,pos) == ',' then pos = pos + 1 end
    else
      -- unquoted field
      local nextComma = line:find(',', pos, true) or (len+1)
      table.insert(res, line:sub(pos, nextComma-1))
      pos = nextComma + 1
    end
  end
  return res
end

---------------------------------------------------------------------
-- DB UTIL ----------------------------------------------------------
---------------------------------------------------------------------
local function exec(db, sql)
  local cur, err = db:execute(sql)
  if not cur then error("SQL error: " .. tostring(err) .. "\nQuery: " .. sql) end
  if type(cur) ~= "userdata" then return cur end -- e.g. INSERT returns number
  cur:close()
end

local function initTables(db)
  exec(db, [[
    CREATE TABLE IF NOT EXISTS item_random_suffix (
      id INT PRIMARY KEY,
      internal_name VARCHAR(64),
      name_ru VARCHAR(255)
    ) CHARACTER SET utf8mb4;
  ]])
  exec(db, [[
    CREATE TABLE IF NOT EXISTS item_random_properties (
      id INT PRIMARY KEY,
      internal_name VARCHAR(64),
      name_ru VARCHAR(255)
    ) CHARACTER SET utf8mb4;
  ]])
end

---------------------------------------------------------------------
-- IMPORTER ---------------------------------------------------------
---------------------------------------------------------------------
local function importCSV(db, path, tableName)
  print("[+] Importing " .. path .. " → " .. tableName)
  local file = assert(io.open(path, "r"))
  -- read header to get column indices
  local header = parseCSVLine(file:read("*l"))
  local idxId, idxNameRu, idxInternal = nil, nil, nil
  for i,col in ipairs(header) do
    if col == "ID" then idxId = i
    elseif col == "Name_Lang_ruRU" then idxNameRu = i
    elseif col == "InternalName" or col == "Name" then idxInternal = i end
  end
  assert(idxId and idxNameRu, "Required columns not found in " .. path)
  if not idxInternal then idxInternal = idxNameRu end -- fallback

  -- truncate before re-import to keep things idempotent
  exec(db, "TRUNCATE TABLE " .. tableName)

  local inserted, lineNo = 0, 1
  for line in file:lines() do
    lineNo = lineNo + 1
    if line:match("%S") then  -- skip blank lines
      local cols = parseCSVLine(line)
      local id        = tonumber(cols[idxId])
      local name_ru   = cols[idxNameRu]
      local internal  = cols[idxInternal] or ""
      if id and name_ru and name_ru ~= "" then
        local stmt = string.format(
          "INSERT INTO %s (id, internal_name, name_ru) VALUES (%d, %s, %s);",
          tableName,
          id,
          db:escape(internal and ("'" .. internal .. "'") or "NULL"),
          db:escape("'" .. name_ru .. "'")
        )
        exec(db, stmt)
        inserted = inserted + 1
      end
    end
  end
  file:close()
  print(string.format("    → %d rows imported from %d lines", inserted, lineNo))
end

---------------------------------------------------------------------
-- MAIN -------------------------------------------------------------
---------------------------------------------------------------------
local db = assert(env:connect(DB_NAME, DB_USER, DB_PASS, DB_HOST, DB_PORT))
initTables(db)
importCSV(db, PATH_SUFFIX_CSV,     "item_random_suffix")
importCSV(db, PATH_PROPERTIES_CSV, "item_random_properties")

db:close()
env:close()

print("[✓] Import completed. You can now run extract_random_item_data.lua to build GoAgainAH tables.") 