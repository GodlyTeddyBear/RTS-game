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
