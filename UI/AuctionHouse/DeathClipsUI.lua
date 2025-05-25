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
    OFSortButton_UpdateArrow(OFDeathClipsOldLevelSort, "clips", "oldlevel")
    OFSortButton_UpdateArrow(OFDeathClipsOldClassSort, "clips", "oldclass")
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
            local q = GetQuestDifficultyColor(actualLevelForColor)
            levelFS:SetFormattedText("|cff%02x%02x%02x%d|r", q.r * 255, q.g * 255, q.b * 255, actualLevelForColor)
        end

        -- ===== OLD LEVEL =====
        if oldLevelFS then
            if columnVisibility["OldLevelText"] then
                oldLevelFS:Show()
                if clip.isReincarnated then
                    oldLevelFS:SetText(clip.oldLevel or "?")
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
                    local oldClassLocalizedName = (oldClassToken and LOCALIZED_CLASS_NAMES_MALE[oldClassToken]) or ""
                    local coloredOldClassText = oldClassLocalizedName
                    if oldClassToken and RAID_CLASS_COLORS[oldClassToken] then
                        local color = RAID_CLASS_COLORS[oldClassToken]
                        coloredOldClassText = string.format("|cff%02x%02x%02x%s|r", color.r*255, color.g*255, color.b*255, oldClassLocalizedName)
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
            whereFS:SetJustifyH("LEFT")
            local zone = clip.mapId and C_Map.GetMapInfo(clip.mapId).name or clip.where or L["Unknown"]
            if zone == "Полуостров Адского Пламени" then
                zone = "Полуостров\nАдского Пламени"
            end
            if whereFS:GetText() ~= zone then
                whereFS:SetText(zone)
            end
        end

        -- ===== CAUSE / MOB LEVEL / COMPLETED TIMER (Clip Text) =====
        -- All these use clipTextFS and mobLevelFS, controlled by the visibility of the "Clip" (CLIP_INFO column)
        if columnVisibility["Clip"] then
            local causeId = clip.causeCode or 0
            local newClipDisplayText = ""
            local newMobLevelText = ""
            local mr, mg, mb

            if clip.isReincarnated then
                -- For reincarnated, always show original death cause
                if clipTextFS:GetFontObject() ~= GameFontNormal then clipTextFS:SetFontObject("GameFontNormal") end

                if causeId == 7 and clip.deathCause and clip.deathCause ~= "" then
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
                else
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
            local cc = RAID_CLASS_COLORS[key] or { r = 1, g = 1, b = 1 }
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
        local pool = ns.FilterClipsThisRealm(rawPool) -- Base pool for LIVE and for finding original clips
        local tempClips = {}

        if ns.currentActiveTabId == "REINCARNATED_CLIPS" then
            if _G.AuctionHouseDBSaved and _G.AuctionHouseDBSaved.watchedFriends then -- Ensure global DB is used
                for playerNameLower, watchedEntry in pairs(_G.AuctionHouseDBSaved.watchedFriends) do
                    if watchedEntry.hasBeenNotifiedForThisAdd and watchedEntry.characterName then
                        -- Call the namespaced function
                        local _, isConnected, currentLevel, currentClassToken = ns.IsPlayerOnFriendsList(watchedEntry.characterName)

                        if currentLevel and currentClassToken then -- Friend still exists and info retrieved
                            local latestOriginalClip = nil
                            for _, clip in ipairs(pool) do -- Search in the 'pool' of live/non-completed clips
                                if string.lower(clip.characterName or "") == playerNameLower and not clip.completed then
                                    if not latestOriginalClip or (clip.ts and latestOriginalClip.ts and clip.ts > latestOriginalClip.ts) then
                                        latestOriginalClip = clip
                                    end
                                end
                            end

                            if latestOriginalClip then
                                local displayClip = {
                                    characterName = watchedEntry.characterName,
                                    level = currentLevel, -- 'level' for sorting will refer to newLevel
                                    newLevel = currentLevel,
                                    -- Assuming ns.russianClassNameToEnglishToken is available in ns
                                    newClassToken = (ns.russianClassNameToEnglishToken and ns.russianClassNameToEnglishToken[currentClassToken]) or currentClassToken,
                                    oldLevel = watchedEntry.clipLevel,
                                    oldClassToken = latestOriginalClip.class,

                                    id = latestOriginalClip.id,
                                    deathCause = latestOriginalClip.deathCause,
                                    causeCode = latestOriginalClip.causeCode,
                                    mobLevel = latestOriginalClip.mobLevel,
                                    ts = latestOriginalClip.ts, -- This is the original death timestamp
                                    -- rating = latestOriginalClip.rating, -- If rating is stored directly on clip
                                    mapId = latestOriginalClip.mapId, -- For 'where' if needed by helper
                                    where = latestOriginalClip.where, -- For 'where' if needed by helper
                                    faction = latestOriginalClip.faction,
                                    class = latestOriginalClip.class, -- Original class for color consistency if newClassToken is not used by nameFS
                                    -- Mark as reincarnated for potential specific handling in UpdateClipEntry
                                    isReincarnated = true
                                }
                                -- If ratings are fetched by clip.id, this will use original clip's rating
                                -- The 'rating' field in displayClip might be populated by UpdateClipEntry or here if available on latestOriginalClip
                                table.insert(tempClips, displayClip)
                            end
                        end
                    end
                end
            end
        elseif ns.currentActiveTabId == "COMPLETED_CLIPS" then
            -- Corrected logic for COMPLETED_CLIPS:
            -- tempClips is already initialized before this if/elseif/else block
            if pool then -- Check if pool is not nil (it's already realm-filtered)
                for _, clip in ipairs(pool) do -- Iterate 'pool'
                    if clip.completed then
                        table.insert(tempClips, clip)
                    end
                end
            end
        else -- Default to "LIVE_CLIPS"
            for _, clip in ipairs(pool) do -- 'pool' here is already non-completed clips
                if not clip.completed then -- This check is redundant if 'pool' is already filtered
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

-- (addonName and ns are assumed to be defined at the top of your file)
-- The large block of code related to saved variables, friend notifications,
-- tooltips, and event handling has been moved to DeathClipsAgain.lua


