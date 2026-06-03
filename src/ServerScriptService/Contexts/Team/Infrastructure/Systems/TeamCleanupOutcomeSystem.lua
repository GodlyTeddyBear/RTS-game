--!strict

local TeamTypes = require(game:GetService("ReplicatedStorage").Contexts.Team.Types.TeamTypes)

local TeamCleanupOutcomeSystem = {}
TeamCleanupOutcomeSystem.__index = TeamCleanupOutcomeSystem

function TeamCleanupOutcomeSystem.new(entityFactory: any, teamContext: any)
	return setmetatable({
		_entityFactory = entityFactory,
		_teamContext = teamContext,
	}, TeamCleanupOutcomeSystem)
end

function TeamCleanupOutcomeSystem:Run()
	-- READS: Entity.CleanupOutcomeRequest [AUTHORITATIVE], Entity.CleanupRequestTag, Entity.Identity [AUTHORITATIVE]
	-- WRITES: Entity.CleanupOutcomeRequest [AUTHORITATIVE], Entity.CleanupProcessedTag, Entity.CleanupFailedTag
	local result = self._entityFactory:Query({ FeatureName = "Entity", Keys = { "CleanupOutcomeRequest", "CleanupRequestTag" } })
	if not result.success then
		return
	end

	for _, requestEntity in ipairs(result.value) do
		local request = self:_Get(requestEntity, "CleanupOutcomeRequest", "Entity")
		if type(request) == "table" and request.OutcomeId == "TeamUnassign" then
			self:_Resolve(requestEntity, request)
		end
	end
end

function TeamCleanupOutcomeSystem:_Resolve(requestEntity: number, request: any)
	local identity = self:_Get(request.SourceEntity, "Identity", "Entity")
	if type(identity) ~= "table" then
		self:_MarkProcessed(requestEntity, request)
		return
	end

	if
		not TeamTypes.IsMemberKind(identity.EntityKind)
		or type(identity.EntityId) ~= "string"
		or identity.EntityId == ""
	then
		self:_MarkProcessed(requestEntity, request)
		return
	end

	local unassignResult = self._teamContext:UnassignMember(TeamTypes.BuildMemberHandle(identity.EntityKind, identity.EntityId))
	if unassignResult.success then
		self:_MarkProcessed(requestEntity, request)
		return
	end

	self:_MarkFailed(requestEntity, request, unassignResult.message)
end

function TeamCleanupOutcomeSystem:_MarkProcessed(requestEntity: number, request: any)
	local nextRequest = table.clone(request)
	nextRequest.Status = "Processed"
	self._entityFactory:Set(requestEntity, "CleanupOutcomeRequest", nextRequest, "Entity")
	self._entityFactory:Add(requestEntity, "CleanupProcessedTag", "Entity")
end

function TeamCleanupOutcomeSystem:_MarkFailed(requestEntity: number, request: any, reason: string?)
	local nextRequest = table.clone(request)
	nextRequest.Status = "Failed"
	nextRequest.FailureReason = reason
	self._entityFactory:Set(requestEntity, "CleanupOutcomeRequest", nextRequest, "Entity")
	self._entityFactory:Add(requestEntity, "CleanupFailedTag", "Entity")
end

function TeamCleanupOutcomeSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return TeamCleanupOutcomeSystem
