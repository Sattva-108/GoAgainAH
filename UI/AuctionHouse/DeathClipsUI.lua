local addonName, ns = ...
local L = ns.L

-- Time formatting functions for last activity display
local function FormatLastActivityTime(timestamp, isOnline)
    -- If player is online, show green dot
    if isOnline then
        return "__ONLINE_DOT__"
    end

    if not timestamp or timestamp == 0 then
        return "-"
    end

    local currentTime = time()
    local timeDiff = currentTime - timestamp

    -- Use the same PrettyDuration function as regular clips
    return ns.PrettyDuration(timeDiff)
end

-- Get color for activity time based on how long ago it was
local function GetLastActivityColor(timestamp, isOnline)
    -- If player is online, use bright green
    if isOnline then
        return 0, 1, 0 -- Bright green for online dot
    end

    if not timestamp or timestamp == 0 then
        return 0.6, 0.6, 0.6 -- Gray for unknown
    end

    local currentTime = time()
    local timeDiff = currentTime - timestamp

    if timeDiff < 3600 then -- less than 1 hour - GREEN
        return 0, 1, 0
    elseif timeDiff < 7200 then -- less than 2 hours - YELLOW
        return 1, 1, 0
    elseif timeDiff < 14400 then -- less than 4 hours - WHITE
        return 1, 1, 1
    elseif timeDiff < 43200 then -- less than 12 hours - ORANGE
        return 1, 0.5, 0
    elseif timeDiff < 86400 then -- less than 1 day - RED
        return 1, 0, 0
    else -- more than 1 day - GRAY
        return 0.6, 0.6, 0.6
    end
end

-- Function to create/show online dot texture on whenText FontString
local function ShowOnlineDot(whenFS)
    if not whenFS.onlineDot then
        -- Create the texture once
        whenFS.onlineDot = whenFS:GetParent():CreateTexture(nil, "OVERLAY")
        whenFS.onlineDot:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\clean_dot.tga")
        whenFS.onlineDot:SetSize(22, 22) -- 1.5x larger than original 8x8
        whenFS.onlineDot:SetVertexColor(0, 1, 0, 1) -- Bright green
    end

    -- Position the dot relative to the FontString
    whenFS.onlineDot:ClearAllPoints()
    whenFS.onlineDot:SetPoint("CENTER", whenFS, "CENTER", 0, 0)
    whenFS.onlineDot:Show()

    -- Hide the text since we're showing texture instead
    whenFS:SetText("")
end

-- Function to hide online dot texture
local function HideOnlineDot(whenFS)
    if whenFS.onlineDot then
        whenFS.onlineDot:Hide()
    end
end

-- Keep track if the sort hook has been applied to avoid duplicates
local sortHookApplied = false

local NUM_CLIPS_TO_DISPLAY = 9
local NUM_CLIPS_PER_PAGE = 50
local CLIPS_BUTTON_HEIGHT = 37

local function formatWhen(clip)
    if clip.ts == nil then
        return L["Unknown"]
    end
    local serverTime = GetServerTime()
    local timeDiff = serverTime - clip.ts

    if timeDiff < 0 then
        --print(string.format(
        --        "Time sync issue - Server: %d, Clip: %d, Diff: %d (Clip ID: %s)",
        --        serverTime, clip.ts, timeDiff, clip.id or "nil"
        --))
        timeDiff = 0  -- Ensure we never show negative time
    end

    return ns.PrettyDuration(timeDiff)
end

-- This must match your <Binding name="GOAGAINAH_TOGGLE_CLIPS" …> in Bindings.xml
-- 1) Key-Bindings header and friendly name
_G.BINDING_HEADER_GoAgainAH = "GoAgainAH"
_G.BINDING_NAME_GOAGAINAH_TOGGLE_CLIPS = "Показать панель смертей"

-- 2) This must exactly match your <Binding name="GOAGAINAH_TOGGLE_CLIPS" …>
function GOAGAINAH_TOGGLE_CLIPS()
    local af = _G["OFAuctionFrame"]
    if not af then
        return
    end

    -- if visible, just hide and exit
    if af:IsShown() then
        af:Hide()
        return
    end

    -- otherwise show & select Death-Clips → Live
    af:Show()

    -- click main tab #6 (Death-Clips)
    local tab6 = _G["OFAuctionFrameTab6"]
    if tab6 and tab6:IsShown() then
        tab6:Click()
    end

    -- click the "Live" sub-tab
    local liveTab = _G["OFDeathClipsTabLive"]
    if liveTab and liveTab:IsShown() then
        liveTab:Click()
    end
end

local function updateSortArrows()
    OFSortButton_UpdateArrow(OFDeathClipsStreamerSort, "clips", "streamer")
    OFSortButton_UpdateArrow(OFDeathClipsRaceSort, "clips", "race")
    OFSortButton_UpdateArrow(OFDeathClipsLevelSort, "clips", "level")
    OFSortButton_UpdateArrow(OFDeathClipsClassSort, "clips", "class")
    OFSortButton_UpdateArrow(OFDeathClipsWhenSort, "clips", "when")
    OFSortButton_UpdateArrow(OFDeathClipsRatingSort, "clips", "rating")
    OFSortButton_UpdateArrow(OFDeathClipsWhereSort, "clips", "where")
    OFSortButton_UpdateArrow(OFDeathClipsClipSort, "clips", "clip")
    OFSortButton_UpdateArrow(OFDeathClipsOldLevelSort, "clips", "oldlevel")
    OFSortButton_UpdateArrow(OFDeathClipsOldClassSort, "clips", "oldclass")
end

-- Forward declaration of UpdateClipEntry for use in event handlers
local UpdateClipEntry

