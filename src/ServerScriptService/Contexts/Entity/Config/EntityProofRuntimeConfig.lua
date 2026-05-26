--!strict

local ServerStorage = game:GetService("ServerStorage")

local AI = require(ServerStorage.Utilities.ContextUtilities.AI)
local BaseExecutor = require(ServerStorage.Utilities.ContextUtilities.BaseExecutor)

local BehaviorSystem = AI.GetBehaviorSystem()

local EntityProofRuntimeConfig = {}

EntityProofRuntimeConfig.FeatureName = "EntityProof"
EntityProofRuntimeConfig.ArchetypeName = "EntityProof.ProofActor"
EntityProofRuntimeConfig.ActorType = "EntityProof.Actor"
EntityProofRuntimeConfig.ActionId = "EntityProof.Idle"
EntityProofRuntimeConfig.BehaviorDefinition = table.freeze({
	Sequence = {
		"EntityProofIdle",
	},
})

local ProofIdleExecutor = {}
ProofIdleExecutor.__index = ProofIdleExecutor
setmetatable(ProofIdleExecutor, BaseExecutor)

function ProofIdleExecutor.new()
	local self = BaseExecutor.new({
		ActionId = EntityProofRuntimeConfig.ActionId,
		IsCommitted = false,
	})
	return setmetatable(self, ProofIdleExecutor)
end

function ProofIdleExecutor:OnTick(_entity: number, _dt: number, _services: any): string
	return self:Running()
end

EntityProofRuntimeConfig.Commands = table.freeze({
	EntityProofIdle = function()
		return BehaviorSystem.Helpers.CreateCommandTask(function(task, context)
			context.ActionFactory:SetPendingAction(context.Entity, EntityProofRuntimeConfig.ActionId, nil)
			task:success()
		end)
	end,
})

EntityProofRuntimeConfig.Executors = table.freeze({
	[EntityProofRuntimeConfig.ActionId] = table.freeze({
		ActionId = EntityProofRuntimeConfig.ActionId,
		CreateExecutor = ProofIdleExecutor.new,
	}),
})

return table.freeze(EntityProofRuntimeConfig)
