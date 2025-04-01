local addonName, ns = ...

local L = LibStub("AceLocale-3.0"):NewLocale("GoAgainAH", "esES", false, true)
local locale = GetLocale()

if locale ~= "esES" then
    return
end
if not L then
    print("warning: could not find locale", locale)
    return
end

ns.LocaleBuilder_esES = L

L["_locale"] = "esES"