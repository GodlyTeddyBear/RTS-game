--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local GoodSignal = require(ReplicatedStorage.Packages.Goodsignal)
local Result = require(ReplicatedStorage.Utilities.Result)

local Config = require(script.Config)
local Constants = require(script.Constants)
local Snapshot = require(script.Snapshot)
local Types = require(script.Types)
local useSelectDropdown = require(script.useSelectDropdown)
local useSelectDropdownActions = require(script.useSelectDropdownActions)

-- Constants
local ACTION_OPEN = Constants.Action.Open
local ACTION_CLOSE = Constants.Action.Close
local ACTION_TOGGLE = Constants.Action.Toggle
local ACTION_SELECT = Constants.Action.Select
local ACTION_CLEAR_SELECTION = Constants.Action.ClearSelection
local ACTION_RESET = Constants.Action.Reset

local ERROR_DESTROYED = Constants.Error.Destroyed
local ERROR_INVALID_OPTION = Constants.Error.InvalidOption
local ERROR_DISABLED_OPTION = Constants.Error.DisabledOption
local ERROR_CLEAR_NOT_ALLOWED = Constants.Error.ClearNotAllowed

-- Types
export type TSelectDropdownOption = Types.TSelectDropdownOption
export type TSelectDropdownConfig = Types.TSelectDropdownConfig
export type TSelectDropdownSnapshot = Types.TSelectDropdownSnapshot
export type TSelectDropdownTransitionAction = Types.TSelectDropdownTransitionAction
export type TSelectDropdownTransitionInfo = Types.TSelectDropdownTransitionInfo

type TChangedSignal = Types.TChangedSignal
type TNormalizedSelectDropdownConfig = Types.TNormalizedSelectDropdownConfig
type TNormalizedSelectDropdownOption = Types.TNormalizedSelectDropdownOption

export type TSelectDropdownController = {
	Changed: TChangedSignal,
	_config: TNormalizedSelectDropdownConfig,
	_snapshot: TSelectDropdownSnapshot,
	_isDestroyed: boolean,

	Open: (self: TSelectDropdownController) -> Result.Result<TSelectDropdownSnapshot>,
	Close: (self: TSelectDropdownController) -> Result.Result<TSelectDropdownSnapshot>,
	Toggle: (self: TSelectDropdownController) -> Result.Result<TSelectDropdownSnapshot>,
	Select: (self: TSelectDropdownController, optionId: string) -> Result.Result<TSelectDropdownSnapshot>,
	ClearSelection: (self: TSelectDropdownController) -> Result.Result<TSelectDropdownSnapshot>,
	Reset: (self: TSelectDropdownController) -> Result.Result<TSelectDropdownSnapshot>,
	IsOpen: (self: TSelectDropdownController) -> boolean,
	GetSelectedId: (self: TSelectDropdownController) -> string?,
	GetSelectedOption: (self: TSelectDropdownController) -> TNormalizedSelectDropdownOption?,
	GetOptions: (self: TSelectDropdownController) -> { TNormalizedSelectDropdownOption },
	GetSnapshot: (self: TSelectDropdownController) -> TSelectDropdownSnapshot,
	HasOption: (self: TSelectDropdownController, optionId: string) -> boolean,
	Destroy: (self: TSelectDropdownController) -> (),
}

-- Module
local SelectDropdownController = {}
SelectDropdownController.__index = SelectDropdownController

-- Constructor
function SelectDropdownController.new(config: TSelectDropdownConfig): TSelectDropdownController
	local normalizedConfig = Config.NormalizeConfig(config)

	local self = setmetatable({}, SelectDropdownController) :: any
	self._config = normalizedConfig
	self._snapshot = Snapshot.CreateSnapshot(
		normalizedConfig.InitialOpen,
		normalizedConfig.InitialSelectedId,
		normalizedConfig
	)
	self._isDestroyed = false
	self.Changed = GoodSignal.new()

	return self
end

-- Public methods
function SelectDropdownController:Open(): Result.Result<TSelectDropdownSnapshot>
	local destroyedResult = self:_GuardDestroyed(ACTION_OPEN, nil)
	if destroyedResult ~= nil then
		return destroyedResult
	end

	if self._snapshot.IsOpen then
		return Result.Ok(self._snapshot)
	end

	return self:_Transition(ACTION_OPEN, true, self._snapshot.SelectedId)
end

function SelectDropdownController:Close(): Result.Result<TSelectDropdownSnapshot>
	local destroyedResult = self:_GuardDestroyed(ACTION_CLOSE, nil)
	if destroyedResult ~= nil then
		return destroyedResult
	end

	if not self._snapshot.IsOpen then
		return Result.Ok(self._snapshot)
	end

	return self:_Transition(ACTION_CLOSE, false, self._snapshot.SelectedId)
end

function SelectDropdownController:Toggle(): Result.Result<TSelectDropdownSnapshot>
	local destroyedResult = self:_GuardDestroyed(ACTION_TOGGLE, nil)
	if destroyedResult ~= nil then
		return destroyedResult
	end

	return self:_Transition(ACTION_TOGGLE, not self._snapshot.IsOpen, self._snapshot.SelectedId)
end

