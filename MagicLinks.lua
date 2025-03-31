local _, ns = ...

ns.SPELL_ID_DEATH_CLIPS = 30882


ns.CreateMagicLink = function(spellID, label, color)
    color = color or "ff71d5ff"
    return "|c"..color.."|Hspell:"..spellID.."|h["..label.."]|h|r"
end

local function handleDeathClipsLink()
    local tab = ns.AUCTION_TAB_DEATH_CLIPS
    if OFAuctionFrame:IsShown() then
        OFAuctionFrameSwitchTab(tab)
    else
        OFAuctionFrame_OverrideInitialTab(tab)
        OFAuctionFrame:Show()
    end
end


ItemRefTooltip:HookScript("OnTooltipSetSpell", function(self)
    local _, tooltipSpellID = self:GetSpell()
    if tooltipSpellID == ns.SPELL_ID_DEATH_CLIPS then
        handleDeathClipsLink()
        self:Hide()
    end
end)


