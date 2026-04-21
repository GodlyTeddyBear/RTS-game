--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)

local TargetIndexService = require(script.Parent.Infrastructure.TargetIndexService)

--[=[
	Knit controller that exposes target lookup queries to other client-side systems.
	@class TargetingController
	@client
]=]
local TargetingController = Knit.CreateController({
	Name = "TargetingController",
})

function TargetingController:KnitInit()
	local registry = Registry.new("Client")
	self.Registry = registry

	self._TargetIndexService = TargetIndexService.new()
	registry:Register("TargetIndexService", self._TargetIndexService, "Infrastructure")

	registry:InitAll()
end

function TargetingController:KnitStart()
	self.Registry:StartOrdered({ "Infrastructure" })
end

--[=[
	Returns the first indexed instance matching both `targetType` and `targetId`, in insertion order.
	@within TargetingController
	@param targetType string -- The type attribute to match (e.g. `"NPC"`)
	@param targetId string -- The id attribute to match
	@return Instance? -- The first matching instance, or `nil` if none found
]=]
function TargetingController:FindFirstByTypeAndId(targetType: string, targetId: string): Instance?
	return self._TargetIndexService:FindFirstByTypeAndId(targetType, targetId)
end

--[=[
	Returns all indexed instances matching both `targetType` and `targetId`, in insertion order.
	@within TargetingController
	@param targetType string -- The type attribute to match
	@param targetId string -- The id attribute to match
	@return { Instance } -- All matching instances (may be empty)
]=]
function TargetingController:FindAllByTypeAndId(targetType: string, targetId: string): { Instance }
	return self._TargetIndexService:FindAllByTypeAndId(targetType, targetId)
end

--[=[
	Returns the first indexed instance carrying the given CollectionService tag, in insertion order.
	@within TargetingController
	@param tag string -- The CollectionService tag to search for
	@return Instance? -- The first matching instance, or `nil` if none found
]=]
function TargetingController:FindFirstByTag(tag: string): Instance?
	return self._TargetIndexService:FindFirstByTag(tag)
end

--[=[
	Returns all indexed instances carrying the given CollectionService tag, in insertion order.
	@within TargetingController
	@param tag string -- The CollectionService tag to search for
	@return { Instance } -- All matching instances (may be empty)
]=]
function TargetingController:FindAllByTag(tag: string): { Instance }
	return self._TargetIndexService:FindAllByTag(tag)
end

--[=[
	Returns all indexed instances whose tags include at least one tag starting with `prefix`.
	@within TargetingController
	@param prefix string -- The tag prefix to match against
	@return { Instance } -- All matching instances (may be empty)
]=]
function TargetingController:FindAllByTagPrefix(prefix: string): { Instance }
	return self._TargetIndexService:FindAllByTagPrefix(prefix)
end

--[=[
	Returns the first indexed instance whose attribute `attributeName` equals `attributeValue`.
	@within TargetingController
	@param attributeName string -- The Roblox attribute name to inspect
	@param attributeValue any -- The value to match
	@return Instance? -- The first matching instance, or `nil` if none found
]=]
function TargetingController:FindFirstByAttribute(attributeName: string, attributeValue: any): Instance?
	return self._TargetIndexService:FindFirstByAttribute(attributeName, attributeValue)
end

--[=[
	Returns all indexed instances whose attribute `attributeName` equals `attributeValue`.
	@within TargetingController
	@param attributeName string -- The Roblox attribute name to inspect
	@param attributeValue any -- The value to match
	@return { Instance } -- All matching instances (may be empty)
]=]
function TargetingController:FindAllByAttribute(attributeName: string, attributeValue: any): { Instance }
	return self._TargetIndexService:FindAllByAttribute(attributeName, attributeValue)
end

return TargetingController
