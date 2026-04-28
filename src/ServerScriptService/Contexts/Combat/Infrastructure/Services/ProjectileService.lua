--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FastCast = require(ReplicatedStorage.Utilities.FastCastRedux)
local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local PartCache = require(ReplicatedStorage.Utilities.PartCache)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)
local ProjectileConfig = require(ReplicatedStorage.Contexts.Combat.Config.ProjectileConfig)

local PROJECTILE_FOLDER_NAME = "Projectiles"
local MUZZLE_ATTACHMENT_NAME = "Muzzle"

type TBulletConfig = typeof(ProjectileConfig.Bullet)

export type TStructureBulletRequest = {
	StructureEntity: number,
	TargetEnemyEntity: number,
	Damage: number,
	MaxDistance: number,
}

type TFireResult = {
	success: boolean,
	projectileId: string?,
	reason: string?,
}

type TCastUserData = {
	ProjectileId: string,
	StructureEntity: number,
	TargetEnemyEntity: number,
	Damage: number,
	MaxPierces: number,
	HitEnemies: { [number]: boolean },
	HitCount: number,
}

--[=[
	@class ProjectileService
	Owns FastCast projectile simulation and optional PartCache cosmetics for Combat.
	@server
]=]
local ProjectileService = {}
ProjectileService.__index = ProjectileService

function ProjectileService.new()
	local self = setmetatable({}, ProjectileService)
	self._caster = FastCast.new()
	self._behavior = FastCast.newBehavior()
	self._projectileFolder = nil :: Folder?
	self._bulletCache = nil :: any
	self._registry = nil
	self._enemyContext = nil
	self._enemyEntityFactory = nil
	self._enemyInstanceFactory = nil
	self._structureEntityFactory = nil
	self._connections = {} :: { RBXScriptConnection }
	self._activeCasts = {} :: { [string]: any }
	self._nextProjectileId = 0
	return self
end

function ProjectileService:Init(registry: any, _name: string)
	self._registry = registry
end

function ProjectileService:Start()
	self._enemyContext = self._registry:Get("EnemyContext")
	self._enemyEntityFactory = self._registry:Get("EnemyEntityFactory")
	self._enemyInstanceFactory = self._registry:Get("EnemyInstanceFactory")
	self._structureEntityFactory = self._registry:Get("StructureEntityFactory")
	self._projectileFolder = self:_EnsureProjectileFolder()
	self._bulletCache = self:_BuildBulletCache(ProjectileConfig.Bullet)
	self:_ConfigureBehavior(ProjectileConfig.Bullet)
	self:_ConnectCaster()
end

function ProjectileService:FireStructureBullet(request: TStructureBulletRequest): TFireResult
	-- Resolve the firing position and target before allocating any projectile state.
	local originCFrame = self:_ResolveStructureMuzzleCFrame(request.StructureEntity)
	if originCFrame == nil then
		return {
			success = false,
			reason = "MissingProjectileOrigin",
		}
	end

	local targetCFrame = self._enemyEntityFactory:GetEntityCFrame(request.TargetEnemyEntity)
	if targetCFrame == nil then
		return {
			success = false,
			reason = "MissingProjectileTarget",
		}
	end

	local direction = targetCFrame.Position - originCFrame.Position
	if direction.Magnitude <= 0 then
		return {
			success = false,
			reason = "InvalidProjectileDirection",
		}
	end

	-- Build the shot only after the direction is known so the cast cannot start invalid.
	local projectileId = self:_NextProjectileId()
	local behavior = self:_BuildBehaviorForShot(request)
	local cast = self._caster:Fire(originCFrame.Position, direction.Unit, ProjectileConfig.Bullet.Speed, behavior)
	cast.UserData = {
		ProjectileId = projectileId,
		StructureEntity = request.StructureEntity,
		TargetEnemyEntity = request.TargetEnemyEntity,
		Damage = request.Damage,
		MaxPierces = ProjectileConfig.Bullet.MaxPierces,
		HitEnemies = {},
		HitCount = 0,
	} :: TCastUserData
	self._activeCasts[projectileId] = cast

	return {
		success = true,
		projectileId = projectileId,
	}
end

