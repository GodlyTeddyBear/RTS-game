--!strict

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local RenderConfig = require(ReplicatedStorage.Contexts.Render.Config.RenderConfig)

local RenderRuntimeService = {}
RenderRuntimeService.__index = RenderRuntimeService

function RenderRuntimeService.new()
	local self = setmetatable({}, RenderRuntimeService)
	self._janitor = Janitor.new()
	return self
end

function RenderRuntimeService:Start()
	-- Apply the low-cost lighting profile first.
	self:_ApplyLightingProfile()

	-- Stamp and strip current world parts before normal gameplay begins.
	self:_ApplyWorkspaceProfile()

	-- Keep the server render profile applied to future runtime descendants.
	self:_TrackWorkspaceDescendants()
end

function RenderRuntimeService:Destroy()
	self._janitor:Destroy()
end

function RenderRuntimeService:_ApplyLightingProfile()
	for propertyName, propertyValue in RenderConfig.ServerProfile.Lighting do
		(Lighting :: any)[propertyName] = propertyValue
	end
end

function RenderRuntimeService:_ApplyWorkspaceProfile()
	for _, descendant in Workspace:GetDescendants() do
		self:_ApplyInstanceProfile(descendant)
	end
end

function RenderRuntimeService:_TrackWorkspaceDescendants()
	self._janitor:Add(Workspace.DescendantAdded:Connect(function(instance: Instance)
		self:_ApplyInstanceProfile(instance)
	end), "Disconnect")
end

function RenderRuntimeService:_ApplyInstanceProfile(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end

	self:_StampAuthoredShadowState(instance)
	instance.CastShadow = false
end

function RenderRuntimeService:_StampAuthoredShadowState(part: BasePart)
	local attributeName = RenderConfig.ShadowStateAttributeName
	local authoredShadowState = part:GetAttribute(attributeName)
	if typeof(authoredShadowState) == "boolean" then
		return
	end

	part:SetAttribute(attributeName, part.CastShadow)
end

return RenderRuntimeService
