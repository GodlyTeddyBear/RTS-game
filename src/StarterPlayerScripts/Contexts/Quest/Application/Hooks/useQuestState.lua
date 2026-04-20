--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])

local useAtom = ReactCharm.useAtom

local questStateAtom = nil

--[=[
	@function useQuestState
	@within useQuestState
	Read hook that subscribes to the quest state atom.
	Component will re-render whenever quest state changes.
	@return TQuestState? -- Current quest state or nil if not yet hydrated
]=]
local function useQuestState()
	if questStateAtom == nil then
		local questController = Knit.GetController("QuestController")
		if not questController then
			warn("useQuestState: QuestController not available")
			return nil
		end
		questStateAtom = questController:GetQuestStateAtom()
	end
	return useAtom(questStateAtom)
end

return useQuestState
