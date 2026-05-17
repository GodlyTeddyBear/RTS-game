--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoidsConfig = require(ReplicatedStorage.Contexts.Combat.Config.BoidsConfig)
local FlowSeparationPairSnapshotSchema = require(script.Parent.Parent.Parallel.FlowSeparationPairSnapshotSchema)

return function(MovementService: any)
	function MovementService:_GetFlowArrivalThreshold(): number
		local configuredThreshold = BoidsConfig.ArrivalThreshold
		if type(configuredThreshold) ~= "number" or configuredThreshold <= 0 then
			return 2.75
		end
		return configuredThreshold
	end

	function MovementService:_GetFlowClumpIdleRadiusStuds(sepConfig: any): number
		local configuredRadius = sepConfig and sepConfig.ClumpIdleRadiusStuds
		if type(configuredRadius) == "number" and configuredRadius > 0 then
			return configuredRadius
		end
		return self:_GetFlowArrivalThreshold() * 2.5
	end

	function MovementService:_GetFlowClumpTouchPaddingStuds(sepConfig: any): number
		local configuredPadding = sepConfig and sepConfig.ClumpTouchDistancePaddingStuds
		if type(configuredPadding) == "number" and configuredPadding >= 0 then
			return configuredPadding
		end
		return 0.5
	end

	function MovementService:_GetSharedFlowfieldRefreshCooldownSeconds(sepConfig: any): number
		local sharedFieldConfig = self:_GetFastFlowSharedFieldConfig()
		local configuredCooldown = sharedFieldConfig and sharedFieldConfig.RefreshCooldownSeconds
		if type(configuredCooldown) == "number" and configuredCooldown > 0 then
			return configuredCooldown
		end

		configuredCooldown = sepConfig and sepConfig.SharedFlowfieldRefreshCooldownSeconds
		if type(configuredCooldown) == "number" and configuredCooldown > 0 then
			return configuredCooldown
		end
		return 0.35
	end

	function MovementService:_UsePrunedSharedGeneration(): boolean
		local sharedFieldConfig = self:_GetFastFlowSharedFieldConfig()
		return (sharedFieldConfig and sharedFieldConfig.UsePrunedGeneration == true) or false
	end

	function MovementService:_AllowSingleSharedRefreshPerCooldown(): boolean
		local sharedFieldConfig = self:_GetFastFlowSharedFieldConfig()
		return sharedFieldConfig == nil or sharedFieldConfig.AllowSingleRefreshPerCooldown ~= false
	end

	function MovementService:_GetSharedRepresentativeStartCap(): number
		local sharedFieldConfig = self:_GetFastFlowSharedFieldConfig()
		local configuredCap = sharedFieldConfig and sharedFieldConfig.RepresentativeStartCap
		if type(configuredCap) == "number" and configuredCap > 0 then
			return math.max(1, math.floor(configuredCap))
		end
		return 8
	end

	function MovementService:_GetIsolationSkipRadiusStuds(sepConfig: any): number
		local configuredRadius = sepConfig and sepConfig.IsolationSkipRadiusStuds
		if type(configuredRadius) == "number" and configuredRadius > 0 then
			return configuredRadius
		end
		return 6
	end

	function MovementService:_UseIsolationSkip(sepConfig: any): boolean
		return (sepConfig and sepConfig.IsolationSkipEnabled == true) or false
	end

	function MovementService:_UseDenseCellFallback(sepConfig: any): boolean
		return false
	end

	function MovementService:_GetDenseCellOccupancyThreshold(sepConfig: any): number
		local configuredThreshold = sepConfig and sepConfig.DenseCellOccupancyThreshold
		if type(configuredThreshold) == "number" and configuredThreshold >= 2 then
			return math.max(2, math.floor(configuredThreshold))
		end
		return 10
	end

	function MovementService:_GetNearGoalSeparationScale(sepConfig: any): number
		local configuredScale = sepConfig and sepConfig.NearGoalSeparationScale
		if type(configuredScale) == "number" and configuredScale >= 0 then
			return math.clamp(configuredScale, 0, 1)
		end
		return 0.35
	end

	function MovementService:_GetNearGoalSeparationRadiusStuds(sepConfig: any): number
		local configuredRadius = sepConfig and sepConfig.NearGoalSeparationRadiusStuds
		if type(configuredRadius) == "number" and configuredRadius > 0 then
			return configuredRadius
		end
		return 8
	end

	function MovementService:_GetNeighborDirtyMoveThresholdStuds(sepConfig: any, cellWidthStuds: number): number
		local configuredThreshold = sepConfig and sepConfig.NeighborDirtyMoveThresholdStuds
		if type(configuredThreshold) == "number" and configuredThreshold > 0 then
			return configuredThreshold
		end
		return math.max(0.5, cellWidthStuds * 0.5)
	end

	function MovementService:_IsFlowSeparationParallelEnabled(sepConfig: any): boolean
		return (sepConfig and sepConfig.ParallelEnabled == true) or false
	end

	function MovementService:_GetFlowSeparationParallelActorCount(sepConfig: any): number
		local configuredActorCount = sepConfig and sepConfig.ParallelActorCount
		if type(configuredActorCount) == "number" and configuredActorCount > 0 then
			return math.max(1, math.floor(configuredActorCount))
		end
		return 4
	end

	function MovementService:_GetFlowSeparationParallelBatchSize(sepConfig: any): number
		local configuredBatchSize = sepConfig and sepConfig.ParallelBatchSize
		if type(configuredBatchSize) == "number" and configuredBatchSize > 0 then
			return math.max(1, math.floor(configuredBatchSize))
		end
		return 64
	end

	function MovementService:_GetFlowSeparationParallelMinPairCount(sepConfig: any): number
		local configuredMinPairCount = sepConfig and sepConfig.ParallelMinPairCount
		if type(configuredMinPairCount) == "number" and configuredMinPairCount >= 1 then
			return math.max(1, math.floor(configuredMinPairCount))
		end
		return 1
	end

	function MovementService:_IsFlowSeparationParallelSnapshotBuildEnabled(sepConfig: any): boolean
		return self:_IsFlowSeparationParallelEnabled(sepConfig)
			and sepConfig
			and sepConfig.ParallelSnapshotBuildEnabled ~= false
	end

	function MovementService:_GetFlowSeparationParallelSnapshotBuildMinCandidateCount(sepConfig: any): number
		local configuredMinCandidateCount = sepConfig and sepConfig.ParallelSnapshotBuildMinCandidateCount
		if type(configuredMinCandidateCount) == "number" and configuredMinCandidateCount >= 1 then
			return math.max(1, math.floor(configuredMinCandidateCount))
		end
		return 1
	end

	function MovementService:_GetFlowSeparationParallelSnapshotBuildMaxPairsPerTask(_sepConfig: any): number
		return FlowSeparationPairSnapshotSchema.GetFixedMaxPairsPerTask()
	end

	function MovementService:_GetFlowSeparationParallelSnapshotBuildMaxEntitiesPerTask(
		sepConfig: any,
		maxPairsPerTask: number
	): number
		local configuredMaxEntitiesPerTask = sepConfig and sepConfig.ParallelSnapshotBuildMaxEntitiesPerTask
		assert(type(maxPairsPerTask) == "number" and maxPairsPerTask > 0 and maxPairsPerTask % 1 == 0, "maxPairsPerTask must be a positive integer")
		assert(
			type(configuredMaxEntitiesPerTask) == "number"
				and configuredMaxEntitiesPerTask >= 2
				and configuredMaxEntitiesPerTask % 1 == 0,
			"FLOW_SOFT_SEPARATION.ParallelSnapshotBuildMaxEntitiesPerTask must be an integer >= 2"
		)
		return configuredMaxEntitiesPerTask
	end

	function MovementService:_GetFlowSeparationParallelSnapshotBuildOverflowMode(_sepConfig: any): "Chunk" | "Local"
		return "Chunk"
	end

	function MovementService:_GetFlowSeparationParallelSnapshotBuildBatchSize(sepConfig: any): number
		local configuredBatchSize = sepConfig and sepConfig.ParallelSnapshotBuildBatchSize
		if type(configuredBatchSize) == "number" and configuredBatchSize > 0 then
			return math.max(1, math.floor(configuredBatchSize))
		end
		return 32
	end

	function MovementService:_GetFlowSeparationParallelSnapshotBuildTimeoutSeconds(sepConfig: any): number
		local configuredTimeout = sepConfig and sepConfig.ParallelSnapshotBuildTimeoutSeconds
		if type(configuredTimeout) == "number" and configuredTimeout > 0 then
			return configuredTimeout
		end
		return 0.02
	end

	function MovementService:_GetFlowSeparationParallelTimeoutSeconds(sepConfig: any): number
		local configuredTimeout = sepConfig and sepConfig.ParallelTimeoutSeconds
		if type(configuredTimeout) == "number" and configuredTimeout > 0 then
			return configuredTimeout
		end
		return 0.02
	end

	function MovementService:_GetFlowVelocityParallelBatchSize(sepConfig: any): number
		local configuredBatchSize = sepConfig and sepConfig.ParallelVelocityBatchSize
		if type(configuredBatchSize) == "number" and configuredBatchSize > 0 then
			return math.max(1, math.floor(configuredBatchSize))
		end
		return 64
	end

	function MovementService:_GetFlowVelocityParallelMinEntityCount(sepConfig: any): number
		local configuredMinEntityCount = sepConfig and sepConfig.ParallelMinVelocityEntityCount
		if type(configuredMinEntityCount) == "number" and configuredMinEntityCount >= 1 then
			return math.max(1, math.floor(configuredMinEntityCount))
		end
		return 1
	end

	function MovementService:_GetFlowVelocityParallelTimeoutSeconds(sepConfig: any): number
		local configuredTimeout = sepConfig and sepConfig.ParallelVelocityTimeoutSeconds
		if type(configuredTimeout) == "number" and configuredTimeout > 0 then
			return configuredTimeout
		end
		return 0.02
	end

	function MovementService:_IsFlowSeparationParallelAsyncEnabled(sepConfig: any): boolean
		return self:_IsFlowSeparationParallelEnabled(sepConfig)
			and sepConfig
			and sepConfig.ParallelAsyncEnabled ~= false
	end

	function MovementService:_GetFlowSeparationParallelAsyncMaxInFlightSeconds(sepConfig: any): number
		local configuredTimeout = sepConfig and sepConfig.ParallelAsyncMaxInFlightSeconds
		if type(configuredTimeout) == "number" and configuredTimeout > 0 then
			return configuredTimeout
		end
		return 0.05
	end

	function MovementService:_ShouldUsePreviousFlowSeparationParallelResult(sepConfig: any): boolean
		return sepConfig == nil or sepConfig.ParallelAsyncUsePreviousResult ~= false
	end

	function MovementService:_GetAgentRadiusStuds(entity: number): number
		local params = self:_GetAgentParams(entity)
		local agentRadius = params.AgentRadius
		if type(agentRadius) == "number" and agentRadius > 0 then
			return agentRadius
		end
		return 2
	end
end
