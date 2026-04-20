--!strict
--[=[
	@class AppController
	Knit controller that mounts the React root and bootstraps the client UI.
	@client
]=]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local Jabby = require(ReplicatedStorage.Packages.Jabby)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local DEVELOPER_USER_ID = 205423638 -- TODO: replace with your Roblox UserId

local AppController = Knit.CreateController({
	Name = "AppController",
})

-- Initialize resources
function AppController:KnitInit()
	-- Create shared registry and UI container for all App-level controllers
	local registry = Registry.new("Client")
	self.Registry = registry

	self.janitor = Janitor.new()
	self.player = Players.LocalPlayer
	self.playerGui = self.player:WaitForChild("PlayerGui")

	-- Create root ScreenGui that will hold the entire React tree
	self.rootContainer = Instance.new("ScreenGui")
	self.rootContainer.Name = "AppRoot"
	self.rootContainer.IgnoreGuiInset = true
	self.rootContainer.ResetOnSpawn = false
	self.rootContainer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	self.rootContainer.Parent = self.playerGui

	self.janitor:Add(self.rootContainer, "Destroy")

	-- Initialize all child controllers (Atoms, Hooks, etc.)
	registry:InitAll()
end

-- Mount React after all controllers initialized
function AppController:KnitStart()
	-- Start all child controllers in dependency order
	self.Registry:StartOrdered({})

	local App = require(script.Parent.Presentation.App)

	-- Mount React to the root container
	local root = ReactRoblox.createRoot(self.rootContainer)
	self.janitor:Add(root, "unmount")

	root:render(e(App))

	-- Mount debugging tools for developer accounts
	if self.player.UserId == DEVELOPER_USER_ID then
		self:_mountDevTools()
	end
end

function AppController:_mountDevTools()
	local jabbyClient = Jabby.obtain_client()
	local jabbyGui: ScreenGui? = nil

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.KeyCode ~= Enum.KeyCode.F4 then
			return
		end

		-- Check if Jabby was closed by user; if so, allow respawning
		if jabbyGui and not jabbyGui.Parent then
			jabbyGui = nil
		end

		-- Toggle Jabby visibility on F4; create it on first press
		if not jabbyGui then
			jabbyGui = self:_spawnJabby(jabbyClient)
		else
			jabbyGui.Enabled = not jabbyGui.Enabled
		end
	end)
end

function AppController:_spawnJabby(jabbyClient: any): ScreenGui?
	-- Snapshot current children; Jabby will add a new ScreenGui
	local before = self.playerGui:GetChildren()
	jabbyClient.spawn_app(jabbyClient.apps.home, nil)

	-- Find and return the newly created ScreenGui
	for _, child in self.playerGui:GetChildren() do
		if not table.find(before, child) then
			return child :: ScreenGui
		end
	end

	return nil
end

-- Cleanup
function AppController:Destroy()
	self.janitor:Destroy()
end

return AppController
