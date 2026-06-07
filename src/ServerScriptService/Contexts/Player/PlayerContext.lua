--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ServerStorage.Utilities.ContextUtilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)

local PlayerEntitySchema = require(script.Parent.Infrastructure.Entity.PlayerEntitySchema)

local PlayerContext = Knit.CreateService({
	Name = "PlayerContext",
	Client = {},
	Modules = {},
	ExternalServices = {
		{ Name = "EntityContext", CacheAs = "_entityContext" },
		{ Name = "AnimationContext", CacheAs = "_animationContext" },
	},
	Teardown = {},
})

local PlayerBaseContext = BaseContext.new(PlayerContext)

function PlayerContext:KnitInit()
	PlayerBaseContext:KnitInit()
	self._entityByPlayer = {}
	self._connectionsByPlayer = {}
	self._playerAddedConnection = nil
	self._playerRemovingConnection = nil
end

function PlayerContext:KnitStart()
	PlayerBaseContext:KnitStart()
	local registrationResult = self._entityContext:RegisterEntityFeature({
		FeatureName = "Player",
		Schema = PlayerEntitySchema,
	})
	local completionResult = self._entityContext:CompleteRegistration(self.Name, registrationResult)
	if not completionResult.success then
		error(("PlayerContext failed to complete Entity registration: [%s] %s"):format(
			tostring(completionResult.type),
			tostring(completionResult.message)
		))
	end

	local readyResult = self._entityContext:OnRuntimeReady(function()
		self:_StartPlayerRuntime()
	end)
	if not readyResult.success then
		error(("PlayerContext failed to await Entity runtime: [%s] %s"):format(
			tostring(readyResult.type),
			tostring(readyResult.message)
		))
	end
end

function PlayerContext:_StartPlayerRuntime()
	self._playerAddedConnection = Players.PlayerAdded:Connect(function(player)
		self:_TrackPlayer(player)
	end)
	self._playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		self:_RemovePlayer(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		self:_TrackPlayer(player)
	end
end

function PlayerContext:_TrackPlayer(player: Player)
	self:_DisconnectPlayer(player)
	local connections = {}
	connections.CharacterAdded = player.CharacterAdded:Connect(function(character)
		self:_BindCharacter(player, character)
	end)
	connections.CharacterRemoving = player.CharacterRemoving:Connect(function()
		local entity = self._entityByPlayer[player]
		if entity ~= nil then
			self._entityContext:UnbindEntityInstance(entity)
		end
	end)
	self._connectionsByPlayer[player] = connections
	if player.Character ~= nil then
		self:_BindCharacter(player, player.Character)
	end
end

function PlayerContext:_BindCharacter(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end

	local entity = self._entityByPlayer[player]
	if entity == nil then
		local createResult = self._entityContext:CreateEntity("Player.Actor", {
			Identity = {
				EntityId = tostring(player.UserId),
				EntityKind = "Player",
				DefinitionId = "Player",
			},
			Ownership = {
				Faction = "Player",
				OwnerKind = "Player",
				OwnerId = tostring(player.UserId),
			},
			Health = {
				Current = humanoid.Health,
				Max = humanoid.MaxHealth,
			},
			Transform = {
				CFrame = character:GetPivot(),
			},
			ModelRef = {
				Model = character,
			},
			ModelAsset = {
				AssetDomain = "Player",
				AssetId = tostring(player.UserId),
				AssetKind = "Existing",
			},
			ModelBinding = {
				SetupProfileId = "ExistingHumanoidActor",
				RevealTag = "EntityPlayer",
				PreserveInstance = true,
			},
			HumanoidProjection = {
				Enabled = false,
				Health = false,
				WalkSpeed = false,
			},
			TransformProjection = {
				Enabled = false,
			},
			TransformPoll = {
				Enabled = true,
			},
			PlayerState = {
				UserId = player.UserId,
				Name = player.Name,
			},
		})
		if not createResult.success then
			warn("[PlayerContext] failed to create player entity:", createResult.message)
			return
		end
		entity = createResult.value
		self._entityByPlayer[player] = entity
		local animationResult = self._animationContext:SetupEntity(entity, {
			ProfileId = "PlayerHumanoid",
			AnimationSetId = "Player",
			VariantId = "Default",
		})
		if not animationResult.success then
			warn("[PlayerContext] failed to setup player animation:", animationResult.message)
		end
		local runtimeResult = self._entityContext:RegisterRuntimeEntity(entity)
		if not runtimeResult.success then
			warn("[PlayerContext] failed to register player runtime:", runtimeResult.message)
			return
		end
		self._entityContext:FlushBindQueue()
		return
	end

	self._entityContext:Set(entity, "ModelRef", { Model = character }, "Entity")
	self._entityContext:Set(entity, "Transform", { CFrame = character:GetPivot() }, "Entity")
	self._entityContext:Set(entity, "Health", { Current = humanoid.Health, Max = humanoid.MaxHealth }, "Entity")
	self._entityContext:BindEntityInstance(entity)
end

function PlayerContext:_DisconnectPlayer(player: Player)
	local connections = self._connectionsByPlayer[player]
	if connections == nil then
		return
	end
	for _, connection in pairs(connections) do
		connection:Disconnect()
	end
	self._connectionsByPlayer[player] = nil
end

function PlayerContext:_RemovePlayer(player: Player)
	self:_DisconnectPlayer(player)
	local entity = self._entityByPlayer[player]
	if entity ~= nil then
		self._entityContext:DestroyEntity(entity)
		self._entityByPlayer[player] = nil
	end
end

function PlayerContext:Destroy()
	if self._playerAddedConnection ~= nil then
		self._playerAddedConnection:Disconnect()
	end
	if self._playerRemovingConnection ~= nil then
		self._playerRemovingConnection:Disconnect()
	end
	for _, player in ipairs(Players:GetPlayers()) do
		self:_RemovePlayer(player)
	end
	PlayerBaseContext:Destroy()
end

return PlayerContext
