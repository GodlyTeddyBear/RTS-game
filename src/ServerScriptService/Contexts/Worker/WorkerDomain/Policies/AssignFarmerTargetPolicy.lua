--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CropConfig = require(ReplicatedStorage.Contexts.Worker.Config.CropConfig)
local WorkerSpecs = require(script.Parent.Parent.Specs.WorkerSpecs)

local BaseAssignZoneTargetPolicy = require(script.Parent.Shared.BaseAssignZoneTargetPolicy)
local ZoneTargetUtils = require(script.Parent.Shared.ZoneTargetUtils)

local AssignFarmerTargetPolicy = {}
AssignFarmerTargetPolicy.__index = AssignFarmerTargetPolicy

function AssignFarmerTargetPolicy.new()
	return BaseAssignZoneTargetPolicy.new({
		RoleName = "Farmer",
		ConfigTable = CropConfig,
		Spec = WorkerSpecs.CanAssignFarmerTarget,
		ResultInstanceKey = "CropInstance",
		SlotServiceName = "FarmSlotService",
		GetZoneFolder = function(lotContext: any, userId: number)
			return lotContext:GetFarmFolderForUser(userId)
		end,
		FindTargetInZone = function(zoneFolder: any, targetId: string)
			return ZoneTargetUtils.FindTargetInZone(zoneFolder, targetId, "Default")
		end,
		BuildCandidate = function(ctx: BaseAssignZoneTargetPolicy.TZonePolicyCheckContext): WorkerSpecs.TAssignFarmerTargetCandidate
			return {
				Entity = ctx.Entity,
				IsFarmer = ctx.Assignment ~= nil and ctx.Assignment.Role == "Farmer",
				CropTypeExists = ctx.TargetConfig ~= nil,
				FarmFolderExists = ctx.ZoneFolder ~= nil,
				CropInLot = ctx.TargetInstance ~= nil,
				WorkersAtCrop = ctx.WorkersAtTarget,
				MaxWorkers = ctx.TargetConfig and ctx.TargetConfig.MaxWorkers or 0,
				IsUnlocked = ctx.IsUnlocked,
			}
		end,
	})
end

return AssignFarmerTargetPolicy
