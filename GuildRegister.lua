local _, ns = ...
-- Create a simple table to store guild member information.
-- Key = character name (e.g., "CharacterName-Realm"), Value = member info.
local GuildRegister = {table={}}
ns.GuildRegister = GuildRegister

function GuildRegister:OnGuildRosterUpdate()

    local numGuildMembers = GetNumGuildMembers()

    local seen = {}
    for i = 1, numGuildMembers do
        local fullName, rank, rankIndex, level, class, zone,
        publicNote, officerNote, isOnline, status, classFileName,
        achievementPoints, achievementRank, isMobile, canSoR, rep = GetGuildRosterInfo(i)

        if fullName then
            seen[fullName] = true
            self.table[fullName] = {
                rank       = rank,
                rankIndex  = rankIndex,
                level      = level,
                class      = class,
                classFileName = classFileName,
                zone       = zone,
                isOnline   = isOnline,
                status     = status,
                isMobile   = isMobile,
                publicNote = publicNote,
                officerNote= officerNote,
                achievementPoints = achievementPoints,
                achievementRank = achievementRank,
                canSoR = canSoR,
                rep = rep,
            }
        end
    end
    for k, _ in pairs(self.table) do
        if not seen[k] then
            self.table[k] = nil
        end
    end

    -- Fire event after roster update is complete
    ns.AuctionHouseAPI:FireEvent(ns.T_GUILD_ROSTER_CHANGED)
end

ns.GameEventHandler:On("GUILD_ROSTER_UPDATE", function()
    GuildRegister:OnGuildRosterUpdate()
end)

function GuildRegister:GetMemberData(characterName)
    local memberData = self.table[characterName] or self.table[characterName .. "-" .. GetRealmName()]
    if memberData then
        return memberData
    end
    return false
end

function GuildRegister:IsMemberOnline(characterName)
    local memberData = self.table[characterName] or self.table[characterName .. "-" .. GetRealmName()]
    if memberData then
        return memberData.isOnline
    end
    return false
end
