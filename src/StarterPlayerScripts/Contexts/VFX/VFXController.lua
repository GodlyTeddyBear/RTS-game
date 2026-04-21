--!strict

--[=[
	@class VFXController
	Client-side Knit controller that manages visual effect spawning and attachment via `VFXEngine`.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)

local VFXEngine = require(script.Parent.Infrastructure.VFXEngine)

local VFXController = Knit.CreateController({
	Name = "VFXController",
})

function VFXController:KnitInit()
	local registry = Registry.new("Client")
	self.Registry = registry
	self._Janitor = Janitor.new()

	local effectsFolder = ReplicatedStorage:FindFirstChild("Assets")
		and ReplicatedStorage.Assets:FindFirstChild("Effects")
	self._VFXEngine = VFXEngine.new(effectsFolder :: Folder?)
	registry:Register("VFXEngine", self._VFXEngine, "Infrastructure")

	registry:InitAll()
end

function VFXController:KnitStart()
	local registry = self.Registry

	-- Resolve cross-context dependencies
	local vfxContext = Knit.GetService("VFXContext")
	registry:Register("VFXContext", vfxContext)

	self._Janitor:Add(vfxContext.PlayVFX:Connect(function(effectKey: string, options: any)
		self:_HandleServerVFX(effectKey, options)
	end))

	registry:StartOrdered({ "Infrastructure" })

	print("[VFXController] Started")
end

--[=[
	Spawn a named visual effect at a world-space position.
	@within VFXController
	@param effectKey string -- Name of the effect asset under `Assets/Effects/`
	@param position Vector3 -- World position at which to spawn the effect
	@param category string? -- Asset category; `"Skill"` (default) or `"StatusEffect"`
]=]
function VFXController:Spawn(effectKey: string, position: Vector3, category: string?)
	self._VFXEngine:Spawn(effectKey, position, category)
end

--[=[
	Attach a named visual effect to a target `Instance`, returning the clone for early cleanup.
	@within VFXController
	@param effectKey string -- Name of the effect asset under `Assets/Effects/`
	@param parent Instance -- The instance to attach the effect to (e.g. `HumanoidRootPart`)
	@param offset CFrame? -- Optional CFrame offset from the attachment point
	@param category string? -- Asset category; `"Skill"` (default) or `"StatusEffect"`
	@return Instance? -- The cloned effect container, or `nil` if the effect was not found
]=]
function VFXController:Attach(effectKey: string, parent: Instance, offset: CFrame?, category: string?): Instance?
	return self._VFXEngine:Attach(effectKey, parent, offset, category)
end

--[=[
	Return the underlying `VFXEngine` instance for direct injection into action contexts.
	@within VFXController
	@return VFXEngine -- The engine used by this controller
]=]
function VFXController:GetVFXEngine()
	return self._VFXEngine
end

---
--- Private
---

--[[
	Handle a VFX trigger from the server.
	Resolves the target instance or position and dispatches to VFXEngine.
]]
function VFXController:_HandleServerVFX(effectKey: string, options: any)
	local vfxOptions = options or {}
	local category = vfxOptions.Category or "Skill"

	if self:_TryAttachFromTarget(effectKey, vfxOptions, category) then
		return
	end

	if self:_TrySpawnAtPosition(effectKey, vfxOptions, category) then
		return
	end

	warn("[VFXController] Server VFX missing target or position:", effectKey)
end

function VFXController:_TryAttachFromTarget(effectKey: string, vfxOptions: any, category: string): boolean
	if vfxOptions.TargetInstance and typeof(vfxOptions.TargetInstance) == "Instance" then
		self._VFXEngine:Attach(effectKey, vfxOptions.TargetInstance, vfxOptions.Offset, category)
		return true
	end

	if vfxOptions.TargetInstance and vfxOptions.AttachTo then
		local targetPart = vfxOptions.TargetInstance:FindFirstChild(vfxOptions.AttachTo)
		if targetPart then
			self._VFXEngine:Attach(effectKey, targetPart, vfxOptions.Offset, category)
			return true
		end
	end

	return false
end

function VFXController:_TrySpawnAtPosition(effectKey: string, vfxOptions: any, category: string): boolean
	if vfxOptions.Position and typeof(vfxOptions.Position) == "Vector3" then
		self._VFXEngine:Spawn(effectKey, vfxOptions.Position, category)
		return true
	end

	return false
end

return VFXController
