--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AIBehaviorDefinitionRegistry =
	require(ServerScriptService.Contexts.AI.Infrastructure.Services.AIBehaviorDefinitionRegistry)
local AIEntitySetupPolicy = require(ServerScriptService.Contexts.AI.AIDomain.Policies.AIEntitySetupPolicy)
local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)
local SetupEntityAICommand = require(ServerScriptService.Contexts.AI.Application.Commands.SetupEntityAICommand)

local function createRegistry(entityContext: any, behaviorRegistry: any, setupPolicy: any?)
	return {
		Get = function(_self, name: string)
			if name == "EntityContext" then
				return entityContext
			end
			if name == "AIBehaviorDefinitionRegistry" then
				return behaviorRegistry
			end
			if name == "AIEntitySetupPolicy" then
				return setupPolicy
			end

			error(("Unexpected registry lookup: %s"):format(name))
		end,
	}
end

local function createCommand(entityContext: any)
	local behaviorRegistry = AIBehaviorDefinitionRegistry.new()
	behaviorRegistry:RegisterDefinition({
		DefinitionId = "Enemy.Swarm",
		Definition = {},
	})

	local policy = AIEntitySetupPolicy.new()
	policy:Init(createRegistry(entityContext, behaviorRegistry), "AIEntitySetupPolicy")

	local command = SetupEntityAICommand.new()
	command:Init(createRegistry(entityContext, behaviorRegistry, policy), "SetupEntityAICommand")
	return command
end

return function()
	describe("SetupEntityAICommand", function()
		it("writes AI setup components for a valid profile", function()
			local writes = {}
			local entityContext = {
				Has = function(_self, _entity: number, key: string, featureName: string?)
					return {
						success = key == "Identity" and featureName == "Entity",
						value = true,
					}
				end,
				Set = function(_self, entity: number, key: string, value: any, featureName: string?)
					table.insert(writes, {
						Entity = entity,
						Key = key,
						Value = value,
						FeatureName = featureName,
					})
					return {
						success = true,
						value = true,
					}
				end,
			}
			local command = createCommand(entityContext)

			local result = command:Execute(123, {
				DefinitionId = "Enemy.Swarm",
				TickInterval = 0.25,
				InitialBehaviorId = "Attack",
				InitialNodePath = { "Root", "Attack" },
				Blackboard = {
					Target = 456,
				},
				ActionStateStatus = AISharedContract.ActionStatus.Idle,
			})

			expect(result.success).to.equal(true)
			expect(#writes).to.equal(5)
			expect(writes[1].Key).to.equal(AISharedContract.Components.BehaviorTree)
			expect(writes[1].Value.DefinitionId).to.equal("Enemy.Swarm")
			expect(writes[2].Key).to.equal(AISharedContract.Components.CurrentBehavior)
			expect(writes[2].Value.BehaviorId).to.equal("Attack")
			expect(writes[4].Key).to.equal(AISharedContract.Components.BehaviorState)
			expect(writes[4].Value.Blackboard.Target).to.equal(456)
			expect(writes[5].Key).to.equal(AISharedContract.Components.ActionState)
		end)

		it("fails clearly when the entity is missing", function()
			local entityContext = {
				Has = function()
					return {
						success = true,
						value = false,
					}
				end,
				Set = function()
					error("Set should not be called")
				end,
			}
			local command = createCommand(entityContext)

			local result = command:Execute(999, {
				DefinitionId = "Enemy.Swarm",
				TickInterval = 0.25,
			})

			expect(result.success).to.equal(false)
			expect(result.type).to.equal("UnknownEntity")
		end)

		it("fails clearly when the behavior definition is unknown", function()
			local entityContext = {
				Has = function()
					return {
						success = true,
						value = true,
					}
				end,
				Set = function()
					error("Set should not be called")
				end,
			}
			local command = createCommand(entityContext)

			local result = command:Execute(123, {
				DefinitionId = "Missing",
				TickInterval = 0.25,
			})

			expect(result.success).to.equal(false)
			expect(result.type).to.equal("UnknownBehaviorDefinition")
		end)

		it("rejects invalid setup profile fields", function()
			local entityContext = {
				Has = function()
					return {
						success = true,
						value = true,
					}
				end,
				Set = function()
					error("Set should not be called")
				end,
			}
			local command = createCommand(entityContext)

			local badTick = command:Execute(123, {
				DefinitionId = "Enemy.Swarm",
				TickInterval = 0,
			})
			local badNodePath = command:Execute(123, {
				DefinitionId = "Enemy.Swarm",
				TickInterval = 0.25,
				InitialNodePath = { "Root", [3] = "Gap" },
			} :: any)
			local badStatus = command:Execute(123, {
				DefinitionId = "Enemy.Swarm",
				TickInterval = 0.25,
				ActionStateStatus = "Unknown",
			} :: any)

			expect(badTick.success).to.equal(false)
			expect(badTick.type).to.equal("InvalidEntityProfile")
			expect(badNodePath.success).to.equal(false)
			expect(badNodePath.type).to.equal("InvalidEntityProfile")
			expect(badStatus.success).to.equal(false)
			expect(badStatus.type).to.equal("InvalidEntityProfile")
		end)
	end)
end
