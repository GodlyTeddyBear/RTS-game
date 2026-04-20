--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local ECSRevealApplier = require(ServerScriptService.Infrastructure.ECSRevealApplier)

export type TBuildingRevealData = {
	BuildingType: string,
	Level: number,
	ZoneName: string,
	SlotIndex: number,
}

local BuildingRevealAdapter = {}
BuildingRevealAdapter.__index = BuildingRevealAdapter

export type TBuildingRevealAdapter = typeof(setmetatable({}, BuildingRevealAdapter))

function BuildingRevealAdapter.new(): TBuildingRevealAdapter
	return setmetatable({}, BuildingRevealAdapter)
end

function BuildingRevealAdapter:ApplyModel(model: Model, data: TBuildingRevealData)
	ECSRevealApplier.Apply(model, {
		Attributes = {
			BuildingType = data.BuildingType,
			BuildingLevel = data.Level,
			ZoneName = data.ZoneName,
			SlotIndex = data.SlotIndex,
		},
	})
end

function BuildingRevealAdapter:ApplyMachinePrompt(prompt: ProximityPrompt, zoneName: string, slotIndex: number)
	ECSRevealApplier.Apply(prompt, {
		Attributes = {
			MachineZone = zoneName,
			MachineSlot = slotIndex,
		},
	})
end

return BuildingRevealAdapter
