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

    -- ---- START OF PAGINATION BUTTONS LOGIC (Unchanged from previous correct version) ----
    local prevButton = _G["OFDeathClipsPrevPageButton"]
    local nextButton = _G["OFDeathClipsNextPageButton"]

    if prevButton then
        prevButton:SetScript("OnClick", function()
            local currentOffset = FauxScrollFrame_GetOffset(OFDeathClipsScroll)
            local newOffset = math.max(0, currentOffset - NUM_CLIPS_TO_DISPLAY)
            if newOffset ~= currentOffset then
                FauxScrollFrame_SetOffset(OFDeathClipsScroll, newOffset)
                OFAuctionFrameDeathClips_Update()
            end
        end)
    end

    if nextButton then
        nextButton:SetScript("OnClick", function()
            local totalClips = #OFAuctionFrameDeathClips.currentDisplayableClips
            local currentOffset = FauxScrollFrame_GetOffset(OFDeathClipsScroll)

            local maxOffsetPossible = math.max(0, totalClips - NUM_CLIPS_TO_DISPLAY)
            local newOffset = math.min(maxOffsetPossible, currentOffset + NUM_CLIPS_TO_DISPLAY)

            if newOffset ~= currentOffset then
                FauxScrollFrame_SetOffset(OFDeathClipsScroll, newOffset)
                OFAuctionFrameDeathClips_Update()
            end
        end)
    end
    -- ---- END OF PAGINATION BUTTONS LOGIC ----

    -- ---- START OF MINIMAL CHANGE TO DISABLE MOUSE WHEEL SCROLLING ----
    local scrollFrame = _G["OFDeathClipsScroll"]
    if scrollFrame then
        -- FauxScrollFrames typically handle mouse wheel via their OnMouseWheel script.
        -- Nilling it out is the most direct way to disable it if it's set.
        scrollFrame:SetScript("OnMouseWheel", nil)

        -- Some custom FauxScrollFrame setups might use EnableMouseWheel (less common for FauxScrollFrame itself)
        -- This is more for Blizzard's ScrollFrameTemplate based frames.
        -- It's generally safe to call if the method exists, but nilling OnMouseWheel is key for FauxScroll.
        if scrollFrame.EnableMouseWheel then
            scrollFrame:EnableMouseWheel(false)
        end
    end
    -- ---- END OF MINIMAL CHANGE TO DISABLE MOUSE WHEEL SCROLLING ----

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

    -- ---- START OF MINIMAL CHANGE TO HIDE SCROLLBAR ----
    -- Explicitly hide the scrollbar after FauxScrollFrame_Update has potentially shown it.
    -- This makes the UI rely purely on pagination buttons.
    if _G["OFDeathClipsScrollScrollBar"] then
        _G["OFDeathClipsScrollScrollBar"]:Hide()
    end
    -- ---- END OF MINIMAL CHANGE TO HIDE SCROLLBAR ----

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


function OFAuctionFrameDeathClips_OnHide()
    if OFAuctionFrameDeathClips._whenUpdateTicker then
        OFAuctionFrameDeathClips._whenUpdateTicker:Cancel()
        OFAuctionFrameDeathClips._whenUpdateTicker = nil
    end
    if ns.HideAllClipPrompts then
        ns.HideAllClipPrompts()
    end
end

-- (addonName and ns are assumed to be defined at the top of your file)

-- SAVED VARIABLES:
if type(AuctionHouseDBSaved) ~= "table" then _G.AuctionHouseDBSaved = {} end
AuctionHouseDBSaved.watchedFriends = AuctionHouseDBSaved.watchedFriends or {}
-- Structure: { [playerLowerName] = { clipLevel = number, hasBeenNotifiedForThisAdd = boolean } }

-- State for AddFriend Error Handling (Session Only)
local suppressPlayerNotFoundSystemMessageActive = false
local PLAYER_NOT_FOUND_RU = "Игрок не найден."
ns.expectingFriendAddSystemMessageFor = nil
ns.capturedFriendAddSystemMessage = nil

