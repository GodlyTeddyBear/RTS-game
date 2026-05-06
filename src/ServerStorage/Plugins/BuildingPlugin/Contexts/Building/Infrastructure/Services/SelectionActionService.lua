--!strict

local PluginTypes = require(script.Parent.Parent.Parent.Parent.Parent.Types.PluginTypes)

type TPluginActionResult = PluginTypes.TPluginActionResult

local SelectionActionService = {}
SelectionActionService.__index = SelectionActionService

function SelectionActionService.new(historyAdapter, selectionService)
	local self = setmetatable({}, SelectionActionService)
	self.History = historyAdapter
	self.Selection = selectionService
	return self
end

function SelectionActionService:DuplicateSelection(): TPluginActionResult
	local selectionRoots = self.Selection.GetSelectionRoots()
	if #selectionRoots == 0 then
		return self:_CreateResult(false, 0, 0, "Select at least one instance before duplicating.")
	end

	local duplicatedInstances = {}

	self.History:Run("Duplicate Selection", function()
		for _, selectionRoot in selectionRoots do
			local parentInstance = selectionRoot.Parent
			if parentInstance ~= nil then
				local clone = selectionRoot:Clone()
				clone.Parent = parentInstance
				table.insert(duplicatedInstances, clone)
			end
		end
	end)

	if #duplicatedInstances == 0 then
		return self:_CreateResult(false, 0, #selectionRoots, "No selected instances could be duplicated.")
	end

	self.Selection.SetSelection(duplicatedInstances)

	return self:_CreateResult(true, #duplicatedInstances, #selectionRoots - #duplicatedInstances, "Duplicated current selection.")
end

function SelectionActionService:CreateSingleWeld(): TPluginActionResult
	local selectedInstances = self.Selection.GetSelection()
	if #selectedInstances ~= 2 then
		return self:_CreateResult(false, 0, 0, "Select exactly two instances before creating a weld.")
	end

	local part0 = selectedInstances[1]
	local part1 = selectedInstances[2]
	if not part0:IsA("BasePart") then
		return self:_CreateResult(false, 0, 1, "The first selected instance must be a BasePart.")
	end

	if not part1:IsA("BasePart") then
		return self:_CreateResult(false, 0, 1, "The second selected instance must be a BasePart.")
	end

	if part0 == part1 then
		return self:_CreateResult(false, 0, 1, "Cannot create a weld from a part to itself.")
	end

	self.History:Run("Create Single Weld", function()
		self:_CreateWeldConstraint(part0, part1)
	end)

	return self:_CreateResult(true, 1, 0, ("Created weld from %s to %s."):format(part0.Name, part1.Name))
end

function SelectionActionService:CreateMassWeld(): TPluginActionResult
	local selectedInstances = self.Selection.GetSelection()
	if #selectedInstances < 2 then
		return self:_CreateResult(false, 0, 0, "Select at least two instances before creating mass welds.")
	end

	local part0 = selectedInstances[1]
	if not part0:IsA("BasePart") then
		return self:_CreateResult(false, 0, #selectedInstances - 1, "The first selected instance must be a BasePart.")
	end

	local createdCount = 0
	local skippedCount = 0

	self.History:Run("Create Mass Welds", function()
		for index = 2, #selectedInstances do
			local part1 = selectedInstances[index]
			if part1 == part0 then
				skippedCount += 1
			elseif part1:IsA("BasePart") then
				self:_CreateWeldConstraint(part0, part1)
				createdCount += 1
			else
				skippedCount += 1
			end
		end
	end)

	if createdCount == 0 then
		return self:_CreateResult(false, 0, skippedCount, "No welds were created from the current selection.")
	end

	local message = ("Created %d weld(s) with %s as Part0."):format(createdCount, part0.Name)
	if skippedCount > 0 then
		message ..= (" Skipped %d selection(s)."):format(skippedCount)
	end

	return self:_CreateResult(true, createdCount, skippedCount, message)
end

function SelectionActionService:_CreateWeldConstraint(part0: BasePart, part1: BasePart): WeldConstraint
	local weldConstraint = Instance.new("WeldConstraint")
	weldConstraint.Name = self:_CreateUniqueWeldName(part0, part1.Name .. "Weld")
	weldConstraint.Part0 = part0
	weldConstraint.Part1 = part1
	weldConstraint.Parent = part0
	return weldConstraint
end

function SelectionActionService:_CreateUniqueWeldName(parentPart: BasePart, baseName: string): string
	if parentPart:FindFirstChild(baseName) == nil then
		return baseName
	end

	local suffix = 2
	while true do
		local candidateName = ("%s%d"):format(baseName, suffix)
		if parentPart:FindFirstChild(candidateName) == nil then
			return candidateName
		end

		suffix += 1
	end
end

function SelectionActionService:_CreateResult(success: boolean, changedCount: number, skippedCount: number, message: string): TPluginActionResult
	return {
		Success = success,
		ChangedCount = changedCount,
		SkippedCount = skippedCount,
		Message = message,
		Path = nil,
	}
end

return SelectionActionService
