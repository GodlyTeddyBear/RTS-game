--!strict

local PluginTypes = require(script.Parent.Parent.Parent.Parent.Parent.Types.PluginTypes)

type TPluginActionResult = PluginTypes.TPluginActionResult
type TPropertyTarget = BasePart | Decal | Texture

local PropertyService = {}
PropertyService.__index = PropertyService

function PropertyService.new(historyAdapter, selectionService)
	local self = setmetatable({}, PropertyService)
	self.History = historyAdapter
	self.Selection = selectionService
	return self
end

function PropertyService:SetAnchored(isAnchored: boolean): TPluginActionResult
	return self:_ApplyBasePartProperty("Set Anchored", "Anchored", isAnchored)
end

function PropertyService:SetCanCollide(canCollide: boolean): TPluginActionResult
	return self:_ApplyBasePartProperty("Set CanCollide", "CanCollide", canCollide)
end

function PropertyService:SetCanQuery(canQuery: boolean): TPluginActionResult
	return self:_ApplyBasePartProperty("Set CanQuery", "CanQuery", canQuery)
end

function PropertyService:SetCanTouch(canTouch: boolean): TPluginActionResult
	return self:_ApplyBasePartProperty("Set CanTouch", "CanTouch", canTouch)
end

function PropertyService:SetTransparency(transparency: number): TPluginActionResult
	local selectionRoots = self.Selection.GetSelectionRoots()
	if #selectionRoots == 0 then
		return self:_CreateResult(false, 0, 0, "Select at least one instance before changing transparency.")
	end

	local targets = self:_CollectTransparencyTargets(selectionRoots)
	if #targets == 0 then
		return self:_CreateResult(false, 0, #selectionRoots, "No selected instances support transparency.")
	end

	self.History:Run("Set Transparency", function()
		for _, target in targets do
			target.Transparency = transparency
		end
	end)

	return self:_CreateResult(true, #targets, 0, ("Set transparency to %.2f."):format(transparency))
end

function PropertyService:SetMaterial(material: Enum.Material): TPluginActionResult
	local baseParts = self:_CollectBaseParts(self.Selection.GetSelectionRoots())
	if #baseParts == 0 then
		return self:_CreateResult(false, 0, 0, "No selected parts support material changes.")
	end

	self.History:Run("Set Material", function()
		for _, basePart in baseParts do
			basePart.Material = material
		end
	end)

	return self:_CreateResult(true, #baseParts, 0, "Set material to " .. material.Name .. ".")
end

function PropertyService:SetColor(color: Color3, colorName: string): TPluginActionResult
	local baseParts = self:_CollectBaseParts(self.Selection.GetSelectionRoots())
	if #baseParts == 0 then
		return self:_CreateResult(false, 0, 0, "No selected parts support color changes.")
	end

	self.History:Run("Set Color", function()
		for _, basePart in baseParts do
			basePart.Color = color
		end
	end)

	return self:_CreateResult(true, #baseParts, 0, "Set color to " .. colorName .. ".")
end

function PropertyService:_ApplyBasePartProperty(
	waypointName: string,
	propertyName: "Anchored" | "CanCollide" | "CanQuery" | "CanTouch",
	propertyValue: boolean
): TPluginActionResult
	local baseParts = self:_CollectBaseParts(self.Selection.GetSelectionRoots())
	if #baseParts == 0 then
		return self:_CreateResult(false, 0, 0, "No selected parts support " .. propertyName .. ".")
	end

	self.History:Run(waypointName, function()
		for _, basePart in baseParts do
			if propertyName == "Anchored" then
				basePart.Anchored = propertyValue
			elseif propertyName == "CanCollide" then
				basePart.CanCollide = propertyValue
			elseif propertyName == "CanQuery" then
				basePart.CanQuery = propertyValue
			else
				basePart.CanTouch = propertyValue
			end
		end
	end)

	return self:_CreateResult(true, #baseParts, 0, ("Set %s to %s."):format(propertyName, tostring(propertyValue)))
end

function PropertyService:_CollectBaseParts(selectionRoots: { Instance }): { BasePart }
	local baseParts = {}

	for _, selectionRoot in selectionRoots do
		if selectionRoot:IsA("BasePart") then
			table.insert(baseParts, selectionRoot)
		end

		for _, descendant in selectionRoot:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(baseParts, descendant)
			end
		end
	end

	return baseParts
end

function PropertyService:_CollectTransparencyTargets(selectionRoots: { Instance }): { TPropertyTarget }
	local transparencyTargets = {}

	for _, selectionRoot in selectionRoots do
		if selectionRoot:IsA("BasePart") or selectionRoot:IsA("Decal") or selectionRoot:IsA("Texture") then
			table.insert(transparencyTargets, selectionRoot)
		end

		for _, descendant in selectionRoot:GetDescendants() do
			if descendant:IsA("BasePart") or descendant:IsA("Decal") or descendant:IsA("Texture") then
				table.insert(transparencyTargets, descendant)
			end
		end
	end

	return transparencyTargets
end

function PropertyService:_CreateResult(success: boolean, changedCount: number, skippedCount: number, message: string): TPluginActionResult
	return {
		Success = success,
		ChangedCount = changedCount,
		SkippedCount = skippedCount,
		Message = message,
		Path = nil,
	}
end

return PropertyService
