--!strict

--[=[
	@class CommanderContext
	Purpose: Owns the authoritative commander runtime, including state hydration, ability execution, god-mode overrides, and death signaling.
	Used In System: Started by Knit on the server and called by combat, run, and developer log flows that need commander state or mutation.
	High-Level Flow: Initialize registry -> hydrate player state -> service queries and commands -> sync changes and emit death signals.
	Boundaries: Owns orchestration only; does not own commander formulas, sync payload shape, or client presentation.
	@server
]=]
-- [Dependencies]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ReplicatedStorage.Utilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)
local CommanderTypes = require(ReplicatedStorage.Contexts.Commander.Types.CommanderTypes)
local CommanderConfig = require(ReplicatedStorage.Contexts.Commander.Config.CommanderConfig)
local CommandRegistry = require(ReplicatedStorage.Contexts.Log.CommandRegistry)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local BlinkServer = require(ReplicatedStorage.Network.Generated.CommanderSyncServer)

local CommanderECSWorldService = require(script.Parent.Infrastructure.ECS.CommanderECSWorldService)
local CommanderComponentRegistry = require(script.Parent.Infrastructure.ECS.CommanderComponentRegistry)
local CommanderEntityFactory = require(script.Parent.Infrastructure.ECS.CommanderEntityFactory)
local CommanderSyncService = require(script.Parent.Infrastructure.Persistence.CommanderSyncService)
local AbilityService = require(script.Parent.CommanderDomain.Services.AbilityService)
local CooldownService = require(script.Parent.CommanderDomain.Services.CooldownService)
local AbilityUsePolicy = require(script.Parent.CommanderDomain.Policies.AbilityUsePolicy)
local UseAbilityCommand = require(script.Parent.Application.Commands.UseAbilityCommand)
local GetCommanderStateQuery = require(script.Parent.Application.Queries.GetCommanderStateQuery)
local GetCooldownQuery = require(script.Parent.Application.Queries.GetCooldownQuery)
local Errors = require(script.Parent.Errors)

local Catch = Result.Catch
local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure
local fromNilable = Result.fromNilable

-- [Types]

type CommanderState = CommanderTypes.CommanderState
type SlotKey = CommanderTypes.SlotKey

-- [Constants]

local DEVELOPER_USER_ID = 205423638

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "BlinkServer",
		Instance = BlinkServer,
	},
	{
		Name = "CommanderComponentRegistry",
		Module = CommanderComponentRegistry,
	},
	{
		Name = "CommanderEntityFactory",
		Module = CommanderEntityFactory,
		CacheAs = "_entityFactory",
	},
	{
		Name = "CommanderSyncService",
		Module = CommanderSyncService,
		CacheAs = "_syncService",
	},
}

local DomainModules: { BaseContext.TModuleSpec } = {
	{
		Name = "AbilityService",
		Module = AbilityService,
	},
	{
		Name = "CooldownService",
		Module = CooldownService,
	},
	{
		Name = "AbilityUsePolicy",
		Module = AbilityUsePolicy,
	},
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	{
		Name = "UseAbilityCommand",
		Module = UseAbilityCommand,
		CacheAs = "_useAbilityCommand",
	},
	{
		Name = "GetCommanderStateQuery",
		Module = GetCommanderStateQuery,
		CacheAs = "_getCommanderStateQuery",
	},
	{
		Name = "GetCooldownQuery",
		Module = GetCooldownQuery,
		CacheAs = "_getCooldownQuery",
	},
}

local CommanderModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
	Domain = DomainModules,
	Application = ApplicationModules,
}

local CommanderContext = Knit.CreateService({
	Name = "CommanderContext",
	Client = {},
	WorldService = {
		Name = "CommanderECSWorldService",
		Module = CommanderECSWorldService,
	},
	Modules = CommanderModules,
	ProfileLifecycle = {
		LoaderName = "Commander",
		OnLoaded = "_HandleProfileLoaded",
		OnSaving = "_HandleProfileSaving",
		OnRemoving = "_HandlePlayerRemoving",
	},
	Teardown = {
		Fields = {
			{ Field = "_syncService", Method = "Destroy" },
		},
	},
	ExternalServices = {
		{ Name = "EconomyContext" },
		{ Name = "RunContext" },
		{ Name = "SummonContext" },
	},
})

