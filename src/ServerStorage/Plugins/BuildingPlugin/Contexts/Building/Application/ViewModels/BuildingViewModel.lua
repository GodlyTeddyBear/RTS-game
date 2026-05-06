--!strict

local BuildingViewModel = {}

function BuildingViewModel.FromState(state)
	local selectionSummary = state.SelectionSummary

	if selectionSummary.Count == 0 then
		return table.freeze({
			FolderName = state.FolderName,
			SelectionCount = 0,
			SelectionText = "Selection: 0",
		})
	end

	local previewNames = {}
	for index, selectionName in selectionSummary.Names do
		if index > 4 then
			break
		end

		table.insert(previewNames, selectionName)
	end

	local suffix = if selectionSummary.Count > #previewNames then " ..." else ""

	return table.freeze({
		FolderName = state.FolderName,
		SelectionCount = selectionSummary.Count,
		SelectionText = ("Selection: %d\n%s%s"):format(
			selectionSummary.Count,
			table.concat(previewNames, ", "),
			suffix
		),
	})
end

return BuildingViewModel
