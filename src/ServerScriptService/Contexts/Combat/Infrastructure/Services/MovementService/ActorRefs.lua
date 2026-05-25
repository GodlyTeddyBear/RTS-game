--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local Option = require(ReplicatedStorage.Utilities.Option)
local MovementTypes = require(script.Parent.Types)

type TFlowActorRefs = MovementTypes.TFlowActorRefs
type TMovementActorKey = MovementTypes.TMovementActorKey
type TMovementService = MovementTypes.TMovementService

return function(MovementService: TMovementService)
	-- Returns the cached actor-reference table for one entity, creating it on first use.
	function MovementService:_GetOrCreateFlowActorRefs(actorKey: TMovementActorKey): TFlowActorRefs
		local refs = self._flowActorRefsByActorKey[actorKey]
		if not refs then
			refs = {
				Model = nil,
				RootPart = nil,
				Humanoid = nil,
				LastWalkSpeed = nil,
			}
			self._flowActorRefsByActorKey[actorKey] = refs
		end
		return refs
	end

	-- Drops the cached actor-reference table so the next lookup re-resolves live instances.
	function MovementService:_InvalidateFlowActorRefs(actorKey: TMovementActorKey)
		self._flowActorRefsByActorKey[actorKey] = nil
	end

	-- Resolves the entity model used as the root for humanoid and root-part lookups.
	function MovementService:_GetEntityModel(actorKey: TMovementActorKey): Model?
		local refs = self:_GetOrCreateFlowActorRefs(actorKey)
		local binding = self:_GetMovementBinding(actorKey)
		local modelRef = if binding ~= nil then binding:GetModelRef() else nil
		local resolvedModel = Option.Wrap(modelRef and modelRef.Model or nil):UnwrapOr(nil)
		if refs.Model ~= resolvedModel then
			refs.Model = resolvedModel
			refs.RootPart = nil
			refs.Humanoid = nil
		end
		if not resolvedModel then
			refs.RootPart = nil
			refs.Humanoid = nil
		end
		return resolvedModel
	end

	-- Resolves the cached primary part for the entity model and refreshes it when the model changes.
	function MovementService:_GetEntityRootPart(actorKey: TMovementActorKey): BasePart?
		local refs = self:_GetOrCreateFlowActorRefs(actorKey)
		local rootPart = Option.Wrap(refs.RootPart):UnwrapOr(nil)
		local model = refs.Model
		if rootPart and rootPart.Parent and model and rootPart:IsDescendantOf(model) then
			return rootPart
		end

		model = self:_GetEntityModel(actorKey)
		rootPart = Option.Wrap(model and model.PrimaryPart or nil):UnwrapOr(nil)
		refs.RootPart = rootPart
		return rootPart
	end

	-- Returns the current world position from the cached root part, if one is available.
	function MovementService:_GetEntityPosition(actorKey: TMovementActorKey): Vector3?
		local rootPart = self:_GetEntityRootPart(actorKey)
		return rootPart and rootPart.Position or nil
	end

	-- Resolves the humanoid used to apply walk speed and movement commands.
	function MovementService:_GetHumanoid(actorKey: TMovementActorKey): Humanoid?
		local refs = self:_GetOrCreateFlowActorRefs(actorKey)
		local humanoid = Option.Wrap(refs.Humanoid):UnwrapOr(nil)
		local model = refs.Model
		if humanoid and humanoid.Parent and model and humanoid:IsDescendantOf(model) then
			return humanoid
		end

		model = self:_GetEntityModel(actorKey)
		humanoid = Option.Wrap(model and model:FindFirstChildWhichIsA("Humanoid") or nil):UnwrapOr(nil)
		refs.Humanoid = humanoid
		return humanoid
	end

	-- Returns the epsilon used to avoid rewriting humanoid walk speed on trivial changes.
	function MovementService:_GetWalkSpeedWriteEpsilon(): number
		local sepConfig = CombatMovementConfig.FLOW_SOFT_SEPARATION
		local configuredEpsilon = sepConfig and sepConfig.WalkSpeedWriteEpsilon or nil
		if type(configuredEpsilon) == "number" and configuredEpsilon >= 0 then
			return configuredEpsilon
		end
		return 0.05
	end

	-- Applies the current combat move speed to the humanoid and caches the written value.
	function MovementService:_ApplyCurrentMoveSpeed(actorKey: TMovementActorKey): number
		local humanoid = self:_GetHumanoid(actorKey)
		local refs = self:_GetOrCreateFlowActorRefs(actorKey)
		local binding = self:_GetMovementBinding(actorKey)
		local currentMoveSpeed = if binding ~= nil then binding:GetCurrentMoveSpeed() else nil

		-- Read the authoritative combat speed first so the humanoid mirrors live gameplay state.
		local resolvedMoveSpeed = (type(currentMoveSpeed) == "number" and currentMoveSpeed > 0) and currentMoveSpeed or 16
		local walkSpeedWriteEpsilon = self:_GetWalkSpeedWriteEpsilon()
		if humanoid and math.abs(humanoid.WalkSpeed - resolvedMoveSpeed) > walkSpeedWriteEpsilon then
			-- Skip tiny writes to avoid redundant humanoid property churn.
			humanoid.WalkSpeed = resolvedMoveSpeed
		end
		refs.LastWalkSpeed = resolvedMoveSpeed
		return resolvedMoveSpeed
	end

	-- Issues a humanoid movement command and updates facing state for flow-based motion.
	function MovementService:_IssueHumanoidMoveTo(actorKey: TMovementActorKey, targetPosition: Vector3?, velocityXZ: Vector2)
		local humanoid = self:_GetHumanoid(actorKey)
		local entityId = self:_GetMovementEntityId(actorKey)
		if not humanoid then
			return false
		end

		-- Fall back to the current root position when flow movement has no explicit target.
		if not targetPosition then
			local rootPart = self:_GetEntityRootPart(actorKey)
			if rootPart then
				humanoid:MoveTo(rootPart.Position)
			else
				humanoid:Move(Vector3.zero)
			end
			if entityId ~= nil and self._lockOnService and type(self._lockOnService.SetBoidsFacingFlatForward) == "function" then
				self._lockOnService:SetBoidsFacingFlatForward(entityId, nil)
			end
			return true
		end

		-- When a target exists, command the humanoid and keep boid-facing aligned to velocity.
		humanoid:MoveTo(targetPosition)
		if entityId ~= nil and self._lockOnService and type(self._lockOnService.SetBoidsFacingFlatForward) == "function" then
			local flatForward = (velocityXZ.Magnitude > 0) and Vector3.new(velocityXZ.X, 0, velocityXZ.Y).Unit or nil
			self._lockOnService:SetBoidsFacingFlatForward(entityId, flatForward)
		end
		return true
	end

	-- Stops humanoid motion and clears any facing override so the entity fully settles.
	function MovementService:_StopHumanoid(actorKey: TMovementActorKey)
		local humanoid = self:_GetHumanoid(actorKey)
		local entityId = self:_GetMovementEntityId(actorKey)
		if not humanoid then
			return
		end

		local rootPart = self:_GetEntityRootPart(actorKey)
		-- Zero the move vector before pinning the humanoid back to its current root position.
		humanoid:Move(Vector3.zero)
		if rootPart then
			humanoid:MoveTo(rootPart.Position)
		end
		if entityId ~= nil and self._lockOnService and type(self._lockOnService.SetBoidsFacingFlatForward) == "function" then
			self._lockOnService:SetBoidsFacingFlatForward(entityId, nil)
		end
	end
end
