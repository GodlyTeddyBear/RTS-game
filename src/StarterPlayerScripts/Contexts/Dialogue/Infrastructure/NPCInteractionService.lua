--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Promise = require(ReplicatedStorage.Packages.Promise)
local DialogueConfig = require(ReplicatedStorage.Contexts.Dialogue.Config.DialogueConfig)

local PROMPT_DISTANCE = 12
local PRIMARY_PART_TIMEOUT = 10

--[=[
	@class NPCInteractionService
	Manages proximity prompts for NPC interaction and dialogue initiation.
	@client
]=]
local NPCInteractionService = {}
NPCInteractionService.__index = NPCInteractionService

export type TNPCInteractionService = typeof(setmetatable(
	{} :: {
		PromptsByModel: { [Model]: ProximityPrompt },
		Connections: { RBXScriptConnection },
		OnInteract: ((npcId: string) -> ())?,
	},
	NPCInteractionService
))

-- Resolves the NPC ID from a model's attribute, validating it exists in config.
local function _ResolveNPCId(model: Model): string?
	local npcId = model:GetAttribute("NPCId")
	if type(npcId) ~= "string" then
		return nil
	end
	return DialogueConfig.NPCS[npcId] and npcId or nil
end

-- Waits for a model's PrimaryPart to be set, with a fallback to recursive search on timeout.
-- This is necessary because some NPCs may set their PrimaryPart after streaming or loading.
local function _WaitForPrimaryPart(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end

	local _success, result = Promise.new(function(resolve, _, onCancel)
		local conn: RBXScriptConnection
		conn = model:GetPropertyChangedSignal("PrimaryPart"):Connect(function()
			if model.PrimaryPart then
				conn:Disconnect()
				resolve(model.PrimaryPart)
			end
		end)
		onCancel(function()
			conn:Disconnect()
		end)
	end)
		:timeout(PRIMARY_PART_TIMEOUT)
		:catch(function()
			-- Timeout: fall back to recursive search
			return model:FindFirstChildWhichIsA("BasePart", true)
		end)
		:await()

	return result :: BasePart?
end

--[=[
	Create a new NPCInteractionService instance.
	@within NPCInteractionService
	@return TNPCInteractionService -- A new interaction service
]=]
function NPCInteractionService.new(): TNPCInteractionService
	return setmetatable({
		PromptsByModel = {},
		Connections = {},
		OnInteract = nil,
	}, NPCInteractionService)
end

--[=[
	Start listening for NPC models and create interaction prompts.
	@within NPCInteractionService
	@param onInteract (npcId: string) -> () -- Callback fired when a player interacts with an NPC
]=]
function NPCInteractionService:Start(onInteract: (npcId: string) -> ())
	self.OnInteract = onInteract

	local function handleModel(instance: Instance)
		if not instance:IsA("Model") then
			return
		end
		local model = instance :: Model

		-- Resolve NPCId before spawning — no point waiting if the config doesn't know this NPC
		local npcId = _ResolveNPCId(model)
		if not npcId then
			return
		end

		-- Spawn so we can yield waiting for PrimaryPart without blocking the signal handler
		task.spawn(function()
			if self.PromptsByModel[model] then
				return
			end

			local promptParent = _WaitForPrimaryPart(model)
			if not promptParent then
				warn("[NPCInteractionService] PrimaryPart never resolved for:", model.Name)
				return
			end

			-- Guard again after the yield — model may have been removed or prompt already added
			if not model.Parent or self.PromptsByModel[model] then
				return
			end

			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Talk"
			prompt.ObjectText = DialogueConfig.NPCS[npcId].DisplayName
			prompt.HoldDuration = 0.2
			prompt.MaxActivationDistance = PROMPT_DISTANCE
			prompt.RequiresLineOfSight = false
			prompt.Parent = promptParent

			table.insert(
				self.Connections,
				prompt.Triggered:Connect(function()
					-- print("[NPCInteractionService] Prompt triggered for:", npcId, "| OnInteract set:", self.OnInteract ~= nil)
					if self.OnInteract then
						self.OnInteract(npcId)
					end
				end)
			)

			self.PromptsByModel[model] = prompt
		end)
	end

	for _, tagName in ipairs(DialogueConfig.INTERACTION_TAGS) do
		-- Handle models already tagged and present
		for _, instance in ipairs(CollectionService:GetTagged(tagName)) do
			handleModel(instance)
		end

		-- Handle models tagged in the future (streaming or runtime tagging)
		table.insert(self.Connections, CollectionService:GetInstanceAddedSignal(tagName):Connect(handleModel))

		table.insert(
			self.Connections,
			CollectionService:GetInstanceRemovedSignal(tagName):Connect(function(instance)
				if instance:IsA("Model") then
					self:_RemoveModel(instance :: Model)
				end
			end)
		)
	end
end

-- Removes the proximity prompt associated with a model.
function NPCInteractionService:_RemoveModel(model: Model)
	local prompt = self.PromptsByModel[model]
	if prompt then
		prompt:Destroy()
		self.PromptsByModel[model] = nil
	end
end

--[=[
	Clean up all connections and prompts.
	@within NPCInteractionService
]=]
function NPCInteractionService:Destroy()
	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	self.Connections = {}

	for model, prompt in pairs(self.PromptsByModel) do
		prompt:Destroy()
		self.PromptsByModel[model] = nil
	end

	self.OnInteract = nil
end

return NPCInteractionService
