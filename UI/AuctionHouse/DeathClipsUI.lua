local addonName, ns = ...
local L = ns.L

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

    -- click the “Live” sub-tab
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
end

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
            if clip and clip.ts then
                local whenFS = el.whenText
                whenFS:SetText(formatWhen(clip))
                if clip.playedTime and clip.level then
                    local r, g, b = ns.GetPlayedTimeColor(clip.playedTime, clip.level)
                    whenFS:SetTextColor(r, g, b, .7)
                else
                    whenFS:SetTextColor(.6, .6, .6, .5)
                end
            end
        end
    end)

    ns.AuctionHouseAPI:RegisterEvent(ns.EV_DEATH_CLIPS_CHANGED, function()
        OFAuctionFrameDeathClips.needsDataRefresh = true -- Mark data as needing refresh
        if OFAuctionFrame:IsShown() and OFAuctionFrameDeathClips:IsShown() then
            OFAuctionFrameDeathClips_Update()
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
                    --OFAuctionFrameDeathClips_Update() -- Update will be called by scroll or other events
                end
            end)
            sortHookApplied = true
        else
            ns.DebugLog(addonName .. ": Error - Could not find OFAuctionFrame_SetSort to hook.")
        end
    end

    -- Hook tab clicks to set needsDataRefresh
    -- Assuming OFDeathClipsTabLive and OFDeathClipsTabCompleted are global or accessible
    if OFDeathClipsTabLive then
        OFDeathClipsTabLive:HookScript("OnClick", function()
            if OFAuctionFrameDeathClips.currentSubTab ~= "live" then
                OFAuctionFrameDeathClips.currentSubTab = "live"
                OFAuctionFrameDeathClips.needsDataRefresh = true
                OFAuctionFrame_SetSort("clips", "when", false) -- Reset sort for live tab
                -- OFAuctionFrameDeathClips_Update() will be called by FauxScrollFrame or other mechanisms
            end
        end)
    end
    if OFDeathClipsTabCompleted then
        OFDeathClipsTabCompleted:HookScript("OnClick", function()
            if OFAuctionFrameDeathClips.currentSubTab ~= "completed" then
                OFAuctionFrameDeathClips.currentSubTab = "completed"
                OFAuctionFrameDeathClips.needsDataRefresh = true
                OFAuctionFrame_SetSort("clips", "clip", true) -- Reset sort for completed tab
                -- OFAuctionFrameDeathClips_Update()
            end
        end)
    end
    ---- Быстрое обновление колонки «Когда» при скролле, сортировке и смене вкладок
    --local function RefreshWhenColumn()
    --    for i = 1, NUM_CLIPS_TO_DISPLAY do
    --        local el = ns.clipButtonElements[i]
    --        local clip = el and el.button.clipData
    --        if clip and clip.ts then
    --            local whenFS = el.whenText
    --            whenFS:SetText(formatWhen(clip))
    --            if clip.playedTime and clip.level then
    --                local r,g,b = ns.GetPlayedTimeColor(clip.playedTime, clip.level)
    --                whenFS:SetTextColor(r, g, b, .7)
    --            else
    --                whenFS:SetTextColor(.6, .6, .6, .5)
    --            end
    --        end
    --    end
    --end

    ---- при скролле
    --OFDeathClipsScroll:HookScript("OnVerticalScroll", function(self, offset)
    --    RefreshWhenColumn()
    --end)
    --
    ---- сразу после сортировки
    --hooksecurefunc("OFAuctionFrame_SetSort", function(type, key, ascending)
    --    if type == "clips" then
    --        print("refresh")
    --        RefreshWhenColumn()
    --    end
    --end)
    --
    ---- при переключении подп вкладок (если они есть)
    --if OFDeathClipsTabLive and OFDeathClipsTabCompleted then
    --    OFDeathClipsTabLive:HookScript("OnClick", RefreshWhenColumn)
    --    OFDeathClipsTabCompleted:HookScript("OnClick", RefreshWhenColumn)
    --end

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

                if button and button:IsShown() and clip and clip.ts then
                    ------------------------------------------------------
                    -- 1) «Когда»
                    ------------------------------------------------------
                    local whenFS = el.whenText
                    whenFS:SetText(formatWhen(clip))

                    if clip.playedTime and clip.level then
                        local r, g, b = ns.GetPlayedTimeColor(clip.playedTime, clip.level)
                        whenFS:SetTextColor(r, g, b, .7)
                    else
                        whenFS:SetTextColor(.6, .6, .6, .5)
                    end

                    ------------------------------------------------------
                    -- 2) Подсветка новых клипов (меньше 60 с)
                    ------------------------------------------------------
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
        end)
    end

