local addonName, Addon = ...
local A = _G.FugaziBAGS or Addon or {}
_G.FugaziBAGS = A

-- Create a frame for handling events
local frame = CreateFrame("Frame")
A.TweaksFrame = frame

-- Register events for quest/gossip automation
frame:RegisterEvent("QUEST_GREETING")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_PROGRESS")
frame:RegisterEvent("QUEST_COMPLETE")
frame:RegisterEvent("GOSSIP_SHOW")

frame:SetScript("OnEvent", function(self, event, ...)
    -- If the option is disabled, do nothing
    if not A.GetOption("gphAutoQuestGossip") then return end
    
    -- If user is holding Shift key, bypass automation
    if IsShiftKeyDown() then return end

    if event == "QUEST_GREETING" then
        -- Multiple quests or gossip options
        local numAvailable = GetNumAvailableQuests()
        if numAvailable > 0 then
            SelectAvailableQuest(1)
            return
        end
        local numActive = GetNumActiveQuests()
        if numActive > 0 then
            SelectActiveQuest(1)
            return
        end

    elseif event == "QUEST_DETAIL" then
        -- Accepting quest details
        AcceptQuest()

    elseif event == "QUEST_PROGRESS" then
        -- Continuing quest progress
        if IsQuestCompletable() then
            CompleteQuest()
        end

    elseif event == "QUEST_COMPLETE" then
        -- Turning in the quest
        local choices = GetNumQuestChoices()
        if choices == 0 then
            GetQuestReward()
        elseif choices == 1 then
            GetQuestReward(1)
        end
        -- If choices > 1, do nothing so player can manually choose the reward

    elseif event == "GOSSIP_SHOW" then
        -- Gossip interface (can contain quests and gossip options)
        local numAvailable = GetNumGossipAvailableQuests()
        if numAvailable > 0 then
            SelectGossipAvailableQuest(1)
            return
        end

        local numActive = GetNumGossipActiveQuests()
        if numActive > 0 then
            SelectGossipActiveQuest(1)
            return
        end

        -- Auto-select first option only if there is exactly one gossip option
        local numOptions = GetNumGossipOptions()
        if numOptions == 1 then
            SelectGossipOption(1)
        end
    end
end)
