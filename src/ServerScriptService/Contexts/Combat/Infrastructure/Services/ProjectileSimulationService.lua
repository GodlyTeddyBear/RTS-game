--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FastCast = require(ReplicatedStorage.Utilities.FastCastRedux)
local PartCache = require(ReplicatedStorage.Utilities.PartCache)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)
local ProjectileConfig = require(ReplicatedStorage.Contexts.Combat.Config.ProjectileConfig)

local ProjectileSimulationService = {}
ProjectileSimulationService.__index = ProjectileSimulationService

function ProjectileSimulationService.new()
	local self = setmetatable({}, ProjectileSimulationService)
	self._caster = FastCast.new()
	self._connections = {}
	self._impacts = {}
	self._completedHandles = {}
	self._nextHandle = 0
	self._casts = {}
	self._folder = nil
	self._bulletCache = nil
	return self
end

function ProjectileSimulationService:Start()
	self._folder = self:_EnsureFolder()
	local template = self:_ResolveTemplate(ProjectileConfig.Bullet.TemplatePath)
	if template ~= nil then
		self._bulletCache = PartCache.new(template, ProjectileConfig.Bullet.CosmeticCacheSize, self._folder)
	end
	table.insert(self._connections, self._caster.LengthChanged:Connect(function(
		_cast: any,
		lastPoint: Vector3,
		rayDirection: Vector3,
		rayDisplacement: number,
		_segmentVelocity: Vector3,
		cosmeticBullet: Instance?
	)
		if cosmeticBullet == nil or not cosmeticBullet:IsA("BasePart") then return end
		local offset = CFrame.new(0, 0, -(rayDisplacement - cosmeticBullet.Size.Z) / 2)
		cosmeticBullet.CFrame = CFrame.lookAt(lastPoint, lastPoint + rayDirection) * offset
	end))
	table.insert(self._connections, self._caster.RayHit:Connect(function(cast: any, raycastResult: RaycastResult)
		self:_CaptureImpact(cast, raycastResult)
	end))
	table.insert(self._connections, self._caster.CastTerminating:Connect(function(cast: any)
		local userData = cast.UserData
		if type(userData) == "table" and type(userData.Handle) == "string" then
			self._casts[userData.Handle] = nil
			table.insert(self._completedHandles, userData.Handle)
		end
		local cosmeticBullet = cast.RayInfo and cast.RayInfo.CosmeticBulletObject
		if cosmeticBullet ~= nil and self._bulletCache ~= nil and cosmeticBullet:IsA("BasePart") then
			self._bulletCache:ReturnPart(cosmeticBullet)
		end
	end))
end

function ProjectileSimulationService:Spawn(request: any): any
	local origin = request.Origin
	local targetPosition = request.TargetPosition
	if typeof(origin) ~= "CFrame" or typeof(targetPosition) ~= "Vector3" then
		return { success = false, reason = "InvalidProjectileEndpoints" }
	end
	local direction = targetPosition - origin.Position
	if direction.Magnitude <= 0 then
		return { success = false, reason = "InvalidProjectileDirection" }
	end

	self._nextHandle += 1
	local handle = string.format("CombatProjectile_%d", self._nextHandle)
	local behavior = FastCast.newBehavior()
	behavior.Acceleration = request.Gravity or Vector3.zero
	behavior.MaxDistance = request.MaxDistance
	behavior.AutoIgnoreContainer = true
	behavior.CosmeticBulletProvider = self._bulletCache
	behavior.CosmeticBulletContainer = self._folder
	behavior.RaycastParams = SpatialQuery.BuildRaycastParams(SpatialQuery.CreateRaycastOptions({
		IgnoreWater = true,
	}))

	local cast = self._caster:Fire(origin.Position, direction.Unit, request.Speed or 80, behavior)
	cast.UserData = {
		Handle = handle,
		SourceEntity = request.SourceEntity,
		AbilityId = request.AbilityId,
		Damage = request.Damage,
		ResolveEntity = request.ResolveEntity,
	}
	self._casts[handle] = cast
	return { success = true, handle = handle }
end

function ProjectileSimulationService:_CaptureImpact(cast: any, raycastResult: RaycastResult)
	local userData = cast.UserData
	if type(userData) ~= "table" or type(userData.ResolveEntity) ~= "function" then
		return
	end
	local targetEntity = userData.ResolveEntity(raycastResult.Instance)
	if type(targetEntity) ~= "number" then
		return
	end
	table.insert(self._impacts, {
		Handle = userData.Handle,
		SourceEntity = userData.SourceEntity,
		TargetEntity = targetEntity,
		AbilityId = userData.AbilityId,
		Damage = userData.Damage,
	})
end

function ProjectileSimulationService:DrainImpacts(): { any }
	local impacts = self._impacts
	self._impacts = {}
	return impacts
end

function ProjectileSimulationService:DrainCompletedHandles(): { string }
	local handles = self._completedHandles
	self._completedHandles = {}
	return handles
end

function ProjectileSimulationService:CleanupAll()
	for _, cast in pairs(table.clone(self._casts)) do
		if cast.StateInfo ~= nil and cast.StateInfo.UpdateConnection ~= nil then
			pcall(function() cast:Terminate() end)
		end
	end
	table.clear(self._casts)
	table.clear(self._impacts)
	table.clear(self._completedHandles)
end

function ProjectileSimulationService:Destroy()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
	self:CleanupAll()
	if self._bulletCache ~= nil then
		self._bulletCache:Dispose()
		self._bulletCache = nil
	end
end

function ProjectileSimulationService:_ResolveTemplate(path: { string }): BasePart?
	local current: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	for _, segment in ipairs(path) do
		current = if current ~= nil then current:FindFirstChild(segment) else nil
	end
	return if current ~= nil and current:IsA("BasePart") then current else nil
end

function ProjectileSimulationService:_EnsureFolder(): Folder
	local existing = Workspace:FindFirstChild("Projectiles")
	if existing ~= nil and existing:IsA("Folder") then return existing end
	local folder = Instance.new("Folder")
	folder.Name = "Projectiles"
	folder.Parent = Workspace
	return folder
end

return ProjectileSimulationService
