local addonName, ns = ...
local L = ns.L

-- Keep track if the sort hook has been applied to avoid duplicates
local sortHookApplied = false

local NUM_CLIPS_TO_DISPLAY = 9
local NUM_CLIPS_PER_PAGE = 50
local CLIPS_BUTTON_HEIGHT = 37

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

--local function updateSortArrows()
--    OFSortButton_UpdateArrow(OFDeathClipsStreamerSort, "clips", "streamer")
--    OFSortButton_UpdateArrow(OFDeathClipsRaceSort, "clips", "race")
--    OFSortButton_UpdateArrow(OFDeathClipsLevelSort, "clips", "level")
--    OFSortButton_UpdateArrow(OFDeathClipsClassSort, "clips", "class")
--    OFSortButton_UpdateArrow(OFDeathClipsWhenSort, "clips", "when")
--    OFSortButton_UpdateArrow(OFDeathClipsRatingSort, "clips", "rating")
--    OFSortButton_UpdateArrow(OFDeathClipsWhereSort, "clips", "where")
--    OFSortButton_UpdateArrow(OFDeathClipsClipSort, "clips", "clip")
--end

-- Example of how updateSortArrows MIGHT need to change (conceptual)
local function updateSortArrows() -- New name to avoid conflict if original is elsewhere
    local currentKey = OFAuctionFrameDeathClips.clipsSortKey
    local currentAsc = OFAuctionFrameDeathClips.clipsSortAscending

    -- OFSortButton_UpdateArrow(frame, sortType, sortKey, currentSortKey, currentSortAscending)
    -- The OFSortButton_UpdateArrow function needs to know the CURRENT active sort key and direction
    -- to correctly show arrows.
    -- If OFSortButton_UpdateArrow takes currentKey and currentAsc as params:
    -- OFSortButton_UpdateArrow(OFDeathClipsStreamerSort, "clips", "streamer", currentKey, currentAsc)
    -- OFSortButton_UpdateArrow(OFDeathClipsRaceSort, "clips", "race", currentKey, currentAsc)
    -- ... and so on for all sort buttons.

    -- OR, if OFSortButton_UpdateArrow calls OFGetCurrentSortParams itself, then that OFSortButton_UpdateArrow
    -- function in the main OF framework is the one that needs to be "taught" about your internal clip sort state,
    -- which is much harder.

    -- For now, let's assume you can modify updateSortArrows or OFSortButton_UpdateArrow
    -- to use OFAuctionFrameDeathClips.clipsSortKey and OFAuctionFrameDeathClips.clipsSortAscending
    -- when the type is "clips".

    -- Fallback: If you can't modify the arrow update logic easily, the arrows might not display correctly,
    -- but the sorting itself *will* work based on your internal state.
    -- The original updateSortArrows() might just work if it correctly uses the arguments passed to OFSortButton_UpdateArrow
    -- and if those arguments are enough to determine the arrow state without calling OFGetCurrentSortParams itself.
    -- Your original call: OFSortButton_UpdateArrow(OFDeathClipsStreamerSort, "clips", "streamer")
    -- The OFSortButton_UpdateArrow function itself needs to know the global current sort.
    -- This is the hardest part to fix without changing the OF framework.

    -- Simplest for now: Assume your original updateSortArrows() will still be called,
    -- but it might not show the correct arrow state because OFGetCurrentSortParams("clips") is nil.
    -- The actual sorting will still use your internal variables.
    OFSortButton_UpdateArrow(OFDeathClipsStreamerSort, "clips", "streamer")
    OFSortButton_UpdateArrow(OFDeathClipsRaceSort, "clips", "race")
    OFSortButton_UpdateArrow(OFDeathClipsLevelSort, "clips", "level")
    OFSortButton_UpdateArrow(OFDeathClipsClassSort, "clips", "class")
    OFSortButton_UpdateArrow(OFDeathClipsWhenSort, "clips", "when")
    OFSortButton_UpdateArrow(OFDeathClipsRatingSort, "clips", "rating")
    OFSortButton_UpdateArrow(OFDeathClipsWhereSort, "clips", "where")
    OFSortButton_UpdateArrow(OFDeathClipsClipSort, "clips", "clip")
    -- To make arrows work, OFSortButton_UpdateArrow needs to be aware of OFAuctionFrameDeathClips.clipsSortKey and .clipsSortAscending
end

