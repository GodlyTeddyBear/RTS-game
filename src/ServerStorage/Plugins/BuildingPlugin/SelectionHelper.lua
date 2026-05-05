--!strict

local Selection = game:GetService("Selection")

export type TSelectionSummary = {
	Count: number,
	Names: { string },
}

local SelectionHelper = {}

function SelectionHelper.GetSelection(): { Instance }
	return Selection:Get()
end

function SelectionHelper.SetSelection(instances: { Instance })
	Selection:Set(instances)
end

function SelectionHelper.GetSummary(): TSelectionSummary
	local selectedInstances = SelectionHelper.GetSelection()
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

function SelectionHelper.GetSelectionRoots(): { Instance }
	local selectedInstances = SelectionHelper.GetSelection()
	local selectedLookup = {}
	local roots = {}

	for _, selectedInstance in selectedInstances do
		selectedLookup[selectedInstance] = true
	end

	for _, selectedInstance in selectedInstances do
		local parentInstance = selectedInstance.Parent
		if parentInstance == nil or (not selectedLookup[parentInstance]) then
			table.insert(roots, selectedInstance)
		end
	end

	return roots
end

function SelectionHelper.GetSingleSelection(): Instance?
	local selectionRoots = SelectionHelper.GetSelectionRoots()
	if #selectionRoots ~= 1 then
		return nil
	end

	return selectionRoots[1]
end

return SelectionHelper
