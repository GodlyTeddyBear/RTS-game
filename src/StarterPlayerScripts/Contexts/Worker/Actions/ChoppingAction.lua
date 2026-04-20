--!strict

--[=[
	@class ChoppingAction
	Chopping animation action. Uses BaseAction's data-driven dispatch with sound and VFX events.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseAction = require(ReplicatedStorage.Utilities.ActionSystem.BaseAction)
local SoundIds = require(ReplicatedStorage.Contexts.Sound.Config.SoundIds)

local ChoppingAction = {}
ChoppingAction.__index = ChoppingAction
setmetatable(ChoppingAction, BaseAction)

--[=[
	@prop AnimationKey string
	@within ChoppingAction
	Animation state name ("Chopping")
]=]
ChoppingAction.AnimationKey = "Chopping"

--[=[
	@prop Looped boolean
	@within ChoppingAction
	Whether the animation loops on completion
]=]
ChoppingAction.Looped = true

--[=[
	@prop Events table
	@within ChoppingAction
	Data-driven event config: Swing event plays chopping sound and creates VFX at target
]=]
ChoppingAction.Events = {
	Swing = {
		SFX = SoundIds.SFX.ChoppingHit,
		VFX = "WoodChips",
		VFXAtTarget = true,
	},
}

--[=[
	Create a new ChoppingAction instance.
	@within ChoppingAction
	@return ChoppingAction -- New action
]=]
function ChoppingAction.new()
	local self = BaseAction.new()
	return setmetatable(self :: any, ChoppingAction)
end

return ChoppingAction