function ProjectileService:CleanupAll()
	-- Clone the active cast map so termination can mutate the live table safely.
	local activeCasts = table.clone(self._activeCasts)

	for _, cast in pairs(activeCasts) do
		-- Terminate only casts that still own an update connection.
		if cast.StateInfo ~= nil and cast.StateInfo.UpdateConnection ~= nil then
			pcall(function()
				cast:Terminate()
			end)
		end
	end
end

function ProjectileService:Destroy()
	-- Reuse the cleanup path so cast teardown stays consistent with combat shutdown.
	self:CleanupAll()

	-- Disconnect event listeners before releasing cached cosmetic parts.
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)

	-- Dispose the cache last so any queued cast teardown can still return parts safely.
	if self._bulletCache ~= nil then
		self._bulletCache:Dispose()
		self._bulletCache = nil
	end
end

function ProjectileService:_ConnectCaster()
	-- Keep the cosmetic bullet aligned with the simulated ray segment as it advances.
	table.insert(self._connections, self._caster.LengthChanged:Connect(function(
		_cast: any,
		lastPoint: Vector3,
		rayDirection: Vector3,
		rayDisplacement: number,
		_segmentVelocity: Vector3,
		cosmeticBulletObject: Instance?
	)
		if cosmeticBulletObject == nil or not cosmeticBulletObject:IsA("BasePart") then
			return
		end

		local bulletLength = cosmeticBulletObject.Size.Z
		local offset = CFrame.new(0, 0, -(rayDisplacement - bulletLength) / 2)
		cosmeticBulletObject.CFrame = CFrame.lookAt(lastPoint, lastPoint + rayDirection) * offset
	end))

	-- Forward hit events into the damage pipeline and clean up terminated casts.
	table.insert(self._connections, self._caster.RayHit:Connect(function(cast: any, raycastResult: RaycastResult)
		self:_HandleRayHit(cast, raycastResult)
	end))

	table.insert(self._connections, self._caster.RayPierced:Connect(function(_cast: any, _raycastResult: RaycastResult) end))

	table.insert(self._connections, self._caster.CastTerminating:Connect(function(cast: any)
		self:_HandleCastTerminating(cast)
	end))
end

function ProjectileService:_ConfigureBehavior(config: TBulletConfig)
	self._behavior.Acceleration = config.Gravity
	self._behavior.HighFidelityBehavior = FastCast.HighFidelityBehavior.Always
	self._behavior.HighFidelitySegmentSize = config.HighFidelitySegmentSize
	self._behavior.CosmeticBulletProvider = self._bulletCache
	self._behavior.CosmeticBulletContainer = self._projectileFolder
	self._behavior.AutoIgnoreContainer = true
	self._behavior.CanPierceFunction = function(cast: any, raycastResult: RaycastResult)
		return self:_CanPierce(cast, raycastResult)
	end
end

function ProjectileService:_BuildBehaviorForShot(request: TStructureBulletRequest)
	local behavior = FastCast.newBehavior()
	behavior.Acceleration = self._behavior.Acceleration
	behavior.HighFidelityBehavior = self._behavior.HighFidelityBehavior
	behavior.HighFidelitySegmentSize = self._behavior.HighFidelitySegmentSize
	behavior.CosmeticBulletProvider = self._bulletCache
	behavior.CosmeticBulletContainer = self._projectileFolder
	behavior.AutoIgnoreContainer = true
	behavior.MaxDistance = request.MaxDistance
	behavior.CanPierceFunction = self._behavior.CanPierceFunction
	behavior.RaycastParams = self:_BuildRaycastParams(request.StructureEntity)
	return behavior
end

function ProjectileService:_BuildRaycastParams(structureEntity: number): RaycastParams
	local excludedInstances = {}
	local modelRef = self._structureEntityFactory:GetModelRef(structureEntity)
	if modelRef ~= nil and modelRef.Model ~= nil then
		table.insert(excludedInstances, modelRef.Model)
	end
	if self._projectileFolder ~= nil then
		table.insert(excludedInstances, self._projectileFolder)
	end

	local raycastOptions = SpatialQuery.MergeOptions(
		SpatialQuery.CreateRaycastOptions({
			IgnoreWater = true,
		}),
		SpatialQuery.WithExcludedInstances(excludedInstances)
	)

	return SpatialQuery.BuildRaycastParams(raycastOptions)
