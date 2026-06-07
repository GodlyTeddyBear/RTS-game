--!strict

local Sets = require(script.Parent.Sets)
local Types = require(script.Parent.Parent.Types.AnimationTypes)

type TAnimationSet = Types.TAnimationSet

local AnimationSetRegistry = {}

function AnimationSetRegistry.Get(setId: string): TAnimationSet
	local setDefinition = Sets[setId]
	assert(setDefinition ~= nil, ("AnimationSetRegistry: unknown set '%s'"):format(tostring(setId)))
	return setDefinition
end

function AnimationSetRegistry.Exists(setId: string): boolean
	return Sets[setId] ~= nil
end

function AnimationSetRegistry.GetAll(): { [string]: TAnimationSet }
	return Sets
end

return table.freeze(AnimationSetRegistry)
