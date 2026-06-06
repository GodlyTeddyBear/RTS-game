--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local StructureConstructionPresentationSystem =
	require(script.Parent.Infrastructure.Systems.StructureConstructionPresentationSystem)

local StructurePresentationController = Knit.CreateController({
	Name = "StructurePresentationController",
})

function StructurePresentationController:KnitStart()
	local entityController = Knit.GetController("EntityController")
	entityController:RegisterSystem(
		"StructureConstructionPresentationSystem",
		StructureConstructionPresentationSystem.new(entityController)
	)
end

return StructurePresentationController
