--!strict

local AnimationSetRegistry = require(script.Parent.AnimationSetRegistry)
local Types = require(script.Parent.Parent.Types.AnimationTypes)

type TCompiledAnimationSet = Types.TCompiledAnimationSet

local AnimationSetCompiler = {}

local function _MergeSet(setId: string, slots: { [string]: string }, visiting: { [string]: boolean }, visited: { [string]: boolean })
	assert(visiting[setId] ~= true, ("AnimationSetCompiler: inheritance cycle at '%s'"):format(setId))
	if visited[setId] then
		return
	end

	visiting[setId] = true
	local setDefinition = AnimationSetRegistry.Get(setId)
	for _, parentSetId in ipairs(setDefinition.Extends or {}) do
		_MergeSet(parentSetId, slots, visiting, visited)
	end
	for slotId, clipKey in pairs(setDefinition.Slots) do
		slots[slotId] = clipKey
	end
	visiting[setId] = nil
	visited[setId] = true
end

function AnimationSetCompiler.Compile(setId: string, variantId: string?): TCompiledAnimationSet
	local resolvedVariantId = if type(variantId) == "string" and variantId ~= "" then variantId else "Default"
	local slots = {}
	_MergeSet(setId, slots, {}, {})

	local setDefinition = AnimationSetRegistry.Get(setId)
	local variantSlots = if setDefinition.Variants ~= nil then setDefinition.Variants[resolvedVariantId] else nil
	if variantSlots ~= nil then
		for slotId, clipKey in pairs(variantSlots) do
			slots[slotId] = clipKey
		end
	end

	return table.freeze({
		SetId = setId,
		VariantId = resolvedVariantId,
		Slots = table.freeze(slots),
	})
end

return table.freeze(AnimationSetCompiler)
