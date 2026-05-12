--!strict
--[=[
	@class useSelectDropdownActions
	React hook that returns stable bound actions for a `SelectDropdownController`.
	@client
]=]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local React = require(ReplicatedStorage.Packages.React)
local Result = require(ReplicatedStorage.Utilities.Result)

-- Types
type TSelectDropdownSnapshot = {
	Id: string,
	IsOpen: boolean,
	SelectedId: string?,
	SelectedOption: {
		Id: string,
		Label: string,
		Disabled: boolean?,
	}?,
	PlaceholderLabel: string?,
	CanClearSelection: boolean,
}

type TSelectDropdownActions = {
	Open: () -> Result.Result<TSelectDropdownSnapshot>,
	Close: () -> Result.Result<TSelectDropdownSnapshot>,
	Toggle: () -> Result.Result<TSelectDropdownSnapshot>,
	Select: (optionId: string) -> Result.Result<TSelectDropdownSnapshot>,
	ClearSelection: () -> Result.Result<TSelectDropdownSnapshot>,
	Reset: () -> Result.Result<TSelectDropdownSnapshot>,
}

type TSelectDropdownController = {
	Open: (self: TSelectDropdownController) -> Result.Result<TSelectDropdownSnapshot>,
	Close: (self: TSelectDropdownController) -> Result.Result<TSelectDropdownSnapshot>,
	Toggle: (self: TSelectDropdownController) -> Result.Result<TSelectDropdownSnapshot>,
	Select: (self: TSelectDropdownController, optionId: string) -> Result.Result<TSelectDropdownSnapshot>,
	ClearSelection: (self: TSelectDropdownController) -> Result.Result<TSelectDropdownSnapshot>,
	Reset: (self: TSelectDropdownController) -> Result.Result<TSelectDropdownSnapshot>,
}

-- Main
local function useSelectDropdownActions(controller: TSelectDropdownController): TSelectDropdownActions
	return React.useMemo(function()
		return table.freeze({
			Open = function()
				return controller:Open()
			end,
			Close = function()
				return controller:Close()
			end,
			Toggle = function()
				return controller:Toggle()
			end,
			Select = function(optionId: string)
				return controller:Select(optionId)
			end,
			ClearSelection = function()
				return controller:ClearSelection()
			end,
			Reset = function()
				return controller:Reset()
			end,
		} :: TSelectDropdownActions)
	end, { controller })
end

return useSelectDropdownActions
