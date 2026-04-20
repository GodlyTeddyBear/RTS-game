--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlantConfig = require(ReplicatedStorage.Contexts.Worker.Config.PlantConfig)
local WorkerSpecs = require(script.Parent.Parent.Specs.WorkerSpecs)

local BaseAssignZoneTargetPolicy = require(script.Parent.Shared.BaseAssignZoneTargetPolicy)
local ZoneTargetUtils = require(script.Parent.Shared.ZoneTargetUtils)

local AssignHerbalistTargetPolicy = {}
AssignHerbalistTargetPolicy.__index = AssignHerbalistTargetPolicy

function AssignHerbalistTargetPolicy.new()
	return BaseAssignZoneTargetPolicy.new({
		RoleName = "Herbalist",
		ConfigTable = PlantConfig,
		Spec = WorkerSpecs.CanAssignHerbalistTarget,
		ResultInstanceKey = "PlantInstance",
		SlotServiceName = "GardenSlotService",
		GetZoneFolder = function(lotContext: any, userId: number)
			return lotContext:GetGardenFolderForUser(userId)
		end,
		FindTargetInZone = function(zoneFolder: any, targetId: string)
			return ZoneTargetUtils.FindTargetInZone(zoneFolder, targetId, "Default")
		end,
		BuildCandidate = function(ctx: BaseAssignZoneTargetPolicy.TZonePolicyCheckContext): WorkerSpecs.TAssignHerbalistTargetCandidate
			return {
				Entity = ctx.Entity,
				IsHerbalist = ctx.Assignment ~= nil and ctx.Assignment.Role == "Herbalist",
				PlantTypeExists = ctx.TargetConfig ~= nil,
				GardenFolderExists = ctx.ZoneFolder ~= nil,
				PlantInLot = ctx.TargetInstance ~= nil,
				WorkersAtPlant = ctx.WorkersAtTarget,
				MaxWorkers = ctx.TargetConfig and ctx.TargetConfig.MaxWorkers or 0,
				IsUnlocked = ctx.IsUnlocked,
			}
		end,
	})
end

return AssignHerbalistTargetPolicy
