--!strict

local Types = require(script.Parent.Types)

type TNormalizedSelectDropdownConfig = Types.TNormalizedSelectDropdownConfig
type TSelectDropdownSnapshot = Types.TSelectDropdownSnapshot

local Snapshot = {}

function Snapshot.CreateSnapshot(
	isOpen: boolean,
	selectedId: string?,
	config: TNormalizedSelectDropdownConfig
): TSelectDropdownSnapshot
	local selectedOption = if selectedId == nil then nil else config.OptionsById[selectedId]

	return table.freeze({
		Id = config.Id,
		IsOpen = isOpen,
		SelectedId = selectedId,
		SelectedOption = selectedOption,
		PlaceholderLabel = config.PlaceholderLabel,
		CanClearSelection = config.AllowEmptySelection and selectedId ~= nil,
	})
end

return table.freeze(Snapshot)
