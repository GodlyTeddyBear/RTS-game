--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local PluginTypes = require(script.Parent.Parent.Parent.Parent.Types.PluginTypes)

type TSelectionSummary = PluginTypes.TSelectionSummary

export type TBuildingState = {
	SelectionSummary: TSelectionSummary,
	FolderName: string,
}

local buildingAtom = Charm.atom({
	SelectionSummary = {
		Count = 0,
		Names = {},
	} :: TSelectionSummary,
	FolderName = "",
} :: TBuildingState)

local BuildingAtom = {}

function BuildingAtom.GetAtom()
	return buildingAtom
end

function BuildingAtom.GetState(): TBuildingState
	return buildingAtom()
end

function BuildingAtom.SetSelectionSummary(selectionSummary: TSelectionSummary)
	local state = buildingAtom()
	buildingAtom({
		SelectionSummary = selectionSummary,
		FolderName = state.FolderName,
	})
end

function BuildingAtom.SetFolderName(folderName: string)
	local state = buildingAtom()
	buildingAtom({
		SelectionSummary = state.SelectionSummary,
		FolderName = folderName,
	})
end

return BuildingAtom
