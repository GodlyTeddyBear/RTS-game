--!strict

local SelectionHelper = require(script.Parent.SelectionHelper)

export type TResult = {
	Success: boolean,
	ChangedCount: number,
	SkippedCount: number,
	Message: string,
}

local FolderService = {}
FolderService.__index = FolderService

function FolderService.new(historyAdapter)
	local self = setmetatable({}, FolderService)
	self.HistoryAdapter = historyAdapter
	return self
end

function FolderService:WrapSelection(folderName: string): TResult
	local normalizedFolderName = string.gsub(folderName, "^%s*(.-)%s*$", "%1")
	if normalizedFolderName == "" then
		return self:_CreateResult(false, 0, 0, "Enter a folder name before grouping the selection.")
	end

	local selectionRoots = SelectionHelper.GetSelectionRoots()
	if #selectionRoots == 0 then
		return self:_CreateResult(false, 0, 0, "Select at least one instance before creating a folder.")
	end

	local parentInstance = selectionRoots[1].Parent
	if parentInstance == nil then
		return self:_CreateResult(false, 0, 0, "The current selection cannot be grouped because it has no parent.")
	end

	for _, selectionRoot in selectionRoots do
		if selectionRoot.Parent ~= parentInstance then
			return self:_CreateResult(false, 0, 0, "All selected roots must share the same parent in v1.")
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = normalizedFolderName

	self.HistoryAdapter:Run("Wrap Selection In Folder", function()
		folder.Parent = parentInstance

		for _, selectionRoot in selectionRoots do
			selectionRoot.Parent = folder
		end
	end)

	SelectionHelper.SetSelection({ folder })

	return self:_CreateResult(true, #selectionRoots, 0, "Wrapped selection into folder " .. normalizedFolderName .. ".")
end

function FolderService:_CreateResult(success: boolean, changedCount: number, skippedCount: number, message: string): TResult
	return {
		Success = success,
		ChangedCount = changedCount,
		SkippedCount = skippedCount,
		Message = message,
	}
end

return FolderService
