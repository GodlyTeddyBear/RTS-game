--!strict

local CollectionService = game:GetService("CollectionService")

export type TAttributeValue = string | number | boolean | Vector3 | CFrame | Color3 | BrickColor | UDim | UDim2 | NumberSequence | ColorSequence | NumberRange | Rect | nil

export type TRevealState = {
	Attributes: { [string]: TAttributeValue }?,
	ClearAttributes: { string }?,
	Tags: { [string]: boolean }?,
}

local ECSRevealApplier = {}

function ECSRevealApplier.Apply(instance: Instance?, revealState: TRevealState?)
	if not instance or not revealState then
		return
	end

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
			local hasTag = CollectionService:HasTag(instance, tagName)
			if shouldHaveTag and not hasTag then
				CollectionService:AddTag(instance, tagName)
			elseif not shouldHaveTag and hasTag then
				CollectionService:RemoveTag(instance, tagName)
			end
		end
	end
end

return ECSRevealApplier
