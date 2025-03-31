local _, ns = ...

-- a simple persisted key-value store for user specific state
local PlayerPrefs = {}
ns.PlayerPrefs = PlayerPrefs

local function GetPrefs()
    if not PlayerPrefsSaved then
        PlayerPrefsSaved = {}
    end
    return PlayerPrefsSaved
end

function PlayerPrefs:Get(key)
    return GetPrefs()[key]
end

function PlayerPrefs:Set(key, value)
    GetPrefs()[key] = value
end
