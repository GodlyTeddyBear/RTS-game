--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local NPCCommandTypes = require(script.Parent.Parent.Parent.Types.NPCCommandTypes)

--[[
	Write hook that exposes NPC command mutation actions.
	Does NOT subscribe to any atom — no re-renders triggered by this hook.
]]
local function useNPCCommandActions()
	local function issueCommand(commandType: NPCCommandTypes.TCommandType)
		local controller = Knit.GetController("NPCCommandController")
		if not controller then
			return
		end
		controller:IssueCommand(commandType)
	end

	local function setActiveMode(key: string?)
		local controller = Knit.GetController("NPCCommandController")
		if not controller then
			return
		end
		controller:SetActiveMode(key)
	end

	local function toggleMode()
		local controller = Knit.GetController("NPCCommandController")
		if not controller then
			return
		end
		controller:SwitchModeForAll()
	end

	local function closePanel()
		local controller = Knit.GetController("NPCCommandController")
		if not controller then
			return
		end
		controller:ClearSelection()
	end

	local function selectAll()
		local controller = Knit.GetController("NPCCommandController")
		if not controller then
			return
		end
		controller:SelectAll()
	end

	local function selectOnly(npcId: string)
		local controller = Knit.GetController("NPCCommandController")
		if not controller then
			return
		end
		controller:SelectOnly(npcId)
	end

	local function deselectNPC(npcId: string)
		local controller = Knit.GetController("NPCCommandController")
		if not controller then
			return
		end
		controller:DeselectNPC(npcId)
	end

	local function toggleRosterUnit(npcId: string)
		local controller = Knit.GetController("NPCCommandController")
		if not controller then
			return
		end
		controller:ToggleRosterUnit(npcId)
	end

	local function clearTargetedHighlights()
		local controller = Knit.GetController("NPCCommandController")
		if not controller then
			return
		end
		controller:ClearTargetedHighlights()
	end

	local function useConsumable(slotIndex: number, targetNpcId: string)
		local questController = Knit.GetController("QuestController")
		if not questController then
			return
		end
		return questController:UseExpeditionConsumable(slotIndex, targetNpcId)
	end

	return {
		issueCommand = issueCommand,
		useConsumable = useConsumable,
		setActiveMode = setActiveMode,
		toggleMode = toggleMode,
		clearTargetedHighlights = clearTargetedHighlights,
		closePanel = closePanel,
		selectAll = selectAll,
		selectOnly = selectOnly,
		deselectNPC = deselectNPC,
		toggleRosterUnit = toggleRosterUnit,
	}
end

return useNPCCommandActions
