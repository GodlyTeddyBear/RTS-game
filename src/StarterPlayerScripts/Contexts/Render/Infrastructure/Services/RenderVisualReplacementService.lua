--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Knit = require(ReplicatedStorage.Packages.Knit)
local RenderAccessoryTransportSchema = require(ReplicatedStorage.Contexts.Render.RenderAccessoryTransportSchema)
local RenderVisualReplacementConfig = require(ReplicatedStorage.Contexts.Render.Config.RenderVisualReplacementConfig)
local RenderTypes = require(ReplicatedStorage.Contexts.Render.Types.RenderTypes)

type TRenderAccessoryBootstrapChunk = RenderTypes.TRenderAccessoryBootstrapChunk
type TRenderAccessoryDelta = RenderTypes.TRenderAccessoryDelta
type TRenderAccessoryEntry = RenderTypes.TRenderAccessoryEntry

local RenderVisualReplacementService = {}
RenderVisualReplacementService.__index = RenderVisualReplacementService

local function _AttachAccessoryWithWelds(rig: Model, accessory: Accessory): boolean
	local handle = accessory:FindFirstChild("Handle")
	if handle == nil or not handle:IsA("BasePart") then
		warn("[RenderVisualReplacementService] Accessory is missing BasePart Handle", accessory.Name)
		return false
	end

	local attachment = handle:FindFirstChildOfClass("Attachment")
	if attachment == nil then
		warn("[RenderVisualReplacementService] Accessory handle is missing Attachment", accessory.Name)
		return false
	end

	local createdWeld = false
	for _, child in ipairs(rig:GetChildren()) do
		if not child:IsA("BasePart") then
			continue
		end

		local correspondingAttachment = child:FindFirstChild(attachment.Name)
		if correspondingAttachment == nil or not correspondingAttachment:IsA("Attachment") then
			continue
		end

		local weld = Instance.new("Weld")
		weld.Name = "AccessoryWeld"
		weld.Part0 = child
		weld.Part1 = handle
		weld.C0 = correspondingAttachment.CFrame
		weld.C1 = attachment.CFrame
		weld.Parent = handle
		createdWeld = true
	end

	if not createdWeld then
		warn(
			"[RenderVisualReplacementService] No matching rig attachment found for accessory",
			accessory.Name,
			attachment.Name,
			rig:GetFullName()
		)
		return false
	end

	accessory.Parent = rig
	return accessory.Parent == rig
end

function RenderVisualReplacementService.new(renderRegistryClientService: any)
	local self = setmetatable({}, RenderVisualReplacementService)
	self._janitor = Janitor.new()
	self._renderRegistryClientService = renderRegistryClientService
	self._renderContext = nil
	self._trueVisualsRoot = nil
	self._entriesByAccessoryId = {} :: { [string]: TRenderAccessoryEntry }
	self._pendingAccessoryIds = {} :: { [string]: true }
	self._hydratedAccessoryByAccessoryId = {} :: { [string]: Accessory }
	return self
end

function RenderVisualReplacementService:Start()
	self._trueVisualsRoot = self:_EnsureTrueVisualsRoot()
	self:_ConnectTransport()
	self:_TrackTrueVisualProfiles()
	self:_TrackParentResolution()
	self._renderContext:RequestRenderAccessoryBootstrap()
end

function RenderVisualReplacementService:Destroy()
	table.clear(self._entriesByAccessoryId)
	table.clear(self._pendingAccessoryIds)
	table.clear(self._hydratedAccessoryByAccessoryId)
	self._renderContext = nil
	self._trueVisualsRoot = nil
	self._janitor:Destroy()
end

function RenderVisualReplacementService:_EnsureTrueVisualsRoot(): Folder
	local trueVisualsRoot = ReplicatedStorage:WaitForChild(RenderVisualReplacementConfig.TrueVisualsFolderName)
	assert(trueVisualsRoot:IsA("Folder"), "RenderVisualReplacementService: true visuals root must be a Folder")
	return trueVisualsRoot
end

function RenderVisualReplacementService:_ConnectTransport()
	self._renderContext = Knit.GetService("RenderContext")

	self._janitor:Add(
		self._renderContext.RenderAccessoryBootstrapChunk:Connect(function(payloadBuffer: buffer)
			self:HandleAccessoryBootstrapChunk(payloadBuffer)
		end),
		"Disconnect"
	)

	self._janitor:Add(
		self._renderContext.RenderAccessoryDelta:Connect(function(payloadBuffer: buffer)
			self:HandleAccessoryDelta(payloadBuffer)
		end),
		"Disconnect"
	)
