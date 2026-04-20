--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TreeConfig = require(ReplicatedStorage.Contexts.Worker.Config.TreeConfig)
local WorkerSpecs = require(script.Parent.Parent.Specs.WorkerSpecs)

local BaseAssignZoneTargetPolicy = require(script.Parent.Shared.BaseAssignZoneTargetPolicy)
local ZoneTargetUtils = require(script.Parent.Shared.ZoneTargetUtils)

local AssignLumberjackTargetPolicy = {}
AssignLumberjackTargetPolicy.__index = AssignLumberjackTargetPolicy

function AssignLumberjackTargetPolicy.new()
	return BaseAssignZoneTargetPolicy.new({
		RoleName = "Lumberjack",
		ConfigTable = TreeConfig,
		Spec = WorkerSpecs.CanAssignLumberjackTarget,
		ResultInstanceKey = "TreeInstance",
		SlotServiceName = "ForestSlotService",
		GetZoneFolder = function(lotContext: any, userId: number)
			return lotContext:GetForestFolderForUser(userId)
		end,
		FindTargetInZone = function(zoneFolder: any, targetId: string)
			return ZoneTargetUtils.FindTargetInZone(zoneFolder, targetId, "Default")
		end,
		BuildCandidate = function(ctx: BaseAssignZoneTargetPolicy.TZonePolicyCheckContext): WorkerSpecs.TAssignLumberjackTargetCandidate
			return {
				Entity = ctx.Entity,
				IsLumberjack = ctx.Assignment ~= nil and ctx.Assignment.Role == "Lumberjack",
				TreeTypeExists = ctx.TargetConfig ~= nil,
				ForestFolderExists = ctx.ZoneFolder ~= nil,
				TreeInLot = ctx.TargetInstance ~= nil,
				WorkersAtTree = ctx.WorkersAtTarget,
				MaxWorkers = ctx.TargetConfig and ctx.TargetConfig.MaxWorkers or 0,
				IsUnlocked = ctx.IsUnlocked,
			}
		end,
	})
end

return AssignLumberjackTargetPolicy
