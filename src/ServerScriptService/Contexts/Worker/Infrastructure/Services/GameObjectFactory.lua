--!strict

--[[
    GameObject Factory - Creates and destroys Roblox instances for workers.

    Responsibilities:
    - Create worker models from templates
    - Update visual properties (level, position)
    - Destroy worker models

    Pattern: Infrastructure layer service
]]

local Workspace = game:GetService("Workspace")
local PhysicsService = game:GetService("PhysicsService")

local WORKER_COLLISION_GROUP = "Workers"
local WORKER_COLLIDES_WITH_WORKERS = false

local GameObjectFactory = {}
GameObjectFactory.__index = GameObjectFactory

export type TGameObjectFactory = typeof(setmetatable({} :: {
	WorkerRegistry: any,
	AnimationsFolder: Folder?,
	EquipmentService: any?,
	WorkersFolder: Folder,
}, GameObjectFactory))

function GameObjectFactory.new(animationsFolder: Folder?): TGameObjectFactory
	local self = setmetatable({}, GameObjectFactory)
	self.AnimationsFolder = animationsFolder

	-- Folder for worker models in workspace
	self.WorkersFolder = Workspace:FindFirstChild("Workers")
	if not self.WorkersFolder then
		self.WorkersFolder = Instance.new("Folder")
		self.WorkersFolder.Name = "Workers"
		self.WorkersFolder.Parent = Workspace
	end
	return self
end

function GameObjectFactory:Init(registry: any, _name: string)
	local workerRegistry = registry:Get("WorkerRegistry")
	assert(workerRegistry, "GameObjectFactory requires a WorkerRegistry")
	self.WorkerRegistry = workerRegistry
	self.EquipmentService = registry:Get("EquipmentService")
	self:_EnsureCollisionGroupConfig()
end

function GameObjectFactory:_EnsureCollisionGroupConfig()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(WORKER_COLLISION_GROUP)
	end)

	PhysicsService:CollisionGroupSetCollidable(
		WORKER_COLLISION_GROUP,
		WORKER_COLLISION_GROUP,
		WORKER_COLLIDES_WITH_WORKERS
	)
end

function GameObjectFactory:_ApplyCollisionGroup(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = WORKER_COLLISION_GROUP
		end
	end
end

function GameObjectFactory:_StabilizeWorker(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	end
end

--[[
    Create a worker model from template.
    Returns: Model instance
]]
function GameObjectFactory:CreateWorkerModel(workerType: string, workerId: string): Model
	-- WorkerRegistry:GetWorkerModel already returns a clone with validated structure
	local model = self.WorkerRegistry:GetWorkerModel(workerType)

	model.Name = "Worker_" .. workerId

	-- Inject the animations folder reference so AnimateWorker can find it without string lookups
	if self.AnimationsFolder then
		local folderRef = Instance.new("ObjectValue")
		folderRef.Name = "AnimationsFolder"
		folderRef.Value = self.AnimationsFolder
		folderRef.Parent = model
	end

	model.Parent = self.WorkersFolder
	self:_ApplyCollisionGroup(model)
	self:_StabilizeWorker(model)

	return model
end

--[[
    Update worker model visual properties.
]]
function GameObjectFactory:UpdateWorkerVisuals(model: Model, worker: any)
	-- Update BillboardGui level text (if exists)
	local billboardGui = model:FindFirstChild("BillboardGui", true)
	if billboardGui and billboardGui:IsA("BillboardGui") then
		local levelText = billboardGui:FindFirstChild("LevelText")
		if levelText and levelText:IsA("TextLabel") then
			levelText.Text = "Lv " .. tostring(worker.Level)
		end

		-- Update XP bar (if exists)
		local xpBar = billboardGui:FindFirstChild("XPBar")
		if xpBar and xpBar:IsA("Frame") then
			-- Calculate XP percentage (placeholder - would need XP requirements from config)
			local xpPercent = math.min(1, worker.Experience / 100)
			xpBar.Size = UDim2.new(xpPercent, 0, 1, 0)
		end
	end
end

--[[
    Update worker model position and optional facing direction.
    If lookAt is provided, the model will face that point.
]]
function GameObjectFactory:UpdateWorkerPosition(model: Model, position: Vector3, lookAt: Vector3?)
	if model.PrimaryPart then
		if lookAt and (lookAt - position).Magnitude > 0.01 then
			model:PivotTo(CFrame.lookAt(position, lookAt))
		else
			model:PivotTo(CFrame.new(position))
		end
	else
		warn("[GameObjectFactory] Worker model has no PrimaryPart:", model.Name)
	end
end

--[[
    Set the animation state attribute on a worker model.
    The AnimateWorker script inside the model listens to this attribute.
]]
function GameObjectFactory:SetAnimationState(model: Model, state: string, looping: boolean?)
	model:SetAttribute("AnimationLooping", looping == true)
	model:SetAttribute("AnimationState", state)
end

--[[
    Read the current world position of a worker model from the Roblox instance.
    Returns nil if the model has no PrimaryPart.
]]
function GameObjectFactory:GetWorkerPosition(model: Model): Vector3?
	if model.PrimaryPart then
		return model:GetPivot().Position
	end
	return nil
end

--[[
    Attach a tool to a worker model via EquipmentService.
    No-op if no EquipmentService was provided.
]]
function GameObjectFactory:AttachTool(model: Model, toolId: string): boolean
	if not self.EquipmentService then
		warn("[GameObjectFactory] AttachTool called but no EquipmentService provided")
		return false
	end
	local equipped = self.EquipmentService:EquipTool(model, toolId)
	if equipped then
		self:_ApplyCollisionGroup(model)
	end
	return equipped
end

--[[
    Detach any equipped tool from a worker model via EquipmentService.
    No-op if no EquipmentService was provided.
]]
function GameObjectFactory:DetachTool(model: Model)
	if not self.EquipmentService then
		return
	end
	self.EquipmentService:UnequipTool(model)
end

--[[
    Destroy worker model.
]]
function GameObjectFactory:DestroyWorkerModel(model: Model)
	model:Destroy()
end

return GameObjectFactory
