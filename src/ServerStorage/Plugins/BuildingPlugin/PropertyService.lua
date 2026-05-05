--!strict

local SelectionHelper = require(script.Parent.SelectionHelper)

export type TResult = {
	Success: boolean,
	ChangedCount: number,
	SkippedCount: number,
	Message: string,
}

type TPropertyTarget = BasePart | Decal | Texture

local PropertyService = {}
PropertyService.__index = PropertyService

function PropertyService.new(historyAdapter)
	local self = setmetatable({}, PropertyService)
	self.HistoryAdapter = historyAdapter
	return self
end

function PropertyService:SetAnchored(isAnchored: boolean): TResult
	return self:_ApplyBasePartProperty("Set Anchored", "Anchored", isAnchored)
end

function PropertyService:SetCanCollide(canCollide: boolean): TResult
	return self:_ApplyBasePartProperty("Set CanCollide", "CanCollide", canCollide)
end

function PropertyService:SetCanQuery(canQuery: boolean): TResult
	return self:_ApplyBasePartProperty("Set CanQuery", "CanQuery", canQuery)
end

function PropertyService:SetCanTouch(canTouch: boolean): TResult
	return self:_ApplyBasePartProperty("Set CanTouch", "CanTouch", canTouch)
end

function PropertyService:SetTransparency(transparency: number): TResult
	local selectionRoots = SelectionHelper.GetSelectionRoots()
	if #selectionRoots == 0 then
		return self:_CreateResult(false, 0, 0, "Select at least one instance before changing transparency.")
	end

	local targets = self:_CollectTransparencyTargets(selectionRoots)
	if #targets == 0 then
		return self:_CreateResult(false, 0, #selectionRoots, "No selected instances support transparency.")
	end

	self.HistoryAdapter:Run("Set Transparency", function()
		for _, target in targets do
			target.Transparency = transparency
		end
	end)

	return self:_CreateResult(true, #targets, 0, ("Set transparency to %.2f."):format(transparency))
end

function PropertyService:SetMaterial(material: Enum.Material): TResult
	local baseParts = self:_CollectBaseParts(SelectionHelper.GetSelectionRoots())
	if #baseParts == 0 then
		return self:_CreateResult(false, 0, 0, "No selected parts support material changes.")
	end

	self.HistoryAdapter:Run("Set Material", function()
		for _, basePart in baseParts do
			basePart.Material = material
		end
	end)

	return self:_CreateResult(true, #baseParts, 0, "Set material to " .. material.Name .. ".")
end

function PropertyService:SetColor(color: Color3, colorName: string): TResult
	local baseParts = self:_CollectBaseParts(SelectionHelper.GetSelectionRoots())
	if #baseParts == 0 then
		return self:_CreateResult(false, 0, 0, "No selected parts support color changes.")
	end

	self.HistoryAdapter:Run("Set Color", function()
		for _, basePart in baseParts do
			basePart.Color = color
		end
	end)

	return self:_CreateResult(true, #baseParts, 0, "Set color to " .. colorName .. ".")
end

function PropertyService:_ApplyBasePartProperty(waypointName: string, propertyName: "Anchored" | "CanCollide" | "CanQuery" | "CanTouch", propertyValue: boolean): TResult
	local baseParts = self:_CollectBaseParts(SelectionHelper.GetSelectionRoots())
	if #baseParts == 0 then
		return self:_CreateResult(false, 0, 0, "No selected parts support " .. propertyName .. ".")
	end

	self.HistoryAdapter:Run(waypointName, function()
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
		self:_CollectDescendantsOfType(selectionRoot, "BasePart", baseParts)
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

function PropertyService:_CollectDescendantsOfType(selectionRoot: Instance, className: string, results: { BasePart })
	if className == "BasePart" and selectionRoot:IsA("BasePart") then
		table.insert(results, selectionRoot :: BasePart)
	end

	for _, descendant in selectionRoot:GetDescendants() do
		if className == "BasePart" and descendant:IsA("BasePart") then
			table.insert(results, descendant :: BasePart)
		end
	end
end

function PropertyService:_CreateResult(success: boolean, changedCount: number, skippedCount: number, message: string): TResult
	return {
		Success = success,
		ChangedCount = changedCount,
		SkippedCount = skippedCount,
		Message = message,
	}
end

return PropertyService
