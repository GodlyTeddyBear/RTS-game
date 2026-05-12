--!strict
--[=[
	@class useMenu
	React hook that subscribes to a `MenuController` and returns its current snapshot.
	@client
]=]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local React = require(ReplicatedStorage.Packages.React)

-- Types
type TMenuStateMeta = {
	Title: string?,
	ShowBack: boolean?,
	ShowClose: boolean?,
}

type TMenuSnapshot = {
	IsOpen: boolean,
	CurrentState: string?,
	History: { string },
	Context: { [string]: any },
	CanGoBack: boolean,
	CanClose: boolean,
	Meta: TMenuStateMeta,
}

type TMenuTransitionInfo = {
	Action: string,
	FromState: string?,
	ToState: string?,
	Payload: { [string]: any }?,
	ContextPatch: { [string]: any }?,
}

type TMenuConnection = {
	Disconnect: (self: TMenuConnection) -> (),
}

type TMenuSignal = {
	Connect: (
		self: TMenuSignal,
		callback: (newSnapshot: TMenuSnapshot, previousSnapshot: TMenuSnapshot, transitionInfo: TMenuTransitionInfo) -> ()
	) -> TMenuConnection,
}

type TMenuController = {
	Changed: TMenuSignal,
	GetSnapshot: (self: TMenuController) -> TMenuSnapshot,
}

-- Main
local function useMenu(controller: TMenuController): TMenuSnapshot
	local snapshot, setSnapshot = React.useState(function()
		return controller:GetSnapshot()
	end)

	React.useEffect(function()
		setSnapshot(controller:GetSnapshot())

		local connection = controller.Changed:Connect(function(newSnapshot: TMenuSnapshot)
			setSnapshot(newSnapshot)
		end)

		return function()
			connection:Disconnect()
		end
	end, { controller })

	return snapshot
end

return useMenu