-- OFAuctionFrameDeathClips_OnLoad
function OFAuctionFrameDeathClips_OnLoad()
    OFAuctionFrameDeathClips.page = 0
    OFAuctionFrame_SetSort("clips", "when", false) -- Initial sort

    -- Initialize state variables for data caching
    OFAuctionFrameDeathClips.currentDisplayableClips = {}
    OFAuctionFrameDeathClips.needsDataRefresh = true -- Force initial data load
    OFAuctionFrameDeathClips.lastSortKey = "when"
    OFAuctionFrameDeathClips.lastSortAscending = false
    OFAuctionFrameDeathClips.lastSubTab = OFAuctionFrameDeathClips.currentSubTab or "live" -- Assuming 'live' is default

    -- —— КЭШ КНОПОК ——
    ns.clipButtonElements = {}
    for i = 1, NUM_CLIPS_TO_DISPLAY do
        local button = _G["OFDeathClipsButton" .. i]
        local buttonName = button:GetName()

        ns.clipButtonElements[i] = {
            button = button,
            highlight = _G[buttonName .. "Highlight"],
            name = _G[buttonName .. "Name"],
            level = _G[buttonName .. "Level"],
            raceText = _G[buttonName .. "RaceText"],
            itemIconTexture = _G[buttonName .. "ItemIconTexture"],
            classText = _G[buttonName .. "ClassText"],
            whenText = _G[buttonName .. "WhenText"],
            whereText = _G[buttonName .. "WhereText"],
            clipText = _G[buttonName .. "ClipText"],
            clipMobLevel = _G[buttonName .. "ClipMobLevel"],
            rating = _G[buttonName .. "Rating"],
            clipFrame = _G[buttonName .. "Clip"],
            oldLevelText = _G[buttonName .. "OldLevelText"], -- New cache entry
            oldClassText = _G[buttonName .. "OldClassText"], -- New cache entry
        }
        button.displayedClipID = nil -- Initialize for conditional updates

        ns.SetupClipHighlight(button)

        button:SetScript("OnClick", function(self)
            local c = self.clipData
            if not c or not c.id then
                return
            end
            local wasOpen = (OFAuctionFrameDeathClips.openedPromptClipID == c.id)
            ns.HideAllClipPrompts()
            if not wasOpen then
                ns.ShowDeathClipReviewsPrompt(c)
                OFAuctionFrameDeathClips.openedPromptClipID = c.id
            end
            OFAuctionFrameDeathClips_Update()
        end)
    end

    -- Быстрое обновление столбца «Когда» сразу после любого обновления списка
    hooksecurefunc("OFAuctionFrameDeathClips_Update", function()
        for i = 1, NUM_CLIPS_TO_DISPLAY do
            local el = ns.clipButtonElements[i]
            local clip = el and el.button.clipData
            if clip then
                local whenFS = el.whenText
                if clip.isReincarnated then
                    -- For reincarnated friends, show last activity time
                    if clip.lastActivityTimestamp and clip.lastActivityTimestamp > 0 then
                        local activityText = FormatLastActivityTime(clip.lastActivityTimestamp, clip.isOnline)
                        if activityText == "__ONLINE_DOT__" then
                            ShowOnlineDot(whenFS)
                        else
                            HideOnlineDot(whenFS)
                            local r, g, b = GetLastActivityColor(clip.lastActivityTimestamp, clip.isOnline)
                            whenFS:SetText(activityText)
                            whenFS:SetTextColor(r, g, b, 0.8)
                        end
                    elseif clip.isOnline then
                        -- Player is online but no activity timestamp
                        ShowOnlineDot(whenFS)
                    else
                        HideOnlineDot(whenFS)
                        whenFS:SetText("-")
                        whenFS:SetTextColor(0.6, 0.6, 0.6, 0.8)
                    end
                elseif ns.currentActiveTabId == "SPEED_CLIPS" then
                    -- Для живых игроков на вкладке "Скорость" проверяем онлайн-статус в реальном времени
                    local memberData = ns.GuildRegister and ns.GuildRegister.GetMemberData and ns.GuildRegister:GetMemberData(clip.characterName)
                    local isCurrentlyOnline = memberData and memberData.isOnline

                    if isCurrentlyOnline then
                        ShowOnlineDot(whenFS)
                    else
                        HideOnlineDot(whenFS)
                        -- Показываем время последнего онлайна для оффлайн игроков
                        if clip.ts then
                            whenFS:SetText(formatWhen(clip))
                            if clip.playedTime and clip.level then
                                local r, g, b = ns.GetPlayedTimeColor(clip.playedTime, clip.level)
                                whenFS:SetTextColor(r, g, b, .7)
                            else
                                whenFS:SetTextColor(.6, .6, .6, .5)
                            end
                        else
                            whenFS:SetText("-")
                            whenFS:SetTextColor(0.6, 0.6, 0.6, 0.8)
                        end
                    end
                elseif clip.ts then
                    -- Regular clips with timestamp
                    HideOnlineDot(whenFS) -- Make sure dot is hidden for regular clips
                    whenFS:SetText(formatWhen(clip))
                    if clip.playedTime and clip.level then
                        local r, g, b = ns.GetPlayedTimeColor(clip.playedTime, clip.level)
                        whenFS:SetTextColor(r, g, b, .7)
                    else
                        whenFS:SetTextColor(.6, .6, .6, .5)
                    end
                end
            end
        end
    end)

    ns.AuctionHouseAPI:RegisterEvent(ns.EV_DEATH_CLIPS_CHANGED, function()
        OFAuctionFrameDeathClips.needsDataRefresh = true -- Mark data as needing refresh
        if OFAuctionFrame:IsShown() and OFAuctionFrameDeathClips:IsShown() then
            OFAuctionFrameDeathClips_Update()
        end
        -- Update checkbox state when clips change
        OFDeathClips_UpdateSpeedClipsCheckbox()
    end)

    -- Listen for played time updates to refresh UI in real-time
    ns.AuctionHouseAPI:RegisterEvent(ns.EV_PLAYED_TIME_UPDATED, function(clipID)
        if OFAuctionFrame:IsShown() and OFAuctionFrameDeathClips:IsShown() then
            -- Update only the specific clip row if visible, otherwise full refresh
            local updated = false
            for i = 1, NUM_CLIPS_TO_DISPLAY do
                local el = ns.clipButtonElements[i]
                local button = el and el.button
                if button and button.clipData and button.clipData.id == clipID then
                    -- Update just this row with proper parameters
                    local state = nil -- We don't have state in this context
                    local offset = FauxScrollFrame_GetOffset(OFDeathClipsScroll) or 0
                    local ratings = ns.GetTopReactions(clipID, 1) or {}
                    UpdateClipEntry(state, i, offset, el, button.clipData, ratings, 1, 1, true)
                    updated = true
                    break
                end
            end
            if not updated then
                -- Clip not visible, do full refresh
                OFAuctionFrameDeathClips_Update()
            end
        end
    end)

    OFAuctionFrameDeathClips.openedPromptClipID = nil
    OFAuctionFrameDeathClips._highlightedClips = OFAuctionFrameDeathClips._highlightedClips or {}

    if not sortHookApplied then
        if type(OFAuctionFrame_SetSort) == "function" then
            hooksecurefunc("OFAuctionFrame_SetSort", function(type, key, ascending)
                if type == "clips" then
                    -- Only react to sorts for our "clips" type
                    OFAuctionFrameDeathClips.page = 0
                    FauxScrollFrame_SetOffset(OFDeathClipsScroll, 0)
                    if OFDeathClipsScrollScrollBar then
                        OFDeathClipsScrollScrollBar:SetValue(0)
                    end
                    OFAuctionFrameDeathClips.needsDataRefresh = true -- Sort changed, needs data refresh
                    -- OFAuctionFrameDeathClips_Update()
                end
            end)
            sortHookApplied = true
        else
            ns.DebugLog(addonName .. ": Error - Could not find OFAuctionFrame_SetSort to hook.")
        end
    end

    -- Hook tab clicks to set needsDataRefresh
    if OFDeathClipsTabLive then
        OFDeathClipsTabLive:HookScript("OnClick", function()
            if OFAuctionFrameDeathClips.currentSubTab ~= "live" then
                OFAuctionFrameDeathClips.currentSubTab = "live"
                OFAuctionFrameDeathClips.needsDataRefresh = true
                OFAuctionFrame_SetSort("clips", "when", false)
                -- OFAuctionFrameDeathClips_Update()
            end
        end)
    end
    if OFDeathClipsTabCompleted then
        OFDeathClipsTabCompleted:HookScript("OnClick", function()
            if OFAuctionFrameDeathClips.currentSubTab ~= "completed" then
                OFAuctionFrameDeathClips.currentSubTab = "completed"
                OFAuctionFrameDeathClips.needsDataRefresh = true
                OFAuctionFrame_SetSort("clips", "clip", true)
                -- OFAuctionFrameDeathClips_Update()
            end
        end)
    end

    local nav = CreateFrame("Button", "OFDeathClipsNavFrame", OFAuctionFrameDeathClips)
    nav:SetSize(250, 70); nav:SetScale(0.8); nav:SetAlpha(0.9)
    nav:SetPoint("RIGHT", OFAuctionFrameDeathClips, "BOTTOMRIGHT", 98, 25)
    nav:SetNormalAtlas("Glue-Shadow-Button-Normal", true)
    nav:GetNormalTexture():SetVertexColor(1, 1, 1, 0.7)
    nav:SetHighlightAtlas("Glue-Shadow-Button-Highlight", true)
    nav:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.05)

    local label = nav:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nav.pageLabel = label
    label:SetFont(label:GetFont(), 16)
    label:SetTextColor(1, 0.8, 0)
    label:SetJustifyH("RIGHT")
    label:SetPoint("CENTER", nav, "CENTER", 0, 5)

    local prev = CreateFrame("Button", "OFDeathClipsPrevPageButton", nav)
    prev:SetSize(80, 50); prev:SetPoint("LEFT", nav, "LEFT", 10, 5)
    prev:SetNormalAtlas("Glue-Left-Array-Shadow-Button-Normal")
    prev:SetPushedAtlas("Glue-Left-Array-Shadow-Button-Pushed")
    prev:SetHighlightAtlas("Glue-Left-Array-Shadow-Button-Highlight")
    prev:SetDisabledAtlas("Glue-Left-Array-Shadow-Button-Disable")
    prev:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local next = CreateFrame("Button", "OFDeathClipsNextPageButton", nav)
    next:SetSize(80, 50); next:SetPoint("RIGHT", nav, "RIGHT", -10, 5)
    next:SetNormalAtlas("Glue-Right-Array-Shadow-Button-Normal")
    next:SetPushedAtlas("Glue-Right-Array-Shadow-Button-Pushed")
    next:SetHighlightAtlas("Glue-Right-Array-Shadow-Button-Highlight")
    next:SetDisabledAtlas("Glue-Right-Array-Shadow-Button-Disable")
    next:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    prev:GetHighlightTexture():SetVertexColor(0.3, 0.3, 0.3, 0.7)
    next:GetHighlightTexture():SetVertexColor(0.3, 0.3, 0.3, 0.7)
    prev:GetNormalTexture():SetVertexColor(1, 1, 1, 0.6)
    next:GetNormalTexture():SetVertexColor(1, 1, 1, 0.6)
    prev:GetDisabledTexture():SetVertexColor(0.2, 0.2, 0.2, 1)
    next:GetDisabledTexture():SetVertexColor(0.2, 0.2, 0.2, 1)

    local function SetButtonTextureLayout(btn, w, h)
        local t = {btn:GetNormalTexture(), btn:GetHighlightTexture(), btn:GetPushedTexture(), btn:GetDisabledTexture()}
        for _, tex in ipairs(t) do
            if tex then tex:ClearAllPoints(); tex:SetPoint("CENTER", btn, "CENTER"); tex:SetSize(w, h) end
        end
    end

    SetButtonTextureLayout(next, 55, 45)
    SetButtonTextureLayout(prev, 55, 45)





    prev:SetScript("OnClick", function(self, button)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        local off   = FauxScrollFrame_GetOffset(OFDeathClipsScroll)
        local pages = NUM_CLIPS_TO_DISPLAY
        if IsShiftKeyDown() then
            off = 0
        elseif button == "LeftButton" then
            off = off - pages
        else  -- RightButton: назад на 10 страниц
            off = off - pages * 10
        end
        off = math.max(0, off)
        FauxScrollFrame_SetOffset(OFDeathClipsScroll, off)
        OFAuctionFrameDeathClips_Update()
    end)

    next:SetScript("OnClick", function(self, button)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        local total  = #OFAuctionFrameDeathClips.currentDisplayableClips
        local pages  = NUM_CLIPS_TO_DISPLAY
        local maxOff = math.max(0, total - pages)
        local off    = FauxScrollFrame_GetOffset(OFDeathClipsScroll)
        if IsShiftKeyDown() then
            off = maxOff
        elseif button == "LeftButton" then
            off = off + pages
        else  -- RightButton: "вперёд 10 стр." или с 0 сразу к 9-й
            if off == 0 then
                off = pages * 9
            else
                off = off + pages * 10
            end
        end
        off = math.min(maxOff, off)
        FauxScrollFrame_SetOffset(OFDeathClipsScroll, off)
        OFAuctionFrameDeathClips_Update()
    end)



    prev:SetScript("OnMouseDown", function(self)
        SetButtonTextureLayout(self, 40, 40)
    end)
    prev:SetScript("OnMouseUp", function(self)
        SetButtonTextureLayout(self, 55, 45)
    end)

    next:SetScript("OnMouseDown", function(self)
        SetButtonTextureLayout(self, 40, 40)
    end)
    next:SetScript("OnMouseUp", function(self)
        SetButtonTextureLayout(self, 55, 45)
    end)





    -- ---- START OF MINIMAL CHANGE TO DISABLE MOUSE WHEEL SCROLLING ----
    local scrollFrame = _G["OFDeathClipsScroll"]
    if scrollFrame then
        -- Disable mouse wheel (you already had this)
        scrollFrame:SetScript("OnMouseWheel", nil)
        if scrollFrame.EnableMouseWheel then
            scrollFrame:EnableMouseWheel(false)
        end
        -- Hide the entire scroll frame (slider, arrows, background)
        scrollFrame:Hide()
    end
    -- ---- END OF MINIMAL CHANGE TO DISABLE MOUSE WHEEL SCROLLING ----

    -- Create Cleanup Friends Button
    local cleanupButton = CreateFrame("Button", "OFDeathClipsCleanupButton", OFAuctionFrameDeathClips, "UIPanelButtonTemplate")
    cleanupButton:SetText("Очистить друзей")
    cleanupButton:SetSize(120, 22)
    -- Anchor it to the right of OFAuctionFrameCloseButton, but as a child of OFAuctionFrameDeathClips.
    -- This requires OFAuctionFrameCloseButton to be a global name or accessible.
    if _G["OFAuctionFrameCloseButton"] then
        cleanupButton:SetPoint("RIGHT", _G["OFAuctionFrameCloseButton"], "LEFT", -10, 0)
    else
        -- Fallback positioning if OFAuctionFrameCloseButton is not found (e.g. top right of the panel)
        cleanupButton:SetPoint("TOPRIGHT", OFAuctionFrameDeathClips, "TOPRIGHT", -10, -10)
        if ns.debug then print(addonName .. ": OFAuctionFrameCloseButton not found, using fallback for CleanupButton position.") end
    end

    cleanupButton:SetScript("OnClick", function()
        if ns.InitiateFriendCleanup then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            ns.InitiateFriendCleanup()
        else
            DEFAULT_CHAT_FRAME:AddMessage(addonName .. ": Cleanup function (InitiateFriendCleanup) not found in ns.")
        end
    end)

    -- Set initial visibility (will be updated by OFAuctionFrameDeathClips_Update)
    cleanupButton:Hide()
    OFAuctionFrameDeathClips.cleanupButton = cleanupButton -- Store reference if needed elsewhere or for clarity

