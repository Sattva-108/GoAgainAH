local addonName, ns = ...

local function SetRoleButtonEnabled(button, enabled, hideDisabled)
    if enabled then
        button:Show()
        button:GetNormalTexture():SetDesaturated(false)
        button:GetNormalTexture():SetAlpha(1)

        if button.checkButton then
            button.checkButton:Enable()
        end
    elseif hideDisabled then
        button:Hide()
    else
        button:Show()
        button:GetNormalTexture():SetDesaturated(true)
        button:GetNormalTexture():SetAlpha(0.7)

        if button.checkButton then
            button.checkButton:Disable()
        end
    end
end

ns.GetRoleString = function(roles)
    if not roles then
        return nil
    end
    local text = ""
    if roles[1] then
        text = text .. "Healer"
    end
    if roles[2] then
        text = text .. (text ~= "" and ", " or "") .. "Tank"
    end
    if roles[3] then
        text = text .. (text ~= "" and ", " or "") .. "Dps"
    end

    if string.len(text) == 0 then
        return "(no roles selected)"
    end
    return text
end

ns.GetRoleSelections = function(roleFrame)
    if not roleFrame then
        return
    end

    return {
        roleFrame.roleButtons[1].checkButton:GetChecked(),
        roleFrame.roleButtons[2].checkButton:GetChecked(),
        roleFrame.roleButtons[3].checkButton:GetChecked(),
    }
end

ns.RoleButtonsToggleChecked = function(roleFrame, roles)
    if not roleFrame then
        return
    end

    -- heal
    roleFrame.roleButtons[1].checkButton:SetChecked((roles and roles[1]) or false)
    -- tank
    roleFrame.roleButtons[2].checkButton:SetChecked((roles and roles[2]) or false)
    -- dps
    roleFrame.roleButtons[3].checkButton:SetChecked((roles and roles[3]) or false)
end

ns.RoleButtonsToggleEnabled = function(roleFrame, enabled)
    if not roleFrame then
        return
    end

    -- Update button enabled states
    SetRoleButtonEnabled(roleFrame.roleButtons[1], enabled, false)
    SetRoleButtonEnabled(roleFrame.roleButtons[2], enabled, false)
    SetRoleButtonEnabled(roleFrame.roleButtons[3], enabled, false)
end

ns.RoleButtonsToggleVisible = function(roleFrame, roles)
    if not roleFrame then
        return
    end

    local healer = (roles and roles[1]) or false
    local tank = (roles and roles[2]) or false
    local dps = (roles and roles[3]) or false

    -- Update button enabled states
    SetRoleButtonEnabled(roleFrame.roleButtons[1], healer, true)
    SetRoleButtonEnabled(roleFrame.roleButtons[2], tank, true)
    SetRoleButtonEnabled(roleFrame.roleButtons[3], dps, true)

    -- update anchors so buttons are always right-aligned
    local lastVisible = nil

    -- DPS
    if dps then
        roleFrame.dpsButton:ClearAllPoints()
        roleFrame.dpsButton:SetPoint("TOP", 0, 0)
        lastVisible = roleFrame.dpsButton
    end

    -- Healer
    if healer then
        roleFrame.healButton:ClearAllPoints()
        if lastVisible then
            roleFrame.healButton:SetPoint("RIGHT", lastVisible, "LEFT", 2, 0)
        else
            roleFrame.healButton:SetPoint("TOP", 0, 0)
        end
        lastVisible = roleFrame.healButton
    end

    -- Tank
    if tank then
        roleFrame.tankButton:ClearAllPoints()
        if lastVisible then
            roleFrame.tankButton:SetPoint("RIGHT", lastVisible, "LEFT", 2, 0)
        else
            roleFrame.tankButton:SetPoint("TOP", 0, 0)
        end
    end
end
