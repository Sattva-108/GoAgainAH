local addonName, ns = ...
local L = ns.L

local NUM_RESULTS_TO_DISPLAY = 9

local function FormatNumber(number)
    if not number then return "0" end
    if number < 1000 then
        return tostring(number)
    end
    return string.format("%.1fk", number/1000)
end

local function ToPascalCase(str)
    if not str then return "" end
    -- Convert first character to uppercase and the rest to lowercase
    return str:sub(1,1):upper() .. str:lower():sub(2)
end

local function CheckRequirements(entry)
    local localPlayerName = UnitName("player")
    local localPlayerLevel = ns.GetPlayerLevel()

    -- Get local player's settings
    local myEntry = ns.LfgAPI:GetMyEntry()

    local meetsRequirements = true
    local reasons = {}

    if localPlayerName == entry.name then
        -- always show as meeting the requirements
    else
        -- Check level difference
        local levelDiff = math.abs(localPlayerLevel - entry.level)
        if levelDiff > 6 then
            meetsRequirements = false
            -- Clamp the level range to 0-60
            local minLevel = math.max(0, entry.level - 6)
            local maxLevel = math.min(60, entry.level + 6)
            -- TODO Cedric still up-to-date for GoAgain?
            table.insert(reasons, string.format("Must be between level %d-%d (OnlyFangs rule)", minLevel, maxLevel))
        end

        if (entry.minLevel and localPlayerLevel < entry.minLevel) or (entry.maxLevel and localPlayerLevel > entry.maxLevel) then
            meetsRequirements = false
            table.insert(reasons, string.format("Level %d-%d", entry.minLevel, entry.maxLevel))
        end

        if entry.isDungeon and (not myEntry or not myEntry.isDungeon) then
            meetsRequirements = false
            table.insert(reasons, L["Enable Any Dungeon"])
        end
    end

    return meetsRequirements, reasons
end

local function AddPartyMemberToTooltip(unit)
    local name = UnitName(unit)
    if not name then
        return
    end

    local role = UnitGroupRolesAssigned(unit)
    local roleName = _G[role]
    if role == "DAMAGER" then
        roleName = L["Dps"]
    elseif role == "TANK" then
        roleName = L["Tank"]
    elseif role == "HEALER" then
        roleName = L["Healer"]
    end
    GameTooltip:AddLine(name .. " " .. roleName, 1, 1, 1)
end