local CommanderBaseContext = BaseContext.new(CommanderContext)

-- [Initialization]

--[=[
	Initializes the commander ECS stack, sync service, commands, and queries.
	@within CommanderContext
]=]
function CommanderContext:KnitInit()
	CommanderBaseContext:KnitInit()
	self._godModeEnabledByUserId = {}
	self._loadedUserIds = {} :: { [number]: true }
	CommanderBaseContext:RegisterProfileLoader()
	self:_RegisterDeveloperLogCommands()
end

-- [Private Helpers]

local function _parseUserId(rawValue: string?): number
	local parsed = tonumber(rawValue)
	if parsed == nil then
		return DEVELOPER_USER_ID
	end

	return math.floor(parsed)
end

local function _isValidSlot(slotKey: string): boolean
	for _, slot in CommanderConfig.SLOTS do
		if slot.key == slotKey then
			return true
		end
	end

	return false
end

local function _parseBooleanDirective(rawValue: string?): boolean?
	if rawValue == nil then
		return nil
	end

	local normalized = string.lower(string.gsub(rawValue, "^%s*(.-)%s*$", "%1"))
	if normalized == "true" or normalized == "1" or normalized == "on" or normalized == "yes" then
		return true
	end
	if normalized == "false" or normalized == "0" or normalized == "off" or normalized == "no" then
		return false
	end

	return nil
end

function CommanderContext:_HandleProfileLoaded(player: Player)
	if self._loadedUserIds[player.UserId] == true then
		self._syncService:HydrateAndSyncPlayer(player)
		return
	end

	self._entityFactory:CreateOrResetCommander(player.UserId, CommanderConfig.MAX_HP)
	self._syncService:HydrateAndSyncPlayer(player)
	self._loadedUserIds[player.UserId] = true
end

function CommanderContext:_HandleProfileSaving(player: Player)
	self._syncService:SyncCommanderState(player.UserId)
end

function CommanderContext:_HandlePlayerRemoving(player: Player)
	self._entityFactory:RemoveCommander(player.UserId)
	self._entityFactory:FlushPendingDeletes()
	self._syncService:RemovePlayer(player.UserId)
	self:SetGodModeEnabled(player.UserId, false)
	self._loadedUserIds[player.UserId] = nil
end

function CommanderContext:_RegisterDeveloperLogCommands()
	CommandRegistry.Register({
		name = "Commander.GetStateSummary",
		context = "Commander",
		description = "Shows HP and active cooldown count for a commander user id.",
		params = {
			{ name = "userId", label = "User ID", default = tostring(DEVELOPER_USER_ID) },
		},
		handler = function(params: { [string]: string }): (boolean, string)
			local userId = _parseUserId(params.userId)
			local state = self._getCommanderStateQuery:Execute(userId)
			if state == nil then
				return false, string.format("No commander state found for user %d", userId)
			end

			local cooldownCount = 0
			for _, cooldown in pairs(state.cooldowns) do
				if cooldown ~= nil then
					cooldownCount += 1
				end
			end

			return true,
				string.format("userId=%d hp=%d/%d activeCooldowns=%d", userId, state.hp, state.maxHp, cooldownCount)
		end,
	})

	CommandRegistry.Register({
		name = "Commander.GetCooldownRemaining",
		context = "Commander",
		description = "Returns remaining cooldown in seconds for a commander slot.",
		params = {
			{ name = "userId", label = "User ID", default = tostring(DEVELOPER_USER_ID) },
			{ name = "slotKey", label = "Slot Key", default = "Mobility" },
		},
		handler = function(params: { [string]: string }): (boolean, string)
			local userId = _parseUserId(params.userId)
			local slotKey = params.slotKey or "Mobility"
			if not _isValidSlot(slotKey) then
				return false, string.format("Invalid slotKey '%s'", slotKey)
			end

			local remaining = self._getCooldownQuery:Execute(userId, slotKey :: SlotKey)
			return true, string.format("userId=%d slot=%s remaining=%.2fs", userId, slotKey, remaining)
		end,
	})

	CommandRegistry.Register({
		name = "Run.SetGodMode",
		context = "Run",
		description = "Enable, disable, or toggle commander god mode for a user id.",
		params = {
			{ name = "userId", label = "User ID", default = tostring(DEVELOPER_USER_ID) },
			{ name = "enabled", label = "Enabled (true/false/toggle)", default = "toggle" },
		},
		handler = function(params: { [string]: string }): (boolean, string)
			local userId = _parseUserId(params.userId)
			local current = self:IsGodModeEnabled(userId)
			local enabledParam = params.enabled
			local nextEnabled: boolean

			if enabledParam == nil or string.lower(enabledParam) == "toggle" then
				nextEnabled = not current
			else
				local parsed = _parseBooleanDirective(enabledParam)
				if parsed == nil then
					return false,
						string.format("Invalid enabled value '%s'. Use true/false/toggle.", tostring(enabledParam))
				end
				nextEnabled = parsed
			end

			self:SetGodModeEnabled(userId, nextEnabled)
			Result.MentionEvent("CommanderContext:GodMode", "God mode updated", {
				UserId = userId,
				Enabled = nextEnabled,
			})

			return true, string.format("Run.SetGodMode userId=%d enabled=%s", userId, tostring(nextEnabled))
		end,
	})