end

local function ResizeEntry(button, numBatchAuctions, totalAuctions)
    local buttonHighlight = _G[button:GetName() .. "Highlight"]
    if (numBatchAuctions < NUM_CLIPS_TO_DISPLAY) then
        button:SetWidth(793)
        buttonHighlight:SetWidth(758)
    elseif (numBatchAuctions == NUM_CLIPS_TO_DISPLAY and totalAuctions <= NUM_CLIPS_TO_DISPLAY) then
        button:SetWidth(793)
        buttonHighlight:SetWidth(758)
    else
        button:SetWidth(769)
        buttonHighlight:SetWidth(735)
    end
end

local function UpdateLayout(buttonName)
    -- Fetch elements for Name, Level, Clip, ClassText, WhereText, and RaceText
    local name = _G[buttonName .. "Name"]
    local level = _G[buttonName .. "Level"]
    local clipFrame = _G[buttonName .. "Clip"]
    local classText = _G[buttonName .. "ClassText"]
    local whereText = _G[buttonName .. "WhereText"]
    local raceText = _G[buttonName .. "RaceText"]
    -- Re-anchor WhenText to the right of RaceText
    local whenText = _G[buttonName .. "WhenText"]
    -- Re-anchor Rating frame to the right of WhenText
    local rating = _G[buttonName .. "Rating"]

    if ns.isCompletedTabActive then
        -- When completed tab is active, hide the level and expand the name
        level:Hide()
        name:SetWidth(name:GetWidth() + level:GetWidth())  -- Expand name to take up the space of level

        -- Re-anchor the clip to the right of name
        clipFrame:ClearAllPoints()
        clipFrame:SetPoint("LEFT", name, "RIGHT", -8, 0)  -- Position Clip immediately to the right of Name

        -- Hide WhereText and adjust ClassText and RaceText
        whereText:Hide()

        -- Get half the width of WhereText to distribute between ClassText and RaceText
        local whereWidth = whereText:GetWidth()
        local halfWhereWidth = whereWidth / 2

        -- Increase the width of ClassText and RaceText by half of WhereText's width
        classText:SetWidth(classText:GetWidth() + halfWhereWidth - 20)
        raceText:SetWidth(raceText:GetWidth() + halfWhereWidth - 20)

        -- Re-anchor the ClassText and RaceText to slide them to the right of Clip
        classText:ClearAllPoints()
        raceText:ClearAllPoints()

        -- Anchor ClassText immediately to the right of Clip
        classText:SetPoint("LEFT", clipFrame, "RIGHT", 15, 0)

        -- Anchor RaceText immediately to the right of ClassText
        raceText:SetPoint("LEFT", classText, "RIGHT", 2, 0)

        -- Set font for ClassText and RaceText in the live tab (fallback font)
        classText:SetFontObject("GameFontNormal")  -- Fallback font for live tab
        raceText:SetFontObject("GameFontNormal")   -- Fallback font for live tab
        classText:SetJustifyH("CENTER")
        raceText:SetJustifyH("CENTER")

        whenText:ClearAllPoints()
        whenText:SetPoint("LEFT", raceText, "RIGHT", 0, 0)
    else
        -- If live tab is active, show the level again and reset the name width
        level:Show()
        name:SetWidth(100)  -- Reset to original width (adjust if needed)

        -- Re-anchor the whereText to the right of level (was clipFrame before)
        whereText:ClearAllPoints()
        whereText:SetPoint("LEFT", level, "RIGHT", 2, 0)
        whereText:Show()

        -- Move the clipFrame where whereText was
        clipFrame:ClearAllPoints()
        clipFrame:SetPoint("LEFT", whereText, "RIGHT", 2, 0)

        -- Reset the width of ClassText and RaceText to original sizes (adjust as needed)
        classText:SetWidth(84)  -- Adjust to original width as needed
        raceText:SetWidth(84)   -- Adjust to original width as needed

        -- Re-anchor the ClassText and RaceText to the right of clipFrame
        classText:ClearAllPoints()
        raceText:ClearAllPoints()

        -- Anchor ClassText immediately to the right of Clip (was WhereText before)
        classText:SetPoint("LEFT", clipFrame, "RIGHT", -15, 0)

        -- Anchor RaceText immediately to the right of ClassText
        raceText:SetPoint("LEFT", classText, "RIGHT", 2, 0)

        -- Set font and alignment for ClassText and RaceText in the live tab
        classText:SetFontObject("GameFontHighlightSmall")  -- Example font for live tab
        raceText:SetFontObject("GameFontHighlightSmall")   -- Example font for live tab
        classText:SetJustifyH("RIGHT")
        raceText:SetJustifyH("LEFT")

        whenText:ClearAllPoints()
        whenText:SetPoint("LEFT", raceText, "RIGHT", -10, 0)

        rating:ClearAllPoints()
        rating:SetPoint("LEFT", whenText, "RIGHT", 5, 0)

    end