local MAP_PING_SOUND_FILE = "Sound\\interface\\MapPing.wav"
ns.fallbackClassNames = {
    WARRIOR = "Воин", PALADIN = "Паладин", HUNTER = "Охотник", ROGUE = "Разбойник",
    PRIEST = "Жрец", DEATHKNIGHT = "Рыцарь смерти", SHAMAN = "Шаман", MAGE = "Маг",
    WARLOCK = "Чернокнижник", DRUID = "Друид", ["РЫЦАРЬ СМЕРТИ"] = "Рыцарь смерти"
}

-- Debounce/Cooldown variables
local FRIENDLIST_UPDATE_DEBOUNCE_TIME = 10
local NOTIFICATION_COOLDOWN = 3
local lastFriendListScanTime = 0
local lastNotificationTime = 0
local friendListDebounceTimer = nil
local initialLoginScanTimer = nil

local TOOLTIP_MIN_WIDTH = 150
local TOOLTIP_MAX_WIDTH = 350
local TOOLTIP_HORIZONTAL_PADDING = 20
local TOOLTIP_VERTICAL_PADDING = 16
local LINE_SPACING = 2

local function ShowStatusTooltip(anchorFrame, line1Str, line2Str, line3Str)
    local tooltip = _G["GoAgainAH_StatusTooltip"]
    if not tooltip then
        print(addonName .. " Error: GoAgainAH_StatusTooltip frame not found!")
        return
    end
    -- if the user moved off the icon before we fire, don’t show at all
    if anchorFrame and not anchorFrame:IsMouseOver() then
        return
    end

    -- Variant B: Dark charcoal (#181818), fully opaque
    if not tooltip.__bgVariantB then
        local bg = tooltip:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetAllPoints(tooltip)
        -- RGB(24/255,24/255,24/255), alpha=1
        bg:SetTexture(0.094, 0.094, 0.094, 1)
        tooltip.__bgVariantB = bg
    end


    -- Hide if parent isn’t visible
    local parentFrame = tooltip:GetParent()
    if not parentFrame or not parentFrame:IsShown() then
        tooltip:Hide()
        return
    end

    -- Fetch our three FontStrings
    local l1 = _G[tooltip:GetName().."Line1"]
    local l2 = _G[tooltip:GetName().."Line2"]
    local l3 = _G[tooltip:GetName().."Line3"]
    if not (l1 and l2 and l3) then
        print(addonName .. " Error: StatusTooltip lines not found!")
        return
    end

    -- ── Measure & wrap text exactly as before ──
    local initialMax = TOOLTIP_MAX_WIDTH - TOOLTIP_HORIZONTAL_PADDING
    l1:SetWidth(initialMax); l2:SetWidth(initialMax); l3:SetWidth(initialMax)
    l1:SetText(line1Str or "")
    l2:SetText(line2Str or "")
    l3:SetText(line3Str or "")

    local usedW = 0
    if line1Str and line1Str ~= "" then usedW = math.max(usedW, l1:GetStringWidth()) end
    if line2Str and line2Str ~= "" then usedW = math.max(usedW, l2:GetStringWidth()) end
    if line3Str and line3Str ~= "" then usedW = math.max(usedW, l3:GetStringWidth()) end

    local contentW = math.min(initialMax, usedW)
    local finalW = math.max(TOOLTIP_MIN_WIDTH,
            math.min(TOOLTIP_MAX_WIDTH,
                    contentW + TOOLTIP_HORIZONTAL_PADDING))
    tooltip:SetWidth(finalW)

    local innerW = finalW - TOOLTIP_HORIZONTAL_PADDING
    l1:SetWidth(innerW); l2:SetWidth(innerW); l3:SetWidth(innerW)
    l1:SetText(line1Str or ""); l2:SetText(line2Str or ""); l3:SetText(line3Str or "")

    -- compute height
    local totalH, lines = 0, 0
    if line1Str ~= "" then totalH=totalH+l1:GetHeight(); lines=lines+1 else l1:SetText("") end
    if line2Str ~= "" then
        if lines>0 then totalH=totalH+LINE_SPACING end
        totalH=totalH+l2:GetHeight(); lines=lines+1
    else l2:SetText("") end
    if line3Str ~= "" then
        if lines>0 then totalH=totalH+LINE_SPACING end
        --totalH=totalH+l3:GetHeight(); lines=lines+1
    else l3:SetText("") end

    if lines == 0 then
        tooltip:Hide()
        return
    end

    tooltip:SetHeight(math.max(35, TOOLTIP_VERTICAL_PADDING + totalH))

    -- ── REANCHOR TO ICON BUTTON ──
    -- new: place the bottom-left of the tooltip at the top-left of the button
    tooltip:ClearAllPoints()
    tooltip:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 21.5, 0)




    tooltip:Show()