function SelectDropdownController:Select(optionId: string): Result.Result<TSelectDropdownSnapshot>
	local destroyedResult = self:_GuardDestroyed(ACTION_SELECT, {
		OptionId = optionId,
	})
	if destroyedResult ~= nil then
		return destroyedResult
	end

	if type(optionId) ~= "string" or #optionId == 0 then
		return self:_BuildError(ERROR_INVALID_OPTION, "OptionId must be a non-empty string", ACTION_SELECT, {
			OptionId = optionId,
		})
	end

	local option = self._config.OptionsById[optionId]
	if option == nil then
		return self:_BuildError(ERROR_INVALID_OPTION, "OptionId is not registered", ACTION_SELECT, {
			OptionId = optionId,
		})
	end

	if option.Disabled then
		return self:_BuildError(ERROR_DISABLED_OPTION, "OptionId is disabled", ACTION_SELECT, {
			OptionId = optionId,
		})
	end

	local nextIsOpen = if self._config.CloseOnSelect then false else self._snapshot.IsOpen
	if (self._snapshot.SelectedId == optionId) and (self._snapshot.IsOpen == nextIsOpen) then
		return Result.Ok(self._snapshot)
	end

	return self:_Transition(ACTION_SELECT, nextIsOpen, optionId)
end

function SelectDropdownController:ClearSelection(): Result.Result<TSelectDropdownSnapshot>
	local destroyedResult = self:_GuardDestroyed(ACTION_CLEAR_SELECTION, nil)
	if destroyedResult ~= nil then
		return destroyedResult
	end

	if not self._config.AllowEmptySelection then
		return self:_BuildError(
			ERROR_CLEAR_NOT_ALLOWED,
			"ClearSelection is not allowed for this dropdown",
			ACTION_CLEAR_SELECTION,
			nil
		)
	end

	if self._snapshot.SelectedId == nil then
		return Result.Ok(self._snapshot)
	end

	return self:_Transition(ACTION_CLEAR_SELECTION, self._snapshot.IsOpen, nil)
end

function SelectDropdownController:Reset(): Result.Result<TSelectDropdownSnapshot>
	local destroyedResult = self:_GuardDestroyed(ACTION_RESET, nil)
	if destroyedResult ~= nil then
		return destroyedResult
	end

	if (self._snapshot.IsOpen == self._config.InitialOpen) and (self._snapshot.SelectedId == self._config.InitialSelectedId) then
		return Result.Ok(self._snapshot)
	end

	return self:_Transition(ACTION_RESET, self._config.InitialOpen, self._config.InitialSelectedId)
end

function SelectDropdownController:IsOpen(): boolean
	return self._snapshot.IsOpen
end

function SelectDropdownController:GetSelectedId(): string?
	return self._snapshot.SelectedId
end

function SelectDropdownController:GetSelectedOption(): TNormalizedSelectDropdownOption?
	return self._snapshot.SelectedOption :: TNormalizedSelectDropdownOption?
end

function SelectDropdownController:GetOptions(): { TNormalizedSelectDropdownOption }
	return self._config.Options
end

function SelectDropdownController:GetSnapshot(): TSelectDropdownSnapshot
	return self._snapshot
end

function SelectDropdownController:HasOption(optionId: string): boolean
	if type(optionId) ~= "string" or #optionId == 0 then
		return false
	end

	return self._config.OptionsById[optionId] ~= nil
end

function SelectDropdownController:Destroy(): ()
	if self._isDestroyed then
		return
	end

	self._isDestroyed = true
	self.Changed:DisconnectAll()
end

-- Private helpers
function SelectDropdownController:_Transition(
	actionName: TSelectDropdownTransitionAction,
	nextIsOpen: boolean,
	nextSelectedId: string?
): Result.Result<TSelectDropdownSnapshot>
	local nextSnapshot = Snapshot.CreateSnapshot(nextIsOpen, nextSelectedId, self._config)
	return self:_Commit(nextSnapshot, {
		Action = actionName,
		PreviousIsOpen = self._snapshot.IsOpen,
		NextIsOpen = nextSnapshot.IsOpen,
		PreviousSelectedId = self._snapshot.SelectedId,
		NextSelectedId = nextSnapshot.SelectedId,
	})
end

function SelectDropdownController:_Commit(
	nextSnapshot: TSelectDropdownSnapshot,
	transitionInfo: TSelectDropdownTransitionInfo
): Result.Result<TSelectDropdownSnapshot>
	local previousSnapshot = self._snapshot
	self._snapshot = nextSnapshot
	self.Changed:Fire(nextSnapshot, previousSnapshot, table.freeze(transitionInfo))
	return Result.Ok(nextSnapshot)
end

function SelectDropdownController:_GuardDestroyed(
	actionName: TSelectDropdownTransitionAction,
	data: { [string]: any }?
): Result.Err?
	if not self._isDestroyed then
		return nil
	end

	return self:_BuildError(ERROR_DESTROYED, "Select dropdown controller has been destroyed", actionName, data)
end

function SelectDropdownController:_BuildError(
	errorType: string,
	message: string,
	actionName: TSelectDropdownTransitionAction,
	data: { [string]: any }?
): Result.Err
	local errorData = if data then table.clone(data) else {}
	errorData.DropdownId = self._config.Id
	errorData.Action = actionName
	errorData.IsOpen = self._snapshot.IsOpen
	errorData.SelectedId = self._snapshot.SelectedId
	return Result.Err(errorType, message, errorData)
end

return table.freeze({
	new = SelectDropdownController.new,
	useSelectDropdown = useSelectDropdown,
	useSelectDropdownActions = useSelectDropdownActions,
})
