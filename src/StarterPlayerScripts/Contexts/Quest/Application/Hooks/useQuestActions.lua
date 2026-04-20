--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

--[=[
	@function useQuestActions
	@within useQuestActions
	Write hook that exposes quest mutation actions.
	Does NOT subscribe to any atom — component will not re-render from this hook.
	@return { departOnQuest: (zoneId: string, partyAdventurerIds: { string }) -> Result<void>, fleeExpedition: () -> Result<void> }
]=]
local function useQuestActions()
	return {
		departOnQuest = function(zoneId: string, partyAdventurerIds: { string })
			return Knit.GetController("QuestController"):DepartOnQuest(zoneId, partyAdventurerIds)
		end,

		fleeExpedition = function()
			return Knit.GetController("QuestController"):FleeExpedition()
		end,

		acknowledgeExpedition = function()
			return Knit.GetController("QuestController"):AcknowledgeExpedition()
		end,

		useExpeditionConsumable = function(slotIndex: number, targetNpcId: string)
			return Knit.GetController("QuestController"):UseExpeditionConsumable(slotIndex, targetNpcId)
		end,
	}
end

return useQuestActions
