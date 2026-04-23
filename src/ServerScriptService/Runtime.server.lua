local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreFolder = script.Parent:WaitForChild("Nevermore")
local NevermoreLoaderModule = NevermoreFolder.node_modules["@quenty"].loader :: ModuleScript
local NevermoreLoader = require(NevermoreLoaderModule)
NevermoreLoader.bootstrapGame(NevermoreFolder)

local Knit = require(ReplicatedStorage.Packages.Knit)
local Jabby = require(ReplicatedStorage.Packages.Jabby)

local ServerScheduler = require(script.Parent.Scheduler.ServerScheduler)
local PlayerCollisionService = require(script.Parent.PlayerCollisionService)

local DEVELOPER_USER_ID = 205423638 -- TODO: replace with your Roblox UserId

local Contexts: Folder = script.Parent.Contexts

-- Get contexts
for _, context in ipairs(Contexts:GetChildren()) do
	task.wait()
	if context:FindFirstChildOfClass("ModuleScript") then
		Knit.AddServices(context)
	end
end

Knit.Start()
	:andThen(function()
		-- Restrict jabby access to developer only
		Jabby.set_check_function(function(player)
			return player.UserId == DEVELOPER_USER_ID
		end)

		ServerScheduler:Initialize()
		PlayerCollisionService:Initialize()
	end)
	:catch(warn)