end

-- [Public API]

function CommanderContext:IsGodModeEnabled(userId: number): boolean
	return self._godModeEnabledByUserId[userId] == true
end

function CommanderContext:SetGodModeEnabled(userId: number, isEnabled: boolean)
	if isEnabled then
		self._godModeEnabledByUserId[userId] = true
		return
	end

	self._godModeEnabledByUserId[userId] = nil
end

--[=[
	Starts commander lifecycle wiring.
	@within CommanderContext
]=]
function CommanderContext:KnitStart()
	CommanderBaseContext:KnitStart()
	CommanderBaseContext:StartProfileLifecycle()
end

function CommanderContext:ApplyDamage(player: Player, amount: number): Result.Result<number>
	return Catch(function()
		Ensure(player, "InvalidPlayer", Errors.INVALID_PLAYER)
		Ensure(amount > 0, "InvalidDamageAmount", Errors.INVALID_DAMAGE_AMOUNT, { amount = amount })

		local previousState = Try(
			fromNilable(
				self._getCommanderStateQuery:Execute(player.UserId),
				"CommanderNotFound",
				Errors.COMMANDER_NOT_FOUND,
				{ userId = player.UserId }
			)
		) :: CommanderState

		if self:IsGodModeEnabled(player.UserId) then
			return Ok(previousState.hp)
		end

		local nextHp = Try(
			fromNilable(
				self._entityFactory:ApplyDamage(player.UserId, amount),
				"CommanderNotFound",
				Errors.COMMANDER_NOT_FOUND,
				{ userId = player.UserId }
			)
		)
		self._syncService:SyncCommanderState(player.UserId)

		if previousState.hp > 0 and nextHp <= 0 then
			Result.MentionEvent("CommanderContext:CommanderDeath", "Commander HP reached zero", {
				UserId = player.UserId,
			})
			GameEvents.Bus:Emit(GameEvents.Events.Commander.CommanderDied, player)
		end

		return Ok(nextHp)
	end, "Commander:ApplyDamage")
end

function CommanderContext:GetCommanderState(userId: number): Result.Result<CommanderState?>
	return Catch(function()
		return Ok(self._getCommanderStateQuery:Execute(userId))
	end, "Commander:GetCommanderState")
end

function CommanderContext:GetCooldownRemaining(userId: number, slotKey: SlotKey): Result.Result<number>
	return Catch(function()
		return Ok(self._getCooldownQuery:Execute(userId, slotKey))
	end, "Commander:GetCooldownRemaining")
end

function CommanderContext:UseAbility(player: Player, slotKey: SlotKey): Result.Result<{ slotKey: SlotKey }>
	return Catch(function()
		Ensure(player, "InvalidPlayer", Errors.INVALID_PLAYER)
		return self._useAbilityCommand:Execute(player, slotKey)
	end, "Commander:UseAbility")
end

function CommanderContext.Client:UseAbility(player: Player, slotKey: SlotKey)
	return self.Server:UseAbility(player, slotKey)
end

function CommanderContext:Destroy()
	local destroyResult = CommanderBaseContext:Destroy()
	if not destroyResult.success then
		Result.MentionError("Commander:Destroy", "BaseContext teardown failed", {
			CauseType = destroyResult.type,
			CauseMessage = destroyResult.message,
		}, destroyResult.type)
	end
end

return CommanderContext
