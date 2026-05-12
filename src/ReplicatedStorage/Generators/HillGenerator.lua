--!strict

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local GeneratorRunner = require(script.Parent.GeneratorRunner)

assert(RunService:IsServer(), "[ReplicatedStorage.Generators.HillGenerator] This module is server-only")

type TRunOptions = GeneratorRunner.TRunOptions

local serverGeneratorModule = ServerStorage:WaitForChild("Generators"):WaitForChild(script.Name) :: ModuleScript
local serverGenerator = GeneratorRunner.RequireGeneratorModule(serverGeneratorModule)

local Generator = {
	Defaults = serverGenerator.Defaults,
	Generate = serverGenerator.Generate,
	Attributes = serverGenerator.Defaults,
	OnGenerate = serverGenerator.Generate,
	Run = function(sourceInstance: Instance, targetContainer: Instance, options: TRunOptions?)
		return GeneratorRunner.RunGeneratorModule(serverGeneratorModule, sourceInstance, targetContainer, options)
	end,
}

return table.freeze(Generator)