function OFAuctionFrameDeathClips_OnLoad()
    OFAuctionFrameDeathClips.page = 0

    -- Initialize INTERNAL sort state variables
    OFAuctionFrameDeathClips.clipsSortKey = "when"      -- Initial default for "live" tab
    OFAuctionFrameDeathClips.clipsSortAscending = false -- Initial default for "live" tab (descending)
    OFAuctionFrameDeathClips.currentSubTab = "live"     -- Initial default subTab
    if ns then ns.isCompletedTabActive = false end      -- Ensure layout flag matches initial tab

    OFAuctionFrameDeathClips.currentDisplayableClips = {}
    OFAuctionFrameDeathClips.needsDataRefresh = true -- Force initial data load and sort

    ns.clipButtonElements = {}
    for i = 1, NUM_CLIPS_TO_DISPLAY do
        local button = _G["OFDeathClipsButton" .. i]
        if button then
            local buttonName = button:GetName()
            if (_G[buttonName .. "Highlight"] and _G[buttonName .. "Name"] and _G[buttonName .. "Level"] and
                    _G[buttonName .. "RaceText"] and _G[buttonName .. "ItemIconTexture"] and _G[buttonName .. "ClassText"] and
                    _G[buttonName .. "WhenText"] and _G[buttonName .. "WhereText"] and _G[buttonName .. "ClipText"] and
                    _G[buttonName .. "ClipMobLevel"] and _G[buttonName .. "Rating"] and _G[buttonName .. "Clip"]) then

                ns.clipButtonElements[i] = {
                    button = button, highlight = _G[buttonName .. "Highlight"], name = _G[buttonName .. "Name"],
                    level = _G[buttonName .. "Level"], raceText = _G[buttonName .. "RaceText"],
                    itemIconTexture = _G[buttonName .. "ItemIconTexture"], classText = _G[buttonName .. "ClassText"],
                    whenText = _G[buttonName .. "WhenText"], whereText = _G[buttonName .. "WhereText"],
                    clipText = _G[buttonName .. "ClipText"], clipMobLevel = _G[buttonName .. "ClipMobLevel"],
                    rating = _G[buttonName .. "Rating"], clipFrame = _G[buttonName .. "Clip"],
                }
                button.displayedClipID = nil
                if ns and ns.SetupClipHighlight then ns.SetupClipHighlight(button) end

                button:SetScript("OnClick", function(self)
                    local c = self.clipData
                    if not c or not c.id then return end
                    local wasOpen = (OFAuctionFrameDeathClips.openedPromptClipID == c.id)
                    if ns and ns.HideAllClipPrompts then ns.HideAllClipPrompts() end
                    if not wasOpen then
                        if ns and ns.ShowDeathClipReviewsPrompt then ns.ShowDeathClipReviewsPrompt(c) end
                        OFAuctionFrameDeathClips.openedPromptClipID = c.id
                    end
                    OFAuctionFrameDeathClips_Update()
                end)
            else
                if ns and ns.DebugLog then ns.DebugLog(addonName .. ": Critical Error - Child elements missing for " .. buttonName .. " in OnLoad!") end
            end
        else
            if ns and ns.DebugLog then ns.DebugLog(addonName .. ": Critical Error - OFDeathClipsButton" .. i .. " not found in OnLoad!") end
        end
    end

    if ns and ns.AuctionHouseAPI then
        ns.AuctionHouseAPI:RegisterEvent(ns.EV_DEATH_CLIPS_CHANGED, function()
            OFAuctionFrameDeathClips.needsDataRefresh = true
            if OFAuctionFrame and OFAuctionFrame:IsShown() and OFAuctionFrameDeathClips and OFAuctionFrameDeathClips:IsShown() then
                OFAuctionFrameDeathClips_Update()
            end
        end)
    end

    OFAuctionFrameDeathClips.openedPromptClipID = nil
    OFAuctionFrameDeathClips._highlightedClips = OFAuctionFrameDeathClips._highlightedClips or {}

    if not sortHookApplied then
        if type(OFAuctionFrame_SetSort) == "function" then
            hooksecurefunc("OFAuctionFrame_SetSort", function(type, key, ascending)
                if type == "clips" then
                    print(string.format("DEBUG_SORT_HOOK: OFAuctionFrame_SetSort received for 'clips'. Key: %s, Ascending: %s.", tostring(key), tostring(ascending)))

                    OFAuctionFrameDeathClips.clipsSortKey = key
                    OFAuctionFrameDeathClips.clipsSortAscending = ascending -- Store the value AS RECEIVED

                    OFAuctionFrameDeathClips.page = 0
                    if OFDeathClipsScroll then FauxScrollFrame_SetOffset(OFDeathClipsScroll, 0) end
                    if OFDeathClipsScrollScrollBar then OFDeathClipsScrollScrollBar:SetValue(0) end
                    OFAuctionFrameDeathClips.needsDataRefresh = true

                    if OFAuctionFrame and OFAuctionFrame:IsShown() and OFAuctionFrameDeathClips and OFAuctionFrameDeathClips:IsShown() then
                        OFAuctionFrameDeathClips_Update()
                    end
                end
            end)
            sortHookApplied = true
        else
            if ns and ns.DebugLog then ns.DebugLog(addonName .. ": Error - Could not find OFAuctionFrame_SetSort to hook for clip sorting.") end
        end
    end

    -- Tab click handlers
    if OFDeathClipsTabLive and OFDeathClipsTabLive.HookScript then
        OFDeathClipsTabLive:HookScript("OnClick", function()
            if OFAuctionFrameDeathClips.currentSubTab ~= "live" then
                OFAuctionFrameDeathClips.currentSubTab = "live"
                if ns then ns.isCompletedTabActive = false end
                print("DEBUG_TAB_CLICK: Switched to LIVE tab. Setting sort to 'when', false (desc).")
                OFAuctionFrame_SetSort("clips", "when", false) -- This call will trigger the hook
            end
        end)
    end
    if OFDeathClipsTabCompleted and OFDeathClipsTabCompleted.HookScript then
        OFDeathClipsTabCompleted:HookScript("OnClick", function()
            if OFAuctionFrameDeathClips.currentSubTab ~= "completed" then
                OFAuctionFrameDeathClips.currentSubTab = "completed"
                if ns then ns.isCompletedTabActive = true end
                print("DEBUG_TAB_CLICK: Switched to COMPLETED tab. Setting sort to 'clip', true (asc).")
                OFAuctionFrame_SetSort("clips", "clip", true) -- This call will trigger the hook
            end
        end)
    end

    -- Explicitly call OFAuctionFrame_SetSort at the end of OnLoad to set the initial state
    -- This ensures the hook fires and variables are primed.
    if type(OFAuctionFrame_SetSort) == "function" then
        OFAuctionFrame_SetSort("clips", OFAuctionFrameDeathClips.clipsSortKey, OFAuctionFrameDeathClips.clipsSortAscending)
    else
        -- If OFAuctionFrame_SetSort isn't available, we have to manually trigger a refresh if UI is shown
        -- This path is less ideal as it bypasses the hook logic for initialization
        OFAuctionFrameDeathClips.needsDataRefresh = true;
        if OFAuctionFrame and OFAuctionFrame:IsShown() and OFAuctionFrameDeathClips and OFAuctionFrameDeathClips:IsShown() then
            OFAuctionFrameDeathClips_Update()
        end
    end
