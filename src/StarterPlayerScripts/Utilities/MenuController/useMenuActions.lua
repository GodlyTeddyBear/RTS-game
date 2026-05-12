--!strict
--[=[
	@class useMenuActions
	React hook that returns stable bound actions for a `MenuController`.
	@client
]=]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local React = require(ReplicatedStorage.Packages.React)
local Result = require(ReplicatedStorage.Utilities.Result)

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

type TMenuActions = {
	Open: () -> Result.Result<TMenuSnapshot>,
	Close: () -> Result.Result<TMenuSnapshot>,
	GoTo: (stateId: string, payload: { [string]: any }?) -> Result.Result<TMenuSnapshot>,
	Back: () -> Result.Result<TMenuSnapshot>,
	Reset: () -> Result.Result<TMenuSnapshot>,
	SetContext: (patch: { [string]: any }) -> Result.Result<TMenuSnapshot>,
	ClearContext: (...string) -> Result.Result<TMenuSnapshot>,
}

type TMenuController = {
	Open: (self: TMenuController) -> Result.Result<TMenuSnapshot>,
	Close: (self: TMenuController) -> Result.Result<TMenuSnapshot>,
	GoTo: (self: TMenuController, stateId: string, payload: { [string]: any }?) -> Result.Result<TMenuSnapshot>,
	Back: (self: TMenuController) -> Result.Result<TMenuSnapshot>,
	Reset: (self: TMenuController) -> Result.Result<TMenuSnapshot>,
	SetContext: (self: TMenuController, patch: { [string]: any }) -> Result.Result<TMenuSnapshot>,
	ClearContext: (self: TMenuController, ...string) -> Result.Result<TMenuSnapshot>,
}

-- Main
local function useMenuActions(controller: TMenuController): TMenuActions
	return React.useMemo(function()
		return table.freeze({
			Open = function()
				return controller:Open()
			end,
			Close = function()
				return controller:Close()
			end,
			GoTo = function(stateId: string, payload: { [string]: any }?)
				return controller:GoTo(stateId, payload)
			end,
			Back = function()
				return controller:Back()
			end,
			Reset = function()
				return controller:Reset()
			end,
			SetContext = function(patch: { [string]: any })
				return controller:SetContext(patch)
			end,
			ClearContext = function(...: string)
				return controller:ClearContext(...)
			end,
		} :: TMenuActions)
	end, { controller })
end

return useMenuActions