end

function RenderVisualReplacementService:_TrackTrueVisualProfiles()
	self._janitor:Add(
		self._trueVisualsRoot.DescendantAdded:Connect(function(_instance: Instance)
			self:_RetryPendingAccessories()
		end),
		"Disconnect"
	)
end

function RenderVisualReplacementService:_TrackParentResolution()
	self._janitor:Add(
		self._renderRegistryClientService:ObserveEntryChanged(function(_id: string)
			self:_RetryPendingAccessories()
		end),
		"Disconnect"
	)

	self._janitor:Add(
		self._renderRegistryClientService:ObserveEntryRemoved(function(_id: string)
			self:_RetryPendingAccessories()
		end),
		"Disconnect"
	)
end

function RenderVisualReplacementService:HandleAccessoryBootstrapChunk(payloadBuffer: buffer)
	local payload, decodeError = RenderAccessoryTransportSchema.DeserializeBootstrapChunk(payloadBuffer)
	if payload == nil then
		warn(`RenderVisualReplacementService: failed to decode accessory bootstrap chunk: {decodeError}`)
		return
	end

	self:_ApplyAccessoryBootstrapChunk(payload)
end

function RenderVisualReplacementService:HandleAccessoryDelta(payloadBuffer: buffer)
	local payload, decodeError = RenderAccessoryTransportSchema.DeserializeDelta(payloadBuffer)
	if payload == nil then
		warn(`RenderVisualReplacementService: failed to decode accessory delta: {decodeError}`)
		return
	end

	self:_ApplyAccessoryDelta(payload)
end

function RenderVisualReplacementService:_ApplyAccessoryBootstrapChunk(payload: TRenderAccessoryBootstrapChunk)
	for index = 1, payload.Count do
		self:_UpsertAccessoryEntry({
			AccessoryId = payload.AccessoryIdsByIndex[index],
			AccessoryName = payload.AccessoryNamesByIndex[index],
			ParentRenderId = payload.ParentRenderIdsByIndex[index],
			VisualId = payload.VisualIdsByIndex[index],
		})
	end

	self:_RetryPendingAccessories()
end

function RenderVisualReplacementService:_ApplyAccessoryDelta(payload: TRenderAccessoryDelta)
	if payload.AddedAccessoryIdsByIndex ~= nil then
		local addedCount = payload.AddedCount or #payload.AddedAccessoryIdsByIndex
		for index = 1, addedCount do
			self:_UpsertAccessoryEntry({
				AccessoryId = payload.AddedAccessoryIdsByIndex[index],
				AccessoryName = (payload.AddedAccessoryNamesByIndex :: { string })[index],
				ParentRenderId = (payload.AddedParentRenderIdsByIndex :: { string })[index],
				VisualId = (payload.AddedVisualIdsByIndex :: { string })[index],
			})
		end
	end

	if payload.RemovedAccessoryIds ~= nil then
		for _, accessoryId in ipairs(payload.RemovedAccessoryIds) do
			self:_RemoveAccessoryEntry(accessoryId)
		end
	end

	self:_RetryPendingAccessories()
end

function RenderVisualReplacementService:_UpsertAccessoryEntry(entry: TRenderAccessoryEntry)
	self._entriesByAccessoryId[entry.AccessoryId] = entry
	self._pendingAccessoryIds[entry.AccessoryId] = true
end

function RenderVisualReplacementService:_RemoveAccessoryEntry(accessoryId: string)
	self._entriesByAccessoryId[accessoryId] = nil
	self._pendingAccessoryIds[accessoryId] = nil

	local hydratedAccessory = self._hydratedAccessoryByAccessoryId[accessoryId]
	if hydratedAccessory ~= nil and hydratedAccessory.Parent ~= nil then
		self:_ResetServerAccessory(hydratedAccessory)
	end

	self._hydratedAccessoryByAccessoryId[accessoryId] = nil
end

function RenderVisualReplacementService:_RetryPendingAccessories()
	local pendingAccessoryIds = {}
	for accessoryId in self._pendingAccessoryIds do
		table.insert(pendingAccessoryIds, accessoryId)
	end

	for _, accessoryId in ipairs(pendingAccessoryIds) do
		if self:_RealizeAccessory(accessoryId) then
			self._pendingAccessoryIds[accessoryId] = nil
		end
	end
end

