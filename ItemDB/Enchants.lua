local _, ns = ...

ns.SPELL_ITEM_CLASS_ID = 50
ns.MIN_ITEM_ID_SPELL = 1000000
ns.MAX_ITEM_ID_SPELL = 9999999

ns.IsSpellItem = function(itemID)
    return itemID >= ns.MIN_ITEM_ID_SPELL and itemID <= ns.MAX_ITEM_ID_SPELL
end

ns.ItemIDToSpellID = function(itemID)
    return itemID - ns.MIN_ITEM_ID_SPELL
end

ns.GetSpellItemInfo = function(itemID)
    local spellID = ns.ItemIDToSpellID(itemID)
    local name, rank, icon, castTime, minRange, maxRange = GetSpellInfo(spellID)
    local spellLink = GetSpellLink(spellID)
    return name, spellLink, 1, 0, 0, 0, 0, 1, "", icon, 0, ns.SPELL_ITEM_CLASS_ID, 0, 0, 0, 0, false
end

ns.GetSpellItemInfoInstant = function(itemID)
    local spellID = ns.ItemIDToSpellID(itemID)
    local _, _, icon, _, _, _ = GetSpellInfo(spellID)
    return itemID, "", "", "", icon, ns.SPELL_ITEM_CLASS_ID, 0
end

ns.ENCHANT_SPELL_IDS = {
    [20034]=1,
    [13898]=1,
    [13890]=1,
    [20025]=1,
    [22749]=1,
    [22750]=1,
    [13882]=1,
    [13947]=1,
    [20010]=1,
    [13941]=1,
    [20014]=1,
    [20012]=1,
    [20023]=1,
    [20008]=1,
    [20026]=1,
    [25080]=1,
    [20011]=1,
    [23800]=1,
    [20013]=1,
    [27837]=1,
    [20017]=1,
    [23804]=1,
    [20032]=1,
    [13661]=1,
    [13939]=1,
    [25079]=1,
    [23802]=1,
    [13943]=1,
    [20031]=1,
    [20036]=1,
    [13937]=1,
    [25084]=1,
    [20030]=1,
    [13948]=1,
    [25073]=1,
    [20015]=1,
    [20029]=1,
    [13693]=1,
    [13945]=1,
    [20020]=1,
    [20028]=1,
    [21931]=1,
    [13695]=1,
    [13815]=1,
    [13642]=1,
    [25078]=1,
    [13887]=1,
    [13698]=1,
    [13841]=1,
    [13935]=1,
    [13858]=1,
    [25082]=1,
    [13746]=1,
    [20009]=1,
    [25086]=1,
    [13653]=1,
    [13836]=1,
    [13657]=1,
    [25074]=1,
    [13536]=1,
    [7779]=1,
    [13915]=1,
    [7793]=1,
    [7786]=1,
    [23799]=1,
    [13648]=1,
    [20033]=1,
    [13501]=1,
    [13822]=1,
    [25072]=1,
    [13700]=1,
    [25081]=1,
    [23803]=1,
    [13419]=1,
    [13794]=1,
    [13868]=1,
    [13931]=1,
    [13655]=1,
    [13689]=1,
    [20035]=1,
    [13846]=1,
    [23801]=1,
    [13529]=1,
    [25083]=1,
    [13538]=1,
    [13620]=1,
    [7418]=1,
    [13522]=1,
    [20024]=1,
    [13503]=1,
    [7457]=1,
    [7745]=1,
    [13380]=1,
    [13917]=1,
    [13663]=1,
    [7867]=1,
    [13640]=1,
    [7857]=1,
    [13817]=1,
    [13607]=1,
    [7788]=1,
    [13626]=1,
    [13631]=1,
    [13622]=1,
    [13637]=1,
    [20016]=1,
    [13378]=1,
    [13617]=1,
    [13464]=1,
    [7426]=1,
    [13644]=1,
    [13646]=1,
    [13421]=1,
    [13612]=1,
    [7443]=1,
    [7863]=1,
    [13905]=1,
    [13635]=1,
    [7428]=1,
    [13687]=1,
    [7859]=1,
    [7861]=1,
    [13659]=1,
    [7782]=1,
    [7420]=1,
    [13933]=1,
    [7766]=1,
    [7771]=1,
    [7776]=1,
    [7454]=1,
    [13485]=1,
    [7748]=1,
}
local items = {}
for id, _ in pairs(ns.ENCHANT_SPELL_IDS) do
    local itemID = ns.MIN_ITEM_ID_SPELL + id
    local name = GetSpellInfo(id)
    items[itemID] = name
end
ns.AllItems[ns.SPELL_ITEM_CLASS_ID] = {
    -- subclass
    [0] = {
        -- equipSlot
        [0] = {
            -- quality
            [1] = {
                -- level
                [0] = items
            }
        }
    }
}
ns.ENCHANT_ITEMS = items