local function ShowTooltip(self, meetsRequirements, requirementsReason, entry, copy)
    GameTooltip:ClearLines()

    if copy and meetsRequirements then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["Copy Link"])
        GameTooltip:AddLine(L["Press CTRL+C to copy"], 1, 1, 1)

    else
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT", 0, 5)
        -- GameTooltip:SetUnit(entry.name)
        GameTooltip:SetMinimumWidth(200)

        if entry then
            GameTooltip:AddLine(entry.name)
            GameTooltip:AddLine(string.format(L["Level %d %s %s"], entry.level, ns.LocalizeEnum(entry.race), ns.LocalizeEnum(entry.class)), 1, 1, 1)

            if entry.isDungeon and entry.roles then
                GameTooltip:AddLine(ns.GetRoleString(entry.roles), 1, 1, 1)
            end

            GameTooltip:AddLine(" ")
        end

        if not meetsRequirements then
            GameTooltip:AddLine(L["REQUIREMENTS NOT MET"], 0.8, 0, 0)
            GameTooltip:AddLine(L["This streamer has set certain level and/or viewer requirements"])
            GameTooltip:AddLine(" ")

            if requirementsReason and #requirementsReason > 0 then
                GameTooltip:AddLine(L["They require:"], 1, 1, 1)
                for _, reason in ipairs(requirementsReason) do
                    GameTooltip:AddLine("• " .. reason, 1, 1, 1, true)
                end
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(" ")
        end

        if entry then
            -- Gather party members first
            local partyMembers = {}
            if IsInGroup() and UnitInParty(entry.name) then
                table.insert(partyMembers, {unit = "player", name = UnitName("player")})

                for i = 1, GetNumGroupMembers() do
                    local unit = "party" .. i
                    local name = UnitName(unit)
                    if name then
                        table.insert(partyMembers, {unit = unit, name = name})
                    end
                end
            end

            -- Check if any party member has RP enabled
            local hasRP = entry.isRP
            if not hasRP and ns.AuctionHouseDB and ns.AuctionHouseDB.lfg then
                for _, member in ipairs(partyMembers) do
                    local memberEntry = ns.AuctionHouseDB.lfg[member.name]
                    if memberEntry and memberEntry.isRP then
                        hasRP = true
                        break
                    end
                end
            end


            if hasRP then
                if IsInGroup() and UnitInParty(entry.name) then
                    GameTooltip:AddLine(L["Roleplay"])
                    GameTooltip:AddLine(L["This party has roleplay enabled."], 1, 1, 1)
                else
                    GameTooltip:AddLine(L["Roleplay (RP) enabled"])
                end
                GameTooltip:AddLine(" ")
            end

            -- Show party members if in group
            if #partyMembers > 0 then
                GameTooltip:AddLine(L["Party"])
                for _, member in ipairs(partyMembers) do
                    AddPartyMemberToTooltip(member.unit)
                end
                GameTooltip:AddLine(" ") -- blank line separator
            end

            -- Show all dungeons the player has selected
            local scroll = OFAuctionFrameLFG.dungeonScrollList
            if scroll and entry.isDungeon then
                GameTooltip:AddLine(L["Dungeons"])

                if entry.dungeons then
                -- Create a sorted copy of the dungeons table
                    local sortedDungeons = {}
                    for _, dungeonIndex in pairs(entry.dungeons) do
                        table.insert(sortedDungeons, ns.DUNGEONS[dungeonIndex])
                    end
                    table.sort(sortedDungeons, function(a, b) return a.index < b.index end)

                    for _, dungeon in ipairs(sortedDungeons) do
                        -- GameTooltip:AddLine(text, 1, 1, 1)
                        GameTooltip:AddDoubleLine(
                            dungeon.name,
                            string.format("%d-%d",
                                dungeon.minimumLevel,
                                dungeon.maximumLevel
                            ),
                            1, 1, 1,
                            1, 1, 1
                        )
                    end
                end
                GameTooltip:AddLine(" ") -- blank line separator
            end
        end
    end
    GameTooltip:Show()
end

local function GetDungeonText(entry)
    if not entry.dungeons then
        return nil
    end

    -- Count number of dungeons (keys with true values)
    local dungeonCount = 0
    local singleDungeonIndex = nil

    for _, dungeonIndex in ipairs(entry.dungeons) do
        dungeonCount = dungeonCount + 1
        singleDungeonIndex = dungeonIndex
    end

    if dungeonCount == 1 and singleDungeonIndex <= #ns.DUNGEONS then
        return ns.DUNGEONS[singleDungeonIndex].name

    elseif dungeonCount == 0 then
        return nil

    else
        return dungeonCount .. " " .. L["dungeons"]
    end
end

local function GetColabText(entry)
    local text = ""

    if entry.isRP then
        text = L["RP"]
    end

    if entry.isDungeon then
        local dungeonText = GetDungeonText(entry)
        if dungeonText then
            if string.len(text) > 1 then
                text = text .. " & "
            end
            text = text .. dungeonText
        end
    end

    return text
end

local function SelectRow(button)
    -- If clicking the same row that's already selected, deselect it
    if selectedRow == button then
        selectedRow:UnlockHighlight()
        selectedRow = nil
        return
    end

    -- Deselect previous row if it exists
    if selectedRow and selectedRow ~= button then
        selectedRow:UnlockHighlight()
    end

    -- Select new row
    selectedRow = button
end

