--!strict

--[[
	BaseAction - Base class for data-driven action event handling.

	Subclasses declare a self.Events table mapping marker names to effect definitions:
		MiningAction.Events = {
			Swing = { SFX = SoundIds.SFX.MiningHit, VFX = "MiningDust" },
		}

	OnEvent reads the table and dispatches SFX/VFX with all null-checking handled here.

	For custom imperative logic on specific markers, define OnCustomEvent on your action:

		MiningAction.Events = {
			Swing = { SFX = SoundIds.SFX.MiningHit, VFX = "MiningDust" },
			PickaxeRetract = {},  -- empty entry: only custom logic, no SFX/VFX
		}

		function MiningAction:OnCustomEvent(name: string, context: any)
			if name == "PickaxeRetract" then
				local primaryPart = context.Model and context.Model.PrimaryPart
				if primaryPart then
					local debris = Instance.new("Part")
					debris.Size = Vector3.new(0.5, 0.5, 0.5)
					debris.Position = primaryPart.Position - Vector3.new(0, 2, 0)
					debris.Anchored = true
					debris.Parent = workspace
				end
			end
		end

	OnCustomEvent is called AFTER the Events table is processed, so SFX/VFX
	from the table still fire normally alongside your custom logic.

	IMPORTANT: The marker must be listed in the Events table (even as an empty {})
	for the ActionEventRouter to wire it.

	Implements the IAction interface (see Types.lua).
]]

--[=[
	@class BaseAction
	Base class for data-driven action event handling.
	Provides automatic SFX/VFX dispatch from animation keyframe markers.
	@server
]=]

local BaseAction = {}
BaseAction.__index = BaseAction

local function _RequestServerCallback(callbackType: string, context: any)
	local actorId = context.ActorId or context.NPCId
	if not context.CombatService or type(actorId) ~= "string" then
		return
	end

	--print("[BaseAction] Requested server callback:", callbackType, "npcId:", context.NPCId)
	context.CombatService.AnimationCallback:Fire(actorId, callbackType, context.ActorKind)
end

function BaseAction:_RequestServerCallback(callbackType: string, context: any)
	_RequestServerCallback(callbackType, context)
end

--[=[
	Construct a new BaseAction instance.

	@within BaseAction
	@return BaseAction -- A new action instance
]=]
function BaseAction.new()
	return setmetatable({}, BaseAction)
end

-- Resolves the position of a target instance (BasePart, Model, or fallback).
-- Tries PrimaryPart first, then model pivot, then first BasePart found.
-- Returns nil and warns if no valid position can be resolved.
local function _ResolveTargetPosition(targetInstance: Instance): Vector3?
	if targetInstance:IsA("BasePart") then
		--print("[BaseAction] Using BasePart target:", targetInstance:GetFullName())
		return targetInstance.Position
	end

	if not targetInstance:IsA("Model") then
		warn("[BaseAction] Unsupported target instance type:", targetInstance.ClassName)
		return nil
	end

	local model = targetInstance :: Model
	local primaryPart = model.PrimaryPart
	if primaryPart then
		--print("[BaseAction] Using Model PrimaryPart target:", primaryPart:GetFullName())
		return primaryPart.Position
	end

	-- Try to get model pivot as fallback when PrimaryPart is not set
	local ok, pivotCFrame = pcall(function()
		return model:GetPivot()
	end)
	if ok then
		--print("[BaseAction] PrimaryPart missing, using model pivot target:", model:GetFullName())
		return pivotCFrame.Position
	end

	-- Last resort: find any BasePart within the model
	local fallbackPart = model:FindFirstChildWhichIsA("BasePart", true)
	if fallbackPart then
		--print("[BaseAction] PrimaryPart/pivot unavailable, using first BasePart target:", fallbackPart:GetFullName())
		return fallbackPart.Position
	end

	warn("[BaseAction] Target model has no PrimaryPart, pivot, or BasePart:", model:GetFullName())
	return nil
end

-- Spawns a VFX effect at a dynamically resolved target position.
-- Validates context and target before spawning; returns false if validation fails.
function BaseAction:_SpawnVFXAtResolvedTarget(eventDef: any, context: any, markerName: string): boolean
	-- Validate required context fields for target resolution
	if not context then
		warn("[BaseAction] Missing action context for target VFX. marker:", markerName)
		return false
	end
	if not context.VFXService then
		warn("[BaseAction] Missing context.VFXService for target VFX. marker:", markerName)
		return false
	end
	if not context.ResolveTargetInstance then
		warn("[BaseAction] Missing context.ResolveTargetInstance for target VFX. marker:", markerName)
		return false
	end

	-- Resolve the target instance from the callback
	local targetInstance = context.ResolveTargetInstance()
	if not targetInstance then
		warn("[BaseAction] ResolveTargetInstance returned nil. marker:", markerName)
		return false
	end

	-- Resolve position and spawn
	local position = _ResolveTargetPosition(targetInstance)
	if not position then
		return false
	end

	--print("[BaseAction] Spawning target VFX", eventDef.VFX, "for marker:", markerName)
	context.VFXService:Spawn(eventDef.VFX, position)
	return true
end

--[=[
	Called once when the action animation starts playing.
	Override in subclass to perform initialization.

	@within BaseAction
	@param _track AnimationTrack -- The animation track that started
	@param _context TActionContext -- Injected action context
]=]
function BaseAction:OnStart(_track: AnimationTrack, _context: any) end

--[=[
	Called once when the action animation stops.
	Override in subclass to perform cleanup.

	@within BaseAction
	@param _context TActionContext -- Injected action context
]=]
function BaseAction:OnStop(_context: any) end

--[=[
	Called on each named keyframe marker fire.
	Dispatches SFX/VFX from the Events table, then calls OnCustomEvent if defined.
	All null-checking for context fields is handled here.

	@within BaseAction
	@param name string -- The keyframe marker name
	@param context TActionContext -- Injected action context
]=]
function BaseAction:OnEvent(name: string, context: any)
	local eventDef = self.Events and self.Events[name]
	if eventDef then
		-- Dispatch sound effect
		if eventDef.SFX and context.SoundEngine then
			local primaryPart = context.Model and context.Model.PrimaryPart
			if primaryPart then
				context.SoundEngine:PlaySFXAt(eventDef.SFX, primaryPart)
			else
				context.SoundEngine:PlaySFX(eventDef.SFX)
			end
		end

		-- Dispatch visual effect (at actor or resolved target)
		if eventDef.VFX then
			if eventDef.VFXAtTarget == true then
				self:_SpawnVFXAtResolvedTarget(eventDef, context, name)
			elseif context.VFXService and context.Model then
				local primaryPart = context.Model.PrimaryPart
				if primaryPart then
					context.VFXService:Spawn(eventDef.VFX, primaryPart.Position)
				end
			end
		end

		-- Request a server-side action at the exact animation marker frame.
		if eventDef.ServerCallback then
			self:_RequestServerCallback(eventDef.ServerCallback, context)
		end
	end
	--print("Playing event", name)
	-- Allow subclass to handle custom logic after table-based dispatch
	if self.OnCustomEvent then
		self:OnCustomEvent(name, context)
	end
end

return BaseAction
