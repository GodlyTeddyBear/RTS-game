--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local MovementTypes = require(script.Parent.Types)

type TFlowActorRefs = MovementTypes.TFlowActorRefs

return function(MovementService: any)
	-- Returns the cached actor-reference table for one entity, creating it on first use.
	function MovementService:_GetOrCreateFlowActorRefs(entity: number): TFlowActorRefs
		local refs = self._flowActorRefsByEntity[entity]
		if refs == nil then
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
		local resolvedModel = if modelRef ~= nil then modelRef.Model else nil
		if refs.Model ~= resolvedModel then
			refs.Model = resolvedModel
			refs.RootPart = nil
			refs.Humanoid = nil
		end
		if resolvedModel == nil then
			refs.RootPart = nil
			refs.Humanoid = nil
		end
		return resolvedModel
	end

	-- Resolves the cached primary part for the entity model and refreshes it when the model changes.
	function MovementService:_GetEntityRootPart(entity: number): BasePart?
		local refs = self:_GetOrCreateFlowActorRefs(entity)
		local rootPart = refs.RootPart
		local model = refs.Model
		if rootPart ~= nil and rootPart.Parent ~= nil and model ~= nil and rootPart:IsDescendantOf(model) then
			return rootPart
		end

		model = self:_GetEntityModel(entity)
		rootPart = if model ~= nil then model.PrimaryPart else nil
		refs.RootPart = rootPart
		return rootPart
	end

	-- Returns the current world position from the cached root part, if one is available.
	function MovementService:_GetEntityPosition(entity: number): Vector3?
		local rootPart = self:_GetEntityRootPart(entity)
		return if rootPart ~= nil then rootPart.Position else nil
	end

	-- Resolves the humanoid used to apply walk speed and movement commands.
	function MovementService:_GetHumanoid(entity: number): Humanoid?
		local refs = self:_GetOrCreateFlowActorRefs(entity)
		local humanoid = refs.Humanoid
		local model = refs.Model
		if humanoid ~= nil and humanoid.Parent ~= nil and model ~= nil and humanoid:IsDescendantOf(model) then
			return humanoid
		end

		model = self:_GetEntityModel(entity)
		humanoid = if model ~= nil then model:FindFirstChildWhichIsA("Humanoid") else nil
		refs.Humanoid = humanoid
		return humanoid
	end

	-- Returns the epsilon used to avoid rewriting humanoid walk speed on trivial changes.
	function MovementService:_GetWalkSpeedWriteEpsilon(): number
		local sepConfig = CombatMovementConfig.FLOW_SOFT_SEPARATION
		local configuredEpsilon = if sepConfig ~= nil then sepConfig.WalkSpeedWriteEpsilon else nil
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
		if self._enemyEntityFactory ~= nil and type(self._enemyEntityFactory.GetCurrentMoveSpeed) == "function" then
			currentMoveSpeed = self._enemyEntityFactory:GetCurrentMoveSpeed(entity)
		end

		-- Read the authoritative combat speed first so the humanoid mirrors live gameplay state.
		local resolvedMoveSpeed = if type(currentMoveSpeed) == "number" and currentMoveSpeed > 0 then currentMoveSpeed else 16
		local walkSpeedWriteEpsilon = self:_GetWalkSpeedWriteEpsilon()
		if humanoid ~= nil and math.abs(humanoid.WalkSpeed - resolvedMoveSpeed) > walkSpeedWriteEpsilon then
			-- Skip tiny writes to avoid redundant humanoid property churn.
			humanoid.WalkSpeed = resolvedMoveSpeed
		end
		refs.LastWalkSpeed = resolvedMoveSpeed
		return resolvedMoveSpeed
	end

	-- Issues a humanoid movement command and updates facing state for flow-based motion.
	function MovementService:_IssueHumanoidMoveTo(entity: number, targetPosition: Vector3?, velocityXZ: Vector2)
		local humanoid = self:_GetHumanoid(entity)
		if humanoid == nil then
			return false
		end

		-- Fall back to the current root position when flow movement has no explicit target.
		if targetPosition == nil then
			local rootPart = self:_GetEntityRootPart(entity)
			if rootPart ~= nil then
				humanoid:MoveTo(rootPart.Position)
			else
				humanoid:Move(Vector3.zero)
			end
			if self._lockOnService ~= nil and type(self._lockOnService.SetBoidsFacingFlatForward) == "function" then
				self._lockOnService:SetBoidsFacingFlatForward(entity, nil)
			end
			return true
		end

		-- When a target exists, command the humanoid and keep boid-facing aligned to velocity.
		humanoid:MoveTo(targetPosition)
		if self._lockOnService ~= nil and type(self._lockOnService.SetBoidsFacingFlatForward) == "function" then
			local flatForward = if velocityXZ.Magnitude > 0
				then Vector3.new(velocityXZ.X, 0, velocityXZ.Y).Unit
				else nil
			self._lockOnService:SetBoidsFacingFlatForward(entity, flatForward)
		end
		return true
	end

	-- Stops humanoid motion and clears any facing override so the entity fully settles.
	function MovementService:_StopHumanoid(entity: number)
		local humanoid = self:_GetHumanoid(entity)
		if humanoid == nil then
			return
		end

		local rootPart = self:_GetEntityRootPart(entity)
		-- Zero the move vector before pinning the humanoid back to its current root position.
		humanoid:Move(Vector3.zero)
		if rootPart ~= nil then
			humanoid:MoveTo(rootPart.Position)
		end
		if self._lockOnService ~= nil and type(self._lockOnService.SetBoidsFacingFlatForward) == "function" then
			self._lockOnService:SetBoidsFacingFlatForward(entity, nil)
		end
	end
end
