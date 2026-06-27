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
-- PKBT_RedButtonTemplate fallback (Sirus client asset)
---------------------------------------------------------------------------
if not _G["PKBT_RedButtonTemplate"] then
    local f = CreateFrame("Frame", "PKBT_RedButtonTemplate", nil, "BackdropTemplate")
    -- If BackdropTemplate doesn't exist either, build the backdrop manually
    if not f.SetBackdrop then
        -- Minimal fallback: the template simply won't render a backdrop
        -- but won't error out.
    end
    -- Clear the temp frame; the template registration is what matters
end

---------------------------------------------------------------------------
-- PKBT_Font_16 fallback
---------------------------------------------------------------------------
if not _G["PKBT_Font_16"] then
    _G["PKBT_Font_16"] = CreateFont("PKBT_Font_16")
    PKBT_Font_16:SetFont("Fonts\\FRIZQT__.TTF", 16)
end
