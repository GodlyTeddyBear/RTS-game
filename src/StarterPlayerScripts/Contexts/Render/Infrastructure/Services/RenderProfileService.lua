--!strict

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local RenderConfig = require(ReplicatedStorage.Contexts.Render.Config.RenderConfig)

local RenderProfileService = {}
RenderProfileService.__index = RenderProfileService

function RenderProfileService.new()
	local self = setmetatable({}, RenderProfileService)
	self._janitor = Janitor.new()
	self._pendingAttributeConnections = {}
	return self
end

function RenderProfileService:Start()
	-- Restore client-only lighting before touching per-instance visuals.
	self:_ApplyLightingProfile()

	-- Restore current world parts, then keep future descendants corrected.
	self:_ApplyWorkspaceProfile()
	self:_TrackWorkspaceDescendants()
end

function RenderProfileService:Destroy()
	self:_DisconnectPendingAttributeConnections()
	self._janitor:Destroy()
end

function RenderProfileService:_ApplyLightingProfile()
	for propertyName, propertyValue in RenderConfig.ClientProfile.Lighting do
		(Lighting :: any)[propertyName] = propertyValue
	end
end

function RenderProfileService:_ApplyWorkspaceProfile()
	for _, descendant in Workspace:GetDescendants() do
		self:_ApplyInstanceProfile(descendant)
	end
end

function RenderProfileService:_TrackWorkspaceDescendants()
	self._janitor:Add(Workspace.DescendantAdded:Connect(function(instance: Instance)
		self:_ApplyInstanceProfile(instance)
	end), "Disconnect")
end

function RenderProfileService:_ApplyInstanceProfile(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end

	self:_RestorePartShadowState(instance)
end

function RenderProfileService:_RestorePartShadowState(part: BasePart)
	local authoredShadowState = part:GetAttribute(RenderConfig.ShadowStateAttributeName)
	if typeof(authoredShadowState) == "boolean" then
		part.CastShadow = authoredShadowState
		self:_DisconnectPendingAttributeConnection(part)
		return
	end

	self:_TrackPendingShadowAttribute(part)
end

function RenderProfileService:_TrackPendingShadowAttribute(part: BasePart)
	if self._pendingAttributeConnections[part] ~= nil then
		return
	end

	local connection: RBXScriptConnection
	connection = part:GetAttributeChangedSignal(RenderConfig.ShadowStateAttributeName):Connect(function()
		local authoredShadowState = part:GetAttribute(RenderConfig.ShadowStateAttributeName)
		if typeof(authoredShadowState) ~= "boolean" then
			return
		end

		part.CastShadow = authoredShadowState
		connection:Disconnect()
		self._pendingAttributeConnections[part] = nil
	end)

	self._pendingAttributeConnections[part] = connection
end

function RenderProfileService:_DisconnectPendingAttributeConnection(part: BasePart)
	local connection = self._pendingAttributeConnections[part]
	if connection == nil then
		return
	end

	connection:Disconnect()
	self._pendingAttributeConnections[part] = nil
end

function RenderProfileService:_DisconnectPendingAttributeConnections()
	for part, connection in self._pendingAttributeConnections do
		connection:Disconnect()
		self._pendingAttributeConnections[part] = nil
	end
end

return RenderProfileService