end
ns.ApplyClipLayout = UpdateLayout

local function UpdateClipEntry(state, i, offset, elements, clip, ratingsFromParent, numBatchClips, totalClips, forceFullUpdate)
    -- 'clip' is the newClipData for this row
    -- 'ratingsFromParent' is the pre-fetched ratings for this specific clip.id, passed from OFAuctionFrameDeathClips_Update
    -- However, your original code called state:GetRatingsByClip() and then ns.GetTopReactions(clip.id, 1) inside here.
    -- Let's stick to calling ns.GetTopReactions directly if that's how it was.

    local button = elements.button
    local ratingFrame = elements.rating -- Get from cached elements

    -- Only update static fields if the clip displayed by this button changes, or if a full update is forced
    if button.displayedClipID ~= clip.id or forceFullUpdate then
        button.displayedClipID = clip.id
        -- button.clipData is set in the calling function (OFAuctionFrameDeathClips_Update)

        ResizeEntry(button, #OFAuctionFrameDeathClips.currentDisplayableClips, #OFAuctionFrameDeathClips.currentDisplayableClips)
        -- Assuming ResizeEntry is handled correctly elsewhere or as part of layout

        local nameFS = elements.name
        local raceFS = elements.raceText
        local levelFS = elements.level
        local classFS = elements.classText
        local whereFS = elements.whereText
        local clipTextFS = elements.clipText
        local mobLevelFS = elements.clipMobLevel
        local iconTexture = elements.itemIconTexture

        -- ===== NAME =====
        local newNameText = clip.characterName or L["Unknown"]
        if nameFS:GetText() ~= newNameText then
            nameFS:SetText(newNameText)
        end
        local clr = RAID_CLASS_COLORS[clip.class] or { r = .85, g = .85, b = .85 }
        local curR, curG, curB = nameFS:GetTextColor()
        if curR ~= clr.r or curG ~= clr.g or curB ~= clr.b then
            nameFS:SetTextColor(clr.r, clr.g, clr.b)
        end

        -- ===== RACE =====
        local newRaceText = clip.race or L["Unknown"]
        if GetLocale() == "ruRU" and ns.isCompletedTabActive then
            if newRaceText == "Ночноро\nждённый" then
                newRaceText = "Ночнорождённый"
            elseif newRaceText == "Озар. дреней" then
                newRaceText = "Озарённый дреней"
            elseif newRaceText == "Дворф Ч. Железа" then
                newRaceText = "Дворф Чёрного Железа"
            end
        end
        if raceFS:GetText() ~= newRaceText then
            raceFS:SetText(newRaceText)
        end
        local rF, gF, bF = 0.9, 0.9, 0.4
        if clip.faction == "Horde" then
            rF, gF, bF = 0.8, 0.3, 0.3
        elseif clip.faction == "Alliance" then
            rF, gF, bF = 0.4, 0.6, 1
        end
        local curRF, curGF, curBF = raceFS:GetTextColor()
        if curRF ~= rF or curGF ~= gF or curBF ~= bF then
            raceFS:SetTextColor(rF, gF, bF)
        end

        -- ===== CLASS ICON =====
        local newTexture = "Interface\\Icons\\INV_Misc_QuestionMark"
        local newCoords = { 0, 1, 0, 1 }
        if clip.class and CLASS_ICON_TCOORDS[clip.class] then
            newTexture = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
            newCoords = CLASS_ICON_TCOORDS[clip.class]
        end
        if iconTexture:GetTexture() ~= newTexture then
            iconTexture:SetTexture(newTexture)
        end
        iconTexture:SetTexCoord(unpack(newCoords))

        -- ===== LEVEL =====
        local lvl = clip.level or 1
        local q = GetQuestDifficultyColor(lvl)
        local newLevelText = string.format("|cff%02x%02x%02x%d|r", q.r * 255, q.g * 255, q.b * 255, lvl)
        -- FontStrings don't have GetFormattedText, so we compare with a stored value or just update
        -- For simplicity, let's assume level might change or its color might due to player level, so update.
        levelFS:SetFormattedText("|cff%02x%02x%02x%d|r", q.r * 255, q.g * 255, q.b * 255, lvl)

        -- ===== CLASS TEXT =====
        local key = clip.class and string.upper(clip.class) or "UNKNOWN"
        local newClassText = LOCALIZED_CLASS_NAMES_MALE[key] or clip.class or L["Unknown"]
        if GetLocale() == "ruRU" and not ns.isCompletedTabActive then
            if key == "WARLOCK" then
                newClassText = "Варлок"
            elseif key == "ROGUE" then
                newClassText = "Разбойник"
            end
        end
        if classFS:GetText() ~= newClassText then
            classFS:SetText(newClassText)
        end
        local cc = RAID_CLASS_COLORS[key] or { r = 1, g = 1, b = 1 }
        local curCCR, curCCG, curCCB = classFS:GetTextColor()
        if curCCR ~= cc.r or curCCG ~= cc.g or curCCB ~= cc.b then
            classFS:SetTextColor(cc.r, cc.g, cc.b)
        end

        -- ===== WHERE =====
        whereFS:SetJustifyH("LEFT")
        local zone = clip.mapId and C_Map.GetMapInfo(clip.mapId).name or clip.where or L["Unknown"]
        if zone == "Полуостров Адского Пламени" then
            zone = "Полуостров\nАдского Пламени"
        end
        if whereFS:GetText() ~= zone then
            whereFS:SetText(zone)
        end

        -- ===== CAUSE / MOB LEVEL (Clip Text) =====
        local causeId = clip.causeCode or 0
        local newClipDisplayText = ""
        local newMobLevelText = ""
        local mr, mg, mb = 0, 0, 0

        if causeId == 7 and clip.deathCause and clip.deathCause ~= "" then
            local mobLvl = clip.mobLevel or 0
            local playerLvl = lvl
            local diff = mobLvl - playerLvl
            mr, mg, mb = 0, 1, 0
            if diff >= 4 then
                mr, mg, mb = 1, 0, 0
            elseif diff >= 2 then
                mr, mg, mb = 1, .5, 0
            elseif diff >= -1 then
                mr, mg, mb = 1, 1, 0
            elseif diff >= -4 then
                mr, mg, mb = 0, 1, 0
            else
                mr, mg, mb = .5, .5, .5
            end

            newClipDisplayText = string.format("|cFF%02X%02X%02X%s|r", mr * 255, mg * 255, mb * 255, clip.deathCause)
            newMobLevelText = tostring(mobLvl)
            mobLevelFS:SetTextColor(mr, mg, mb, 200 / 255)
        else
            newClipDisplayText = "|cFFFFFFFF" .. (ns.DeathCauseByID[causeId] or "Неизвестно") .. "|r"
            newMobLevelText = ""
        end

        if clipTextFS:GetText() ~= newClipDisplayText then
            clipTextFS:SetText(newClipDisplayText)
        end
        if mobLevelFS:GetText() ~= newMobLevelText then
            mobLevelFS:SetText(newMobLevelText)
        end
        mobLevelFS:SetJustifyH("CENTER")

        -- ===== COMPLETED TIMER (also uses clipTextFS) =====
        if clip.completed then
            if clipTextFS:GetFontObject() ~= GameFontNormalLarge then
                clipTextFS:SetFontObject("GameFontNormalLarge")
            end
            if clip.playedTime then
                local s = clip.playedTime
                local completedText = string.format("%dд %dч %dм %dс",
                        math.floor(s / 86400), math.floor(s % 86400 / 3600),
                        math.floor(s % 3600 / 60), s % 60)
                if clipTextFS:GetText() ~= completedText then
                    clipTextFS:SetText(completedText)
                end
            elseif clipTextFS:GetText() ~= "Грузится" then
                clipTextFS:SetText("Грузится")
            end
        else
            if clipTextFS:GetFontObject() ~= GameFontNormal then
                clipTextFS:SetFontObject("GameFontNormal")
            end
            -- If not completed, the cause text was already set above by the "CAUSE / MOB LEVEL" block.
            -- Only re-set it if the font change somehow blanked it or if it differs from newClipDisplayText
            if clipTextFS:GetText() ~= newClipDisplayText then
                clipTextFS:SetText(newClipDisplayText)
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
        -- print("DEBUG: Refreshing full clip data")
        local rawPool = ns.GetLiveDeathClips()
        local pool = ns.FilterClipsThisRealm(rawPool)
        local tempClips = {}

        if frame.currentSubTab == "completed" then
            for _, clip in ipairs(pool) do
                if clip.completed then
                    table.insert(tempClips, clip)
                end
            end
        else
            -- "live" or default
            for _, clip in ipairs(pool) do
                if not clip.completed then
                    table.insert(tempClips, clip)
                end
            end
        end

        local _, sortKey, sortAscending = OFGetCurrentSortParams("clips")
        tempClips = ns.SortDeathClips(tempClips, OFGetCurrentSortParams("clips"))

        frame.currentDisplayableClips = tempClips
        frame.needsDataRefresh = false
        forceFullRowUpdate = true

        -- сброс пагинации и скролла
        frame.page = 0
        FauxScrollFrame_SetOffset(OFDeathClipsScroll, 0)
        if OFDeathClipsScrollScrollBar then
            OFDeathClipsScrollScrollBar:SetValue(0)
        end
    end

    local clipsToDisplay = frame.currentDisplayableClips
    local totalClips = #clipsToDisplay
    local page = frame.page or 0
    local offset = FauxScrollFrame_GetOffset(OFDeathClipsScroll)

    -- Calculate start and end indices for the current view
    -- Note: FauxScrollFrame_GetOffset gives the index of the *first visible item* (0-based for logic, 1-based for lua tables)
    -- If we are using pure pagination (page * NUM_CLIPS_PER_PAGE), then offset should align with that.
    -- For simplicity, let's assume offset is the primary driver from the scrollbar, and page is for next/prev buttons.
    -- The FauxScrollFrame handles the actual "view window" based on its total items and item height.
    -- The number of items to actually process for display is NUM_CLIPS_TO_DISPLAY.
    -- The items we get are from clipsToDisplay[offset + 1] to clipsToDisplay[offset + NUM_CLIPS_TO_DISPLAY]

    updateSortArrows()

    local numActuallyDisplayed = 0
    for i = 1, NUM_CLIPS_TO_DISPLAY do
        local buttonElements = ns.clipButtonElements[i]
        local button = buttonElements.button
        local dataIdx = offset + i
        local clip = clipsToDisplay[dataIdx]

        if not clip then
            button:Hide()
            button.displayedClipID = nil -- Clear stored ID
        else
            numActuallyDisplayed = numActuallyDisplayed + 1
            button:Show()
            -- Store the current clip data on the button for the ticker to use
            button.clipData = clip

            local ratings = (clip.id and ratingsByClip[clip.id]) or {}
            ns.TryExcept(
                    function()
                        -- Pass forceFullRowUpdate to UpdateClipEntry
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
    -- FauxScrollFrame_Update(scrollFrame, numItemsTotal, numItemsPerPage, itemHeight)
    -- numItemsTotal is totalClips
    -- numItemsPerPage is NUM_CLIPS_TO_DISPLAY
    FauxScrollFrame_Update(OFDeathClipsScroll, totalClips, NUM_CLIPS_TO_DISPLAY, CLIPS_BUTTON_HEIGHT)

    OFDeathClipsPrevPageButton:Hide()
    OFDeathClipsNextPageButton:Hide()

    -- Pagination button logic (using totalClips from the cached list)
    -- Keep it for later, don't delete this code.
    local displayableItemsInCurrentView = totalClips - offset
    if totalClips > NUM_CLIPS_TO_DISPLAY then
        -- Only show pagination if total items exceed one page view
        --local currentScrollPage = floor(offset / NUM_CLIPS_TO_DISPLAY) -- Page based on scroll offset
        --local totalScrollPages = ceil(totalClips / NUM_CLIPS_TO_DISPLAY) -1
        --
        --OFDeathClipsPrevPageButton:SetEnabled(offset > 0)
        --OFDeathClipsNextPageButton:SetEnabled(offset + NUM_CLIPS_TO_DISPLAY < totalClips)

        OFDeathClipsSearchCountText:Show()
        local itemsMin = offset + 1
        local itemsMax = offset + numActuallyDisplayed
        OFDeathClipsSearchCountText:SetFormattedText(NUMBER_OF_RESULTS_TEMPLATE, itemsMin, itemsMax, totalClips)
    else
        --        OFDeathClipsPrevPageButton:Disable()
        --        OFDeathClipsNextPageButton:Disable()
        OFDeathClipsSearchCountText:Hide()
    end
end

function OFDeathClipsRatingWidget_OnLoad(self)
    -- Create single large icon texture
    local icon = self:CreateTexture(nil, "ARTWORK")
    icon:SetSize(40, 26)
    icon:SetPoint("LEFT", self, "LEFT", 0, 0)
    icon:Hide()
    icon:SetTexCoord(0.1, 0.9, 0.34, 0.74)

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
            [1] = "Interface\\AddOns\\GoAgainAH\\Media\\laugh_64x64.tga",
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

            if id == 2 then
                icon:SetSize(40, 40)
                icon:SetTexCoord(0, 1, 0, 1)
                count:SetPoint("TOPLEFT", icon, "BOTTOMRIGHT", -3, 12)

            elseif id == 3 then
                icon:SetTexCoord(0.1, 0.9, 0.30, 0.72)

            elseif id == 4 then
                icon:SetTexCoord(0.1, 0.9, 0.12, 0.66)

            elseif id == 1 then
                icon:SetVertexColor(0.5, 0.5, 0.5, 1.0)
                icon:SetTexCoord(0.1, 0.9, 0.24, 0.78)
            end

            icon:SetTexture(path)
            icon:Show()

            count:SetText(countValue)
            count:Show()
        else
            icon:Hide()
            count:Hide()
        end
    end
end


-- (addonName and ns are assumed to be defined at the top of your file)
-- (ns.currentClipActionsIconOwner should be defined once, e.g., ns.currentClipActionsIconOwner = nil)

function GoAgainAH_ClipItemActions_Popup_OnLoad(popupFrame)
    local popupFrameName = popupFrame:GetName()
    -- print(addonName .. ": Popup_OnLoad for " .. popupFrameName) -- Optional debug

    -- Set an initial strata and level for the popup.
    -- GoAgainAH_ClipItemActions_OnClick will re-assert this right before showing.
    popupFrame:SetFrameStrata("DIALOG")
    popupFrame:SetFrameLevel(50)

    local titleText = _G[popupFrameName .. "Title"]
    local action1Button = _G[popupFrameName .. "Action1"]
    local action2Button = _G[popupFrameName .. "Action2"]

    if not titleText or not action1Button or not action2Button then
        print(addonName .. ": ERROR in Popup_OnLoad: Child frames not found for " .. popupFrameName)
        return
    end

    action1Button:SetScript("OnClick", function(self_button)
        local owningPopup = self_button:GetParent()
        -- print(addonName .. ": Action1Button Clicked.") -- Optional debug
        if owningPopup.clipData and owningPopup.clipData.characterName then
            if ChatFrame_SendTell then ChatFrame_SendTell(owningPopup.clipData.characterName) end
        end
        owningPopup:Hide()
        if ns then ns.currentClipActionsIconOwner = nil end -- Reset owner
    end)

    action2Button:SetScript("OnClick", function(self_button)
        local owningPopup = self_button:GetParent()
        -- print(addonName .. ": Action2Button Clicked.") -- Optional debug
        if owningPopup.clipData and owningPopup.clipData.characterName then
            if AddFriend then
                AddFriend(owningPopup.clipData.characterName)
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("Предложение дружбы отправлено %s.", owningPopup.clipData.characterName))
                end
            end
        end
        owningPopup:Hide()
        if ns then ns.currentClipActionsIconOwner = nil end -- Reset owner
    end)

    titleText:SetText("Действия")
    action1Button:SetText("Шёпот")
    action2Button:SetText("Добавить в друзья")
end

function GoAgainAH_ClipItemActions_OnClick(iconButton)
    -- print(addonName .. ": ClipItem_OnClick triggered.") -- Optional debug
    local popup = _G["OFClipItemActionsPopup"]
    if not popup then print(addonName .. ": ERROR: OFClipItemActionsPopup frame not found AT ALL in OnClick.") return end

    local mainRowButton = iconButton:GetParent()
    local clipData = mainRowButton and mainRowButton.clipData
    if not clipData then
        -- print(addonName .. ": No clipData found.") -- Optional debug
        if popup:IsShown() then popup:Hide() end
        if ns then ns.currentClipActionsIconOwner = nil end
        return
    end

    local playerFaction = UnitFactionGroup("player")
    local targetFaction = clipData.faction
    if not targetFaction or not playerFaction or (playerFaction ~= targetFaction) then
        -- print(addonName .. ": Faction mismatch.") -- Optional debug
        if popup:IsShown() then popup:Hide() end
        if ns then ns.currentClipActionsIconOwner = nil end
        return
    end

    if popup:IsShown() and ns.currentClipActionsIconOwner == iconButton then
        -- print(addonName .. ": Popup shown for same button. Hiding.") -- Optional debug
        popup:Hide()
        if ns then ns.currentClipActionsIconOwner = nil end
        return
    elseif popup:IsShown() then
        -- print(addonName .. ": Popup shown for different button. Hiding first.") -- Optional debug
        popup:Hide()
        -- ns.currentClipActionsIconOwner will be set below
    end

    local popupFrameName = popup:GetName()
    local titleText = _G[popupFrameName .. "Title"]
    local action1Button = _G[popupFrameName .. "Action1"]
    local action2Button = _G[popupFrameName .. "Action2"]

    if not titleText or not action1Button or not action2Button then
        print(addonName .. ": ERROR in OnClick: Child frames of popup not found.")
        if popup:IsShown() then popup:Hide() end
        if ns then ns.currentClipActionsIconOwner = nil end
        return
    end

    popup.clipData = clipData
    titleText:SetText("Действия")
    if clipData.characterName then
        action1Button:SetText(string.format("Шёпот: %s", clipData.characterName))
        action2Button:SetText(string.format("В друзья: %s", clipData.characterName))
    else
        action1Button:SetText("Шёпот")
        action2Button:SetText("Добавить в друзья")
    end
    action1Button:SetEnabled(clipData.characterName ~= nil)
    action2Button:SetEnabled(clipData.characterName ~= nil)

    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(50)

    popup:ClearAllPoints()
    popup:SetPoint("TOPLEFT", iconButton, "BOTTOMLEFT", 0, -5)
    -- print(addonName .. ": Showing Popup now.") -- Optional debug
    popup:Show()
    if ns then ns.currentClipActionsIconOwner = iconButton end
end

-- Can be called externally to close the popup
ns.HideClipActionsPopupIfShown = function()
    local popup = _G["OFClipItemActionsPopup"]
    if popup and popup:IsShown() then
        popup:Hide()
        if ns then ns.currentClipActionsIconOwner = nil end -- Reset owner
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