end

function ns.SetupClipHighlight(button)
    if not button.glow then
        -- ✨ Glow
        local glow = button:CreateTexture(nil, 'OVERLAY')
        button.glow = glow
        glow:SetPoint('CENTER', button, 'CENTER')
        glow:SetWidth(400 / 300 * button:GetWidth())
        glow:SetHeight(171 / 70 * button:GetHeight())
        glow:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\UI-Achievement-Alert-Glow")
        glow:SetBlendMode('ADD')
        glow:SetTexCoord(0, .78125, 0, .66796875)
        glow:SetAlpha(0)

        glow.animation = CreateFrame('Frame')
        glow.animation:Hide()
        glow.animation:SetScript('OnUpdate', function(self)
            local t = GetTime() - self.t0
            if t <= .2 then
                glow:SetAlpha(t * 5)
            elseif t <= .7 then
                glow:SetAlpha(1 - (t - .2) * 2)
            else
                glow:SetAlpha(0)
                self:Hide()
            end
        end)
        function glow.animation:Play()
            self.t0 = GetTime()
            self:Show()
        end
    end

    if not button.shine then
        -- ✨ Shine
        local shine = button:CreateTexture(nil, 'ARTWORK')
        button.shine = shine
        shine:SetPoint('TOPLEFT', button, 0, 8)
        shine:SetWidth(67 / 300 * button:GetWidth())
        shine:SetHeight(1.28 * button:GetHeight())
        shine:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\UI-Achievement-Alert-Glow")
        shine:SetBlendMode('ADD')
        shine:SetTexCoord(.78125, .912109375, 0, .28125)
        shine:SetAlpha(0)

        shine.animation = CreateFrame('Frame')
        shine.animation:Hide()
        shine.animation:SetScript('OnUpdate', function(self)
            local t = GetTime() - self.t0
            if t <= .3 then
                shine:SetPoint('TOPLEFT', button, 0, 8)
            elseif t <= .7 then
                shine:SetPoint('TOPLEFT', button, (t - .3) * 2.5 * self.distance, 8)
            end
            if t <= .3 then
                shine:SetAlpha(0)
            elseif t <= .5 then
                shine:SetAlpha(1)
            elseif t <= .7 then
                shine:SetAlpha(1 - (t - .5) * 5)
            else
                shine:SetAlpha(0)
                self:Hide()
            end
        end)
        function shine.animation:Play()
            self.t0 = GetTime()
            self.distance = button:GetWidth() - shine:GetWidth() + 8
            self:Show()
            button:SetAlpha(1)
        end
    end
end

