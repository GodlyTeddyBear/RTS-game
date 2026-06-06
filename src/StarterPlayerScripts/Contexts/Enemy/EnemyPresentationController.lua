--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local EnemyHealthBillboardSystem = require(script.Parent.Infrastructure.Systems.EnemyHealthBillboardSystem)

local EnemyPresentationController = Knit.CreateController({
	Name = "EnemyPresentationController",
})

function EnemyPresentationController:KnitStart()
	local entityController = Knit.GetController("EntityController")
	entityController:RegisterSystem("EnemyHealthBillboardSystem", EnemyHealthBillboardSystem.new(entityController))
end

return EnemyPresentationController