end

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
            if not (OFAuctionFrame:IsShown() and frame:IsShown()) then return end

            for i = 1, NUM_CLIPS_TO_DISPLAY do                -- всегда 9 строк
                local el     = ns.clipButtonElements[i]        -- кэш (Шаг 1)
                local button = el and el.button
                local clip   = button and button.clipData      -- актуальные данные

                if button and button:IsShown() and clip and clip.ts then
                    ------------------------------------------------------
                    -- 1) «Когда»
                    ------------------------------------------------------
                    local whenFS = el.whenText
                    whenFS:SetText(formatWhen(clip))

                    if clip.playedTime and clip.level then
                        local r,g,b = ns.GetPlayedTimeColor(clip.playedTime, clip.level)
                        whenFS:SetTextColor(r,g,b,.7)
                    else
                        whenFS:SetTextColor(.6,.6,.6,.5)
                    end

                    ------------------------------------------------------
                    -- 2) Подсветка новых клипов (меньше 60 с)
                    ------------------------------------------------------
                    local age = GetServerTime() - clip.ts
                    if age < 60 and not frame._highlightedClips[clip.id] then
                        frame._highlightedClips[clip.id] = true

                        if button.glow  then button.glow.animation:Play()  end
                        if button.shine then button.shine.animation:Play() end
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

