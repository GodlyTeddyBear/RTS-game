--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok

local BaseEntityReadService = {}
BaseEntityReadService.__index = BaseEntityReadService

function BaseEntityReadService.new()
	return setmetatable({}, BaseEntityReadService)
end

function BaseEntityReadService:Init(registry: any, _name: string)
	self._entityContext = registry:Get("EntityContext")
end

function BaseEntityReadService:GetActiveBaseEntity(): number?
	local result = self._entityContext:Query({
		Keys = {
			{ Key = "BaseTag", FeatureName = "Base" },
			{ Key = "ActiveTag", FeatureName = "Entity" },
		},
	})
	if not result.success then
		return nil
	end

	return result.value[1]
end

function BaseEntityReadService:GetBaseState(): any?
	local entity = self:GetActiveBaseEntity()
	if entity == nil then
		return nil
	end

	local health = self:_Get(entity, "Health", "Entity")
	if type(health) ~= "table" then
		return nil
	end

	return {
		Hp = health.Current or 0,
		MaxHp = health.Max or health.Current or 0,
	}
end

function BaseEntityReadService:GetTargetCFrame(): CFrame?
	local entity = self:GetActiveBaseEntity()
	if entity == nil then
		return nil
	end

	local anchorRef = self:_Get(entity, "AnchorRef", "Base")
	local anchor = if type(anchorRef) == "table" then anchorRef.Anchor else nil
	if typeof(anchor) == "Instance" and anchor:IsA("BasePart") then
		return anchor.CFrame
	end

	local transform = self:_Get(entity, "Transform", "Entity")
	if type(transform) == "table" and typeof(transform.CFrame) == "CFrame" then
		return transform.CFrame
	end

	return nil
end

function BaseEntityReadService:GetMapInstance(): Instance?
	local entity = self:GetActiveBaseEntity()
	if entity == nil then
		return nil
	end

	local ref = self:_Get(entity, "MapInstanceRef", "Base")
	local instance = if type(ref) == "table" then ref.Instance else nil
	return if typeof(instance) == "Instance" then instance else nil
end

function BaseEntityReadService:SyncState(syncService: any?): Result.Result<boolean>
	if syncService ~= nil and type(syncService.SyncBaseState) == "function" then
		syncService:SyncBaseState()
	end
	return Ok(true)
end

function BaseEntityReadService:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityContext:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return BaseEntityReadService