end


local function HideStatusTooltip()
    local tooltip = _G["GoAgainAH_StatusTooltip"]
    if tooltip and tooltip:IsShown() then tooltip:Hide() end
end

local function IsPlayerOnFriendsList(characterName)
    if not characterName or characterName == "" then return false end
    local lowerCharacterName = string.lower(characterName)
    for i = 1, GetNumFriends() do
        local name, level, classToken, area, connected = GetFriendInfo(i)
        if name then
            local lowerName = string.lower(name)
            local friendBaseName = lowerName:match("([^%-]+)")
            if friendBaseName == lowerCharacterName or lowerName == lowerCharacterName then
                return true, connected, level, classToken, area
            end
        end
    end
    return false, false, nil, nil, nil
end

ns.russianClassNameToEnglishToken = {
    -- Male (and some neutral) forms from LOCALIZED_CLASS_NAMES_MALE
    ["Рыцарь смерти"] = "DEATHKNIGHT",
    ["Воин"] = "WARRIOR",
    ["Разбойник"] = "ROGUE",
    ["Маг"] = "MAGE",
    ["Жрец"] = "PRIEST",
    ["Чернокнижник"] = "WARLOCK",
    ["Охотник"] = "HUNTER",
    ["Друид"] = "DRUID", -- Druid is often neutral
    ["Шаман"] = "SHAMAN",
    ["Паладин"] = "PALADIN", -- Paladin is often neutral

    -- Female forms from LOCALIZED_CLASS_NAMES_FEMALE
    -- Note: DEATHKNIGHT, WARRIOR, MAGE, DRUID, PALADIN often use same localized string for male/female,
    -- so they might overwrite. This is fine as long as the English token is the same.
    ["Разбойница"] = "ROGUE",
    ["Жрица"] = "PRIEST",
    ["Чернокнижница"] = "WARLOCK",
    ["Охотница"] = "HUNTER",
    ["Шаманка"] = "SHAMAN",

    -- Also include uppercase versions if GetFriendInfo might return those
    ["РЫЦАРЬ СМЕРТИ"] = "DEATHKNIGHT",
    ["ВОИН"] = "WARRIOR",
    ["РАЗБОЙНИК"] = "ROGUE",
    ["МАГ"] = "MAGE",
    ["ЖРЕЦ"] = "PRIEST",
    ["ЧЕРНОКНИЖНИК"] = "WARLOCK",
    ["ОХОТНИК"] = "HUNTER",
    ["ДРУИД"] = "DRUID",
    ["ШАМАН"] = "SHAMAN",
    ["ПАЛАДИН"] = "PALADIN",
    ["ОХОТНИЦА"] = "HUNTER", -- Uppercase female
    ["РАЗБОЙНИЦА"] = "ROGUE",
    ["ЖРИЦА"] = "PRIEST",
    ["ЧЕРНОКНИЖНИЦА"] = "WARLOCK",
    ["ШАМАНКА"] = "SHAMAN"
}

