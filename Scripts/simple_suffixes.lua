-- Simple suffix generator - creates fallback names for all used random IDs
local luasql = require("luasql.mysql")
local env = assert(luasql.mysql())

local DB_NAME = "acore_world"
local DB_USER = "acore"
local DB_PASS = "acore"
local DB_HOST = "127.0.0.1"
local DB_PORT = 3306

local db = assert(env:connect(DB_NAME, DB_USER, DB_PASS, DB_HOST, DB_PORT))

-- Get items with random properties/suffixes and generate synthetic names
local sql = [[
  SELECT 
    entry, name, Quality, ItemLevel, class, subclass,
    RandomProperty, RandomSuffix, InventoryType
  FROM item_template 
  WHERE (RandomProperty > 0 OR RandomSuffix > 0)
  ORDER BY entry
]]

local f = assert(io.open("SuffixedItems.lua", "w"))
f:write("-- Auto-generated suffixed items\n")
f:write("local _, ns = ...\n\n")
f:write("ns.SuffixedItems = {\n")

local cur = assert(db:execute(sql))
local newId = 200000
local count = 0

-- All possible suffix names
local suffixNames = {
  " of the Whale", " of the Bear", " of the Gorilla", " of the Tiger", 
  " of the Monkey", " of the Eagle", " of the Boar", " of Stamina",
  " of Spirit", " of Strength", " of Power", " of the Wolf"
}

local row = cur:fetch({}, "a")
while row do
  local baseId = tonumber(row.entry)
  local baseName = row.name or ""
  local quality = tonumber(row.Quality) or 1
  local level = tonumber(row.ItemLevel) or 1
  local class = tonumber(row.class) or 0
  local subclass = tonumber(row.subclass) or 0
  local randomProp = tonumber(row.RandomProperty) or 0
  local randomSuff = tonumber(row.RandomSuffix) or 0
  local invType = tonumber(row.InventoryType) or 0
  
  -- Create multiple variants for each base item
  if randomProp > 0 or randomSuff > 0 then
    for _, suffixName in ipairs(suffixNames) do
      local newName = baseName .. suffixName
      
      -- Write item entry in ItemsCache format with base ID at position 12
      f:write(string.format('  [%d] = {"%s", "%s", %d, %d, false, %d, %d, %d, 0, 0, 0, %d},\n',
        newId, baseName, newName, quality, level, class, subclass, invType, baseId))
      
      newId = newId + 1
      count = count + 1
    end
  end
  
  row = cur:fetch(row, "a")
end

cur:close()
f:write("}\n\n")
f:write(string.format("print('[GoAgainAH] Loaded %d suffixed items')\n", count))
f:close()

db:close()
env:close()

print(string.format("[✓] Generated %d suffixed items in SuffixedItems.lua", count))