local addonName, ns = ...

local max_rows = 25

local column_data = {
    {
        "Streamer",
        90,
        function(_entry, _server_name)
            return _entry["name"] or ""
        end,
    },
    {
        "Race",
        60,
        function(_entry, _server_name)
            if _entry["race_id"] == nil then
                return ""
            end
            local race_info = C_CreatureInfo.GetRaceInfo(_entry["race_id"])
            if race_info then
                return race_info.raceName or ""
            end
            return ""
        end,
    },
    {
        "Level",
        40,
        function(_entry, _server_name)
            return _entry["level"] or ""
        end,
    },
    {
        "Class",
        60,
        function(_entry, _server_name)
            if _entry["class_id"] == nil then
                return ""
            end
            local class_id = _entry["class_id"]
            local class_str, _, _ = GetClassInfo(class_id)
            if class_id then
                if ns.id_to_class[class_id] then
                    local class_color = RAID_CLASS_COLORS[ns.id_to_class[class_id]:upper()]
                    if class_color then
                        return "|c"
                                .. class_color
                                .. class_str
                                .. "|r"
                    end
                end
            end
            return class_str or ""
        end,
    },
    {
        "Avg. Viewers",
        60,
        function(_entry, _server_name)
            return _entry["viewers"] or ""
        end,
    },
    {
        "Livestream",
        120,
        function(_entry, _server_name)
            return _entry["livestream"] or ""
        end,
    }
}

local function createRow(i)
    local row = AceGUI:Create("InteractiveLabel")
    row:SetHighlight("Interface\\Glues\\CharacterSelect\\Glues-CharacterSelect-Highlight")
    row:SetFullWidth(true)
    row:SetHeight(20)
    row:SetLayout("Flow")
    scroll:AddChild(row)

    for j = 1, column_data do
        local column = column_data[j]
        local cell = AceGUI:Create("Label")
        cell:SetWidth(column[2])
        cell:SetHeight(20)
        cell:SetJustifyH("LEFT")
        cell:SetText(column[3](entry, server_name))
        row:AddChild(cell)
    end
    return row
end

local function createTable(name)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetHeight(440)

    for i = 1, max_rows do
        local row = createRow(i)
        scroll:SetScroll(0)
        scroll.scrollbar:Hide()
        scroll.AddChild(row)
    end
end