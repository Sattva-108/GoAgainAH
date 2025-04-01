local addonName, ns = ...

local L = LibStub("AceLocale-3.0"):NewLocale("GoAgainAH", "esMX", false)
local locale = GetLocale()

if locale ~= "esMX" then
    return
end
if not L then
    print("warning: could not find locale esMX, please use Español (España). no se pudo encontrar el locale esMX, por favor use Español (España)")
    return
end

ns.LocaleBuilder_esMX = L

L["_locale"] = "esMX"