local function NotifyPlayerLevelDrop(name, currentLevel, clipLevelWhenAdded, classTokenFromGetFriendInfo, area)
    local lowerName = string.lower(name)
    AuctionHouseDBSaved.watchedFriends = AuctionHouseDBSaved.watchedFriends or {}
    local watchedEntry = AuctionHouseDBSaved.watchedFriends[lowerName]

    if watchedEntry and not watchedEntry.hasBeenNotifiedForThisAdd and
            currentLevel and watchedEntry.clipLevel and currentLevel < watchedEntry.clipLevel then

        local currentTime = GetTime()
        if (currentTime - lastNotificationTime) < NOTIFICATION_COOLDOWN then
            return
        end
        lastNotificationTime = currentTime

        PlaySoundFile(MAP_PING_SOUND_FILE)

        local displayedClassName = "Неизвестный класс"
        local classColorHex = "ffffffff" -- Default to white for color if not found
        local englishTokenForColor = nil

        if classTokenFromGetFriendInfo and type(classTokenFromGetFriendInfo) == "string" and classTokenFromGetFriendInfo ~= "" then
            displayedClassName = classTokenFromGetFriendInfo

            if ns.russianClassNameToEnglishToken then
                englishTokenForColor = ns.russianClassNameToEnglishToken[displayedClassName]
                if not englishTokenForColor then
                    englishTokenForColor = ns.russianClassNameToEnglishToken[string.upper(displayedClassName)]
                end
            end

            if englishTokenForColor and RAID_CLASS_COLORS and RAID_CLASS_COLORS[englishTokenForColor] then
                local c = RAID_CLASS_COLORS[englishTokenForColor]
                classColorHex = string.format("%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
            end
        end

        local zoneName = area and area ~= "" and area or "Неизвестная зона"

        -- Line 1: "GoAgainAH:" (grey) Name (class color) "начал новый путь." (default white)
        local prefix = string.format("|cff888888%s:|r", addonName)
        local clickableColoredName = string.format("|Hplayer:%s|h|cff%s[%s]|h|r", name, classColorHex, name)
        local line1 = string.format("%s %s начал новый путь.", prefix, clickableColoredName)

        -- Line 2: ClassName (class color) Level (yellow) • (light grey) Zone (gold) (прежний уровень: OriginalLevel (yellow))
        local coloredDisplayedClassName = string.format("|cff%s%s|r", classColorHex, displayedClassName)
        local currentLevelStr = string.format("|cffffff00%d ур.|r", currentLevel) -- Yellow #FFFF00
        local separator = "|cffaaaaaa•|r" -- Light grey #AAAAAA
        local zoneNameStr = string.format("|cffffd700%s|r", zoneName) -- Gold #FFD700
        local originalClipLevelStr = string.format("|cffffff00%d|r", watchedEntry.clipLevel) -- Yellow #FFFF00

        local line2 = string.format("%s %s %s %s %s прежний уровень: %s",
                coloredDisplayedClassName,
                currentLevelStr,
                separator,           -- First separator
                zoneNameStr,
                separator,           -- Second separator
                originalClipLevelStr)

        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(line1)
            DEFAULT_CHAT_FRAME:AddMessage(line2)
        else
            print(line1); print(line2)
        end

        watchedEntry.hasBeenNotifiedForThisAdd = true
    end
end

-- at addon load, create a dedicated hover-tooltip
local HoverTooltip = CreateFrame("GameTooltip", "GoAgainAH_HoverTooltip", UIParent, "GameTooltipTemplate")
HoverTooltip:SetFrameStrata("TOOLTIP")
-- you can tweak its default anchor offset here if you like:
-- HoverTooltip:SetOwner(UIParent, "ANCHOR_NONE")

local function ShowHoverTooltipForIcon(iconButton)
    -- don’t run if ours is already visible
    if HoverTooltip:IsShown() then return end

    -- hide the standard GameTooltip if it’s on this button
    if GameTooltip:IsShown() and GameTooltip:IsOwned(iconButton) then
        GameTooltip:Hide()
    end

    -- grab your clipData
    local row = iconButton:GetParent()
    if not row or not row.clipData or not row.clipData.characterName then
        return
    end
    local cd = row.clipData
    local name = cd.characterName

    -- populate *your* tooltip
    HoverTooltip:SetOwner(iconButton, "ANCHOR_RIGHT")
    HoverTooltip:ClearLines()
    HoverTooltip:AddLine(name)

    local pf = UnitFactionGroup("player")
    if cd.faction ~= pf then
        HoverTooltip:AddLine("|cffff2020(Другая фракция)|r")
    else
        local isFriend, isConnected, lvl = IsPlayerOnFriendsList(name)
        HoverTooltip:AddLine("ЛКМ: |cffA0A0A0Шёпот|r")

        if isFriend then
            HoverTooltip:AddLine("ПКМ: |cff00cc00Уже друг|r")
            if isConnected then
                HoverTooltip:AddLine(string.format("|cff69ccf0(В сети - Ур: %d)|r", lvl or 0))
            else
                HoverTooltip:AddLine("|cff888888(Не в сети)|r")
            end
        else
            HoverTooltip:AddLine("ПКМ: |cffA0A0A0В друзья|r")
        end
    end

    -- scale *only* your new tooltip
    HoverTooltip:SetScale(1.5)
    HoverTooltip:Show()
end


function GoAgainAH_ClipItem_OnClick(iconFrameElement, receivedMouseButton)
    -- Hide any existing status tooltip
    HideStatusTooltip()

    -- Hide the GameTooltip if it’s showing for this icon
    if GameTooltip:IsShown() and GameTooltip:IsOwned(iconFrameElement) then
        GameTooltip:Hide()
    end

    -- Hide the custom hover tooltip
    if GoAgainAH_HoverTooltip then
        GoAgainAH_HoverTooltip:Hide()
    end

    -- Grab the clip data from this row
    local mainRowButton = iconFrameElement:GetParent()
    if not mainRowButton or not mainRowButton.clipData then
        return
    end
    local clipData = mainRowButton.clipData
    if not clipData.characterName or not clipData.level then
        return
    end

    local characterName                      = clipData.characterName
    local characterNameLower                 = string.lower(characterName)
    local originalClipLevelFromThisInteraction = clipData.level
    local targetClipFaction                  = clipData.faction
    local playerFaction                      = UnitFactionGroup("player")
    local line1, line2, line3                = "", "", ""

    if receivedMouseButton == "LeftButton" then
        -- Left-click: whisper the character
        local editBox = _G["ChatFrame1EditBox"]
        if editBox then
            if editBox:IsShown() then
                editBox:ClearFocus()
                editBox:Hide()
            else
                ChatFrame_SendTell(characterName)
            end
        else
            ChatFrame_SendTell(characterName)
        end

    elseif receivedMouseButton == "RightButton" then
        -- Right-click: add to friends / notify

        -- 1) Prevent cross-faction adds
        if targetClipFaction ~= playerFaction then
            ShowStatusTooltip(iconFrameElement,
                    "|cffff0000Нельзя добавить в друзья:|r " .. characterName,
                    "(Разные фракции)",
                    nil
            )
            return
        end

        if AddFriend then
            -- Check existing friend status
            local wasAlreadyFriend, wasConnected, currentActualLevel, currentClass, currentArea =
            IsPlayerOnFriendsList(characterName)

            AuctionHouseDBSaved.watchedFriends = AuctionHouseDBSaved.watchedFriends or {}

            if wasAlreadyFriend then
                -- Already a friend: show status and possibly notify level drop
                line1 = string.format("%s |cff00ff00уже в друзьях.|r", characterName)
                -- Online-status + level on one line:
                if wasConnected then
                    -- “В сети – Ур: X”
                    line2 = string.format("|cff69ccf0В сети - Ур: %d|r", currentActualLevel or 0)
                else
                    line2 = "|cff888888Не в сети|r"
                end
                ShowStatusTooltip(iconFrameElement, line1, line2, nil)

                local watchedEntry = AuctionHouseDBSaved.watchedFriends[characterNameLower]
                if wasConnected and watchedEntry and watchedEntry.clipLevel then
                    NotifyPlayerLevelDrop(characterName, currentActualLevel, watchedEntry.clipLevel, currentClass, currentArea)
                end
                return
            end

            -- Not yet a friend: send request and capture system message
            ns.capturedFriendAddSystemMessage = nil
            ns.expectingFriendAddSystemMessageFor = characterNameLower
            suppressPlayerNotFoundSystemMessageActive = true
            AddFriend(characterName)

            -- Re-enable error messages after 0.2s
            C_Timer:After(0.2, function()
                suppressPlayerNotFoundSystemMessageActive = false
                if ns.expectingFriendAddSystemMessageFor == characterNameLower then
                    ns.expectingFriendAddSystemMessageFor = nil
                end
            end)

            -- After 0.3s, check whether the add succeeded
            C_Timer:After(0.3, function()
                local isNowFriend, isConnected, friendActualLevel, friendClass, friendArea =
                IsPlayerOnFriendsList(characterName)

                if isNowFriend then
                    line1 = string.format("|cff00ff00Добавлен в друзья:|r %s", characterName)
                    if isConnected then
                        line2 = "|cff69ccf0В сети|r"
                        -- Store for future level-drop notifications
                        AuctionHouseDBSaved.watchedFriends[characterNameLower] = {
                            clipLevel = originalClipLevelFromThisInteraction,
                            hasBeenNotifiedForThisAdd = false,
                        }
                        NotifyPlayerLevelDrop(characterName, friendActualLevel, originalClipLevelFromThisInteraction, friendClass, friendArea, "added")
                    else
                        line2 = "|cff888888Не в сети|r"
                        AuctionHouseDBSaved.watchedFriends[characterNameLower] = {
                            clipLevel = originalClipLevelFromThisInteraction,
                            hasBeenNotifiedForThisAdd = false,
                        }
                    end
                else
                    line1 = string.format("|cffffcc00Не удалось добавить:|r %s", characterName)
                    if ns.capturedFriendAddSystemMessage then
                        line2 = "|cffffff80Причина: " .. ns.capturedFriendAddSystemMessage .. "|r"
                    else
                        line2 = "(Проверьте ошибки игры в чате)"
                    end
                end

                ShowStatusTooltip(iconFrameElement, line1, line2, line3)
                ns.expectingFriendAddSystemMessageFor = nil
                ns.capturedFriendAddSystemMessage = nil
            end)
        end
    end
