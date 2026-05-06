--!strict

local Selection = game:GetService("Selection")

local SelectionService = {}

function SelectionService.GetSelection(): { Instance }
	return Selection:Get()
end

function SelectionService.SetSelection(instances: { Instance })
	Selection:Set(instances)
end

function SelectionService.GetSummary()
	local selectedInstances = SelectionService.GetSelection()
	local names = {}

	for _, selectedInstance in selectedInstances do
		table.insert(names, selectedInstance.Name)
	end

	table.sort(names)

	return {
		Count = #selectedInstances,
		Names = names,
	}
end

function SelectionService.GetSelectionRoots(): { Instance }
	local selectedInstances = SelectionService.GetSelection()
	local selectedLookup = {}
	local roots = {}

	for _, selectedInstance in selectedInstances do
		selectedLookup[selectedInstance] = true
	end

	for _, selectedInstance in selectedInstances do
		local parentInstance = selectedInstance.Parent
		if parentInstance == nil or not selectedLookup[parentInstance] then
			table.insert(roots, selectedInstance)
		end
	end

	return roots
end

return SelectionService