local MAX_DEATH_CAUSE_LEN = 45 -- Adjust based on your UI space for the clip text

local function UpdateClipEntry(state, i, offset, elements, clip, ratingsFromParent_unused, numBatchClips_unused, totalClips_unused, forceFullUpdate)
    local button = elements.button
    local ratingFrame = elements.rating

    if button.displayedClipID ~= clip.id or forceFullUpdate then
        button.displayedClipID = clip.id
        -- button.clipData is already set by OFAuctionFrameDeathClips_Update

        ResizeEntry(button, #OFAuctionFrameDeathClips.currentDisplayableClips, #OFAuctionFrameDeathClips.currentDisplayableClips) -- ResizeEntry needs definition

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
        if nameFS:GetText() ~= newNameText then nameFS:SetText(newNameText) end
        local clr = RAID_CLASS_COLORS[clip.class] or { r = .85, g = .85, b = .85 }
        local curR, curG, curB = nameFS:GetTextColor()
        if not curR or curR ~= clr.r or not curG or curG ~= clr.g or not curB or curB ~= clr.b then nameFS:SetTextColor(clr.r, clr.g, clr.b) end

        -- ===== RACE =====
        local newRaceText = clip.race or L["Unknown"]
        if GetLocale() == "ruRU" and ns.isCompletedTabActive then -- ns.isCompletedTabActive needs to be set by tab click
            if newRaceText == "Ночноро\nждённый" then newRaceText = "Ночнорождённый"
            elseif newRaceText == "Озар. дреней" then newRaceText = "Озарённый дреней"
            elseif newRaceText == "Дворф Ч. Железа" then newRaceText = "Дворф Чёрного Железа" end
        end
        if raceFS:GetText() ~= newRaceText then raceFS:SetText(newRaceText) end
        local rF,gF,bF = 0.9, 0.9, 0.4
        if clip.faction == "Horde" then rF,gF,bF = 0.8, 0.3, 0.3
        elseif clip.faction == "Alliance" then rF,gF,bF = 0.4, 0.6, 1 end
        local curRF, curGF, curBF = raceFS:GetTextColor()
        if not curRF or curRF ~= rF or not curGF or curGF ~= gF or not curBF or curBF ~= bF then raceFS:SetTextColor(rF,gF,bF) end

        -- ===== CLASS ICON =====
        local newTexture = "Interface\\Icons\\INV_Misc_QuestionMark"
        local newCoords = {0, 1, 0, 1}
        if clip.class and CLASS_ICON_TCOORDS[clip.class] then
            newTexture = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
            newCoords = CLASS_ICON_TCOORDS[clip.class]
        end
        if iconTexture:GetTexture() ~= newTexture then iconTexture:SetTexture(newTexture) end
        iconTexture:SetTexCoord(unpack(newCoords))

        -- ===== LEVEL =====
        local lvl = clip.level or 1
        local q = GetQuestDifficultyColor(lvl)
        levelFS:SetFormattedText("|cff%02x%02x%02x%d|r", q.r * 255, q.g * 255, q.b * 255, lvl)

        -- ===== CLASS TEXT =====
        local key = clip.class and string.upper(clip.class) or "UNKNOWN"
        local newClassText = LOCALIZED_CLASS_NAMES_MALE[key] or clip.class or L["Unknown"]
        if GetLocale() == "ruRU" and not ns.isCompletedTabActive then
            if key == "WARLOCK" then newClassText = "Варлок"
            elseif key == "ROGUE" then newClassText = "Разбойник" end
        end
        if classFS:GetText() ~= newClassText then classFS:SetText(newClassText) end
        local cc = RAID_CLASS_COLORS[key] or { r = 1, g = 1, b = 1 }
        local curCCR, curCCG, curCCB = classFS:GetTextColor()
        if not curCCR or curCCR ~= cc.r or not curCCG or curCCG ~= cc.g or not curCCB or curCCB ~= cc.b then classFS:SetTextColor(cc.r, cc.g, cc.b) end

        -- ===== WHERE =====
        if whereFS then -- Check if whereFS exists
            whereFS:SetJustifyH("LEFT")
            local zone = (clip.mapId and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(clip.mapId) and C_Map.GetMapInfo(clip.mapId).name) or clip.where or L["Unknown"]
            if zone == "Полуостров Адского Пламени" then zone = "Полуостров\nАдского Пламени" end
            if whereFS:GetText() ~= zone then whereFS:SetText(zone) end
        end

        -- ===== CAUSE / MOB LEVEL (Clip Text) =====
        local causeId = clip.causeCode or 0
        local newClipDisplayText = ""
        local newMobLevelText = ""
        local mr, mg, mb = 0,0,0

        if causeId == 7 and clip.deathCause and clip.deathCause ~= "" then
            local mobLvl = clip.mobLevel or 0
            local playerLvl = lvl
            local diff = mobLvl - playerLvl
            mr, mg, mb = 0, 1, 0
            if diff >= 4 then mr, mg, mb = 1, 0, 0
            elseif diff >= 2 then mr, mg, mb = 1, .5, 0
            elseif diff >= -1 then mr, mg, mb = 1, 1, 0
            elseif diff >= -4 then mr, mg, mb = 0, 1, 0
            else mr, mg, mb = .5, .5, .5 end

            local displayDeathCause = clip.deathCause
            if string.len(displayDeathCause) > MAX_DEATH_CAUSE_LEN then
                displayDeathCause = string.sub(displayDeathCause, 1, MAX_DEATH_CAUSE_LEN - 3) .. "..."
            end
            newClipDisplayText = string.format("|cFF%02X%02X%02X%s|r", mr * 255, mg * 255, mb * 255, displayDeathCause)
            newMobLevelText = tostring(mobLvl)
            local curMobR, curMobG, curMobB = mobLevelFS:GetTextColor()
            if not curMobR or curMobR ~= mr or not curMobG or curMobG ~= mg or not curMobB or curMobB ~= mb then
                mobLevelFS:SetTextColor(mr, mg, mb, 200/255)
            end
        else
            newClipDisplayText = "|cFFFFFFFF" .. (ns.DeathCauseByID[causeId] or "Неизвестно") .. "|r"
            newMobLevelText = ""
        end

        if clipTextFS:GetText() ~= newClipDisplayText then clipTextFS:SetText(newClipDisplayText) end
        if mobLevelFS:GetText() ~= newMobLevelText then mobLevelFS:SetText(newMobLevelText) end
        if mobLevelFS.SetJustifyH then mobLevelFS:SetJustifyH("CENTER") end

        -- ===== COMPLETED TIMER (also uses clipTextFS) =====
        local gameFontNormalLarge = _G.GameFontNormalLarge -- Assuming GameFontNormalLarge is a global font object
        local gameFontNormal = _G.GameFontNormal       -- Assuming GameFontNormal is a global font object

        if clip.completed then
            if gameFontNormalLarge and clipTextFS:GetFontObject() ~= gameFontNormalLarge then clipTextFS:SetFontObject(gameFontNormalLarge) end
            if clip.playedTime then
                local s = clip.playedTime
                local completedText = string.format("%dд %dч %dм %дс", -- Changed %dс for seconds from Russian 'м'
                        math.floor(s / 86400), math.floor(s % 86400 / 3600),
                        math.floor(s % 3600 / 60), s % 60)
                if clipTextFS:GetText() ~= completedText then clipTextFS:SetText(completedText) end
            elseif clipTextFS:GetText() ~= "Грузится" then -- "Loading" in Russian
                clipTextFS:SetText("Грузится")
            end
        else
            if gameFontNormal and clipTextFS:GetFontObject() ~= gameFontNormal then clipTextFS:SetFontObject(gameFontNormal) end
            if clipTextFS:GetText() ~= newClipDisplayText then clipTextFS:SetText(newClipDisplayText) end
        end
    end

    -- ===== RATING WIDGET (Always update) =====
    if ratingFrame and ratingFrame.SetReactions then
        if clip and clip.id then
            local currentReactions = ns.GetTopReactions(clip.id, 1) -- ns.GetTopReactions needs to be defined
            ratingFrame:SetReactions(currentReactions)
        else
            ratingFrame:SetReactions(nil)
        end
    end

    -- ===== ХАЙЛАЙТ (Highlight - Always update) =====
    if OFAuctionFrameDeathClips.openedPromptClipID == clip.id then
        button:LockHighlight()
    else
        button:UnlockHighlight()
    end
end

local function FilterHiddenClips(state, clips)
    return clips   -- overrides больше нет → ничего не скрываем
end


function OFAuctionFrameDeathClips_Update()
    local frame = OFAuctionFrameDeathClips
    if not frame then return end -- Safety

    local state = ns.GetDeathClipReviewState()
    local ratingsByClip = state and state:GetRatingsByClip() or {}

    -- Use our INTERNALLY managed sort state, which was set by the hook
    local currentSortKey = frame.clipsSortKey
    local currentSortAscending = frame.clipsSortAscending

    print(string.format("DEBUG_UPDATE_ENTRY: Tab: %s, CurrentInternalSort: Key=%s, Asc=%s. NeedsRefresh: %s. ns.isCompletedTabActive: %s",
            tostring(frame.currentSubTab), tostring(currentSortKey), tostring(currentSortAscending), tostring(frame.needsDataRefresh), tostring(ns and ns.isCompletedTabActive)))

    local forceFullRowUpdate = false
    if frame.needsDataRefresh then
        print("DEBUG_UPDATE: needsDataRefresh is true. Refreshing full clip data.")

        local rawPool = ns.GetLiveDeathClips and ns.GetLiveDeathClips() or {}
        local pool = ns.FilterClipsThisRealm and ns.FilterClipsThisRealm(rawPool) or {}
        local tempClips = {}

        if frame.currentSubTab == "completed" then
            -- print("DEBUG_UPDATE: Filtering for COMPLETED clips.")
            for _, clip in ipairs(pool) do
                if clip.completed then table.insert(tempClips, clip) end
            end
        else -- "live" or default
            -- print("DEBUG_UPDATE: Filtering for LIVE clips.")
            for _, clip in ipairs(pool) do
                if not clip.completed then table.insert(tempClips, clip) end
            end
        end
        print(string.format("DEBUG_UPDATE: Filtered %d clips for tab '%s'.", #tempClips, frame.currentSubTab))

        local sortParamsForSortFunction
        if currentSortKey then
            -- Remember: your sorter uses 'reverse'. If ascending is true, reverse is false.
            sortParamsForSortFunction = {{column = currentSortKey, reverse = not currentSortAscending}}
        else
            sortParamsForSortFunction = {{column = "when", reverse = true}}
            print("DEBUG_UPDATE: currentSortKey was nil, defaulting to 'when' descending.")
        end

        print(string.format("DEBUG_UPDATE: About to sort %d clips. Sort Key: %s, Sort Ascending (from internal state): %s -> reverse: %s. (ns.isCompletedTabActive: %s)",
                #tempClips, tostring(currentSortKey), tostring(currentSortAscending), tostring(sortParamsForSortFunction[1].reverse), tostring(ns and ns.isCompletedTabActive)))

        if ns.SortDeathClips then
            tempClips = ns.SortDeathClips(tempClips, sortParamsForSortFunction)
        else
            print("DEBUG_UPDATE: ns.SortDeathClips not found!")
        end
        print(string.format("DEBUG_UPDATE: Sorting done. Resulting clips: %d", #tempClips))

        frame.currentDisplayableClips = tempClips
        frame.needsDataRefresh = false -- Reset the flag AFTER processing
        forceFullRowUpdate = true

        -- Resetting page/offset is done by the SetSort hook or if explicitly needed on data change
        -- FauxScrollFrame_SetOffset(OFDeathClipsScroll, 0)
        -- if OFDeathClipsScrollScrollBar then OFDeathClipsScrollScrollBar:SetValue(0) end
    end

    local clipsToDisplay = frame.currentDisplayableClips or {}
    local totalClips = #clipsToDisplay
    local offset = (OFDeathClipsScroll and FauxScrollFrame_GetOffset(OFDeathClipsScroll)) or 0

    if updateSortArrows then updateSortArrows() end

    local numActuallyDisplayed = 0
    for i = 1, NUM_CLIPS_TO_DISPLAY do
        local buttonElements = ns.clipButtonElements and ns.clipButtonElements[i]

        if buttonElements then
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

                local ratingsForThisClip = (clip.id and ratingsByClip and ratingsByClip[clip.id]) or {}

                if ns.TryExcept then
                    ns.TryExcept(
                            function()
                                UpdateClipEntry(state, i, offset, buttonElements, clip, ratingsForThisClip, totalClips, totalClips, forceFullRowUpdate)
                            end,
                            function(err)
                                button:Hide()
                                if ns.DebugLog then ns.DebugLog("Error updating clip entry for clip.id " .. tostring(clip and clip.id) .. ": " .. err) end
                            end
                    )
                else -- No TryExcept, call directly
                    UpdateClipEntry(state, i, offset, buttonElements, clip, ratingsForThisClip, totalClips, totalClips, forceFullRowUpdate)
                end
            end
        else
            -- ns.DebugLog(addonName .. ": Warning - ns.clipButtonElements[" .. i .. "] is nil in _Update.")
        end
    end

    if OFDeathClipsScroll then FauxScrollFrame_Update(OFDeathClipsScroll, totalClips, NUM_CLIPS_TO_DISPLAY, CLIPS_BUTTON_HEIGHT) end

    if totalClips > NUM_CLIPS_TO_DISPLAY then
        if OFDeathClipsPrevPageButton then OFDeathClipsPrevPageButton:SetEnabled(offset > 0) end
        if OFDeathClipsNextPageButton then OFDeathClipsNextPageButton:SetEnabled(offset + NUM_CLIPS_TO_DISPLAY < totalClips) end

        if OFDeathClipsSearchCountText then
            OFDeathClipsSearchCountText:Show()
            local itemsMin = offset + 1
            local itemsMax = offset + numActuallyDisplayed
            if NUMBER_OF_RESULTS_TEMPLATE then
                OFDeathClipsSearchCountText:SetFormattedText(NUMBER_OF_RESULTS_TEMPLATE, itemsMin, itemsMax, totalClips)
            else
                OFDeathClipsSearchCountText:SetText(itemsMin .. "-" .. itemsMax .. " / " .. totalClips)
            end
        end
    else
        if OFDeathClipsPrevPageButton then OFDeathClipsPrevPageButton:Disable() end
        if OFDeathClipsNextPageButton then OFDeathClipsNextPageButton:Disable() end
        if OFDeathClipsSearchCountText then OFDeathClipsSearchCountText:Hide() end
    end
    -- print(string.format("DEBUG_UPDATE_END: Offset: %d, TotalClips: %d, Displayed: %d", offset, totalClips, numActuallyDisplayed))
end

function OFDeathClipsRatingWidget_OnLoad(self)
    -- Create single large icon texture
    local icon = self:CreateTexture(nil, "ARTWORK")
    icon:SetSize(40, 26) -- fill most of the rating column
    icon:SetPoint("LEFT", self, "LEFT", 0, 0)
    icon:Hide()

    -- Общая обрезка
    icon:SetTexCoord(0.1, 0.9, 0.34, 0.74)
    icon:SetVertexColor(0.5, 0.5, 0.5) -- slightly dimmed, full color


    -- Create count text overlaid on icon
    local count = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    count:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    count:SetTextColor(1, 1, 1, 0.6)
    count:SetPoint("TOPLEFT", icon, "BOTTOMRIGHT", -12, 6)
    count:Hide()

    -- Store references
    self.reactionIcon = icon
    self.reactionCount = count

    -- Assign SetReactions function
    function self:SetReactions(data)
        local paths = {
            [1] = "Interface\\AddOns\\GoAgainAH\\Media\\laugh_64x64.tga",
            [2] = "Interface\\AddOns\\GoAgainAH\\Media\\frozen_64x64.tga",
            [3] = "Interface\\AddOns\\GoAgainAH\\Media\\clown_64x64.tga",
            [4] = "Interface\\AddOns\\GoAgainAH\\Media\\fire_64x64.tga",
        }

        if data and data[1] then
            local id = data[1].id

            -- Спецпозиции и обрезки
            if id == 3 then
                -- 🤡 Клоун: немного вверх
                icon:SetTexCoord(0.1, 0.9, 0.30, 0.72)

            elseif id == 4 then
                -- 🔥 Огонь: обрезать до самого верха
                icon:SetTexCoord(0.1, 0.9, 0.12, 0.66)

            else
                -- Остальные по центру
                icon:SetTexCoord(0.1, 0.9, 0.24, 0.78)
            end

            local countValue = data[1].count
            local path = paths[id]

            self.reactionIcon:SetTexture(path)
            self.reactionIcon:Show()

            self.reactionCount:SetText(countValue)
            self.reactionCount:Show()
        else
            self.reactionIcon:Hide()
            self.reactionCount:Hide()
        end
    end
end

function OFAuctionFrameDeathClips_OnHide()
    if OFAuctionFrameDeathClips._whenUpdateTicker then
        OFAuctionFrameDeathClips._whenUpdateTicker:Cancel()
        OFAuctionFrameDeathClips._whenUpdateTicker = nil
    end
end