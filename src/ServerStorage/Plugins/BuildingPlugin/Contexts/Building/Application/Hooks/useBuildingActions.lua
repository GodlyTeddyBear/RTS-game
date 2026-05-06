--!strict

local AppAtom = require(script.Parent.Parent.Parent.Parent.App.Infrastructure.AppAtom)
local usePluginServices = require(script.Parent.Parent.Parent.Parent.App.Infrastructure.usePluginServices)
local BuildingAtom = require(script.Parent.Parent.Parent.Infrastructure.BuildingAtom)

local PROPERTY_ACTIONS = {
	AnchoredOn = function(services)
		return services.Property:SetAnchored(true)
	end,
	AnchoredOff = function(services)
		return services.Property:SetAnchored(false)
	end,
	CollideOn = function(services)
		return services.Property:SetCanCollide(true)
	end,
	CollideOff = function(services)
		return services.Property:SetCanCollide(false)
	end,
	QueryOn = function(services)
		return services.Property:SetCanQuery(true)
	end,
	QueryOff = function(services)
		return services.Property:SetCanQuery(false)
	end,
	TouchOn = function(services)
		return services.Property:SetCanTouch(true)
	end,
	TouchOff = function(services)
		return services.Property:SetCanTouch(false)
	end,
	Transparency0 = function(services)
		return services.Property:SetTransparency(0)
	end,
	Transparency25 = function(services)
		return services.Property:SetTransparency(0.25)
	end,
	Transparency50 = function(services)
		return services.Property:SetTransparency(0.5)
	end,
	Transparency100 = function(services)
		return services.Property:SetTransparency(1)
	end,
	MaterialPlastic = function(services)
		return services.Property:SetMaterial(Enum.Material.SmoothPlastic)
	end,
	MaterialConcrete = function(services)
		return services.Property:SetMaterial(Enum.Material.Concrete)
	end,
	MaterialMetal = function(services)
		return services.Property:SetMaterial(Enum.Material.Metal)
	end,
	ColorStone = function(services)
		return services.Property:SetColor(Color3.fromRGB(163, 162, 165), "Stone Grey")
	end,
	ColorWhite = function(services)
		return services.Property:SetColor(Color3.fromRGB(242, 243, 243), "White")
	end,
	ColorBlack = function(services)
		return services.Property:SetColor(Color3.fromRGB(17, 17, 17), "Black")
	end,
}

local function useBuildingActions()
	local services = usePluginServices()

	local function refreshSelectionSummary()
		BuildingAtom.SetSelectionSummary(services.Selection.GetSummary())
	end

	local function applyResult(result)
		AppAtom.SetStatus(result.Message, if result.Success then "Success" else "Error")
		refreshSelectionSummary()
	end

	return {
		RefreshSelectionSummary = refreshSelectionSummary,
		SetFolderName = function(folderName: string)
			BuildingAtom.SetFolderName(folderName)
		end,
		UseFolderPreset = function(folderName: string)
			BuildingAtom.SetFolderName(folderName)
			applyResult(services.Folder:WrapSelection(folderName))
		end,
		WrapSelection = function()
			applyResult(services.Folder:WrapSelection(BuildingAtom.GetState().FolderName))
		end,
		DuplicateSelection = function()
			applyResult(services.SelectionActions:DuplicateSelection())
		end,
		RunPropertyAction = function(actionName: string)
			local action = PROPERTY_ACTIONS[actionName]
			if action == nil then
				AppAtom.SetStatus("Unknown property action: " .. actionName .. ".", "Error")
				return
			end

			applyResult(action(services))
		end,
	}
end

return useBuildingActions
