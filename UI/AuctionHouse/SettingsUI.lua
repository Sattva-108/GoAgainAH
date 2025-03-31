local _, ns = ...

local TAB_ORDERS_MY_BLACKLIST = 1
local TAB_ORDERS_OTHER_BLACKLIST = 2
local TAB_REVIEW_MY_BLACKLIST = 3
local TAB_REVIEW_OTHER_BLACKLIST = 4

local TABS = {
    { name = "My blacklist", id = TAB_ORDERS_MY_BLACKLIST },
    { name = "Who blacklisted me?", id = TAB_ORDERS_OTHER_BLACKLIST },

    { name = "My Blacklist", id = TAB_REVIEW_MY_BLACKLIST },
    { name = "Who blacklisted me?", id = TAB_REVIEW_OTHER_BLACKLIST },
}

local selectedAuctionItems = {
    list = nil,
    bidder = nil,
    owner = nil,
}

local function GetSelectedItem(type)
    return selectedAuctionItems[type]
end

local function OFSetSelectedItem(type, index)
    selectedAuctionItems[type] = index
end


local STATIC_POPUP_NAME = "OF_BLACKLIST_PLAYER_DIALOG"

-- New convenience function
local function GetBlacklistTypeFromTab(tabID)
    return (tabID == TAB_REVIEW_MY_BLACKLIST or tabID == TAB_REVIEW_OTHER_BLACKLIST)
        and ns.BLACKLIST_TYPE_REVIEW
        or ns.BLACKLIST_TYPE_ORDERS
end

local function ToPascalCase(str)
    if not str then return "" end
    -- Convert first character to uppercase and the rest to lowercase
    return str:sub(1,1):upper() .. str:lower():sub(2)
end

StaticPopupDialogs[STATIC_POPUP_NAME] = {
    text = "",
    button1 = "Blacklist Player",
    button2 = "Cancel",
    maxLetters = 12,
    OnAccept = function(self)
        local playerName = ToPascalCase(self.editBox:GetText())
        local selectedTab = OFAuctionFrameSettings.selectedTab
        local blType = GetBlacklistTypeFromTab(selectedTab)

        ns.BlacklistAPI:AddToBlacklist(UnitName("player"), blType, playerName)
        OFAuctionFrameSettings_Update()
    end,
    OnShow = function(self)
        local selectedTab = OFAuctionFrameSettings.selectedTab
        if selectedTab == TAB_REVIEW_MY_BLACKLIST or selectedTab == TAB_REVIEW_OTHER_BLACKLIST then
            self.text:SetText("Type the name of the player you want to blacklist.\nThey will not appear in the reviews of other players.")
        else
            self.text:SetText("Type the name of the player you want to blacklist.\nThey will not be able to buyout or fulfill any of your orders")
        end
        self.editBox:SetFocus()

        self.button1:Disable()
    end,
    OnHide = function(self)
        self.editBox:SetText("")
    end,
    EditBoxOnTextChanged = function(self)
        local text = ToPascalCase(self:GetText())
        local dialog = self:GetParent()
        local button1 = dialog.button1

        if text and (ns.IsGuildMember(text) or text == "Athene") then
            button1:Enable()
        else
            button1:Disable()
        end
    end,
    timeout = 0,
    hasEditBox = true,
    whileDead = true,
    hideOnEscape = true,
}


function OFSettings_CheckUnlockHighlight(self, selectedType, offset)
	local selected = GetSelectedItem(selectedType);
	if (not selected or (selected ~= self:GetParent():GetID() + offset)) then
		self:GetParent():UnlockHighlight();
	end
end


local function InitializeLeftTabs(self, tabs)
    for i, buttonInfo in ipairs(tabs) do
        local button = _G["AHSettings"..i]
        if button then
            buttonInfo.button = button
            AHSettingsButton_SetUp(button, buttonInfo)

            -- Set up click handler
            button:SetScript("OnClick", function()
                if buttonInfo.disabled then
                    return
                end
                OFAuctionFrameSettings_SelectTab(buttonInfo.id)
            end)

            if buttonInfo.id == self.selectedTab then
                button:LockHighlight()
            else
                button:UnlockHighlight()
            end

            -- support disabled buttons
            if buttonInfo.disabled then
                button:Disable()
                button:GetFontString():SetTextColor(0.75, 0.75, 0.75)
            end
        end
    end
end

