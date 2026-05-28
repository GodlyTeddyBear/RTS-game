--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AIEntitySchema = require(ServerScriptService.Contexts.AI.Infrastructure.ECS.AIEntitySchema)
local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)

return function()
	describe("AISharedContract", function()
		it("matches the AI entity schema keys", function()
			expect(AIEntitySchema.FeatureName).to.equal(AISharedContract.FeatureName)

			for _, componentKey in pairs(AISharedContract.Components) do
				expect(AIEntitySchema.Components[componentKey]).never.to.equal(nil)
			end

			for _, tagKey in pairs(AISharedContract.Tags) do
				expect(AIEntitySchema.Tags[tagKey]).never.to.equal(nil)
			end
		end)

		it("builds independent default setup tables", function()
			local profile = {
				DefinitionId = "Enemy.Swarm",
				TickInterval = 0.25,
				InitialBehaviorId = "Attack",
				InitialNodePath = { "Root", "Attack" },
				Blackboard = {
					Target = 10,
				},
			}

			local firstState = AISharedContract.BuildBehaviorState(profile)
			local secondState = AISharedContract.BuildBehaviorState(profile)
			firstState.Blackboard.Target = 20

			local firstCurrent = AISharedContract.BuildCurrentBehavior(profile, 1)
			local secondCurrent = AISharedContract.BuildCurrentBehavior(profile, 1)
			firstCurrent.NodePath[1] = "Changed"

			expect(secondState.Blackboard.Target).to.equal(10)
			expect(secondCurrent.NodePath[1]).to.equal("Root")
		end)

		it("normalizes action state defaults", function()
			local defaultState = AISharedContract.BuildActionState(nil)
			local runningState = AISharedContract.BuildActionState({
				DefinitionId = "Enemy.Swarm",
				TickInterval = 0.25,
				ActionStateStatus = AISharedContract.ActionStatus.Running,
			})

			expect(defaultState.Status).to.equal(AISharedContract.ActionStatus.Idle)
			expect(runningState.Status).to.equal(AISharedContract.ActionStatus.Running)
		end)
	end)
end
