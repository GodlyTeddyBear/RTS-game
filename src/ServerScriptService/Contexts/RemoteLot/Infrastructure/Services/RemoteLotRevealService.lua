--!strict

--[=[
	@class RemoteLotRevealService
	Applies locked and unlocked visibility states to authored remote lot expansion areas.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteLotAreaConfig = require(ReplicatedStorage.Contexts.RemoteLot.Config.RemoteLotAreaConfig)

local EXPANSION_AREAS_FOLDER = "ExpansionAreas"
local ORIGINAL_TRANSPARENCY = "RemoteLotOriginalTransparency"
local ORIGINAL_CAN_COLLIDE = "RemoteLotOriginalCanCollide"
local ORIGINAL_CAN_TOUCH = "RemoteLotOriginalCanTouch"
local ORIGINAL_CAN_QUERY = "RemoteLotOriginalCanQuery"
local ORIGINAL_ENABLED = "RemoteLotOriginalEnabled"

local RemoteLotRevealService = {}
RemoteLotRevealService.__index = RemoteLotRevealService

export type TRemoteLotRevealService = typeof(setmetatable({}, RemoteLotRevealService))

function RemoteLotRevealService.new(): TRemoteLotRevealService
	return setmetatable({}, RemoteLotRevealService)
end

function RemoteLotRevealService:Init(_registry: any, _name: string) end

function RemoteLotRevealService:HideLockedAreas(model: Model)
	for _, areaDef in RemoteLotAreaConfig do
		local area = self:GetAreaGroup(model, areaDef)
		if area then
			self:_ApplyLockedState(area)
		end
	end
end

function RemoteLotRevealService:RevealArea(model: Model, areaDef: any)
	local area = self:GetAreaGroup(model, areaDef)
	if not area then
		return
	end
	self:_ApplyUnlockedState(area)
end

function RemoteLotRevealService:GetAreaGroup(model: Model, areaDef: any): Instance?
	local areasFolder = model:FindFirstChild(EXPANSION_AREAS_FOLDER)
	if not areasFolder then
		return nil
	end
	return areasFolder:FindFirstChild(areaDef.RevealGroupName)
end

function RemoteLotRevealService:_ApplyLockedState(area: Instance)
	for _, instance in area:GetDescendants() do
		local keepVisible = self:_ShouldRemainVisibleWhenLocked(instance)
		if instance:IsA("BasePart") then
			self:_CachePartState(instance)
			if not keepVisible then
				instance.Transparency = 1
				instance.CanCollide = false
				instance.CanTouch = false
				instance.CanQuery = false
			end
		elseif self:_HasEnabledProperty(instance) then
			self:_CacheEnabledState(instance)
			if not keepVisible then
				(instance :: any).Enabled = false
			end
		end
	end
end

function RemoteLotRevealService:_ApplyUnlockedState(area: Instance)
	for _, instance in area:GetDescendants() do
		if instance:IsA("BasePart") then
			self:_RestorePartState(instance)
		elseif self:_HasEnabledProperty(instance) then
			self:_RestoreEnabledState(instance)
		end
	end
end

function RemoteLotRevealService:_CachePartState(part: BasePart)
	if part:GetAttribute(ORIGINAL_TRANSPARENCY) == nil then
		part:SetAttribute(ORIGINAL_TRANSPARENCY, part.Transparency)
		part:SetAttribute(ORIGINAL_CAN_COLLIDE, part.CanCollide)
		part:SetAttribute(ORIGINAL_CAN_TOUCH, part.CanTouch)
		part:SetAttribute(ORIGINAL_CAN_QUERY, part.CanQuery)
	end
end

function RemoteLotRevealService:_RestorePartState(part: BasePart)
	local transparency = part:GetAttribute(ORIGINAL_TRANSPARENCY)
	if type(transparency) == "number" then
		part.Transparency = transparency
	end

	local canCollide = part:GetAttribute(ORIGINAL_CAN_COLLIDE)
	if type(canCollide) == "boolean" then
		part.CanCollide = canCollide
	end

	local canTouch = part:GetAttribute(ORIGINAL_CAN_TOUCH)
	if type(canTouch) == "boolean" then
		part.CanTouch = canTouch
	end

	local canQuery = part:GetAttribute(ORIGINAL_CAN_QUERY)
	if type(canQuery) == "boolean" then
		part.CanQuery = canQuery
	end
end

function RemoteLotRevealService:_CacheEnabledState(instance: Instance)
	if instance:GetAttribute(ORIGINAL_ENABLED) == nil then
		instance:SetAttribute(ORIGINAL_ENABLED, (instance :: any).Enabled)
	end
end

function RemoteLotRevealService:_RestoreEnabledState(instance: Instance)
	local enabled = instance:GetAttribute(ORIGINAL_ENABLED)
	if type(enabled) == "boolean" then
		(instance :: any).Enabled = enabled
	end
end

function RemoteLotRevealService:_HasEnabledProperty(instance: Instance): boolean
	return instance:IsA("ParticleEmitter")
		or instance:IsA("Beam")
		or instance:IsA("Trail")
		or instance:IsA("BillboardGui")
		or instance:IsA("SurfaceGui")
		or instance:IsA("ProximityPrompt")
end

function RemoteLotRevealService:_ShouldRemainVisibleWhenLocked(instance: Instance): boolean
	local current: Instance? = instance
	while current do
		if current:GetAttribute("KeepLockedVisible") == true then
			return true
		end
		if current.Name == "LockedMarker" or current.Name == "LockedPrompt" then
			return true
		end
		current = current.Parent
	end
	return false
end

return RemoteLotRevealService
