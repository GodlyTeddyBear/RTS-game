--!strict
--[=[
	@class useSelectDropdown
	React hook that subscribes to a `SelectDropdownController` and returns its current snapshot.
	@client
]=]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local React = require(ReplicatedStorage.Packages.React)

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

type TSelectDropdownTransitionInfo = {
	Action: string,
	PreviousIsOpen: boolean,
	NextIsOpen: boolean,
	PreviousSelectedId: string?,
	NextSelectedId: string?,
}

type TDropdownConnection = {
	Disconnect: (self: TDropdownConnection) -> (),
}

type TDropdownSignal = {
	Connect: (
		self: TDropdownSignal,
		callback: (
			newSnapshot: TSelectDropdownSnapshot,
			previousSnapshot: TSelectDropdownSnapshot,
			transitionInfo: TSelectDropdownTransitionInfo
		) -> ()
	) -> TDropdownConnection,
}

type TSelectDropdownController = {
	Changed: TDropdownSignal,
	GetSnapshot: (self: TSelectDropdownController) -> TSelectDropdownSnapshot,
}

-- Main
local function useSelectDropdown(controller: TSelectDropdownController): TSelectDropdownSnapshot
	local snapshot, setSnapshot = React.useState(function()
		return controller:GetSnapshot()
	end)

	React.useEffect(function()
		setSnapshot(controller:GetSnapshot())

		local connection = controller.Changed:Connect(function(newSnapshot: TSelectDropdownSnapshot)
			setSnapshot(newSnapshot)
		end)

		return function()
			connection:Disconnect()
		end
	end, { controller })

	return snapshot
end

return useSelectDropdown
