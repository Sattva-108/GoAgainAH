-- namespace
local _, ns = ...;
local L = ns.L

-- constants
local CATEGORY_DUNGEON = L["All Dungeons"]
local CATEGORY_RAID = L["All Raids"]

local DUNGEONS = {
    {
        name = L["Ragefire Chasm"],
        category = CATEGORY_DUNGEON,
        maxPlayers = 5,
        requiredLevel = 10,
        minimumLevel = 13,
        maximumLevel = 18
    },
    {
        name = L["Wailing Caverns"],
        category = CATEGORY_DUNGEON,
        maxPlayers = 5,
        requiredLevel = 10,
        minimumLevel = 17,
        maximumLevel = 24
    },
    {
        name = L["The Deadmines"],
        category = CATEGORY_DUNGEON,
        maxPlayers = 5,
        requiredLevel = 10,
        minimumLevel = 17,
        maximumLevel = 23
    },
    {
        name = L["Shadowfang Keep"],
        category = CATEGORY_DUNGEON,
        maxPlayers = 5,
        requiredLevel = 14,
        minimumLevel = 22,
        maximumLevel = 30
    },
    {
        name = L["Blackfathom Deeps"],
        category = CATEGORY_DUNGEON,
        maxPlayers = 5,
        requiredLevel = 15,
        minimumLevel = 24,
        maximumLevel = 32
    },
    {
        name = L["The Stockade"],
        category = CATEGORY_DUNGEON,
        maxPlayers = 5,
        requiredLevel = 15,
        minimumLevel = 23,
        maximumLevel = 32
    },
    {
        name = L["Gnomeregan"],
        category = CATEGORY_DUNGEON,
        maxPlayers = 5,
        requiredLevel = 19,
        minimumLevel = 26,
        maximumLevel = 38
    },
    {
        name = L["Razorfen Kraul"],
        category = CATEGORY_DUNGEON,
        maxPlayers = 5,
        requiredLevel = 25,
        minimumLevel = 27,
        maximumLevel = 37
    },
    {
        name = L["Scarlet Monastery - Graveyard"],
        category = CATEGORY_DUNGEON,
        maxPlayers = 5,
        requiredLevel = 21,
        minimumLevel = 29,
        maximumLevel = 38
    },
    {
        name = L["Scarlet Monastery - Library"],
        category = CATEGORY_DUNGEON,
        maxPlayers = 5,
        requiredLevel = 21,
        minimumLevel = 33,
        maximumLevel = 41
    },
    {
        name = L["Scarlet Monastery - Armory"],
        category = CATEGORY_DUNGEON,
        maxPlayers = 5,
        requiredLevel = 21,
        minimumLevel = 36,
        maximumLevel = 44
    },
    {
        name = L["Scarlet Monastery - Cathedral"],
        category = CATEGORY_DUNGEON,
        maxPlayers = 5,
        requiredLevel = 21,
        minimumLevel = 38,
        maximumLevel = 46
    },
    {
        name = L["Uldaman"],
        category = CATEGORY_DUNGEON,
        maxPlayers = 5,
        requiredLevel = 30,
        minimumLevel = 41,
        maximumLevel = 51
    },
    {
        name = L["Razorfen Downs"],
        category = CATEGORY_DUNGEON,
        maxPlayers = 5,
        requiredLevel = 35,
        minimumLevel = 37,
        maximumLevel = 46
    },
    {
        name = L["Zul'Farrak"],
        category = CATEGORY_DUNGEON,
        maxPlayers = 5,
        requiredLevel = 39,
        minimumLevel = 44,
        maximumLevel = 52
    },
    {
        name = L["Maraudon"],
        category = CATEGORY_DUNGEON,
        maxPlayers = 5,
        requiredLevel = 30,
        minimumLevel = 46,
        maximumLevel = 55
    },
    {
        name = L["Temple of Atal'Hakkar"],
        category = CATEGORY_DUNGEON,
        maxPlayers = 5,
        requiredLevel = 45,
        minimumLevel = 50,
        maximumLevel = 60
    },
    {
        name = L["Blackrock Depths"],
        category = CATEGORY_DUNGEON,
        maxPlayers = 5,
        requiredLevel = 48,
        minimumLevel = 52,
        maximumLevel = 60
    },
    {
        name = L["Lower Blackrock Spire"],
        category = CATEGORY_DUNGEON,
        maxPlayers = 5,
        requiredLevel = 48,
        minimumLevel = 55,
        maximumLevel = 60
    },
    {
        name = L["Upper Blackrock Spire"],
        category = CATEGORY_DUNGEON,
        maxPlayers = 10,
        requiredLevel = 48,
        minimumLevel = 55,
        maximumLevel = 60
    },
    {
        name = L["Dire Maul"],
        category = CATEGORY_DUNGEON,
        maxPlayers = 5,
        requiredLevel = 48,
        minimumLevel = 55,
        maximumLevel = 60
    },
    {
        name = L["Scholomance"],
        category = CATEGORY_DUNGEON,
        maxPlayers = 5,
        requiredLevel = 48,
        minimumLevel = 58,
        maximumLevel = 60
    },
    {
        name = L["Stratholme"],
        category = CATEGORY_DUNGEON,
        maxPlayers = 5,
        requiredLevel = 48,
        minimumLevel = 58,
        maximumLevel = 60
    }
}
ns.DUNGEONS = DUNGEONS

local RAIDS = {
    {
        name = L["Zul'Gurub"],
        category = CATEGORY_RAID,
        maxPlayers = 20,
        requiredLevel = 60,
        minimumLevel = 60,
        maximumLevel = 60
    },
    {
        name = L["Onyxia's Lair"],
        category = CATEGORY_RAID,
        maxPlayers = 40,
        requiredLevel = 50,
        minimumLevel = 60,
        maximumLevel = 60
    },
    {
        name = L["Molten Core"],
        category = CATEGORY_RAID,
        maxPlayers = 40,
        requiredLevel = 58,
        minimumLevel = 60,
        maximumLevel = 60
    },
    {
        name = L["Blackwing Lair"],
        category = CATEGORY_RAID,
        maxPlayers = 40,
        requiredLevel = 60,
        minimumLevel = 60,
        maximumLevel = 60
    },
    {
        name = L["Ruins of Ahn'Qiraj"],
        category = CATEGORY_RAID,
        maxPlayers = 20,
        requiredLevel = 60,
        minimumLevel = 60,
        maximumLevel = 60
    },
    {
        name = L["Temple of Ahn'Qiraj"],
        category = CATEGORY_RAID,
        maxPlayers = 40,
        requiredLevel = 60,
        minimumLevel = 60,
        maximumLevel = 60
    },
    {
        name = L["Naxxramas"],
        category = CATEGORY_RAID,
        maxPlayers = 40,
        requiredLevel = 60,
        minimumLevel = 60,
        maximumLevel = 60
    }
}

-- Add indices to existing entries
for i, dungeon in ipairs(DUNGEONS) do
    dungeon.index = i
end
for i, raid in ipairs(RAIDS) do
    raid.index = i
end

ns.RAIDS = RAIDS

local DUNGEON_LIST = {}
table.insert(DUNGEON_LIST, { name = CATEGORY_DUNGEON, index = 0 })  -- Category header gets index 0
for i, dungeon in ipairs(DUNGEONS) do
    table.insert(DUNGEON_LIST, dungeon)
end
ns.DUNGEON_LIST = DUNGEON_LIST
