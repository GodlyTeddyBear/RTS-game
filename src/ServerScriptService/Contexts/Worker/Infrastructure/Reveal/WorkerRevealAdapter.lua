--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local ECSRevealApplier = require(ServerScriptService.Infrastructure.ECSRevealApplier)

local WorkerRevealAdapter = {}
WorkerRevealAdapter.__index = WorkerRevealAdapter

export type TWorkerRevealAdapter = typeof(setmetatable({} :: {
	World: any,
	Components: any,
}, WorkerRevealAdapter))

function WorkerRevealAdapter.new(): TWorkerRevealAdapter
	return setmetatable({}, WorkerRevealAdapter)
end

function WorkerRevealAdapter:Init(registry: any, _name: string)
	self.World = registry:Get("World")
	self.Components = registry:Get("Components")
end

function WorkerRevealAdapter:Apply(entity: any, model: Model)
	ECSRevealApplier.Apply(model, self:BuildRevealState(entity))
end

function WorkerRevealAdapter:BuildRevealState(entity: any): ECSRevealApplier.TRevealState?
	local worker = self.World:get(entity, self.Components.WorkerComponent)
	if not worker then
		return nil
	end

	local assignment = self.World:get(entity, self.Components.AssignmentComponent)
	local miningState = self.World:get(entity, self.Components.MiningStateComponent)
	local occupation = if assignment then assignment.Role else "Undecided"
	local animationState = if miningState then miningState.AnimationState or "Mining" else "Idle"

	return {
		Attributes = {
			WorkerId = worker.Id,
			Occupation = occupation,
			ModelTemplate = occupation,
			AnimationState = animationState,
			AnimationLooping = miningState ~= nil,
		},
		Tags = {
			AnimatedWorker = true,
		},
	}
end

return WorkerRevealAdapter
