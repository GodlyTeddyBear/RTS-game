--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type TOrganizationState = {
	MatchObjectName: string,
	DestinationFolderName: string,
	SelectedPresetLabel: string?,
	SelectedChildName: string?,
	AvailableChildNames: { string },
}

local organizationAtom = Charm.atom({
	MatchObjectName = "",
	DestinationFolderName = "",
	SelectedPresetLabel = nil,
	SelectedChildName = nil,
	AvailableChildNames = {},
} :: TOrganizationState)

local OrganizationAtom = {}

function OrganizationAtom.GetAtom()
	return organizationAtom
end

function OrganizationAtom.GetState(): TOrganizationState
	return organizationAtom()
end

function OrganizationAtom.SetMatchObjectName(matchObjectName: string)
	local state = organizationAtom()
	organizationAtom({
		MatchObjectName = matchObjectName,
		DestinationFolderName = state.DestinationFolderName,
		SelectedPresetLabel = state.SelectedPresetLabel,
		SelectedChildName = state.SelectedChildName,
		AvailableChildNames = state.AvailableChildNames,
	})
end

function OrganizationAtom.SetDestinationFolderName(destinationFolderName: string)
	local state = organizationAtom()
	organizationAtom({
		MatchObjectName = state.MatchObjectName,
		DestinationFolderName = destinationFolderName,
		SelectedPresetLabel = state.SelectedPresetLabel,
		SelectedChildName = state.SelectedChildName,
		AvailableChildNames = state.AvailableChildNames,
	})
end

function OrganizationAtom.SetSelectedPresetLabel(selectedPresetLabel: string?)
	local state = organizationAtom()
	organizationAtom({
		MatchObjectName = state.MatchObjectName,
		DestinationFolderName = state.DestinationFolderName,
		SelectedPresetLabel = selectedPresetLabel,
		SelectedChildName = state.SelectedChildName,
		AvailableChildNames = state.AvailableChildNames,
	})
end

function OrganizationAtom.SetSelectedChildName(selectedChildName: string?)
	local state = organizationAtom()
	organizationAtom({
		MatchObjectName = state.MatchObjectName,
		DestinationFolderName = state.DestinationFolderName,
		SelectedPresetLabel = state.SelectedPresetLabel,
		SelectedChildName = selectedChildName,
		AvailableChildNames = state.AvailableChildNames,
	})
end

function OrganizationAtom.SetAvailableChildNames(availableChildNames: { string })
	local state = organizationAtom()
	local selectedChildName = state.SelectedChildName
	if selectedChildName ~= nil then
		local hasSelected = false
		for _, childName in availableChildNames do
			if childName == selectedChildName then
				hasSelected = true
				break
			end
		end
		if not hasSelected then
			selectedChildName = nil
		end
	end

	organizationAtom({
		MatchObjectName = state.MatchObjectName,
		DestinationFolderName = state.DestinationFolderName,
		SelectedPresetLabel = state.SelectedPresetLabel,
		SelectedChildName = selectedChildName,
		AvailableChildNames = availableChildNames,
	})
end

return OrganizationAtom
