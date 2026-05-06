--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Constants = require(script.Parent.Parent.Parent.Parent.Constants)
local PluginTypes = require(script.Parent.Parent.Parent.Parent.Types.PluginTypes)
local Charm = require(ReplicatedStorage.Packages.Charm)

type TPluginStatus = PluginTypes.TPluginStatus
type TPluginStatusTone = PluginTypes.TPluginStatusTone
type TPluginTab = PluginTypes.TPluginTab

export type TAppState = {
	SelectedTab: TPluginTab,
	WidgetEnabled: boolean,
	Status: TPluginStatus,
}

local READY_STATUS = table.freeze({
	Message = "Ready.",
	Tone = "Info",
} :: TPluginStatus)

local statusResetThread: thread? = nil

local appAtom = Charm.atom({
	SelectedTab = "Building" :: TPluginTab,
	WidgetEnabled = false,
	Status = READY_STATUS,
} :: TAppState)

local AppAtom = {}

local function _PatchState(nextState: TAppState)
	appAtom(nextState)
end

function AppAtom.GetAtom()
	return appAtom
end

function AppAtom.GetState(): TAppState
	return appAtom()
end

function AppAtom.SetSelectedTab(selectedTab: TPluginTab)
	local state = appAtom()
	_PatchState({
		SelectedTab = selectedTab,
		WidgetEnabled = state.WidgetEnabled,
		Status = state.Status,
	})
end

function AppAtom.SetWidgetEnabled(widgetEnabled: boolean)
	local state = appAtom()
	_PatchState({
		SelectedTab = state.SelectedTab,
		WidgetEnabled = widgetEnabled,
		Status = state.Status,
	})
end

function AppAtom.ClearStatus()
	if statusResetThread ~= nil then
		task.cancel(statusResetThread)
		statusResetThread = nil
	end

	local state = appAtom()
	_PatchState({
		SelectedTab = state.SelectedTab,
		WidgetEnabled = state.WidgetEnabled,
		Status = READY_STATUS,
	})
end

function AppAtom.SetStatus(message: string, tone: TPluginStatusTone)
	if statusResetThread ~= nil then
		task.cancel(statusResetThread)
		statusResetThread = nil
	end

	local state = appAtom()
	local status = {
		Message = message,
		Tone = tone,
	} :: TPluginStatus

	_PatchState({
		SelectedTab = state.SelectedTab,
		WidgetEnabled = state.WidgetEnabled,
		Status = status,
	})

	statusResetThread = task.delay(Constants.StatusDuration, function()
		AppAtom.ClearStatus()
	end)
end

return AppAtom
