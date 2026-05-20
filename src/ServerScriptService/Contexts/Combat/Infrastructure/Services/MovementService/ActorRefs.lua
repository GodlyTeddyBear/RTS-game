--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local Option = require(ReplicatedStorage.Utilities.Option)
local MovementTypes = require(script.Parent.Types)

type TFlowActorRefs = MovementTypes.TFlowActorRefs

return function(MovementService: any)
	-- Returns the cached actor-reference table for one entity, creating it on first use.
	function MovementService:_GetOrCreateFlowActorRefs(entity: number): TFlowActorRefs
		local refs = self._flowActorRefsByEntity[entity]
		if not refs then
			refs = {
				Model = nil,
				RootPart = nil,
				Humanoid = nil,
				LastWalkSpeed = nil,
			}
			self._flowActorRefsByEntity[entity] = refs
		end
		return refs
	end

	-- Drops the cached actor-reference table so the next lookup re-resolves live instances.
	function MovementService:_InvalidateFlowActorRefs(entity: number)
		self._flowActorRefsByEntity[entity] = nil
	end

	-- Resolves the entity model used as the root for humanoid and root-part lookups.
	function MovementService:_GetEntityModel(entity: number): Model?
		local refs = self:_GetOrCreateFlowActorRefs(entity)
		local modelRef = self._enemyEntityFactory:GetModelRef(entity)
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
	function MovementService:_GetEntityRootPart(entity: number): BasePart?
		local refs = self:_GetOrCreateFlowActorRefs(entity)
		local rootPart = Option.Wrap(refs.RootPart):UnwrapOr(nil)
		local model = refs.Model
		if rootPart and rootPart.Parent and model and rootPart:IsDescendantOf(model) then
			return rootPart
		end

		model = self:_GetEntityModel(entity)
		rootPart = Option.Wrap(model and model.PrimaryPart or nil):UnwrapOr(nil)
		refs.RootPart = rootPart
		return rootPart
	end

	-- Returns the current world position from the cached root part, if one is available.
	function MovementService:_GetEntityPosition(entity: number): Vector3?
		local rootPart = self:_GetEntityRootPart(entity)
		return rootPart and rootPart.Position or nil
	end

	-- Resolves the humanoid used to apply walk speed and movement commands.
	function MovementService:_GetHumanoid(entity: number): Humanoid?
		local refs = self:_GetOrCreateFlowActorRefs(entity)
		local humanoid = Option.Wrap(refs.Humanoid):UnwrapOr(nil)
		local model = refs.Model
		if humanoid and humanoid.Parent and model and humanoid:IsDescendantOf(model) then
			return humanoid
		end

		model = self:_GetEntityModel(entity)
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
	function MovementService:_ApplyCurrentMoveSpeed(entity: number): number
		local humanoid = self:_GetHumanoid(entity)
		local refs = self:_GetOrCreateFlowActorRefs(entity)
		local currentMoveSpeed = nil
		if self._enemyEntityFactory and type(self._enemyEntityFactory.GetCurrentMoveSpeed) == "function" then
			currentMoveSpeed = self._enemyEntityFactory:GetCurrentMoveSpeed(entity)
		end

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
	function MovementService:_IssueHumanoidMoveTo(entity: number, targetPosition: Vector3?, velocityXZ: Vector2)
		local humanoid = self:_GetHumanoid(entity)
		if not humanoid then
			return false
		end

		-- Fall back to the current root position when flow movement has no explicit target.
		if not targetPosition then
			local rootPart = self:_GetEntityRootPart(entity)
			if rootPart then
				humanoid:MoveTo(rootPart.Position)
			else
				humanoid:Move(Vector3.zero)
			end
			if self._lockOnService and type(self._lockOnService.SetBoidsFacingFlatForward) == "function" then
				self._lockOnService:SetBoidsFacingFlatForward(entity, nil)
			end
			return true
		end

		-- When a target exists, command the humanoid and keep boid-facing aligned to velocity.
		humanoid:MoveTo(targetPosition)
		if self._lockOnService and type(self._lockOnService.SetBoidsFacingFlatForward) == "function" then
			local flatForward = (velocityXZ.Magnitude > 0) and Vector3.new(velocityXZ.X, 0, velocityXZ.Y).Unit or nil
			self._lockOnService:SetBoidsFacingFlatForward(entity, flatForward)
		end
		return true
	end

	-- Stops humanoid motion and clears any facing override so the entity fully settles.
	function MovementService:_StopHumanoid(entity: number)
		local humanoid = self:_GetHumanoid(entity)
		if not humanoid then
			return
		end

		local rootPart = self:_GetEntityRootPart(entity)
		-- Zero the move vector before pinning the humanoid back to its current root position.
		humanoid:Move(Vector3.zero)
		if rootPart then
			humanoid:MoveTo(rootPart.Position)
		end
		if self._lockOnService and type(self._lockOnService.SetBoidsFacingFlatForward) == "function" then
			self._lockOnService:SetBoidsFacingFlatForward(entity, nil)
		end
	end
end
