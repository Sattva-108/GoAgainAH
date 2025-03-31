function ChatPrefix()
    -- color = "ffffcc00"
    return "|cffFF8000OnlyFangs AH|r"
end

function ChatPrefixError()
    -- color = "FFFF0000"
    return "|cFFFF0000OnlyFangs AH|r"
end

function CreatePlayerLink(playerName)
    return string.format("|Hplayer:%s|h[%s]|h", playerName, playerName)
end

function CreateAddonLink(menuName, displayText)
    return string.format("|Hathene:%s|h[%s]|h", menuName, menuName)
    --   newMsg = newMsg.."|Hgarrmission:weakauras|h|h|r";
end

function ChatUtils_Initialize()
    -- hooksecurefunc("SetItemRef", function(link, linkType, button, chatFrame)
    --     if link == "athene:main" then
    --         local _, myIdentifier, var1, var2 = strsplit(":", linkType)
    --         print(linkType, myIdentifier)
    --         -- return

    --         if linkType then
    --             -- Handle the click event here
    --             -- For example:
    --             print(linkType)
    --             return
    --         end
    --     end
    -- end)
end
