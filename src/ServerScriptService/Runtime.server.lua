local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Jabby = require(ReplicatedStorage.Packages.Jabby)

local ServerScheduler = require(script.Parent.Scheduler.ServerScheduler)
local PlayerCollisionService = require(script.Parent.PlayerCollisionService)

local DEVELOPER_USER_ID = 205423638 -- TODO: replace with your Roblox UserId

local Contexts: Folder = script.Parent.Contexts

-- Get contexts
for _, context in ipairs(Contexts:GetChildren()) do
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

		-- Register all JECS worlds for entity/component inspection
		local WorkerContext = Knit.GetService("WorkerContext")
		Jabby.register({
			name = "WorkerWorld",
			applet = Jabby.applets.world,
			configuration = { world = WorkerContext.World },
		})

		local LotContext = Knit.GetService("LotContext")
		Jabby.register({
			name = "LotWorld",
			applet = Jabby.applets.world,
			configuration = { world = LotContext.World },
		})

		local NPCContext = Knit.GetService("NPCContext")
		Jabby.register({
			name = "CombatWorld",
			applet = Jabby.applets.world,
			configuration = { world = NPCContext.World },
		})

		PlayerCollisionService:Initialize()
		ServerScheduler:Initialize()
		print("Server started with Planck scheduler")
	end)
	:catch(warn)