function AHSettingsButton_SetUp(button, info)
    -- Set up the button appearance
    button:SetText(info.name)

    -- Set up the texture
    local tex = button:GetNormalTexture()
    tex:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-FilterBg")
    tex:SetTexCoord(0, 0.53125, 0, 0.625)
end

function OFAuctionFrameSettings_SelectTab(tabID)
    local self = OFAuctionFrameSettings
    if not self then return end
    local didSwitch = tabID ~= self.selectedTab

    self.selectedTab = tabID
    -- Update tab highlights
    for i, buttonInfo in ipairs(TABS) do
        local button = _G["AHSettings"..i]
        if button then
            if buttonInfo.id == tabID then
                button:LockHighlight()
            else
                button:UnlockHighlight()
            end
        end
    end

    -- clear selection
    if didSwitch then
        OFSetSelectedItem("list", nil)
    end
    -- Refresh the view
    OFAuctionFrameSettings_Update()
end


local function UpdateEntry(i, offset, button, entry)
    -- Name
    button.name:SetText(entry.displayName)

    -- Use built-in race texture with texcoords
    if entry.race then
        local texture = string.format("Interface\\Icons\\Achievement_Character_%s_Male", entry.race)
        button.item.raceTexture:SetTexture(texture)
    end
    button.item.raceTexture:SetAlpha(entry.meetsRequirements and 1.0 or 0.6)

    -- Highlights
    if (GetSelectedItem("list") and (offset + i) == GetSelectedItem("list")) then
        button:LockHighlight()
    else
        button:UnlockHighlight()
    end
end


-- local function UpdateAtheneTabVisibility()
--     local me = UnitName("player")
--     local atheneBlacklisted = ns.BlacklistAPI:IsBlacklisted(me, ns.BLACKLIST_TYPE_ORDERS, "Athenegpt")
--         or ns.BlacklistAPI:IsBlacklisted(me, ns.BLACKLIST_TYPE_REVIEW, "Athenegpt")
--         or ns.BlacklistAPI:IsBlacklisted(me, ns.BLACKLIST_TYPE_ORDERS, "Athene")
--         or ns.BlacklistAPI:IsBlacklisted(me, ns.BLACKLIST_TYPE_REVIEW, "Athene")

--     if atheneBlacklisted then
--         OFAuctionFrameTab8:Hide()
--         AHSettingsSubtitle:Show()
--     else
--         OFAuctionFrameTab8:Show()
--         AHSettingsSubtitle:Hide()
--     end
-- end

function SettingsUI_Initialize()
    local function Update()
        if OFAuctionFrame:IsShown() and OFAuctionFrameSettings:IsShown() then
            OFAuctionFrameSettings_Update()
        end
    end

    -- -- Check if blacklist has been initialized
    -- if not ns.AuctionHouseDB.isBlacklistInit then
    --     local me = UnitName("player")

    --     -- the very first time, we blacklist Athene by default
    --     ns.BlacklistAPI:AddToBlacklist(me, ns.BLACKLIST_TYPE_ORDERS, "Athene")
    --     ns.AuctionHouseDB.isBlacklistInit = true
    --     ns.DebugLog("intiializing, blacklist Athene")
    -- end

    if not ns.AuctionHouseDB.isBlacklistInitV2 then
        local me = UnitName("player")

        -- undo the v1 logic of blacklisting Athene on start
        -- (just run once)
        ns.BlacklistAPI:AddToBlacklist(me, ns.BLACKLIST_TYPE_ORDERS, "Athene")
        ns.BlacklistAPI:RemoveFromBlacklist(me, ns.BLACKLIST_TYPE_ORDERS, "Athene")
        ns.AuctionHouseDB.isBlacklistInitV2 = true
        ns.DebugLog("intiializing, unblacklist Athene")
    end

    -- UpdateAtheneTabVisibility()

    ns.AuctionHouseAPI:RegisterEvent(ns.T_BLACKLIST_ADD_OR_UPDATE, Update)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_BLACKLIST_DELETED, Update)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_BLACKLIST_SYNCED, Update)
    ns.AuctionHouseAPI:RegisterEvent(ns.T_ON_BLACKLIST_STATE_UPDATE, Update)
end


function OFSettingsRow_OnLoad(self)
end

function OFSettingsRow_OnClick(button)
	assert(button)

	OFSetSelectedItem("list", button:GetID() + FauxScrollFrame_GetOffset(OFSettingsScroll))

	-- Close any auction related popups
	OFCloseAuctionStaticPopups()
	OFAuctionFrameSettings_Update()
