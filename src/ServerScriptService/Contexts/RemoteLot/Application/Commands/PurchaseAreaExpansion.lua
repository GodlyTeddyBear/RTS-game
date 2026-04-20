--!strict

--[=[
	@class PurchaseAreaExpansion
	Purchases and reveals a configured remote lot expansion area.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local RemoteLotAreaConfig = require(ReplicatedStorage.Contexts.RemoteLot.Config.RemoteLotAreaConfig)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok, Try, Ensure = Result.Ok, Result.Try, Result.Ensure
local MentionSuccess = Result.MentionSuccess

local PurchaseAreaExpansion = {}
PurchaseAreaExpansion.__index = PurchaseAreaExpansion

export type TPurchaseAreaExpansion = typeof(setmetatable(
	{} :: {
		_tracker: any,
		_entityFactory: any,
		_revealService: any,
		_unlockContext: any,
	},
	PurchaseAreaExpansion
))

function PurchaseAreaExpansion.new(): TPurchaseAreaExpansion
	local self = setmetatable({}, PurchaseAreaExpansion)
	self._tracker = nil :: any
	self._entityFactory = nil :: any
	self._revealService = nil :: any
	self._unlockContext = nil :: any
	return self
end

function PurchaseAreaExpansion:Init(registry: any, _name: string)
	self._tracker = registry:Get("RemoteLotTracker")
	self._entityFactory = registry:Get("RemoteLotEntityFactory")
	self._revealService = registry:Get("RemoteLotRevealService")
	self._unlockContext = registry:Get("UnlockContext")
end

function PurchaseAreaExpansion:Execute(player: Player, areaId: string): Result.Result<boolean>
	Ensure(type(areaId) == "string" and #areaId > 0, "InvalidAreaId", Errors.INVALID_AREA_ID)

	local areaDef: any = RemoteLotAreaConfig[areaId]
	Ensure(areaDef, "InvalidAreaId", Errors.INVALID_AREA_ID)
	Ensure(self._tracker:Has(player), "NoRemoteLot", Errors.NO_REMOTE_LOT)
	Ensure(not self._unlockContext:IsUnlocked(player.UserId, areaDef.TargetId), "AlreadyUnlocked", Errors.AREA_ALREADY_UNLOCKED)

	local model = self._tracker:GetModel(player)
	Ensure(model, "NoRemoteLot", Errors.NO_REMOTE_LOT)
	Ensure(self._revealService:GetAreaGroup(model, areaDef), "AreaModelMissing", Errors.AREA_MODEL_MISSING)

	Try(self._unlockContext:PurchaseUnlock(player, areaDef.TargetId))
	self._revealService:RevealArea(model, areaDef)

	local entity = self._entityFactory:FindRemoteLotByUserId(player.UserId)
	Ensure(entity, "RemoteLotEntityMissing", Errors.REMOTE_LOT_ENTITY_MISSING)
	self._entityFactory:RegisterExpansionZones(entity, model, areaDef)

	MentionSuccess("RemoteLot:PurchaseAreaExpansion:Execute", "Purchased remote lot expansion area", {
		userId = player.UserId,
		areaId = areaId,
		targetId = areaDef.TargetId,
	})

	return Ok(true)
end

return PurchaseAreaExpansion