end

-- When the mouse enters the icon, show your custom tooltip
function GoAgainAH_ClipItem_OnEnter(iconButton)
    ShowHoverTooltipForIcon(iconButton)
end

-- When the mouse leaves, hide *all* of your tooltips
function GoAgainAH_ClipItem_OnLeave(iconButton)
    -- Hide the custom hover tooltip
    if GoAgainAH_HoverTooltip then
        GoAgainAH_HoverTooltip:Hide()
    end

    -- Hide the status/toast tooltip
    HideStatusTooltip()

    -- In case the default GameTooltip was used, hide that too
    if GameTooltip:IsOwned(iconButton) then
        GameTooltip:Hide()
    end
end


local function FriendAddSystemMessageFilter(self, event, msg, ...)
    if not msg or type(msg) ~= "string" then return false end
    if event == "CHAT_MSG_SYSTEM" and suppressPlayerNotFoundSystemMessageActive and msg == PLAYER_NOT_FOUND_RU then
        if ns.expectingFriendAddSystemMessageFor then ns.capturedFriendAddSystemMessage = msg; ns.expectingFriendAddSystemMessageFor = nil end
        return true
    end
    if event == "CHAT_MSG_SYSTEM" and ns.expectingFriendAddSystemMessageFor and not ns.capturedFriendAddSystemMessage then
        local shortMsg = msg; if string.len(msg) > 60 then shortMsg = string.sub(msg, 1, 60) .. "..." end
        ns.capturedFriendAddSystemMessage = shortMsg; ns.expectingFriendAddSystemMessageFor = nil
    end
    return false
