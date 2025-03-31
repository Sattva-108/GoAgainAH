local _, ns = ...

local POPUP_NAME = "OF_UPDATE_AVAILABLE"
ns.PREF_UPDATE_AVAILABLE_LAST_SHOWN_AT = "UPDATE_AVAILABLE_LAST_SHOWN_AT"

function OFGetUpdateUrl()
    return ns.GetConfig().updateAvailableUrl
end

StaticPopupDialogs[POPUP_NAME] = {
    text = "|cffffd100OnlyFangs AH|r\n|cffffffffUpdate Available. Please copy the link to update.|r",
    button1 = "Open Guild AH (5)",
    OnAccept = function()
        ns.PlayerPrefs:Set(ns.PREF_UPDATE_AVAILABLE_LAST_SHOWN_AT, time())
        OFAuctionFrame:Show()
    end,
    OnShow = function(self)
        self.editBox:SetText(OFGetUpdateUrl())
        self.editBox:SetCursorPosition(0)
        self.editBox:SetFocus()
        self.editBox:HighlightText()
        local seconds = 5
        self.button1:SetText("Open Guild AH ("..seconds..")")
        self.button1:Disable()
        C_Timer.NewTicker(1, function(ticker)
            seconds = max(0, seconds - 1)
            if seconds == 0 then
                self.button1:SetText("Open Guild AH")
                self.button1:Enable()
                ticker:Cancel()
            else
                self.button1:SetText("Open Guild AH ("..seconds..")")
            end
        end)
    end,
    EditBoxOnTextChanged = function(self)
        self:SetText(OFGetUpdateUrl())
        self:SetCursorPosition(0)
        self:HighlightText()
    end,
    hasEditBox = true,
    whileDead = true,
    hideOnEscape = true,
}

local function parseVersion(version)
    local major, minor, patch = string.split(".", version)
    -- strip potential pre release version
    patch = string.split("-", patch)
    -- strip potential build metadata
    patch = string.split("+", patch)

    return {
        major = tonumber(major),
        minor = tonumber(minor),
        patch = tonumber(patch),
    }
end

local function compareVersions(l, r)
    if l.major ~= r.major then
        return l.major - r.major
    end
    if l.minor ~= r.minor then
        return l.minor - r.minor
    end
    return l.patch - r.patch
end

ns.CompareVersions = function(l, r)
    return compareVersions(parseVersion(l), parseVersion(r))
end

local function compareVersionsExclPatch(l, r)
    if l.major ~= r.major then
        return l.major - r.major
    end
    return l.minor - r.minor
end

ns.CompareVersionsExclPatch = function(l, r)
    return compareVersionsExclPatch(parseVersion(l), parseVersion(r))
end

ns.GetLatestVersion = function(allVersionStrs)
    local maxVersion
    for versionStr, _  in pairs(allVersionStrs) do
        if not maxVersion then
            maxVersion = versionStr
        else
            local version = parseVersion(versionStr)
            if compareVersions(version, parseVersion(maxVersion)) > 0 then
                maxVersion = versionStr
            end
        end
    end
    return maxVersion
end

ns.ShowedUpdateAvailablePopupRecently = function()
    local lastShownAt = ns.PlayerPrefs:Get(ns.PREF_UPDATE_AVAILABLE_LAST_SHOWN_AT) or 0
    if not lastShownAt then
        return false
    end
    return time() - lastShownAt < ns.GetConfig().updateAvailableTimeout
end
ns.ShowUpdateAvailablePopup = function()
    StaticPopup_Show(POPUP_NAME)
end