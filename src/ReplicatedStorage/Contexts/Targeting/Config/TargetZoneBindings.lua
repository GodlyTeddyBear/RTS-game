--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OreConfig = require(ReplicatedStorage.Contexts.Worker.Config.OreConfig)
local TreeConfig = require(ReplicatedStorage.Contexts.Worker.Config.TreeConfig)
local PlantConfig = require(ReplicatedStorage.Contexts.Worker.Config.PlantConfig)

--[=[
	@interface TTargetZoneBinding
	@within TargetZoneBindings
	.ZoneName string -- The name of the world zone (e.g. `"Mines"`)
	.ContainerName string -- The container folder name within the zone
	.TargetType string -- The target type used for tagging (e.g. `"Ore"`)
	.Config { [string]: any } -- The resource config table for instances in this zone
]=]
export type TTargetZoneBinding = {
	ZoneName: string,
	ContainerName: string,
	TargetType: string,
	Config: { [string]: any },
}

--[=[
	Static list mapping world zones to their target type and resource config.
	@class TargetZoneBindings
]=]
local TargetZoneBindings = table.freeze({
	{ ZoneName = "Mines", ContainerName = "Default", TargetType = "Ore", Config = OreConfig },
	{ ZoneName = "Forest", ContainerName = "Default", TargetType = "Tree", Config = TreeConfig },
	{ ZoneName = "Garden", ContainerName = "Default", TargetType = "Plant", Config = PlantConfig },
} :: { TTargetZoneBinding })

return TargetZoneBindings
