local addonName, ns = ...

local L = ns.LocaleBuilder_enUS
if not L then
    return  -- null if locale is not set to enUS
end

L["_locale"] = "enUS"
L["warrior"] = "Warrior"
L["priest"] = "Priest"
L["shaman"] = "Shaman"
L["paladin"] = "Paladin"
L["rogue"] = "Rogue"
L["mage"] = "Mage"
L["warlock"] = "Warlock"
L["druid"] = "Druid"

L["dwarf"] = "Dwarf"
L["gnome"] = "Gnome"
L["human"] = "Human"
L["nightelf"] = "Night Elf"
L["night elf"] = "Night Elf"

L["orc"] = "Orc"
L["tauren"] = "Tauren"
L["troll"] = "Troll"
L["undead"] = "Undead"