local function UpdateEntry(i, offset, button, entry)
    -- for use in highlight scripts in XML
    button.meetsRequirements = entry.meetsRequirements
    button.requirementsReason = entry.requirementsReason and #entry.requirementsReason > 0 and entry.requirementsReason or nil
    button.entry = entry

    -- Name
    button.name:SetText(entry.displayName)

    -- Level
    button.level:SetText(entry.level)

    -- Set collaboration text based on dungeons
    button.colab:SetText(GetColabText(entry))

    if entry.meetsRequirements then
        button.colab:SetTextColor(1, 1, 1, 1)
    else
        button.colab:SetTextColor(0.5, 0.5, 0.5, 1)
    end

    -- Viewers
    local viewerCount = ns.GetAvgViewers(entry.name)
    button.viewers:SetText(FormatNumber(viewerCount))

    if button.roleContainer then
        local roles = entry.roles
        if not entry.isDungeon then
            roles = nil
        end
        ns.RoleButtonsToggleVisible(button.roleContainer, roles)
    else
        ns.DebugLog("missing button.roleContainer")
    end

    -- Livestream link
    local livestream = entry.livestream
    local raid = entry.raid


    button.livestreamContainer.editBox:SetText(livestream)
    button.livestreamContainer.editBox:SetCursorPosition(0)

    -- Raid command
    button.raidContainer.editBox:SetText(raid)
    button.raidContainer.editBox:SetCursorPosition(0)

    -- Add OnClick handler for whisper button
    button.whisperButton:SetScript("OnClick", function()
        ChatFrame_SendTell(entry.name)
    end)

    -- Use built-in race texture with texcoords
    if entry.race then
        local texture = string.format("Interface\\Icons\\Achievement_Character_%s_Male", entry.race)
        button.item.raceTexture:SetTexture(texture)
    else
        button.item.raceTexture:SetTexture(nil)
    end
    button.item.raceTexture:SetAlpha(entry.meetsRequirements and 1.0 or 0.6)

    -- Replace the show/hide logic with texture update
    if button.onlineIcon then
        local status
        if entry.isOnline then
            status = L["Online"]
        else
            status = L["Offline"]
        end
        local iconPath = "Interface\\AddOns\\" .. addonName .. "\\Media\\Icons\\Icn_" .. status .. ".png"
        button.onlineIcon:SetTexture(iconPath)
    end

    local enabled = entry.isOnline or false
    OFLFG_Row_SetEnabled(button, enabled, entry.requirementsReason, entry.isOnline or false)

    if enabled then
        -- Level with color based on difference
        local localPlayerLevel = ns.GetPlayerLevel()
        local levelDiff = math.abs(localPlayerLevel - entry.level)

        if levelDiff > 6 then
            button.level:SetTextColor(1, 0.1, 0.1) -- Red
        else
            button.level:SetTextColor(1, 1, 1) -- White
        end
    end

    -- Add tooltip handlers for both input boxes
    button.livestreamContainer.editBox:SetScript("OnEnter", function(self)
        ShowTooltip(self, button.meetsRequirements, button.requirementsReason, button.entry, true)
    end)
    button.livestreamContainer.editBox:SetScript("OnLeave", function(self)
		if GameTooltip:IsOwned(self) then
			GameTooltip:Hide()
		end
    end)

    button.raidContainer.editBox:SetScript("OnEnter", function(self)
        ShowTooltip(self, button.meetsRequirements, button.requirementsReason, button.entry, true)
    end)
    button.raidContainer.editBox:SetScript("OnLeave", function(self)
		if GameTooltip:IsOwned(self) then
			GameTooltip:Hide()
		end
    end)

    -- Update selection state and button states
    if selectedRow == button then
        button:LockHighlight()
    else
        button:UnlockHighlight()
    end
end

