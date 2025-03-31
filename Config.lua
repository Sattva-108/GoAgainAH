local addonName, ns = ...

-- we want to be able to push config changes without requiring a full addon update
-- e.g. for punishments for a certain faction
local defaultConfig = {
    version = 6,
    loanDuration = 7 * 24 * 60 * 60,
    auctionExpiry = 14 * 24 * 60 * 60,
    completedAuctionExpiry = 7 * 24 * 60 * 60,
    codDuration = 3 * 24 * 60 * 60,
    auctionCap = 25,
    updateAvailableTimeout = 60 * 60,
    updateAvailableUrl = "curseforge.com/wow/addons/onlyfangs-ah",
}

ns.GetConfig = function()
    if not AHConfigSaved then
        AHConfigSaved = defaultConfig
    end
    if defaultConfig.version >= AHConfigSaved.version then
        AHConfigSaved = defaultConfig
    end
    return AHConfigSaved
end
