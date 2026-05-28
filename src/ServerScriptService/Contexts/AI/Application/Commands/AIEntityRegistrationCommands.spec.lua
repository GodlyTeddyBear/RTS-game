--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)
local RegisterAIEntitySchemaCommand =
	require(ServerScriptService.Contexts.AI.Application.Commands.RegisterAIEntitySchemaCommand)
local RegisterAIEntitySystemsCommand =
	require(ServerScriptService.Contexts.AI.Application.Commands.RegisterAIEntitySystemsCommand)

local function createRegistry(entityContext: any)
	return {
		Get = function(_self, name: string)
			if name == "EntityContext" then
				return entityContext
			end

			error(("Unexpected registry lookup: %s"):format(name))
		end,
	}
end

return function()
	describe("AI Entity registration commands", function()
		it("registers the AI feature schema before Entity registration closes", function()
			local registeredSchema = nil
			local entityContext = {
				GetFeatureComponents = function(_self, _featureName: string)
					return {
						success = false,
						type = "UnknownFeature",
						message = "missing",
					}
				end,
				RegisterFeatureSchema = function(_self, featureName: string, schema: any)
					registeredSchema = schema
					return {
						success = featureName == AISharedContract.FeatureName,
						value = schema,
					}
				end,
			}
			local command = RegisterAIEntitySchemaCommand.new()
			command:Init(createRegistry(entityContext), "RegisterAIEntitySchemaCommand")

			local result = command:Execute()

			expect(result.success).to.equal(true)
			expect(registeredSchema.FeatureName).to.equal(AISharedContract.FeatureName)
		end)

		it("fails clearly when Entity has already closed schema registration", function()
			local entityContext = {
				GetFeatureComponents = function(_self, _featureName: string)
					return {
						success = false,
						type = "UnknownFeature",
						message = "missing",
					}
				end,
				RegisterFeatureSchema = function()
					return {
						success = false,
						type = "InvalidEntityLifecycleState",
						message = "closed",
					}
				end,
			}
			local command = RegisterAIEntitySchemaCommand.new()
			command:Init(createRegistry(entityContext), "RegisterAIEntitySchemaCommand")

			local result = command:Execute()

			expect(result.success).to.equal(false)
			expect(result.type).to.equal("AIEntitySchemaRegistrationFailed")
		end)

		it("registers validation systems into Entity Commit phase", function()
			local registeredSystems = {}
			local entityContext = {
				RegisterSystem = function(_self, phaseName: string, systemSpec: any)
					table.insert(registeredSystems, {
						PhaseName = phaseName,
						SystemSpec = systemSpec,
					})
					return {
						success = true,
						value = true,
					}
				end,
			}
			local command = RegisterAIEntitySystemsCommand.new()
			command:Init(createRegistry(entityContext), "RegisterAIEntitySystemsCommand")

			local result = command:Execute()

			expect(result.success).to.equal(true)
			expect(#registeredSystems).to.equal(2)
			expect(registeredSystems[1].PhaseName).to.equal("Commit")
			expect(registeredSystems[1].SystemSpec.Name).to.equal("AIBehaviorCommitSystem")
			expect(registeredSystems[2].SystemSpec.Name).to.equal("AIActionIntentValidationSystem")
			expect(registeredSystems[2].SystemSpec.Reads[1]).to.equal("AI.ActionIntent")
		end)
	end)
end