local function updateSortArrows()
    OFSortButton_UpdateArrow(OFLFGStreamerSort, "lfg", "name")
    OFSortButton_UpdateArrow(OFLFGLvlSort,      "lfg", "minLevel")
    OFSortButton_UpdateArrow(OFLFGColabSort,    "lfg", "colab")
    OFSortButton_UpdateArrow(OFLFGAvgViewersSort, "lfg", "minViewers")
    OFSortButton_UpdateArrow(OFLFGLivestreamSort, "lfg", "isOnline")
    OFSortButton_UpdateArrow(OFLFGRaidSort,       "lfg", "isLeveling")
end

function LfgUI_Initialize()
    local function Update()
        if OFAuctionFrame:IsShown() and OFAuctionFrameLFG:IsShown() then
            OFLFGScroll_Update()
        end
    end

    ns.AuctionHouseAPI:RegisterEvent(ns.T_LFG_ADD_OR_UPDATE, Update)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_LFG_DELETED, Update)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_LFG_SYNCED, Update)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_ON_LFG_STATE_UPDATE, Update)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_GUILD_ROSTER_CHANGED, Update)
end

local function GetLFGEntries()
    local me = UnitName("player")
    local myTwitchName = ns.GetTwitchName(me)

    local livestream = ""
    if myTwitchName then
        livestream = string.format("twitch.tv/popout/%s/guest-star", myTwitchName)
    end

    local all = {}
    if ns.AuctionHouseDB and ns.AuctionHouseDB.lfg then
        for _, data in pairs(ns.AuctionHouseDB.lfg) do
            local twitchName = ns.GetTwitchName(data.name)
            local displayName = ns.GetDisplayName(data.name) or data.name

            -- Try to get current level from API
            local currentLevel = data.level
            local isOnline = false
            local guildMemberData = ns.GuildRegister:GetMemberData(data.name)
            if guildMemberData and guildMemberData.level then
                currentLevel = guildMemberData.level
                isOnline = guildMemberData.isOnline
            end
            if data.name == me then
                currentLevel = ns.GetPlayerLevel()  -- override for cheats
            end

            local raid = ""
            if twitchName then
                raid = "/raid " .. twitchName
            end

            local entry = CopyTable(data)
            entry.displayName = displayName
            entry.viewers = 13370
            entry.livestream = livestream
            entry.raid = raid
            entry.level = currentLevel
            entry.isOnline = isOnline

            local meetsRequirements, reasons = CheckRequirements(entry)
            entry.meetsRequirements = meetsRequirements
            entry.requirementsReason = reasons

            table.insert(all, entry)
        end
    end
    return all
end

local function UpdateApplyButton()
    if OFAuctionFrameLFG.applyDirty then
        OFLFG_ApplyButton:Show()
    else
        OFLFG_ApplyButton:Hide()
    end
end

function OFLFGScroll_Update()
    local entries = GetLFGEntries()

    entries = ns.SortLFG(entries, OFGetCurrentSortParams("lfg"))

    local totalEntries = #entries
    local offset = FauxScrollFrame_GetOffset(OFLFGScroll)
    updateSortArrows()

    for i = 1, NUM_RESULTS_TO_DISPLAY do
        local index = offset + i
        local button = _G["OFLFGButton"..i]
        local entry = entries[index]
        if not entry or index > totalEntries then
            button:Hide()
        else
            button:Show()
            UpdateEntry(i, offset, button, entry)
        end
    end

    FauxScrollFrame_Update(OFLFGScroll, totalEntries, NUM_RESULTS_TO_DISPLAY, OF_AUCTIONS_BUTTON_HEIGHT)

    if selectedRow and selectedRow.entry and selectedRow.entry.isOnline then
        OFLFGInviteButton:Enable()
        OFLFGWhisperButton:Enable()
    else
        OFLFGInviteButton:Disable()
        OFLFGWhisperButton:Disable()
    end

    UpdateApplyButton()
end

function OFLFG_ApplyButton_OnClick()
    OFLFG_CheckButton:SetChecked(true)
    OFLFG_Apply()

    -- Clear focus from input fields
    local minViewers = _G["OFLFG_MinViewers"]
    local maxViewers = _G["OFLFG_MaxViewers"]
    minViewers:ClearFocus()
    maxViewers:ClearFocus()