end

function ProjectileService:_CanPierce(cast: any, raycastResult: RaycastResult): boolean
	local enemyEntity = self:_ResolveEnemyEntity(raycastResult.Instance)
	if enemyEntity == nil then
		return false
	end

	if not self._enemyEntityFactory:IsAlive(enemyEntity) then
		return true
	end

	local userData = cast.UserData :: TCastUserData
	if userData.HitEnemies[enemyEntity] == true then
		return true
	end

	userData.HitEnemies[enemyEntity] = true
	userData.HitCount += 1
	self:_ApplyDamage(enemyEntity, userData.Damage)

	return userData.HitCount < userData.MaxPierces
end

function ProjectileService:_HandleRayHit(cast: any, raycastResult: RaycastResult)
	local enemyEntity = self:_ResolveEnemyEntity(raycastResult.Instance)
	if enemyEntity == nil or not self._enemyEntityFactory:IsAlive(enemyEntity) then
		return
	end

	local userData = cast.UserData :: TCastUserData
	if userData.HitEnemies[enemyEntity] == true then
		return
	end

	userData.HitEnemies[enemyEntity] = true
	userData.HitCount += 1
	self:_ApplyDamage(enemyEntity, userData.Damage)
end

function ProjectileService:_HandleCastTerminating(cast: any)
	local userData = cast.UserData
	if type(userData) == "table" and type(userData.ProjectileId) == "string" then
		self._activeCasts[userData.ProjectileId] = nil
	end

	local cosmeticBulletObject = cast.RayInfo and cast.RayInfo.CosmeticBulletObject
	if cosmeticBulletObject ~= nil and self._bulletCache ~= nil and cosmeticBulletObject:IsA("BasePart") then
		self._bulletCache:ReturnPart(cosmeticBulletObject)
	end
end

function ProjectileService:_ApplyDamage(enemyEntity: number, damage: number)
	self._enemyContext:ApplyDamage(enemyEntity, damage)
end

function ProjectileService:_ResolveEnemyEntity(hitPart: Instance): number?
	local model = hitPart:FindFirstAncestorOfClass("Model")
	if model == nil then
		return nil
	end

	return self._enemyInstanceFactory:GetEntity(model)
end

function ProjectileService:_ResolveStructureMuzzleCFrame(structureEntity: number): CFrame?
	local modelRef = self._structureEntityFactory:GetModelRef(structureEntity)
	if modelRef == nil or modelRef.Model == nil or modelRef.Model.Parent == nil then
		return nil
	end

	local muzzle = modelRef.Model:FindFirstChild(MUZZLE_ATTACHMENT_NAME, true)
	if muzzle ~= nil and muzzle:IsA("Attachment") then
		return muzzle.WorldCFrame
	end

	if modelRef.Model.PrimaryPart ~= nil then
		return modelRef.Model.PrimaryPart.CFrame
	end

	return ModelPlus.GetPivot(modelRef.Model)
end

function ProjectileService:_BuildBulletCache(config: TBulletConfig): any?
	local template = self:_ResolveBulletTemplate(config)
	if template == nil then
		return nil
	end

	return PartCache.new(template, config.CosmeticCacheSize, self._projectileFolder)
end

function ProjectileService:_ResolveBulletTemplate(config: TBulletConfig): BasePart?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets == nil then
		return nil
	end

	local current: Instance? = assets
	for _, pathSegment in ipairs(config.TemplatePath) do
		current = current and current:FindFirstChild(pathSegment) or nil
		if current == nil then
			return nil
		end
	end

	if current:IsA("BasePart") then
		return current
	end
	return nil
end

function ProjectileService:_EnsureProjectileFolder(): Folder
	local existing = Workspace:FindFirstChild(PROJECTILE_FOLDER_NAME)
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = PROJECTILE_FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

function ProjectileService:_NextProjectileId(): string
	self._nextProjectileId += 1
	return string.format("Projectile_%d", self._nextProjectileId)
end

return ProjectileService