end

local function PerformFriendListScan()
    lastFriendListScanTime = GetTime()
    if type(AuctionHouseDBSaved) ~= "table" or type(AuctionHouseDBSaved.watchedFriends) ~= "table" then return end
    for i = 1, GetNumFriends() do
        local name, currentActualLevel, classToken, area, connected = GetFriendInfo(i)
        if name and connected then
            local lowerName = string.lower(name)
            local watchedEntry = AuctionHouseDBSaved.watchedFriends[lowerName]
            if watchedEntry and watchedEntry.clipLevel and not watchedEntry.hasBeenNotifiedForThisAdd then
                NotifyPlayerLevelDrop(name, currentActualLevel, watchedEntry.clipLevel, classToken, area, "friend_online_event")
            end
        end
    end
end

local function HandleFriendListUpdate()
    if friendListDebounceTimer then return end
    local currentTime = GetTime()
    if (currentTime - lastFriendListScanTime) < FRIENDLIST_UPDATE_DEBOUNCE_TIME then
        local remainingTime = FRIENDLIST_UPDATE_DEBOUNCE_TIME - (currentTime - lastFriendListScanTime)
        friendListDebounceTimer = C_Timer:After(remainingTime, function()
            friendListDebounceTimer = nil; PerformFriendListScan()
        end)
        return
    end
    PerformFriendListScan()