end

function OFLFG_Apply(overrideDungeons)
    local minViewers = _G["OFLFG_MinViewers"]
    local maxViewers = _G["OFLFG_MaxViewers"]
    local noMin = _G["OFLFG_NoMinViewersCheck"]:GetChecked()
    local noMax = _G["OFLFG_NoMaxViewersCheck"]:GetChecked()

    local minViewerCount = noMin and 0 or tonumber(minViewers:GetText()) or 0
    local maxViewerCount = noMax and 99999 or tonumber(maxViewers:GetText()) or 99999

    -- Check if collaboration is enabled
    local me = UnitName("player")
    local isEnabled = OFLFG_CheckButton:GetChecked()

    if not isEnabled then
        local success, error = ns.LfgAPI:DeleteEntry(me)
        if error then
            ns.DebugLog("[Debug] Error removing LFG entry:", error)
        end
        return
    end

    local myEntry = ns.LfgAPI:GetMyEntry()
    local dungeons = nil
    if overrideDungeons then
        -- overrideDungeons is a table. convert it into array of indices
        dungeons = {}
        for _, dungeon in pairs(overrideDungeons) do
            table.insert(dungeons, dungeon.index)
        end
    elseif myEntry and myEntry.dungeons then
        dungeons = myEntry.dungeons
    end

    -- Otherwise create/update the entry
    local data = {
        name = me,
        minViewers = minViewerCount,
        maxViewers = maxViewerCount,
        isRP = OFLFG_RPTogetherCheck:GetChecked(),
        isDungeon = OFLFG_DungeonCheck:GetChecked(),
        dungeons = dungeons,
        roles = ns.GetRoleSelections(OFLFG_RoleSelection),

        -- player data, for convenience (we could technically look it up all the time to render the UI)
        level = ns.GetPlayerLevel(),  -- we'll overwrite this with live data if we have it
        race = select(2, UnitRace("player")),
        class = select(2, UnitClass("player")),
    }

    local entry, error = ns.LfgAPI:UpsertEntry(data)
    if error then
        print(ChatPrefixError .. "Error creating LFG entry:", error)
    end

    -- Reset applyDirty after applying changes
    OFAuctionFrameLFG.applyDirty = false
    OFLFGScroll_Update()
end

-- This function will handle showing a tooltip when hovering over a row that does NOT meet the requirements.
local function OFLFG_Row_OnEnter(self)
    ShowTooltip(self, self.meetsRequirements, self.requirementsReason, self.entry, false)
end

local function OFLFG_Row_OnLeave(self)
    if GameTooltip:IsOwned(self) then
        GameTooltip:Hide()
    end
end

function OFLFG_Row_OnLoad(self)
    self.onlineIcon:SetTexture("Interface\\Addons\\" .. addonName .. "\\Media\\Icons\\Icn_Online.png")

    -- Hook our newly-created tooltip handlers:
    self:HookScript("OnEnter", OFLFG_Row_OnEnter)
    self:HookScript("OnLeave", OFLFG_Row_OnLeave)
end

local function UpdateDungeonSection()
    local checked = OFLFG_DungeonCheck:GetChecked()

    local roleFrame = OFLFG_RoleSelection
    if roleFrame then
        ns.RoleButtonsToggleEnabled(roleFrame, checked)
    end

    local button = OFLFG_DungeonTypeButton
    if button then
        if checked then
            button:Enable()
        else
            button:Disable()
        end
    end
end

