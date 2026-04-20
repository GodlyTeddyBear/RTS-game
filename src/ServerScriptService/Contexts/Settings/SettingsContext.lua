--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local BlinkServer = require(ReplicatedStorage.Network.Generated.SettingsSyncServer)

local ProfileManager = require(ServerScriptService.Persistence.ProfileManager)
local PlayerLifecycleManager = require(ServerScriptService.Persistence.PlayerLifecycleManager)
local SettingsPersistenceService = require(script.Parent.Infrastructure.Persistence.SettingsPersistenceService)
local SettingsSyncService = require(script.Parent.Infrastructure.Persistence.SettingsSyncService)
local SoundSettingsValidator = require(script.Parent.SettingsDomain.Services.SoundSettingsValidator)
local UpdateSoundSettings = require(script.Parent.Application.Commands.UpdateSoundSettings)
local GetSettings = require(script.Parent.Application.Queries.GetSettings)

local Catch = Result.Catch
local Events = GameEvents.Events

local SettingsContext = Knit.CreateService({
	Name = "SettingsContext",
	Client = {},
})

function SettingsContext:KnitInit()
	local registry = Registry.new("Server")
	self.Registry = registry

	registry:Register("BlinkServer", BlinkServer)
	registry:Register("ProfileManager", ProfileManager)

	PlayerLifecycleManager:RegisterLoader("SettingsContext")

	registry:Register("SoundSettingsValidator", SoundSettingsValidator.new(), "Domain")
	registry:Register("SettingsPersistenceService", SettingsPersistenceService.new(), "Infrastructure")
	registry:Register("SettingsSyncService", SettingsSyncService.new(), "Infrastructure")
	registry:Register("UpdateSoundSettings", UpdateSoundSettings.new(), "Application")
	registry:Register("GetSettings", GetSettings.new(), "Application")

	registry:InitAll()

	self.PersistenceService = registry:Get("SettingsPersistenceService")
	self.SyncService = registry:Get("SettingsSyncService")
	self.UpdateSoundSettings = registry:Get("UpdateSoundSettings")
	self.GetSettings = registry:Get("GetSettings")
end

function SettingsContext:KnitStart()
	self.Registry:StartOrdered({ "Domain", "Infrastructure", "Application" })

	GameEvents.Bus:On(Events.Persistence.ProfileLoaded, function(player)
		ProfileManager:WaitForData(player)
			:andThen(function()
				self:_LoadSettingsOnPlayerJoin(player)
				PlayerLifecycleManager:NotifyLoaded(player, "SettingsContext")
			end)
			:catch(function(err)
				warn("[SettingsContext] Failed to load player data:", tostring(err))
			end)
	end)

	GameEvents.Bus:On(Events.Persistence.ProfileSaving, function(player)
		self.SyncService:RemovePlayerSettings(player.UserId)
	end)
end

function SettingsContext:_LoadSettingsOnPlayerJoin(player: Player)
	local settings = self.PersistenceService:LoadSettings(player)
	if not settings then
		return
	end

	self.SyncService:LoadPlayerSettings(player.UserId, settings)
	self.SyncService:HydratePlayer(player)
end

function SettingsContext.Client:RequestSettingsState(player: Player): boolean
	if not self.Server.SyncService:GetSettingsReadOnly(player.UserId) then
		local settings = self.Server.PersistenceService:LoadSettings(player)
		if settings then
			self.Server.SyncService:LoadPlayerSettings(player.UserId, settings)
		end
	end

	self.Server.SyncService:HydratePlayer(player)
	return true
end

function SettingsContext.Client:GetSettings(player: Player)
	return Catch(function()
		return self.Server.GetSettings:Execute(player, player.UserId)
	end, "Settings.Client:GetSettings")
end

function SettingsContext.Client:UpdateSoundSettings(player: Player, patch: { [string]: any })
	return Catch(function()
		return self.Server.UpdateSoundSettings:Execute(player, player.UserId, patch)
	end, "Settings.Client:UpdateSoundSettings")
end

WrapContext(SettingsContext, "SettingsContext")

return SettingsContext