local initialized = false
function OFAuctionFrameDeathClips_OnShow()
    OFAuctionFrameDeathClips_Update()
    OFDeathClips_UpdateSpeedClipsCheckbox()
    if not initialized then
        initialized = true
        local state = ns.GetDeathClipReviewState()
        local update = function()
            if OFAuctionFrame:IsShown() and OFAuctionFrameDeathClips:IsShown() then
                OFAuctionFrameDeathClips_Update()
            end
        end

        state:RegisterEvent(ns.EV_DEATH_CLIP_REVIEW_ADD_OR_UPDATE, update)
        state:RegisterEvent(ns.EV_DEATH_CLIP_REVIEW_STATE_SYNCED, update)
        --state:RegisterEvent(ns.EV_DEATH_CLIP_OVERRIDE_UPDATED, update)

        -- Hook HideAllClipPrompts ONCE to reset our state tracker
        hooksecurefunc(ns, "HideAllClipPrompts", function()
            OFAuctionFrameDeathClips.openedPromptClipID = nil
            -- Also explicitly update the highlight state of buttons when prompts are closed externally
            if OFAuctionFrame:IsShown() and OFAuctionFrameDeathClips:IsShown() then
                OFAuctionFrameDeathClips_Update() -- Refresh highlights
            end
        end)
    end
    -- —— When-Ticker: обновляет «Когда» и триггерит подсветку новых строк ——
    do
        local frame = OFAuctionFrameDeathClips
        frame._highlightedClips = frame._highlightedClips or {}

        -- остановить прежний тикер, если был
        if frame._whenUpdateTicker then
            frame._whenUpdateTicker:Cancel()
        end

        frame._whenUpdateTicker = C_Timer:NewTicker(1, function()
            -- панель аукциона или под-фрейм скрыты → пропуск
            if not (OFAuctionFrame:IsShown() and frame:IsShown()) then
                return
            end

            for i = 1, NUM_CLIPS_TO_DISPLAY do
                -- всегда 9 строк
                local el = ns.clipButtonElements[i]        -- кэш (Шаг 1)
                local button = el and el.button
                local clip = button and button.clipData      -- актуальные данные

                if button and button:IsShown() and clip and (clip.ts or clip.isReincarnated) then
                    ------------------------------------------------------
                    -- 1) «Когда»
                    ------------------------------------------------------
                    local whenFS = el.whenText

                    if clip.isReincarnated then
                        -- For reincarnated friends, show last activity time
                        if clip.lastActivityTimestamp and clip.lastActivityTimestamp > 0 then
                            local activityText = FormatLastActivityTime(clip.lastActivityTimestamp, clip.isOnline)
                            if activityText == "__ONLINE_DOT__" then
                                ShowOnlineDot(whenFS)
                            else
                                HideOnlineDot(whenFS)
                                local r, g, b = GetLastActivityColor(clip.lastActivityTimestamp, clip.isOnline)
                                whenFS:SetText(activityText)
                                whenFS:SetTextColor(r, g, b, 0.8)
                            end
                        elseif clip.isOnline then
                            -- Player is online but no activity timestamp
                            ShowOnlineDot(whenFS)
                        else
                            HideOnlineDot(whenFS)
                            whenFS:SetText("-")
                            whenFS:SetTextColor(0.6, 0.6, 0.6, 0.8)
                        end
                    elseif ns.currentActiveTabId == "SPEED_CLIPS" then
                        -- Для живых игроков на вкладке "Скорость" проверяем онлайн-статус в реальном времени
                        local memberData = ns.GuildRegister and ns.GuildRegister.GetMemberData and ns.GuildRegister:GetMemberData(clip.characterName)
                        local isCurrentlyOnline = memberData and memberData.isOnline

                        if isCurrentlyOnline then
                            ShowOnlineDot(whenFS)
                        else
                            HideOnlineDot(whenFS)
                            -- Показываем время последнего онлайна для оффлайн игроков
                            if clip.ts then
                                whenFS:SetText(formatWhen(clip))
                                if clip.playedTime and clip.level then
                                    local r, g, b = ns.GetPlayedTimeColor(clip.playedTime, clip.level)
                                    whenFS:SetTextColor(r, g, b, .7)
                                else
                                    whenFS:SetTextColor(.6, .6, .6, .5)
                                end
                            else
                                whenFS:SetText("-")
                                whenFS:SetTextColor(0.6, 0.6, 0.6, 0.8)
                            end
                        end
                    elseif clip.ts == nil then
                        HideOnlineDot(whenFS) -- Make sure dot is hidden for non-reincarnated clips
                        whenFS:SetText("|cffaaaaaa-|r") -- Or L["Unknown"] if preferred, styled
                        whenFS:SetTextColor(0.6, 0.6, 0.6, 0.8) -- Match the color of other N/A text
                    else
                        HideOnlineDot(whenFS) -- Make sure dot is hidden for regular clips
                    whenFS:SetText(formatWhen(clip))

                        if clip.playedTime and clip.level then
                            local r, g, b = ns.GetPlayedTimeColor(clip.playedTime, clip.level)
                            whenFS:SetTextColor(r, g, b, .7)
                        else
                            whenFS:SetTextColor(.6, .6, .6, .5)
                        end
                    end

                    ------------------------------------------------------
                    -- 2) Подсветка новых клипов (меньше 60 с) - only for regular clips
                    ------------------------------------------------------
                    if not clip.isReincarnated and clip.ts then
                        local age = GetServerTime() - clip.ts
                        if age < 60 and not frame._highlightedClips[clip.id] then
                            frame._highlightedClips[clip.id] = true

                            if button.glow then
                                button.glow.animation:Play()
                            end
                            if button.shine then
                                button.shine.animation:Play()
                            end
                        end
                    end
                end
            end
        end)
    end

end

-- Replace the old ResizeEntry with this:
local function ResizeEntry(button, numBatchClips, totalClips)
    -- Always use full width; ignore any scrollbar space
    button:SetWidth(793)
    _G[button:GetName() .. "Highlight"]:SetWidth(758)
end


local function UpdateLayout(buttonName)
    local activeTabKey = ns.currentActiveTabId -- Use the new state variable
    -- Ensure ns.DeathClipsTabSettings is available. If it's loaded with DeathClipsTabs.lua and ns is shared, it should be.
    if not ns.DeathClipsTabSettings then
        if ns.debug then print(addonName .. ": ns.DeathClipsTabSettings not found in UpdateLayout.") end
        return
    end
    local activeTabConfig = ns.DeathClipsTabSettings[activeTabKey]

    if not activeTabConfig or not activeTabConfig.columns then
        if ns.debug then print("Error: No tab configuration or columns found for key: " .. activeTabKey .. " in UpdateLayout (DeathClipsUI.lua)") end
        return
    end

    local button = _G[buttonName] -- The main button for the row, though not directly used for anchoring children in this loop
    if not button then
        if ns.debug then print("Error: Button " .. buttonName .. " not found in UpdateLayout.") end
        return
    end

    -- Start anchoring data relative to the item icon. The item icon itself is usually anchored to the button's left.
    local itemIcon = _G[buttonName .. "Item"]
    if not itemIcon then
        if ns.debug then print("Error: Item icon for " .. buttonName .. " not found.") end
        return -- Cannot proceed without the initial anchor
    end
    local previousVisibleFs = itemIcon
    local initialXOffset = 5 -- Default X offset from the Item icon's RIGHT to the first data FS's LEFT

    -- First, hide all FontStrings that are part of the configurable layout to ensure a clean state
    -- This prevents FontStrings from a previous tab's layout from remaining visible if not used in the current one.
    for _, columnConfigCheck in ipairs(ns.DeathClipsTabSettings["LIVE_CLIPS"].columns) do -- Iterate one config to get all possible FS names
        if columnConfigCheck.fontStringName then
            local fsNameToHide = _G[buttonName .. columnConfigCheck.fontStringName]
            if fsNameToHide then fsNameToHide:Hide() end
        end
    end
    for _, columnConfigCheck in ipairs(ns.DeathClipsTabSettings["COMPLETED_CLIPS"].columns) do -- Iterate other config too
        if columnConfigCheck.fontStringName then
            local fsNameToHide = _G[buttonName .. columnConfigCheck.fontStringName]
            if fsNameToHide then fsNameToHide:Hide() end
        end
    end


    for _, columnConfig in ipairs(activeTabConfig.columns) do
        if columnConfig.fontStringName then -- Ensure there's a font string to manage
            local fs = _G[buttonName .. columnConfig.fontStringName]
            if fs then
                if columnConfig.visible then
                    fs:Show()
                    -- For the "Clip" frame, baseWidth applies to the container. Its internal elements are set in UpdateClipEntry.
                    fs:SetWidth(columnConfig.baseWidth)

                    if columnConfig.fontObject then
                        local font = _G[columnConfig.fontObject] or columnConfig.fontObject -- Check global first, then direct
                        if font then
                            -- Check if fs is a FontString or a Frame. SetFontObject is for FontStrings.
                            -- The "Clip" element is a Frame. Its children FontStrings (ClipText, ClipMobLevel) get fonts in UpdateClipEntry.
                            if type(fs.SetFontObject) == "function" then
                                fs:SetFontObject(font)
                            end
                        elseif ns.debug then
                            print("Warning: Font object not found: " .. columnConfig.fontObject)
                        end
                    end

                    if columnConfig.justifyH then
                        if type(fs.SetJustifyH) == "function" then -- Only FontStrings have SetJustifyH
                            fs:SetJustifyH(columnConfig.justifyH)
                        end
                    end

                    fs:ClearAllPoints()
                    local xOffset = columnConfig.dataRowXOffset or 2 -- Default gap if no specific offset provided in config

                    if previousVisibleFs == itemIcon then
                        -- First data FontString after the item icon. Anchor its LEFT to itemIcon's RIGHT.
                        fs:SetPoint("LEFT", previousVisibleFs, "RIGHT", initialXOffset, 0)
                    else
                        -- Subsequent FontStrings. Anchor its LEFT to previousVisibleFs's RIGHT.
                        fs:SetPoint("LEFT", previousVisibleFs, "RIGHT", xOffset, 0)
                    end
                    previousVisibleFs = fs
                else
                    fs:Hide()
                end
            elseif ns.debug then
                print("Warning: FontString or Frame not found: " .. buttonName .. columnConfig.fontStringName)
            end
        elseif ns.debug then
            -- This case might be okay if a column is purely for header and has no corresponding data row element.
            -- print("Debug: No fontStringName for column ID: " .. columnConfig.id .. " in UpdateLayout.")
        end
    end
end
ns.ApplyClipLayout = UpdateLayout

