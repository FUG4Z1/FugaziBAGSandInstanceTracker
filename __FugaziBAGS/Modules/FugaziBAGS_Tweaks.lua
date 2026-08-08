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

-- QUEST_GREETING: GetActiveTitle(i) -> title, isComplete (1/nil)
local function SelectFirstCompletableActiveGreeting()
    local n = GetNumActiveQuests() or 0
    for i = 1, n do
        local _, isComplete = GetActiveTitle(i)
        if isComplete then
            SelectActiveQuest(i)
            return true
        end
    end
    return false
end

-- GOSSIP_SHOW: GetGossipActiveQuests() packs title, level, isLowLevel, isComplete per quest
local function SelectFirstCompletableActiveGossip()
    local data = { GetGossipActiveQuests() }
    -- 4 return values per active quest on 3.3.5a
    local num = GetNumGossipActiveQuests() or 0
    for i = 1, num do
        local isComplete = data[(i - 1) * 4 + 4]
        if isComplete then
            SelectGossipActiveQuest(i)
            return true
        end
    end
    return false
end

frame:SetScript("OnEvent", function(self, event, ...)
    -- If the option is disabled, do nothing
    if not A.GetOption("gphAutoQuestGossip") then return end

    -- If user is holding Shift key, bypass automation
    if IsShiftKeyDown() then return end

    if event == "QUEST_GREETING" then
        -- Prefer ready turn-ins, then pickups. Never open incomplete actives
        -- (old code always used index 1 and preferred available first → stuck on grey quests).
        if SelectFirstCompletableActiveGreeting() then
            return
        end
        local numAvailable = GetNumAvailableQuests() or 0
        if numAvailable > 0 then
            SelectAvailableQuest(1)
            return
        end
        -- Incomplete-only greeting: leave list open for manual choice

    elseif event == "QUEST_DETAIL" then
        AcceptQuest()

    elseif event == "QUEST_PROGRESS" then
        if IsQuestCompletable() then
            CompleteQuest()
        else
            -- Safety: if we landed on an incomplete progress page, close it
            -- instead of sitting on a grey quest the player can't turn in.
            CloseQuest()
        end

    elseif event == "QUEST_COMPLETE" then
        local choices = GetNumQuestChoices()
        if choices == 0 then
            GetQuestReward()
        elseif choices == 1 then
            GetQuestReward(1)
        end
        -- If choices > 1, do nothing so player can manually choose the reward

    elseif event == "GOSSIP_SHOW" then
        -- Same priority as QUEST_GREETING: complete turn-ins → pickups → single gossip
        if SelectFirstCompletableActiveGossip() then
            return
        end

        local numAvailable = GetNumGossipAvailableQuests() or 0
        if numAvailable > 0 then
            SelectGossipAvailableQuest(1)
            return
        end

        -- Auto-select first option only if there is exactly one gossip option
        local numOptions = GetNumGossipOptions() or 0
        if numOptions == 1 then
            SelectGossipOption(1)
        end
        -- Incomplete actives + multi gossip: leave open for manual choice
    end
end)
