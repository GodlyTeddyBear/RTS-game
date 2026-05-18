--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local MovementTypes = require(script.Parent.Types)

type TFlowActorRefs = MovementTypes.TFlowActorRefs

return function(MovementService: any)
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

	function MovementService:_InvalidateFlowActorRefs(entity: number)
		self._flowActorRefsByEntity[entity] = nil
	end

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

	function MovementService:_GetEntityPosition(entity: number): Vector3?
		local rootPart = self:_GetEntityRootPart(entity)
		return if rootPart ~= nil then rootPart.Position else nil
	end

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

	function MovementService:_GetWalkSpeedWriteEpsilon(): number
		local sepConfig = CombatMovementConfig.FLOW_SOFT_SEPARATION
		local configuredEpsilon = if sepConfig ~= nil then sepConfig.WalkSpeedWriteEpsilon else nil
		if type(configuredEpsilon) == "number" and configuredEpsilon >= 0 then
			return configuredEpsilon
		end
		return 0.05
	end

	function MovementService:_ApplyCurrentMoveSpeed(entity: number): number
		local humanoid = self:_GetHumanoid(entity)
		local refs = self:_GetOrCreateFlowActorRefs(entity)
		local currentMoveSpeed = nil
		if self._enemyEntityFactory ~= nil and type(self._enemyEntityFactory.GetCurrentMoveSpeed) == "function" then
			currentMoveSpeed = self._enemyEntityFactory:GetCurrentMoveSpeed(entity)
		end

		local resolvedMoveSpeed = if type(currentMoveSpeed) == "number" and currentMoveSpeed > 0 then currentMoveSpeed else 16
		local walkSpeedWriteEpsilon = self:_GetWalkSpeedWriteEpsilon()
		if humanoid ~= nil and math.abs(humanoid.WalkSpeed - resolvedMoveSpeed) > walkSpeedWriteEpsilon then
			humanoid.WalkSpeed = resolvedMoveSpeed
		end
		refs.LastWalkSpeed = resolvedMoveSpeed
		return resolvedMoveSpeed
	end

	function MovementService:_IssueHumanoidMoveTo(entity: number, targetPosition: Vector3?, velocityXZ: Vector2)
		local humanoid = self:_GetHumanoid(entity)
		if humanoid == nil then
			return false
		end

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

		humanoid:MoveTo(targetPosition)
		if self._lockOnService ~= nil and type(self._lockOnService.SetBoidsFacingFlatForward) == "function" then
			local flatForward = if velocityXZ.Magnitude > 0
				then Vector3.new(velocityXZ.X, 0, velocityXZ.Y).Unit
				else nil
			self._lockOnService:SetBoidsFacingFlatForward(entity, flatForward)
		end
		return true
	end

	function MovementService:_StopHumanoid(entity: number)
		local humanoid = self:_GetHumanoid(entity)
		if humanoid == nil then
			return
		end

		local rootPart = self:_GetEntityRootPart(entity)
		humanoid:Move(Vector3.zero)
		if rootPart ~= nil then
			humanoid:MoveTo(rootPart.Position)
		end
		if self._lockOnService ~= nil and type(self._lockOnService.SetBoidsFacingFlatForward) == "function" then
			self._lockOnService:SetBoidsFacingFlatForward(entity, nil)
		end
	end
end
