--!strict

local SelectionHelper = require(script.Parent.SelectionHelper)

export type TResult = {
	Success: boolean,
	ChangedCount: number,
	SkippedCount: number,
	Message: string,
}

local SelectionActionService = {}
SelectionActionService.__index = SelectionActionService

function SelectionActionService.new(historyAdapter)
	local self = setmetatable({}, SelectionActionService)
	self.HistoryAdapter = historyAdapter
	return self
end

function SelectionActionService:DuplicateSelection(): TResult
	local selectionRoots = SelectionHelper.GetSelectionRoots()
	if #selectionRoots == 0 then
		return self:_CreateResult(false, 0, 0, "Select at least one instance before duplicating.")
	end

	local duplicatedInstances = {}

	self.HistoryAdapter:Run("Duplicate Selection", function()
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

	SelectionHelper.SetSelection(duplicatedInstances)

	return self:_CreateResult(true, #duplicatedInstances, #selectionRoots - #duplicatedInstances, "Duplicated current selection.")
end

function SelectionActionService:_CreateResult(success: boolean, changedCount: number, skippedCount: number, message: string): TResult
	return {
		Success = success,
		ChangedCount = changedCount,
		SkippedCount = skippedCount,
		Message = message,
	}
end

return SelectionActionService
