--!strict

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

export type TAttributeValue = string | number | boolean | Vector3 | CFrame | Color3 | BrickColor | UDim | UDim2 | NumberSequence | ColorSequence | NumberRange | Rect | nil

export type ECSRevealState = {
	Attributes: { [string]: TAttributeValue }?,
	ClearAttributes: { string }?,
	Tags: { [string]: boolean }?,
}

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
local ECSRevealApplier = {}

function ECSRevealApplier.Apply(instance: Instance?, revealState: ECSRevealState?, collectionServiceOverride: TCollectionServiceLike?)
	assert(RunService:IsServer(), "ECSRevealApplier.Apply is server-only")

	if not instance or not revealState then
		return
	end

	local service = collectionServiceOverride or CollectionService

	local attributes = revealState.Attributes
	if attributes then
		for name, value in attributes do
			if instance:GetAttribute(name) ~= value then
				instance:SetAttribute(name, value)
			end
		end
	end

	local clearAttributes = revealState.ClearAttributes
	if clearAttributes then
		for _, name in clearAttributes do
			if instance:GetAttribute(name) ~= nil then
				instance:SetAttribute(name, nil)
			end
		end
	end

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