end

function OFAuctionFrameSettings_OnLoad()
    local self = OFAuctionFrameSettings
    self.selectedTab = TAB_ORDERS_MY_BLACKLIST

    -- Set up left-column navigation buttons
    InitializeLeftTabs(self, TABS)
end

local NUM_RESULTS_TO_DISPLAY = 9

local function GetBlacklistEntries()
    local entries = {}
    local selectedTab = OFAuctionFrameSettings.selectedTab
    local playerName = UnitName("player")
    local blType = GetBlacklistTypeFromTab(selectedTab)

    -- Handle "Who blacklisted me?" tabs
    if selectedTab == TAB_ORDERS_OTHER_BLACKLIST or selectedTab == TAB_REVIEW_OTHER_BLACKLIST then
        -- Get list of players who have blacklisted the current player
        local blacklisters = ns.BlacklistAPI:GetBlacklisters(playerName, blType)
        for _, name in ipairs(blacklisters or {}) do
            local race = ns.GetUserRace(name) or "Orc"
            table.insert(entries, {
                displayName = name,
                name = name,
                race = race,
                meetsRequirements = true
            })
        end
    else
        -- Handle "My blacklist" tabs (existing logic)
        local blacklist = ns.BlacklistAPI:GetBlacklist(playerName)
        if blacklist and blacklist.namesByType and blacklist.namesByType[blType] then
            for _, name in ipairs(blacklist.namesByType[blType]) do
                local race = ns.GetUserRace(name) or "Orc"
                table.insert(entries, {
                    displayName = name,
                    name = name,
                    race = race,
                    meetsRequirements = true
                })
            end
        end
    end
    return entries
end

function OFAuctionFrameSettings_OnSwitchTab()
	OFSetSelectedItem("list", nil)
end

local function UpdateBottomButtons()
    OFSettingsBottomButton2:SetEnabled(true)

    -- Enable/disable remove/whisper button based on selection
    local selectedItem = GetSelectedItem("list")
    OFSettingsBottomButton1:SetEnabled(selectedItem ~= nil)

    -- Set button text based on selected tab
    local self = OFAuctionFrameSettings
    if self.selectedTab == TAB_ORDERS_OTHER_BLACKLIST or self.selectedTab == TAB_REVIEW_OTHER_BLACKLIST then
        OFSettingsBottomButton1:SetText("Whisper")
    else
        OFSettingsBottomButton1:SetText("Remove")
    end
end

function OFAuctionFrameSettings_Update()
    local entries = GetBlacklistEntries()
    local totalEntries = #entries
    local offset = FauxScrollFrame_GetOffset(OFSettingsScroll)

    -- Update scroll frame entries
    for i = 1, NUM_RESULTS_TO_DISPLAY do
        local index = offset + i
        local button = _G["OFSettingsButton"..i]
        local entry = entries[index]
        if not entry or index > totalEntries then
            button:Hide()
        else
            button:Show()
            UpdateEntry(i, offset, button, entry)
        end
    end

    UpdateBottomButtons()

    FauxScrollFrame_Update(OFSettingsScroll, totalEntries, NUM_RESULTS_TO_DISPLAY, OF_AUCTIONS_BUTTON_HEIGHT)
    -- UpdateAtheneTabVisibility()
end

-- 'Whisper' | 'Remove'
function OFSettingsBottomButton1_OnClick()
    local selectedItem = GetSelectedItem("list")
    if not selectedItem then return end

    local tab = OFAuctionFrameSettings.selectedTab
    local button = _G["OFSettingsButton" .. (selectedItem - FauxScrollFrame_GetOffset(OFSettingsScroll))]
    if button and button.name:GetText() then
        if tab == TAB_ORDERS_OTHER_BLACKLIST or tab == TAB_REVIEW_OTHER_BLACKLIST then
            -- Handle whisper functionality
            ChatFrame_SendTell(button.name:GetText())
        else
            -- Handle remove functionality
            local blType = GetBlacklistTypeFromTab(tab)
            ns.BlacklistAPI:RemoveFromBlacklist(UnitName("player"), blType, button.name:GetText())
            end
    end

    -- clear selection
    OFSetSelectedItem("list", nil)

    OFAuctionFrameSettings_Update()
end

-- 'Blacklist player'
function OFSettingsBottomButton2_OnClick()
    StaticPopup_Show(STATIC_POPUP_NAME)
end
