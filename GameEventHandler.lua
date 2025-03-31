local _, ns = ...

local GameEventHandler = {
    frame = CreateFrame("Frame"),
    listeners = {}
}
GameEventHandler.frame:Hide()
ns.GameEventHandler = GameEventHandler

function GameEventHandler:On(event, callback)
    if not self.listeners[event] then
        self.listeners[event] = {}
        self.frame:RegisterEvent(event)
    end
    table.insert(self.listeners[event], callback)
end

GameEventHandler.frame:SetScript("OnEvent", function(self, event, ...)
    if GameEventHandler.listeners[event] then
        for _, callback in ipairs(GameEventHandler.listeners[event]) do
            local success, err = pcall(callback, ...)
            if not success then
                print(ChatPrefixError() .. " Error in game event handler for " .. event .. ": " .. err)
            end
        end
    end
end)

function GameEventHandler:Simulate(event, ...)
    if self.listeners[event] then
        for _, callback in ipairs(self.listeners[event]) do
            local success, err = pcall(callback, ...)
            if not success then
                print(ChatPrefixError() .. " Error in simulated game event handler for " .. event .. ": " .. err)
            end
        end
    end
end
