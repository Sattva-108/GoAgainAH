local _, ns = ...
local L = ns.L

local TAB_ORDERS_MY_BLACKLIST = 1
local TAB_ORDERS_OTHER_BLACKLIST = 2
local TAB_REVIEW_MY_BLACKLIST = 3
local TAB_REVIEW_OTHER_BLACKLIST = 4

local TABS = {
    { name = L["My blacklist"], id = TAB_ORDERS_MY_BLACKLIST },
    { name = L["Who blacklisted me?"], id = TAB_ORDERS_OTHER_BLACKLIST },

    { name = L["My Blacklist"], id = TAB_REVIEW_MY_BLACKLIST },
    { name = L["Who blacklisted me?"], id = TAB_REVIEW_OTHER_BLACKLIST },
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

-- Had to re-write this for 3.3.5 working bad with Russian characters
local function ToPascalCase(str)
    if not str then return "" end

    -- Получаем первый символ (UTF-8)
    local firstChar = str:match("^[%z\1-\127\194-\244][\128-\191]*")
    if not firstChar then return "" end

    -- Получаем оставшуюся часть строки
    local rest = str:sub(#firstChar + 1)

    -- Делаем первую букву заглавной, а остальные строчными через `string.upper`/`string.lower`
    -- Преобразуем всю строку в нижний регистр, затем первую букву в верхний
    local lowerStr = string.lower(str)
    local firstCharLowered = lowerStr:match("^[%z\1-\127\194-\244][\128-\191]*")
    local firstCharUpper = string.upper(firstCharLowered or "")

    return firstCharUpper .. lowerStr:sub(#firstCharLowered + 1)
end

StaticPopupDialogs[STATIC_POPUP_NAME] = {
    text = "",
    button1 = L["Blacklist Player"],
    button2 = CANCEL,
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
        local line1 = L["Type the name of the player you want to blacklist."]
        if selectedTab == TAB_REVIEW_MY_BLACKLIST or selectedTab == TAB_REVIEW_OTHER_BLACKLIST then
            self.text:SetText(line1 .. "\n" .. L["They will not appear in the reviews of other players."])
        else
            self.text:SetText(line1 .. "\n" .. L["They will not be able to buyout or fulfill any of your orders"])
        end
        self.editBox:SetFocus()

        self.button1:Disable()
    end,
    OnHide = function(self)
        self.editBox:SetText("")
    end,
    EditBoxOnEnterPressed = function(self) -- 'self' here is the editBox
        local dialog = self:GetParent()
        -- Ensure the dialog and its button1 exist and are valid objects
        if dialog and dialog.button1 and type(dialog.button1.IsEnabled) == "function" and type(dialog.button1.Click) == "function" then
            -- Check if the accept button (button1) is enabled (respecting validation)
            if dialog.button1:IsEnabled() then
                -- Simulate clicking the accept button.
                -- The StaticPopup system's handler for button clicks will then
                -- call the appropriate OnAccept function and hide the dialog.
                dialog.button1:Click()
            end
        end
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
    EditBoxOnEscapePressed = function(self)
        StaticPopup_StandardEditBoxOnEscapePressed(self)
        ClearCursor()
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

    if entry.class and CLASS_ICON_TCOORDS[entry.class] then
        button.item.raceTexture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        button.item.raceTexture:SetTexCoord(unpack(CLASS_ICON_TCOORDS[entry.class]))
    else
        ns.DebugLog("Invalid class or missing texcoords for:", entry.class)
        button.item.raceTexture:SetTexture(nil)
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

    local me = UnitName("player")
    if not (ns.AuctionHouseDB.blacklists and ns.AuctionHouseDB.blacklists[me]) then
        -- undo the v1 logic of blacklisting Athene on start
        -- (just run once)
        ns.BlacklistAPI:AddToBlacklist(me, ns.BLACKLIST_TYPE_ORDERS, "Athene")
        ns.BlacklistAPI:RemoveFromBlacklist(me, ns.BLACKLIST_TYPE_ORDERS, "Athene")
        ns.DebugLog("initializing blacklist for " .. me .. ", unblacklist Athene")
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

    -- Helper function to process a list of names
    local function processNames(nameList)
        for _, name in ipairs(nameList or {}) do
            -- Call the new function to get class info
            local class, localizedClass = ns.GetUserClass(name)

            -- Decide on fallbacks if needed (optional, nil might be better)
            -- local displayClass = localizedClass or "?" -- Example fallback for display
            -- local iconClass = classToken or "UNKNOWN" -- Example fallback for icons

            table.insert(entries, {
                displayName = name,
                name = name,
                -- Removed race key
                class = class,         -- Store the English token (e.g., "WARRIOR")
                localizedClass = localizedClass, -- Store the localized name (e.g., "Warrior", "Шаман")
                meetsRequirements = true         -- Assuming this is still relevant
            })
        end
    end

    -- Handle "Who blacklisted me?" tabs
    if selectedTab == TAB_ORDERS_OTHER_BLACKLIST or selectedTab == TAB_REVIEW_OTHER_BLACKLIST then
        -- Get list of players who have blacklisted the current player
        local blacklisters = ns.BlacklistAPI:GetBlacklisters(playerName, blType)
        processNames(blacklisters) -- Use the helper function
    else
        -- Handle "My blacklist" tabs
        local blacklist = ns.BlacklistAPI:GetBlacklist(playerName)
        if blacklist and blacklist.namesByType and blacklist.namesByType[blType] then
            processNames(blacklist.namesByType[blType]) -- Use the helper function
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
        OFSettingsBottomButton1:SetText(WHISPER)
    else
        OFSettingsBottomButton1:SetText(REMOVE)
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