function OFAuctionFrameLFG_OnLoad()
    OFAuctionFrame_SetSort("lfg", "colab", false)
    OFLFG_BlockUsersButton:Disable()

    -- Create the dungeon scroll list
    local root = OFAuctionFrameLFG
    root.dungeonScrollList = ns.CreateDungeonScrollList(OFLFG_DungeonTypeButton)

    -- Initialize applyDirty state
    OFAuctionFrameLFG.applyDirty = false

    -- Add handlers for viewer input boxes
    local minViewers = _G["OFLFG_MinViewers"]
    local maxViewers = _G["OFLFG_MaxViewers"]

    minViewers:SetScript("OnTextChanged", function()
        local value = tonumber(minViewers:GetText())
        if value and value >= 0 then
            OFAuctionFrameLFG.applyDirty = true
            UpdateApplyButton()
        end
    end)

    maxViewers:SetScript("OnTextChanged", function()
        local value = tonumber(maxViewers:GetText())
        if value and value >= 0 then
            OFAuctionFrameLFG.applyDirty = true
            UpdateApplyButton()
        end
    end)

    OFLFG_CheckButton:SetScript("OnClick", function ()
        OFLFG_Apply()
    end)
    OFLFG_RPTogetherCheck:SetScript("OnClick", function ()
        OFLFG_CheckButton:SetChecked(true)
        OFLFG_Apply()
    end)
    OFLFG_DungeonCheck:SetScript("OnClick", function()
        OFLFG_CheckButton:SetChecked(true)

        local overrideDungeons = nil
        if OFLFG_DungeonCheck:GetChecked() then
            -- enable all dungeons when ticking the 'dungeon' checkbox
            local scroll = OFAuctionFrameLFG.dungeonScrollList
            ns.SetLookingForAllDungeons(scroll, true)
            overrideDungeons = scroll.dungeons
        end

        UpdateDungeonSection()
        OFLFG_Apply(overrideDungeons)
    end)

    OFLFG_NoMinViewersCheck:SetScript("OnClick", function(self)
        OFLFG_CheckButton:SetChecked(true)

        local minViewers = _G["OFLFG_MinViewers"]
        local minViewersLabel = _G["OFLFG_MinViewersText"]
        minViewers:SetEnabled(not self:GetChecked())
        LFG_UpdateViewerColor(minViewersLabel, not self:GetChecked())

        OFAuctionFrameLFG.applyDirty = true
        UpdateApplyButton()
    end)
    OFLFG_NoMaxViewersCheck:SetScript("OnClick", function(self)
        OFLFG_CheckButton:SetChecked(true)

        local maxViewers = _G["OFLFG_MaxViewers"]
        local maxViewersLabel = _G["OFLFG_MaxViewersText"]
        maxViewers:SetEnabled(not self:GetChecked())
        LFG_UpdateViewerColor(maxViewersLabel, not self:GetChecked())

        OFAuctionFrameLFG.applyDirty = true
        UpdateApplyButton()
    end)
end

function LFG_UpdateViewerColor(editBox, enabled)
    if enabled then
        editBox:SetTextColor(1, 1, 1, 1)
    else
        editBox:SetTextColor(0.5, 0.5, 0.5, 1)
    end
end

function OFLFG_DungeonCheck_OnClick(self)
    UpdateDungeonSection()
end