end

local function CleanupNotifiedFriendsDB()
    if type(AuctionHouseDBSaved) ~= "table" or type(AuctionHouseDBSaved.watchedFriends) ~= "table" then return end
    local playersToCleanup = {}
    for playerNameLower, data in pairs(AuctionHouseDBSaved.watchedFriends) do
        if data.hasBeenNotifiedForThisAdd then
            table.insert(playersToCleanup, playerNameLower)
        end
    end
    if #playersToCleanup > 0 then
        print(addonName .. ": Очистка " .. #playersToCleanup .. " уведомленных друзей из БД при входе в мир.")
        for _, key in ipairs(playersToCleanup) do
            AuctionHouseDBSaved.watchedFriends[key] = nil
        end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("FRIENDLIST_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if type(AuctionHouseDBSaved) ~= "table" then _G.AuctionHouseDBSaved = {} end
        AuctionHouseDBSaved.watchedFriends = AuctionHouseDBSaved.watchedFriends or {}
        ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", FriendAddSystemMessageFilter)
    elseif event == "PLAYER_ENTERING_WORLD" then
        if type(AuctionHouseDBSaved) ~= "table" then _G.AuctionHouseDBSaved = {} end
        AuctionHouseDBSaved.watchedFriends = AuctionHouseDBSaved.watchedFriends or {}
        CleanupNotifiedFriendsDB()
        lastFriendListScanTime = 0
        if friendListDebounceTimer then friendListDebounceTimer:Cancel(); friendListDebounceTimer = nil end
        if initialLoginScanTimer then initialLoginScanTimer:Cancel(); initialLoginScanTimer = nil end
        initialLoginScanTimer = C_Timer:After(15, function()
            initialLoginScanTimer = nil; PerformFriendListScan()
        end)
    elseif event == "PLAYER_LOGOUT" then
        if friendListDebounceTimer then friendListDebounceTimer:Cancel(); friendListDebounceTimer = nil end
        if initialLoginScanTimer then initialLoginScanTimer:Cancel(); initialLoginScanTimer = nil end
        -- Watched friends data in AuctionHouseDBSaved persists. No session flags to clear here.
    elseif event == "FRIENDLIST_UPDATE" then
        HandleFriendListUpdate()
    end
end)