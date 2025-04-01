local _, ns = ...

-- a simple persisted key-value store for user specific state
local PlayerPrefs = {}
ns.PlayerPrefs = PlayerPrefs

local function GetPlayerPrefs()
    if not PlayerPrefsSaved then
        PlayerPrefsSaved = {}
    end
    return PlayerPrefsSaved
end

function PlayerPrefs:Get(key)
    return GetPlayerPrefs()[key]
end

function PlayerPrefs:Set(key, value)
    GetPlayerPrefs()[key] = value
end

local CharacterPrefs = {}
ns.CharacterPrefs = CharacterPrefs

local function GetCharacterPrefs()
    if not CharacterPrefsSaved then
        CharacterPrefsSaved = {}
    end
    return CharacterPrefsSaved
end

function CharacterPrefs:Get(key)
    return GetCharacterPrefs()[key]
end

function CharacterPrefs:Set(key, value)
    GetCharacterPrefs()[key] = value
end