function OFAuctionFrameLFG_OnShow()
    -- Get current player's entry if it exists
    local currentEntry = ns.LfgAPI:GetMyEntry()

    -- Set checkbox state
    OFLFG_CheckButton:SetChecked(currentEntry ~= nil)

    -- Initialize input fields based on current entry or default values
    OFLFG_RPTogetherCheck:SetChecked(currentEntry and currentEntry.isRP or false)
    OFLFG_DungeonCheck:SetChecked(currentEntry and currentEntry.isDungeon or false)

    -- Update role buttons based on dungeon checkbox
    ns.RoleButtonsToggleChecked(OFLFG_RoleSelection, currentEntry and currentEntry.roles)

    -- Initialize viewer fields and checkboxes
    local minViewers = _G["OFLFG_MinViewers"]
    local maxViewers = _G["OFLFG_MaxViewers"]
    local noMinCheck = _G["OFLFG_NoMinViewersCheck"]
    local noMaxCheck = _G["OFLFG_NoMaxViewersCheck"]
    local minViewersLabel = _G["OFLFG_MinViewersText"]
    local maxViewersLabel = _G["OFLFG_MaxViewersText"]

    if currentEntry then
        local maxViewerCount = currentEntry.maxViewers
        if currentEntry.maxViewers == 99999 then
            maxViewerCount = ""
        end

        minViewers:SetText(currentEntry.minViewers or "1")
        maxViewers:SetText(maxViewerCount or "")
        noMinCheck:SetChecked(currentEntry.minViewers <= 0)
        noMaxCheck:SetChecked(currentEntry.maxViewers == 99999)
    else
        -- Set defaults when no entry exists
        minViewers:SetText("1")
        maxViewers:SetText("")
        noMinCheck:SetChecked(false)
        noMaxCheck:SetChecked(true)
    end

    -- cleanup previous state
    OFAuctionFrameLFG.applyDirty = false

    -- Set initial state
    minViewers:SetEnabled(not noMinCheck:GetChecked())
    maxViewers:SetEnabled(not noMaxCheck:GetChecked())
    LFG_UpdateViewerColor(minViewersLabel, not noMinCheck:GetChecked())
    LFG_UpdateViewerColor(maxViewersLabel, not noMaxCheck:GetChecked())

    UpdateDungeonSection()

    -- Update the scroll frame
    OFLFGScroll_Update()
end

function OFAuctionFrameLFG_OnEvent()
end

function OFAuctionFrameLFG_OnHide()
    local scroll = OFAuctionFrameLFG.dungeonScrollList
    if scroll then
        scroll:Hide()
    end
end

function OFLFGSquare_OnEnter(self, type, index)
    local button = self:GetParent()
    if button and button.entry then
        ShowTooltip(button, button.meetsRequirements, button.requirementsReason, button.entry, false)
    end
end

function OFLFGSquare_OnLeave(self)
    GameTooltip:Hide()
end

function OFLFG_Row_SetEnabled(button, enabled, reason, isOnline)
    -- Grey out the background
    button.disabledBg:SetShown(not enabled)

    -- Grey out all text elements
    local greyColor = enabled and 1 or 0.5
    button.name:SetTextColor(greyColor, greyColor, greyColor)
    button.level:SetTextColor(greyColor, greyColor, greyColor)
    button.colab:SetTextColor(greyColor, greyColor, greyColor)
    button.viewers:SetTextColor(greyColor, greyColor, greyColor)

    -- Grey out the input field texts
    local lightGrey = enabled and 1 or 0.9
    button.livestreamContainer.editBox:SetTextColor(lightGrey, lightGrey, lightGrey)
    button.raidContainer.editBox:SetTextColor(lightGrey, lightGrey, lightGrey)

    -- Disable the editboxes and whisper button
    button.whisperButton:SetEnabled(isOnline)

    -- Store the reason for being disabled (useful for tooltips)
    button.disabledReason = not enabled and reason or nil
end

function OFLFG_DungeonTypeButton_OnClick(self)
    local scroll = OFAuctionFrameLFG.dungeonScrollList
    if scroll then
        if scroll:IsShown() then
            scroll:Hide()
        else
            scroll:Show()
        end
    end
end

function OFLFGInviteButton_OnClick()
    if not selectedRow or not selectedRow.entry then return end

    local playerName = selectedRow.entry.name
    if not playerName then return end

    InviteUnit(playerName)
end

function OFLFGWhisperButton_OnClick()
    if not selectedRow or not selectedRow.entry then return end

    local playerName = selectedRow.entry.name
    if not playerName then return end

    ChatFrame_SendTell(playerName)
end

function OFLFG_Row_OnClick(self)
    if IsModifiedClick() then
        OFAuctionFrameItem_OnClickModified(self, "owner", self:GetParent():GetID() + GetEffectiveAuctionsScrollFrameOffset());
    else
        SelectRow(self)
        OFLFGScroll_Update()
    end
end


ns.GameEventHandler:On("PLAYER_LEVEL_UP", function()
    -- re-submit level
    OFLFG_Apply()
end)
