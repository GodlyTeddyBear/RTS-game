--!strict

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

--[=[
	@type TAttributeValue
	@within ECSRevealApplier
	Attribute value types accepted by the reveal applier.
]=]
export type TAttributeValue = string | number | boolean | Vector3 | CFrame | Color3 | BrickColor | UDim | UDim2 | NumberSequence | ColorSequence | NumberRange | Rect | nil

--[=[
	@interface ECSRevealState
	@within ECSRevealApplier
	.Attributes { [string]: TAttributeValue }? -- Attributes to apply to the target instance.
	.ClearAttributes { string }? -- Attribute names to clear from the target instance.
	.Tags { [string]: boolean }? -- Tags to add or remove on the target instance.
]=]
export type ECSRevealState = {
	Attributes: { [string]: TAttributeValue }?,
	ClearAttributes: { string }?,
	Tags: { [string]: boolean }?,
}

--[=[
	@interface TCollectionServiceLike
	@within ECSRevealApplier
	.HasTag (self: any, instance: Instance, tagName: string) -> boolean -- Checks whether the instance already has a tag.
	.AddTag (self: any, instance: Instance, tagName: string) -> () -- Adds a tag to the instance.
	.RemoveTag (self: any, instance: Instance, tagName: string) -> () -- Removes a tag from the instance.
]=]
export type TCollectionServiceLike = {
	HasTag: (self: any, instance: Instance, tagName: string) -> boolean,
	AddTag: (self: any, instance: Instance, tagName: string) -> (),
	RemoveTag: (self: any, instance: Instance, tagName: string) -> (),
}

--[=[
	Applies a reveal state contract onto a Roblox instance.
	Preferred access: `require(ReplicatedStorage.Utilities.ECS).RevealApplier`.
	@class ECSRevealApplier
	@server
]=]
-- ── Types ──────────────────────────────────────────────────────────────────

local ECSRevealApplier = {}

-- ── Public ─────────────────────────────────────────────────────────────────

--[=[
	Applies the reveal contract to an instance.
	@within ECSRevealApplier
	@param instance Instance? -- Target instance to update.
	@param revealState ECSRevealState? -- Reveal contract to apply.
	@param collectionServiceOverride TCollectionServiceLike? -- Optional service override used for tests.
]=]
function ECSRevealApplier.Apply(instance: Instance?, revealState: ECSRevealState?, collectionServiceOverride: TCollectionServiceLike?)
	-- Enforce the server boundary before mutating live instance metadata.
	assert(RunService:IsServer(), "ECSRevealApplier.Apply is server-only")

	-- Guard nil inputs so callers can pass optional reveal data without branching.
	if not instance or not revealState then
		return
	end

	-- Prefer the injected service in tests; otherwise use the live CollectionService.
	local service = collectionServiceOverride or CollectionService

	-- Sync attributes first so discovery sees the identity payload immediately.
	local attributes = revealState.Attributes
	if attributes then
		for name, value in attributes do
			if instance:GetAttribute(name) ~= value then
				instance:SetAttribute(name, value)
			end
		end
	end

	-- Clear stale attributes after new values are in place.
	local clearAttributes = revealState.ClearAttributes
	if clearAttributes then
		for _, name in clearAttributes do
			if instance:GetAttribute(name) ~= nil then
				instance:SetAttribute(name, nil)
			end
		end
	end

	-- Reconcile tags last so tag listeners observe the final attribute state.
	local tags = revealState.Tags
	if tags then
		for tagName, shouldHaveTag in tags do
			local hasTag = service:HasTag(instance, tagName)
			if shouldHaveTag and not hasTag then
				service:AddTag(instance, tagName)
			elseif not shouldHaveTag and hasTag then
				service:RemoveTag(instance, tagName)
			end
		end
	end
end

return ECSRevealApplier
