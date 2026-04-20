--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

--[[
	Write hook that exposes guild mutation actions.
	Does NOT subscribe to any atom — no re-renders from this hook.

	@return { hireAdventurer, equipItem, unequipItem }
]]
local function useGuildActions()
	return {
		hireAdventurer = function(adventurerType: string)
			return Knit.GetController("GuildController"):HireAdventurer(adventurerType)
		end,

		equipItem = function(adventurerId: string, slotType: string, inventorySlotIndex: number)
			return Knit.GetController("GuildController"):EquipItem(adventurerId, slotType, inventorySlotIndex)
		end,

		unequipItem = function(adventurerId: string, slotType: string)
			return Knit.GetController("GuildController"):UnequipItem(adventurerId, slotType)
		end,
	}
end

return useGuildActions
