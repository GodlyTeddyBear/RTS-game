--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local LogSyncClient = require(script.Parent.Infrastructure.LogSyncClient)
local CommandSyncClient = require(script.Parent.Infrastructure.CommandSyncClient)

local DEVELOPER_USER_ID = 205423638

local LogController = Knit.CreateController({
	Name = "LogController",
})

function LogController:KnitInit()
	self._syncClient = LogSyncClient.new()
	self._player = Players.LocalPlayer
end

function LogController:KnitStart()
	self._syncClient:Start()

	if self._player.UserId == DEVELOPER_USER_ID then
		CommandSyncClient.Initialize()
		self:_mountDevTools()
	end
end

function LogController:_mountDevTools()
	local LogViewerScreen = require(script.Parent.Presentation.Templates.LogViewerScreen)
	local playerGui = self._player:WaitForChild("PlayerGui")
	local logViewerGui: ScreenGui? = nil
	local logViewerRoot: any = nil
	local isVisible = false

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.KeyCode ~= Enum.KeyCode.Backquote then
			return
		end

		if not logViewerGui then
			logViewerGui, logViewerRoot = self:_createLogViewerGui(playerGui)
		end

		isVisible = not isVisible
		logViewerGui.Enabled = isVisible

		if isVisible then
			CommandSyncClient.Initialize()
			logViewerRoot:render(e(LogViewerScreen, { logsAtom = self._syncClient:GetLogsAtom() }))
		else
			logViewerRoot:render(nil)
		end
	end)
end

function LogController:_createLogViewerGui(playerGui: Instance): (ScreenGui, any)
	local gui = Instance.new("ScreenGui")
	gui.Name = "LogViewer"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 100
	gui.Enabled = false
	gui.Parent = playerGui

	local root = ReactRoblox.createRoot(gui)
	return gui, root
end

function LogController:GetLogsAtom()
	return self._syncClient:GetLogsAtom()
end

return LogController
