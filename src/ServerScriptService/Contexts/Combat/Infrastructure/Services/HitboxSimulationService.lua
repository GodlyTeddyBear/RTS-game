--!strict

local ServerStorage = game:GetService("ServerStorage")

local MuchachoHitbox = require(ServerStorage.Utilities.MuchachoHitbox)

local HitboxSimulationService = {}
HitboxSimulationService.__index = HitboxSimulationService

function HitboxSimulationService.new()
	local self = setmetatable({}, HitboxSimulationService)
	self._runner = nil
	self._records = {}
	self._impacts = {}
	return self
end

function HitboxSimulationService:Start()
	if self._runner == nil then
		self._runner = MuchachoHitbox.CreateRunner()
	end
end

function HitboxSimulationService:Tick(dt: number)
	if self._runner ~= nil then
		self._runner:Step(dt)
	end
end

function HitboxSimulationService:Create(request: any): any
	local model = request.SourceModel
	if model == nil or not model:IsA("Model") or model.PrimaryPart == nil then
		return { success = false, reason = "MissingHitboxSourceModel" }
	end

	self:Start()
	local hitbox = MuchachoHitbox.CreateHitbox()
	hitbox.DetectionMode = request.DetectionMode or "HitOnce"
	hitbox.Shape = request.Shape or Enum.PartType.Block
	hitbox.Size = request.Size or Vector3.new(4, 4, 4)
	hitbox.Offset = request.Offset or CFrame.new()
	hitbox.CFrame = model.PrimaryPart
	hitbox.AutoDestroy = false

	local handle = hitbox.Key
	local seen = {}
	local connection = hitbox.Touched:Connect(function(hitPart: BasePart)
		local targetEntity = request.ResolveEntity(hitPart)
		if type(targetEntity) ~= "number" or seen[targetEntity] == true then
			return
		end
		seen[targetEntity] = true
		table.insert(self._impacts, {
			Handle = handle,
			SourceEntity = request.SourceEntity,
			TargetEntity = targetEntity,
			AbilityId = request.AbilityId,
			Damage = request.Damage,
		})
	end)

	self._records[handle] = {
		Hitbox = hitbox,
		Connection = connection,
	}
	hitbox:Start(self._runner)
	return { success = true, handle = handle }
end

function HitboxSimulationService:DrainImpacts(): { any }
	local impacts = self._impacts
	self._impacts = {}
	return impacts
end

function HitboxSimulationService:DestroyHandle(handle: string)
	local record = self._records[handle]
	if record == nil then
		return
	end
	record.Connection:Disconnect()
	record.Hitbox:Destroy()
	self._records[handle] = nil
end

function HitboxSimulationService:CleanupAll()
	for handle in pairs(table.clone(self._records)) do
		self:DestroyHandle(handle)
	end
	table.clear(self._impacts)
end

function HitboxSimulationService:Destroy()
	self:CleanupAll()
	if self._runner ~= nil then
		self._runner:Destroy()
		self._runner = nil
	end
end

return HitboxSimulationService