UpdateClipEntry = function(state, i, offset, elements, clip, ratingsFromParent, numBatchClips, totalClips, forceFullUpdate)
    -- 'clip' is the newClipData for this row
    -- 'ratingsFromParent' is the pre-fetched ratings for this specific clip.id, passed from OFAuctionFrameDeathClips_Update
    -- However, your original code called state:GetRatingsByClip() and then ns.GetTopReactions(clip.id, 1) inside here.
    -- Let's stick to calling ns.GetTopReactions directly if that's how it was.

    local button = elements.button
    local ratingFrame = elements.rating -- Get from cached elements

    -- Only update static fields if the clip displayed by this button changes, or if a full update is forced
    if button.displayedClipID ~= clip.id or forceFullUpdate then
        button.displayedClipID = clip.id
        ResizeEntry(button, #OFAuctionFrameDeathClips.currentDisplayableClips, #OFAuctionFrameDeathClips.currentDisplayableClips)

        local activeTabKey = ns.currentActiveTabId
        if not ns.DeathClipsTabSettings or not ns.DeathClipsTabSettings[activeTabKey] or not ns.DeathClipsTabSettings[activeTabKey].columns then
            if ns.debug then print("UpdateClipEntry: Tab settings not found for " .. activeTabKey) end
            return -- Can't proceed without column visibility info
        end
        local activeTabConfig = ns.DeathClipsTabSettings[activeTabKey]

        local columnVisibility = {}
        for _, colCfg in ipairs(activeTabConfig.columns) do
            if colCfg.fontStringName then -- Use fontStringName as key as it matches element names
                columnVisibility[colCfg.fontStringName] = colCfg.visible
            end
        end

        local nameFS = elements.name
        local raceFS = elements.raceText
        local levelFS = elements.level
        local classFS = elements.classText
        local whereFS = elements.whereText
        local clipTextFS = elements.clipText
        local mobLevelFS = elements.clipMobLevel
        local oldLevelFS = elements.oldLevelText -- New element
        local oldClassFS = elements.oldClassText -- New element
        local iconTexture = elements.itemIconTexture

        -- Determine which level and class to use based on reincarnated status
        local displayLevel = clip.isReincarnated and clip.newLevel or clip.level
        local displayClassToken = clip.isReincarnated and clip.newClassToken or clip.class -- For icon and name color
        local actualLevelForColor = displayLevel or 1 -- Fallback for GetQuestDifficultyColor

        -- ===== CLASS ICON =====
        local newTexture = "Interface\\Icons\\INV_Misc_QuestionMark"
        local newCoords = { 0, 1, 0, 1 }
        if displayClassToken and CLASS_ICON_TCOORDS[displayClassToken] then
            newTexture = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
            newCoords = CLASS_ICON_TCOORDS[displayClassToken]
        elseif clip.class and CLASS_ICON_TCOORDS[clip.class] then -- Fallback to original class if new one is not there
            newTexture = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
            newCoords = CLASS_ICON_TCOORDS[clip.class]
        end
        if iconTexture:GetTexture() ~= newTexture then
            iconTexture:SetTexture(newTexture)
        end
        iconTexture:SetTexCoord(unpack(newCoords))

        -- ===== NAME =====
        if columnVisibility["Name"] then
            local newNameText = clip.characterName or L["Unknown"]
            if nameFS:GetText() ~= newNameText then
                nameFS:SetText(newNameText)
            end
            local classColor = RAID_CLASS_COLORS[displayClassToken] or RAID_CLASS_COLORS[clip.class] or { r = .85, g = .85, b = .85 }
            local curR, curG, curB = nameFS:GetTextColor()
            if curR ~= classColor.r or curG ~= classColor.g or curB ~= classColor.b then
                nameFS:SetTextColor(classColor.r, classColor.g, classColor.b)
            end
        end

        -- ===== LEVEL (Current Level) =====
        if columnVisibility["Level"] then
            if actualLevelForColor == 0 then
                levelFS:SetText("-")
                levelFS:SetTextColor(0.5, 0.5, 0.5, 0.8) -- Grey color for hyphen, slightly more visible
            else
                local q = GetQuestDifficultyColor(actualLevelForColor)
                levelFS:SetFormattedText("|cff%02x%02x%02x%d|r", q.r * 255, q.g * 255, q.b * 255, actualLevelForColor)
            end
        end

        -- ===== OLD LEVEL =====
        if oldLevelFS then
            if columnVisibility["OldLevelText"] then
                oldLevelFS:Show()
                if clip.isReincarnated then
                    local actualOldLevel = clip.oldLevel or 1 -- Fallback to 1 if oldLevel is nil
                    local q = GetQuestDifficultyColor(actualOldLevel) -- Use the level, not the font string
                    oldLevelFS:SetFormattedText("|cff%02x%02x%02x%d|r", q.r * 255, q.g * 255, q.b * 255, actualOldLevel)
                    --oldLevelFS:SetText(clip.oldLevel or "?")
                else
                    oldLevelFS:SetText("")
                end
            else
                oldLevelFS:Hide()
                oldLevelFS:SetText("")
            end
        end

        -- ===== OLD CLASS =====
        if oldClassFS then
            if columnVisibility["OldClassText"] then
                oldClassFS:Show()
                if clip.isReincarnated then
                    local oldClassToken = clip.oldClassToken
                    local oldClassLocalizedName = ""
                    if oldClassToken then
                        -- Assuming oldClassToken might be localized from GetFriendInfo or an English token
                        -- If it's English, LOCALIZED_CLASS_NAMES_MALE will work. If it's already localized, this might be redundant or handled by fallback.
                        oldClassLocalizedName = LOCALIZED_CLASS_NAMES_MALE[string.upper(oldClassToken)] or oldClassToken
                    end

                    local coloredOldClassText = oldClassLocalizedName
                    if oldClassToken and RAID_CLASS_COLORS[string.upper(oldClassToken)] then
                        local color = RAID_CLASS_COLORS[string.upper(oldClassToken)]
                        coloredOldClassText = string.format("|cff%02x%02x%02x%s|r", color.r*255, color.g*255, color.b*255, oldClassLocalizedName)
                    elseif oldClassLocalizedName == "" then
                        coloredOldClassText = "|cffaaaaaaN/A|r"
                    end
                    oldClassFS:SetText(coloredOldClassText)
                else
                    oldClassFS:SetText("")
                end
            else
                oldClassFS:Hide()
                oldClassFS:SetText("")
            end
        end

        -- ===== WHERE =====
        if columnVisibility["WhereText"] then
            if ns.currentActiveTabId == "SPEED_CLIPS" and clip.playedTime and clip.level then
                -- For speed tab, show rank instead of zone
                whereFS:SetJustifyH("CENTER")
                if whereFS:GetFontObject() ~= GameFontNormalLarge then
                    whereFS:SetFontObject("GameFontNormalLarge")
                end
                local r, g, b, median, p25, p75, rank, count = ns.GetPlayedTimeColor(clip.playedTime, clip.level)
                if rank then
                    whereFS:SetText(tostring(rank))
                    whereFS:SetTextColor(r, g, b)
                    -- Debug logging
                    if ns.debug then
                        print(string.format("SPEED_CLIPS: Setting rank for %s: rank=%s, playedTime=%s",
                            clip.characterName or "unknown", tostring(rank), tostring(clip.playedTime)))
                    end
                else
                    whereFS:SetText("-")
                    whereFS:SetTextColor(0.5, 0.5, 0.5)
                end
                -- Debug check after setting
                if ns.debug then
                    print(string.format("SPEED_CLIPS whereFS after update: %s", whereFS:GetText() or "nil"))
                end
            else
                -- Reset to normal font and left alignment for other tabs
                whereFS:SetJustifyH("LEFT")
                if whereFS:GetFontObject() ~= GameFontHighlight then
                    whereFS:SetFontObject("GameFontHighlight")
                end
                local zone = clip.mapId and C_Map.GetMapInfo(clip.mapId).name or clip.where or L["Unknown"]
                if zone == "Полуостров Адского Пламени" then
                    zone = "Полуостров\nАдского Пламени"
                end
                if whereFS:GetText() ~= zone then
                    whereFS:SetText(zone)
                end
                whereFS:SetTextColor(1, 0.82, 0)  -- Reset to gold color for other tabs.
            end
        end

        -- ===== CAUSE / MOB LEVEL / COMPLETED TIMER (Clip Text) =====
        -- All these use clipTextFS and mobLevelFS, controlled by the visibility of the "Clip" (CLIP_INFO column)
        if columnVisibility["Clip"] then
            local causeId = clip.causeCode or 0
            local newClipDisplayText = ""
            local newMobLevelText = ""
            local mr, mg, mb

            if ns.currentActiveTabId == "SPEED_CLIPS" and clip.playedTime then
                -- For speed tab, show played time with color coding
                if clipTextFS:GetFontObject() ~= GameFontNormalLarge then clipTextFS:SetFontObject("GameFontNormalLarge") end
                local s = ns.GetCurrentPlayedTime and ns.GetCurrentPlayedTime(clip) or clip.playedTime
                local r, g, b = ns.GetPlayedTimeColor(s, clip.level)
                newClipDisplayText = string.format("|cFF%02X%02X%02X%dд %dч %dм %dс|r",
                        r * 255, g * 255, b * 255,
                        math.floor(s / 86400), math.floor(s % 86400 / 3600),
                        math.floor(s % 3600 / 60), s % 60)
                newMobLevelText = "" -- No mob level for speed tab
            elseif clip.isReincarnated then
                -- For reincarnated, always show original death cause
                if clipTextFS:GetFontObject() ~= GameFontNormal then clipTextFS:SetFontObject("GameFontNormal") end

                if clip.causeCode == nil then -- No original death info for reincarnated
                    newClipDisplayText = "|cffaaaaaaN/A|r"
                    newMobLevelText = ""
                    mobLevelFS:SetTextColor(0.7,0.7,0.7,1) -- Light gray for N/A
                elseif causeId == 7 and clip.deathCause and clip.deathCause ~= "" then -- Monster kill
                    local mobLvl = clip.mobLevel or 0
                    local playerLvl = clip.oldLevel or 1 -- Use oldLevel for color calculation against mob
                    local diff = mobLvl - playerLvl
                    mr, mg, mb = 0, 1, 0
                    if diff >= 4 then mr, mg, mb = 1, 0, 0
                    elseif diff >= 2 then mr, mg, mb = 1, .5, 0
                    elseif diff >= -1 then mr, mg, mb = 1, 1, 0
                    elseif diff >= -4 then mr, mg, mb = 0, 1, 0
                    else mr, mg, mb = .5, .5, .5 end
                    newClipDisplayText = string.format("|cFF%02X%02X%02X%s|r", mr * 255, mg * 255, mb * 255, clip.deathCause)
                    newMobLevelText = tostring(mobLvl)
                    mobLevelFS:SetTextColor(mr, mg, mb, 200 / 255)
                else -- Other known death causes (environmental, etc.)
                    newClipDisplayText = "|cFFFFFFFF" .. (ns.DeathCauseByID[causeId] or "Неизвестно") .. "|r"
                    newMobLevelText = ""
                    mobLevelFS:SetTextColor(1,1,1,1)
                end
            elseif clip.completed then -- Standard completed clips (not reincarnated)
                if clipTextFS:GetFontObject() ~= GameFontNormalLarge then clipTextFS:SetFontObject("GameFontNormalLarge") end
                if clip.playedTime then
                    local s = clip.playedTime
                    newClipDisplayText = string.format("%dд %dч %dм %dс",
                            math.floor(s / 86400), math.floor(s % 86400 / 3600),
                            math.floor(s % 3600 / 60), s % 60)
                else
                    newClipDisplayText = "Грузится"
                end
                newMobLevelText = "" -- No mob level for completed
            else -- Standard live clips (not reincarnated, not completed)
                if clipTextFS:GetFontObject() ~= GameFontNormal then clipTextFS:SetFontObject("GameFontNormal") end
                if causeId == 7 and clip.deathCause and clip.deathCause ~= "" then
                    local mobLvl = clip.mobLevel or 0
                    local playerLvl = displayLevel or 1 -- Use current display level
                    local diff = mobLvl - playerLvl
                    mr, mg, mb = 0, 1, 0
                    if diff >= 4 then mr, mg, mb = 1, 0, 0
                    elseif diff >= 2 then mr, mg, mb = 1, .5, 0
                    elseif diff >= -1 then mr, mg, mb = 1, 1, 0
                    elseif diff >= -4 then mr, mg, mb = 0, 1, 0
                    else mr, mg, mb = .5, .5, .5 end
                    newClipDisplayText = string.format("|cFF%02X%02X%02X%s|r", mr * 255, mg * 255, mb * 255, clip.deathCause)
                    newMobLevelText = tostring(mobLvl)
                    mobLevelFS:SetTextColor(mr, mg, mb, 200 / 255)
                else
                    newClipDisplayText = "|cFFFFFFFF" .. (ns.DeathCauseByID[causeId] or "Неизвестно") .. "|r"
                    newMobLevelText = ""
                    mobLevelFS:SetTextColor(1,1,1,1)
                end
            end

            if clipTextFS:GetText() ~= newClipDisplayText then clipTextFS:SetText(newClipDisplayText) end
            if mobLevelFS:GetText() ~= newMobLevelText then mobLevelFS:SetText(newMobLevelText) end
            mobLevelFS:SetJustifyH("CENTER") -- Always justify if it's part of the Clip column
        end

        -- ===== CLASS TEXT =====
        if columnVisibility["ClassText"] then
            local key = clip.class and string.upper(clip.class) or "UNKNOWN"
            local newClassText = LOCALIZED_CLASS_NAMES_MALE[key] or clip.class or L["Unknown"]
            if GetLocale() == "ruRU" and ns.currentActiveTabId == "LIVE_CLIPS" then
                if key == "WARLOCK" then newClassText = "Варлок"
                elseif key == "ROGUE" then newClassText = "Разбойник" end
            end
            if classFS:GetText() ~= newClassText then
                classFS:SetText(newClassText)
            end
            -- Use displayClassToken (which is based on newClassToken/currentEnglishClassToken for reincarnated) for color consistency
            local cc = RAID_CLASS_COLORS[displayClassToken] or RAID_CLASS_COLORS[clip.class] or { r = 1, g = 1, b = 1 }
            local curCCR, curCCG, curCCB = classFS:GetTextColor()
            if curCCR ~= cc.r or curCCG ~= cc.g or curCCB ~= cc.b then
                classFS:SetTextColor(cc.r, cc.g, cc.b)
            end
        end

        -- ===== RACE =====
        if columnVisibility["RaceText"] then
            local newRaceText = clip.race or L["Unknown"]
            if GetLocale() == "ruRU" and ns.currentActiveTabId == "COMPLETED_CLIPS" then
                if newRaceText == "Ночноро\nждённый" then newRaceText = "Ночнорождённый"
                elseif newRaceText == "Озар. дреней" then newRaceText = "Озарённый дреней"
                elseif newRaceText == "Дворф Ч. Железа" then newRaceText = "Дворф Чёрного Железа" end
            end
            if raceFS:GetText() ~= newRaceText then
                raceFS:SetText(newRaceText)
            end
            local rF, gF, bF = 0.9, 0.9, 0.4
            if clip.faction == "Horde" then rF, gF, bF = 0.8, 0.3, 0.3
            elseif clip.faction == "Alliance" then rF, gF, bF = 0.4, 0.6, 1 end
            local curRF, curGF, curBF = raceFS:GetTextColor()
            if curRF ~= rF or curGF ~= gF or curBF ~= bF then
                raceFS:SetTextColor(rF, gF, bF)
            end
        end

        -- Note: WhenText is updated by a separate ticker in OFAuctionFrameDeathClips_OnShow for live updates
        -- So, it's not managed here for visibility of its data content.
        -- Its layout (position) is handled by UpdateLayout.
        -- However, for initial setup, especially for reincarnated view where ts might be nil:
        if columnVisibility["WhenText"] then
            local whenFS = elements.whenText
            if clip.isReincarnated then
                -- For reincarnated friends, show last activity time if available
                if clip.lastActivityTimestamp and clip.lastActivityTimestamp > 0 then
                    local activityText = FormatLastActivityTime(clip.lastActivityTimestamp, clip.isOnline)
                    if activityText == "__ONLINE_DOT__" then
                        ShowOnlineDot(whenFS)
                    else
                        HideOnlineDot(whenFS)
                        local r, g, b = GetLastActivityColor(clip.lastActivityTimestamp, clip.isOnline)
                        whenFS:SetText(activityText)
                        whenFS:SetTextColor(r, g, b, 0.8)
                    end
                elseif clip.isOnline then
                    -- Player is online but no activity timestamp
                    ShowOnlineDot(whenFS)
                else
                    HideOnlineDot(whenFS)
                    whenFS:SetText("-") -- No activity data available
                    whenFS:SetTextColor(0.6, 0.6, 0.6, 0.8)
                end
            elseif ns.currentActiveTabId == "SPEED_CLIPS" and clip.isOnline then
                -- Для живых онлайн игроков на вкладке "Скорость" показываем зелёную точку
                ShowOnlineDot(whenFS)
            elseif clip.ts == nil then
                HideOnlineDot(whenFS) -- Make sure dot is hidden for non-reincarnated clips
                whenFS:SetText("|cffaaaaaaN/A|r") -- Or L["Unknown"] if preferred, styled
                whenFS:SetTextColor(0.6, 0.6, 0.6, 0.8) -- Match the color of other N/A text
            else
                HideOnlineDot(whenFS) -- Make sure dot is hidden for regular clips
                -- Let the hook handle formatting for valid timestamps,
                -- but ensure it's not empty if the hook hasn't run yet for this specific row update.
                if whenFS:GetText() == "" then -- Only if not already set by hook
                    whenFS:SetText(formatWhen(clip))
                end
                -- Color will be set by the hook based on playedTime/level or default if ts is valid.
                -- If ts was nil, we set a specific color above.
            end
        end

    end -- END of "if button.displayedClipID ~= clip.id or forceFullUpdate then"

    -- ===== RATING WIDGET =====
    -- This part should ALWAYS run to reflect potential live updates to ratings,
    -- or to clear ratings if the clip is no longer valid or has no ratings.
    if ratingFrame and ratingFrame.SetReactions then
        if clip and clip.id then
            -- Make sure 'clip' itself is valid and has an id
            -- Get fresh reaction data for this clip
            local currentReactions = ns.GetTopReactions(clip.id, 1)
            ratingFrame:SetReactions(currentReactions)
            -- Debug print:
            -- if currentReactions and #currentReactions > 0 then
            --     print(string.format("DEBUG: Clip %s, Reaction ID: %s, Count: %s", clip.id, currentReactions[1].id, currentReactions[1].count))
            -- elseif clip and clip.id then
            --     print(string.format("DEBUG: Clip %s, No reactions found by GetTopReactions", clip.id))
            -- end
        else
            -- If clip is nil or has no id (e.g. an empty row being processed, though Update should hide button)
            -- Ensure the rating is cleared.
            -- Your ratingFrame:SetReactions(nil) should handle this gracefully.
            ratingFrame:SetReactions(nil)
            -- Or, if SetReactions(nil) doesn't explicitly clear:
            -- if ratingFrame.label and ratingFrame.label:GetText() ~= "" then ratingFrame.label:SetText("") end
            -- if ratingFrame.reactionIcon and ratingFrame.reactionIcon:IsShown() then ratingFrame.reactionIcon:Hide() end
            -- if ratingFrame.reactionCount and ratingFrame.reactionCount:IsShown() then ratingFrame.reactionCount:Hide() end
            -- print(string.format("DEBUG: No valid clip or clip.id for rating widget. Clip ID: %s", tostring(clip and clip.id)))
        end
    end

    -- ===== ХАЙЛАЙТ =====
    if OFAuctionFrameDeathClips.openedPromptClipID == clip.id then
        button:LockHighlight()
    else
        button:UnlockHighlight()
    end
end

local function FilterHiddenClips(state, clips)
    return clips   -- overrides больше нет → ничего не скрываем
end

-- OFAuctionFrameDeathClips_Update
-- Updates clip entries based on which tab is active
function OFAuctionFrameDeathClips_Update()
    local frame = OFAuctionFrameDeathClips
    local state = ns.GetDeathClipReviewState()
    local ratingsByClip = state:GetRatingsByClip()

    -- Check if sort parameters or tab changed to trigger data refresh
    local currentSortType, currentSortKey, currentSortAscending = OFGetCurrentSortParams("clips")
    if frame.lastSortKey ~= currentSortKey or frame.lastSortAscending ~= currentSortAscending or frame.lastSubTab ~= frame.currentSubTab then
        frame.needsDataRefresh = true
        frame.lastSortKey = currentSortKey
        frame.lastSortAscending = currentSortAscending
        frame.lastSubTab = frame.currentSubTab
    end

    local forceFullRowUpdate = false
    if frame.needsDataRefresh then
        local rawPool = ns.GetLiveDeathClips()
        local pool = ns.FilterClipsThisRealm(rawPool)
        local tempClips = {}

        if ns.currentActiveTabId == "REINCARNATED_CLIPS" then
            local reincarnatedFriendsData = ns.GetReincarnatedFriendsDisplayList and ns.GetReincarnatedFriendsDisplayList()
            if not reincarnatedFriendsData then reincarnatedFriendsData = {} end

            for _, friendData in ipairs(reincarnatedFriendsData) do
                local displayClip = {
                    -- Core identity and current state
                    characterName = friendData.characterName,
                    id = friendData.characterName .. "_reincarnated", -- Unique key
                    isReincarnated = true,
                    isOnline = friendData.isOnline, -- Add online status for formatting

                    -- Levels
                    level = friendData.actualLevel,  -- Current actual level, used for sorting by "Level"
                    newLevel = friendData.actualLevel, -- Current actual level, for "New Level" display logic
                    oldLevel = friendData.clipLevel,   -- Original clip level, for "Old Level" display

                    -- Class information
                    class = friendData.localizedClassName,       -- Current localized class name for display in "Class" column
                    newClassToken = friendData.currentEnglishClassToken, -- Current English class token for icon/color
                    oldClassToken = friendData.originalEnglishClassToken, -- Original English class token from original clip

                    -- Location
                    where = friendData.zone, -- Current zone if online, or last known. Potentially original zone if needed.
                    -- ns.GetReincarnatedFriendsDisplayList provides 'zone = areaFromFunc' (current zone)
                    -- If originalMapId is preferred for 'where', this needs adjustment or use friendData.originalMapId.
                    -- For now, using friendData.zone (current zone) is consistent with the structure.

                    -- Timestamp for "When" column sorting and display - NOW USE LAST ACTIVITY TIME
                    ts = friendData.lastActivityTimestamp, -- Use last activity time instead of original death time
                    lastActivityTimestamp = friendData.lastActivityTimestamp, -- Keep separate field for reference

                    -- Data from original death clip (or nil if not found)
                    deathCause = friendData.originalDeathCause,
                    causeCode = friendData.originalCauseCode,
                    mobLevel = friendData.originalMobLevel,
                    mapId = friendData.originalMapId,
                    faction = friendData.originalFaction,
                    originalTimestamp = friendData.originalTimestamp -- Keep original death time for reference
                    -- Note: `race` is not explicitly in friendData, `UpdateClipEntry` uses `clip.race` which would be nil here.
                    -- If `originalRace` is needed, it should be added to `friendData` from `originalClip.race`.
                    -- For now, `clip.race` will be nil for reincarnated, and `UpdateClipEntry` handles nil `clip.race`.
                }
                table.insert(tempClips, displayClip)
            end
        elseif ns.currentActiveTabId == "COMPLETED_CLIPS" then
            -- tempClips is already initialized
            if pool then -- Check if pool is not nil (it's already realm-filtered)
                for _, clip in ipairs(pool) do -- Iterate 'pool'
                    if clip.completed then
                        table.insert(tempClips, clip)
                    end
                end
            end
        elseif ns.currentActiveTabId == "SPEED_CLIPS" then
            -- Speed ranking for living players (ALIVE only)
            for _, clip in ipairs(pool) do
                if clip.playedTime and not clip.completed and clip.deathCause == "ALIVE" then
                    -- Check if current player opted out and skip their own clips
                    local currentPlayer = UnitName("player")
                    local shouldIncludeClip = true
                    
                    if clip.characterName == currentPlayer then
                        local participateInSpeedClips = ns.PlayerPrefs:Get("participateInSpeedClips")
                        if participateInSpeedClips == false then
                            shouldIncludeClip = false
                        end
                    end
                    
                    if shouldIncludeClip then
                        -- Обновляем онлайн-статус, уровень и зону из гильд-ростера
                        local memberData = ns.GuildRegister and ns.GuildRegister.GetMemberData and ns.GuildRegister:GetMemberData(clip.characterName)
                        if memberData and memberData.isOnline then
                            clip.isOnline = true
                            clip.level = memberData.level or clip.level
                            clip.where = memberData.zone or clip.where
                        else
                            clip.isOnline = false
                        end
                        table.insert(tempClips, clip)
                    end
                end
            end
        else -- Default to "LIVE_CLIPS" - exclude living players
            for _, clip in ipairs(pool) do -- 'pool' here is already non-completed clips
                -- Only show dead players (exclude ALIVE status from death clips tab)
                if not clip.completed and clip.deathCause ~= "ALIVE" then
                    table.insert(tempClips, clip)
                end
            end
        end

        -- Sorting should occur *after* tempClips is populated for the specific tab
        -- local _, sortKey, sortAscending = OFGetCurrentSortParams("clips") -- Already declared above in the function
        tempClips = ns.SortDeathClips(tempClips, OFGetCurrentSortParams("clips"))

        frame.currentDisplayableClips = tempClips
        frame.needsDataRefresh = false
        forceFullRowUpdate = true
    end

    local clipsToDisplay = frame.currentDisplayableClips
    local totalClips = #clipsToDisplay
    local offset = FauxScrollFrame_GetOffset(OFDeathClipsScroll)

    updateSortArrows()

    local numActuallyDisplayed = 0
    for i = 1, NUM_CLIPS_TO_DISPLAY do
        local buttonElements = ns.clipButtonElements[i]
        local button = buttonElements.button
        local dataIdx = offset + i
        local clip = clipsToDisplay[dataIdx]

        if not clip then
            button:Hide()
            button.displayedClipID = nil
        else
            numActuallyDisplayed = numActuallyDisplayed + 1
            button:Show()
            button.clipData = clip

            local ratings = (clip.id and ratingsByClip[clip.id]) or {}
            ns.TryExcept(
                    function()
                        UpdateClipEntry(state, i, offset, buttonElements, clip, ratings, totalClips, totalClips, forceFullRowUpdate)
                    end,
                    function(err)
                        button:Hide()
                        ns.DebugLog("Error updating clip entry: " .. err)
                    end
            )
        end
    end

    -- Pagination and Scrollbar Update
    -- This call is still necessary for the FauxScrollFrame's internal offset management
    FauxScrollFrame_Update(OFDeathClipsScroll, totalClips, NUM_CLIPS_TO_DISPLAY, CLIPS_BUTTON_HEIGHT)


    -- Logic for pagination buttons visibility and state (remains the same)
    local prevButton = _G["OFDeathClipsPrevPageButton"]
    local nextButton = _G["OFDeathClipsNextPageButton"]
    local searchCountText = _G["OFDeathClipsSearchCountText"]

    if totalClips > NUM_CLIPS_TO_DISPLAY then
        if prevButton then
            prevButton:Show()
            prevButton:SetEnabled(offset > 0)
        end
        if nextButton then
            nextButton:Show()
            nextButton:SetEnabled(offset + NUM_CLIPS_TO_DISPLAY < totalClips)
        end

        if searchCountText then
            searchCountText:Show()
            local itemsMin = offset + 1
            local itemsMax = offset + numActuallyDisplayed
            if itemsMax < itemsMin and totalClips > 0 then itemsMax = itemsMin end
            if totalClips == 0 then itemsMin = 0; itemsMax = 0; end
            searchCountText:SetFormattedText(NUMBER_OF_RESULTS_TEMPLATE, itemsMin, itemsMax, totalClips)
        end
    else
        if prevButton then prevButton:Hide() end
        if nextButton then nextButton:Hide() end
        if searchCountText then searchCountText:Hide() end
    end
    local nav = _G["OFDeathClipsNavFrame"]
    if nav and nav.pageLabel then
        local totalPages = math.max(1, math.ceil(totalClips / NUM_CLIPS_TO_DISPLAY) - 1)
        local offset = FauxScrollFrame_GetOffset(OFDeathClipsScroll)
        if offset == 0 then
            nav.pageLabel:SetText("Навигация")
            nav.pageLabel:SetAlpha(0.8)
        else
            local currentPage = math.floor(offset / NUM_CLIPS_TO_DISPLAY) + 1
            nav.pageLabel:SetText(currentPage .. " / " .. totalPages)
            nav.pageLabel:SetAlpha(0.9)
        end
    end

    -- Update visibility of the cleanup button
    local cleanupButton = OFAuctionFrameDeathClips.cleanupButton or _G["OFDeathClipsCleanupButton"]
    if cleanupButton then
        if OFAuctionFrameDeathClips:IsShown() and ns.currentActiveTabId == "REINCARNATED_CLIPS" then
            cleanupButton:Show()
        else
            cleanupButton:Hide()
        end
    end

end

function OFDeathClipsRatingWidget_OnLoad(self)
    -- Create single large icon texture
    local icon = self:CreateTexture(nil, "ARTWORK")
    icon:SetSize(40, 26)
    icon:SetPoint("LEFT", self, "LEFT", 0, 0)
    icon:SetTexCoord(0.1, 0.9, 0.34, 0.74)
    icon:SetTexture("Interface\\AddOns\\GoAgainAH\\Media\\minus.tga")
    icon:Show()

    -- Create count text overlaid on icon
    local count = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    count:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    count:SetTextColor(1, 1, 1, 0.6, 0.8)
    count:Hide()

    -- Store references
    self.reactionIcon = icon
    self.reactionCount = count

    -- Assign SetReactions function
    function self:SetReactions(data)
        local paths = {
            [1] = "Interface\\AddOns\\GoAgainAH\\Media\\smiley_64x64.tga",
            [2] = "Interface\\AddOns\\GoAgainAH\\Media\\eyes_64x64.tga",
            [3] = "Interface\\AddOns\\GoAgainAH\\Media\\clown_64x64.tga",
            [4] = "Interface\\AddOns\\GoAgainAH\\Media\\fire_64x64.tga",
        }

        if data and data[1] then
            local id = data[1].id
            local path = paths[id]
            local countValue = data[1].count

            -- Defaults
            icon:SetSize(40, 26)
            icon:SetVertexColor(0.5, 0.5, 0.5, 0.8)
            icon:SetTexCoord(0.1, 0.9, 0.24, 0.78)
            count:ClearAllPoints()
            count:SetPoint("TOPLEFT", icon, "BOTTOMRIGHT", -3, 6)
            icon:ClearAllPoints()
            icon:SetPoint("LEFT", self, "LEFT", 0, 0)



            if id == 2 then
                icon:SetSize(40, 36)
                icon:SetTexCoord(0, 1, 0.05, 0.95) -- немного больше
                icon:SetPoint("LEFT", self, "LEFT", 0, -1)
                count:SetPoint("TOPLEFT", icon, "BOTTOMRIGHT", -3, 12)
            elseif id == 3 then
                icon:SetTexCoord(0.1, 0.9, 0.30, 0.72)
            elseif id == 4 then
                icon:SetTexCoord(0.1, 0.9, 0.12, 0.66)
                icon:SetVertexColor(0.5, 0.5, 0.5, 1)

            elseif id == 1 then
                icon:SetSize(40, 24)
                icon:SetVertexColor(0.5, 0.5, 0.5, 0.9)
                icon:SetTexCoord(0.05, 0.95, 0.2644, 0.8044)
            end

            icon:SetTexture(path)
            icon:Show()

            count:SetText(countValue)
            if countValue > 9 then
                count:Show()
            else
                count:Hide()
            end
        else
            icon:SetTexture("Interface\\AddOns\\GoAgainAH\\Media\\minus_final_32x8.tga")
            icon:SetSize(32, 8)
            icon:SetTexCoord(0, 1, 0, 1)
            icon:SetVertexColor(1, 1, 1, 0.1)
            icon:ClearAllPoints()
            icon:SetPoint("LEFT", self, "LEFT", 5, 0)
            icon:Show()
            count:Hide()
        end
    end
end


function OFAuctionFrameDeathClips_OnHide()
    if OFAuctionFrameDeathClips._whenUpdateTicker then
        OFAuctionFrameDeathClips._whenUpdateTicker:Cancel()
        OFAuctionFrameDeathClips._whenUpdateTicker = nil
    end
    if ns.HideAllClipPrompts then
        ns.HideAllClipPrompts()
    end
end

-- Timestamp of the last opt-out broadcast to avoid chat spam
local _speedClipsLastBroadcastTs = 0

function OFDeathClips_UpdateSpeedClipsCheckbox()
    local checkbox = OFDeathClipsSpeedClipsCheckButton
    if not checkbox then return end
    
    -- Only show checkbox in Speed Clips tab
    if ns.currentActiveTabId == "SPEED_CLIPS" then
        checkbox:Show()
        local participateInSpeedClips = ns.PlayerPrefs:Get("participateInSpeedClips")
        if participateInSpeedClips == nil then 
            participateInSpeedClips = true -- default to true
        end
        checkbox:SetChecked(participateInSpeedClips and 1 or nil)
    else
        checkbox:Hide()
    end
end

function OFDeathClips_SpeedClips_OnClick(self)
    local isChecked = self:GetChecked() and true or false
    ns.PlayerPrefs:Set("participateInSpeedClips", isChecked)

    local playerName = UnitName("player")

    if not isChecked then
        if ns.RemovePlayerFromSpeedClips then
            ns.RemovePlayerFromSpeedClips(playerName)
        end

        if (time() - _speedClipsLastBroadcastTs) > 2 then
            ns.BlacklistAPI:AddToBlacklist(playerName, ns.BLACKLIST_TYPE_SPEED_CLIPS_REMOVAL, playerName)
            _speedClipsLastBroadcastTs = time()
            print("Запрос на удаление из Speed Clips отправлен другим игрокам.")
        end
    else
        ns.BlacklistAPI:RemoveFromBlacklist(playerName, ns.BLACKLIST_TYPE_SPEED_CLIPS_REMOVAL, playerName)
        
        -- Restore speed clips from archive for immediate display
        if ns.RestorePlayerSpeedClips then
            local restoredCount = ns.RestorePlayerSpeedClips(playerName)
            if restoredCount > 0 then
                print(string.format("Восстановлено %d Speed Clips", restoredCount))
            end
        else
            -- Fallback if restore function is not available
            if ns.SpeedClipsOptedOut then
                ns.SpeedClipsOptedOut[playerName] = nil
            end
            -- Request immediate played time sync when opting back in
            if UnitIsConnected("player") then
                if ns.SuppressTimePlayedMessages then ns.SuppressTimePlayedMessages() end
                RequestTimePlayed()
                C_Timer:After(1, function()
                    if ns.AllowTimePlayedMessages then ns.AllowTimePlayedMessages() end
                end)
            end
            -- Fire event to update UI immediately
            ns.AuctionHouseAPI:FireEvent(ns.EV_DEATH_CLIPS_CHANGED)
        end
    end
end