function RenderVisualReplacementService:_RealizeAccessory(accessoryId: string): boolean
	local entry = self._entriesByAccessoryId[accessoryId]
	if entry == nil then
		return false
	end

	local parentInstance = self._renderRegistryClientService:GetInstanceById(entry.ParentRenderId)
	if parentInstance == nil then
		return false
	end

	local trueVisualFolder = self:_ResolveTrueVisualFolder(entry.VisualId)
	if trueVisualFolder == nil then
		return false
	end

	local existingAccessory = self._hydratedAccessoryByAccessoryId[accessoryId]
	local serverAccessory = self:_ResolveServerAccessory(entry, parentInstance)
	if serverAccessory == nil then
		return false
	end

	if
		existingAccessory ~= nil
		and existingAccessory == serverAccessory
		and existingAccessory:IsDescendantOf(game)
	then
		return true
	end

	self:_ResetServerAccessory(serverAccessory)
	if not self:_CloneContentIntoAccessory(entry, trueVisualFolder, serverAccessory) then
		return false
	end

	if not self:_AttachAccessoryToParent(serverAccessory, parentInstance) then
		return false
	end

	self._hydratedAccessoryByAccessoryId[accessoryId] = serverAccessory
	return true
end

function RenderVisualReplacementService:_AttachAccessoryToParent(
	accessory: Accessory,
	parentInstance: Instance
): boolean
	if parentInstance:IsA("Model") then
		local humanoid = parentInstance:FindFirstChildOfClass("Humanoid")
		if humanoid ~= nil then
			return _AttachAccessoryWithWelds(parentInstance, accessory)
		end
	end

	accessory.Parent = parentInstance
	return accessory.Parent == parentInstance
end

function RenderVisualReplacementService:_ResolveServerAccessory(
	entry: TRenderAccessoryEntry,
	parentInstance: Instance
): Accessory?
	if not parentInstance:IsA("Model") then
		return nil
	end

	local matchingAccessories = {}
	for _, descendant in ipairs(parentInstance:GetDescendants()) do
		if descendant:IsA("Accessory") then
			local descendantVisualId = RenderVisualReplacementConfig.GetVisualReplacementId(descendant)
			if descendantVisualId == entry.VisualId and descendant.Name == entry.AccessoryName then
				table.insert(matchingAccessories, descendant)
			end
		end
	end

	if #matchingAccessories == 0 then
		warn(
			`RenderVisualReplacementService: failed to resolve replicated server accessory "{entry.AccessoryName}" for visual "{entry.VisualId}" on "{parentInstance:GetFullName()}"`
		)
		return nil
	end

	if #matchingAccessories > 1 then
		warn(
			`RenderVisualReplacementService: multiple replicated server accessories matched "{entry.AccessoryName}" for visual "{entry.VisualId}" on "{parentInstance:GetFullName()}"`
		)
		return nil
	end

	return matchingAccessories[1]
end

function RenderVisualReplacementService:_ResetServerAccessory(accessory: Accessory)
	for _, child in ipairs(accessory:GetChildren()) do
		child:Destroy()
	end
end

function RenderVisualReplacementService:_CloneContentIntoAccessory(
	entry: TRenderAccessoryEntry,
	trueVisualFolder: Folder,
	accessory: Accessory
): boolean
	local payloadChildren = trueVisualFolder:GetChildren()
	if #payloadChildren == 0 then
		warn(
			`RenderVisualReplacementService: true visual folder "{entry.VisualId}" is empty for accessory "{entry.AccessoryId}"`
		)
		return false
	end

	for _, payloadChild in ipairs(payloadChildren) do
		if payloadChild:IsA("Accessory") then
			warn(
				`RenderVisualReplacementService: true visual folder "{entry.VisualId}" contains an Accessory payload but expected direct content for accessory "{entry.AccessoryId}"`
			)
			return false
		end
	end

	for _, payloadChild in ipairs(payloadChildren) do
		local clone = payloadChild:Clone()
		clone.Parent = accessory
	end

	local handle = accessory:FindFirstChild("Handle")
	if handle == nil or not handle:IsA("BasePart") then
		warn(
			`RenderVisualReplacementService: cloned content for "{entry.AccessoryId}" did not produce a BasePart Handle`
		)
		return false
	end

	return true
end

function RenderVisualReplacementService:_ResolveTrueVisualFolder(visualId: string): Folder?
	local trueVisualFolder = self._trueVisualsRoot:FindFirstChild(visualId)
	if trueVisualFolder == nil or not trueVisualFolder:IsA("Folder") then
		warn(`RenderVisualReplacementService: missing true visual folder "{visualId}"`)
		return nil
	end

	return trueVisualFolder
end

return RenderVisualReplacementService
