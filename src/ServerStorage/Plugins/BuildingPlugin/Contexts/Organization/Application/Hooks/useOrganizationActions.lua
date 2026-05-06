--!strict

local AppAtom = require(script.Parent.Parent.Parent.Parent.App.Infrastructure.AppAtom)
local usePluginServices = require(script.Parent.Parent.Parent.Parent.App.Infrastructure.usePluginServices)
local OrganizationAtom = require(script.Parent.Parent.Parent.Infrastructure.OrganizationAtom)

local function useOrganizationActions()
	local services = usePluginServices()

	local function applyResult(result)
		AppAtom.SetStatus(result.Message, if result.Success then "Success" else "Error")
	end

	return {
		SetMatchObjectName = function(matchObjectName: string)
			OrganizationAtom.SetMatchObjectName(matchObjectName)
		end,
		SetDestinationFolderName = function(destinationFolderName: string)
			OrganizationAtom.SetDestinationFolderName(destinationFolderName)
		end,
		SetSelectedChildName = function(selectedChildName: string?)
			OrganizationAtom.SetSelectedChildName(selectedChildName)
			if selectedChildName ~= nil then
				OrganizationAtom.SetMatchObjectName(selectedChildName)
				local state = OrganizationAtom.GetState()
				local normalizedDestination = string.gsub(state.DestinationFolderName, "^%s*(.-)%s*$", "%1")
				if normalizedDestination == "" then
					OrganizationAtom.SetDestinationFolderName(selectedChildName)
				end
			end
		end,
		SetSelectedPresetLabel = function(selectedPresetLabel: string?)
			OrganizationAtom.SetSelectedPresetLabel(selectedPresetLabel)
		end,
		GroupChildrenByName = function()
			local state = OrganizationAtom.GetState()
			applyResult(services.Organization:GroupChildrenByName(state.MatchObjectName, state.DestinationFolderName))
		end,
		CreatePresetFolders = function()
			local selectedPresetLabel = OrganizationAtom.GetState().SelectedPresetLabel
			if selectedPresetLabel == nil then
				AppAtom.SetStatus("Select a preset group before creating folders.", "Error")
				return
			end

			applyResult(services.Organization:CreatePresetFolders(selectedPresetLabel))
		end,
	}
end

return useOrganizationActions
