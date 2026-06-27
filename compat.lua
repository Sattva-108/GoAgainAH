local addonName, ns = ...

---------------------------------------------------------------------------
-- C_Timer polyfill (backported from WoD 6.0, not in standard 3.3.5)
---------------------------------------------------------------------------
if not C_Timer then
    C_Timer = {}

    local tickers = {}
    local tickerID = 0

    function C_Timer:After(delay, callback)
        local frame = CreateFrame("Frame")
        local elapsed = 0
        frame:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if elapsed >= delay then
                self:SetScript("OnUpdate", nil)
                callback()
            end
        end)
        return frame
    end

    function C_Timer:NewTicker(interval, callback, iterations)
        iterations = iterations or 0 -- 0 = infinite
        tickerID = tickerID + 1
        local id = tickerID
        local remaining = iterations
        local elapsed = 0

        local ticker = {
            _cancelled = false,
            Cancel = function(self)
                self._cancelled = true
                tickers[id] = nil
            end,
        }
        tickers[id] = ticker

        local frame = CreateFrame("Frame")
        ticker._frame = frame

        frame:SetScript("OnUpdate", function(_, dt)
            if ticker._cancelled then
                frame:SetScript("OnUpdate", nil)
                return
            end
            elapsed = elapsed + dt
            if elapsed >= interval then
                elapsed = elapsed - interval
                callback(ticker)
                if ticker._cancelled then
                    frame:SetScript("OnUpdate", nil)
                    return
                end
                if iterations > 0 then
                    remaining = remaining - 1
                    if remaining <= 0 then
                        frame:SetScript("OnUpdate", nil)
                        tickers[id] = nil
                    end
                end
            end
        end)

        return ticker
    end
end

---------------------------------------------------------------------------
-- GameTooltip_SetTitle (retail helper, not in 3.3.5)
---------------------------------------------------------------------------
if not GameTooltip_SetTitle then
    function GameTooltip_SetTitle(tooltip, title, manualOrder)
        if not tooltip or not title then return end
        tooltip:AddLine(title, 1, 1, 1)
    end
end

---------------------------------------------------------------------------
-- CreateColor (retail helper, not in 3.3.5)
---------------------------------------------------------------------------
if not CreateColor then
    function CreateColor(r, g, b, a)
        local color = CreateFrame("Frame")
        color.r = r or 1
        color.g = g or 1
        color.b = b or 1
        color.a = a or 1
        color.colorStr = ("ff%02x%02x%02x"):format(
            math.floor(color.r * 255),
            math.floor(color.g * 255),
            math.floor(color.b * 255)
        )
        return color
    end
end

---------------------------------------------------------------------------
-- CreateFromMixins / Mixin (retail helpers, not in 3.3.5)
---------------------------------------------------------------------------
if not CreateFromMixins then
    function CreateFromMixins(...)
        local result = {}
        for i = 1, select("#", ...) do
            local mixin = select(i, ...)
            if mixin then
                for k, v in pairs(mixin) do
                    result[k] = v
                end
            end
        end
        return result
    end
end

if not Mixin then
    function Mixin(object, ...)
        for i = 1, select("#", ...) do
            local mixin = select(i, ...)
            if mixin then
                for k, v in pairs(mixin) do
                    object[k] = v
                end
            end
        end
        return object
    end
end

---------------------------------------------------------------------------
-- MoneyFrame polyfills (not in some 3.3.5 clients)
---------------------------------------------------------------------------
if not MoneyFrame_SetMaxDisplayWidth then
    function MoneyFrame_SetMaxDisplayWidth() end
end

---------------------------------------------------------------------------
-- C_AuctionHouse stub (retail namespace, not in 3.3.5)
---------------------------------------------------------------------------
if not C_AuctionHouse then
    C_AuctionHouse = {}
    function C_AuctionHouse.GetAuctionItemSubClasses()
        return {}
    end
end

---------------------------------------------------------------------------
-- SetNormalAtlas / SetHighlightAtlas / SetPushedAtlas polyfills
-- Retail texture atlas API, not in 3.3.5
---------------------------------------------------------------------------
do
    local mt = getmetatable(CreateFrame("Frame")) or {}
    local oldIndex = mt.__index

    local function AtlasFallback(self, atlas, ...)
        -- no-op on 3.3.5; atlas textures simply don't exist
    end

    -- Patch the Button metatable
    local btn = CreateFrame("Button")
    local btnMT = getmetatable(btn) or {}
    if not btnMT.__index then btnMT.__index = {} end
    if not btnMT.__index.SetNormalAtlas then
        btnMT.__index.SetNormalAtlas = AtlasFallback
    end
    if not btnMT.__index.SetHighlightAtlas then
        btnMT.__index.SetHighlightAtlas = AtlasFallback
    end
    if not btnMT.__index.SetPushedAtlas then
        btnMT.__index.SetPushedAtlas = AtlasFallback
    end
    if not btnMT.__index.SetDisabledAtlas then
        btnMT.__index.SetDisabledAtlas = AtlasFallback
    end

    -- Patch the Texture metatable
    local tex = CreateFrame("Frame"):CreateTexture()
    local texMT = getmetatable(tex) or {}
    if not texMT.__index then texMT.__index = {} end
    if not texMT.__index.SetAtlas then
        texMT.__index.SetAtlas = AtlasFallback
    end
end

---------------------------------------------------------------------------
-- PKBT_RedButtonTemplate fallback (Sirus client asset)
---------------------------------------------------------------------------
if not _G["PKBT_RedButtonTemplate"] then
    _G["PKBT_RedButtonTemplate"] = CreateFrame("Button", "PKBT_RedButtonTemplate")
end

---------------------------------------------------------------------------
-- PKBT_Font_16 fallback
---------------------------------------------------------------------------
if not _G["PKBT_Font_16"] then
    _G["PKBT_Font_16"] = CreateFont("PKBT_Font_16")
    PKBT_Font_16:SetFont("Fonts\\FRIZQT__.TTF", 16)
end
