--!strict

--[=[
	@class MiningAction
	Mining animation action. Uses BaseAction's data-driven dispatch with sound and VFX events.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseAction = require(ReplicatedStorage.Utilities.ActionSystem.BaseAction)
local SoundIds = require(ReplicatedStorage.Contexts.Sound.Config.SoundIds)

local MiningAction = {}
MiningAction.__index = MiningAction
setmetatable(MiningAction, BaseAction)

--[=[
	@prop AnimationKey string
	@within MiningAction
	Animation state name ("Mining")
]=]
MiningAction.AnimationKey = "Mining"

--[=[
	@prop Looped boolean
	@within MiningAction
	Whether the animation loops on completion
]=]
MiningAction.Looped = true

--[=[
	@prop Events table
	@within MiningAction
	Data-driven event config: Swing event plays mining hit sound and creates VFX at target
]=]
MiningAction.Events = {
	Swing = {
		SFX = SoundIds.SFX.MiningHit,
		VFX = "MiningDust",
		VFXAtTarget = true,
	},
}

--[=[
	Create a new MiningAction instance.
	@within MiningAction
	@return MiningAction -- New action
]=]
function MiningAction.new()
	local self = BaseAction.new()
	return setmetatable(self :: any, MiningAction)
end

return MiningAction
