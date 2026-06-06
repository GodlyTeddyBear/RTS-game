--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

local EntityRuntimeAssetResolverService = {}
EntityRuntimeAssetResolverService.__index = EntityRuntimeAssetResolverService

function EntityRuntimeAssetResolverService.new()
	local self = setmetatable({}, EntityRuntimeAssetResolverService)
	self._renderContext = nil
	return self
end

function EntityRuntimeAssetResolverService:Start(registry: any, _name: string)
	self._renderContext = registry:Get("RenderContext")
	assert(self._renderContext ~= nil, "EntityRuntimeAssetResolverService missing RenderContext in Start")
end

function EntityRuntimeAssetResolverService:ResolveAsset(modelAsset: any): Result.Result<Instance>
	return Result.Catch(function()
		local assetKind = if type(modelAsset) == "table" then modelAsset.AssetKind else nil
		local assetDomain = if type(modelAsset) == "table" then modelAsset.AssetDomain else nil
		local assetId = if type(modelAsset) == "table" then modelAsset.AssetId else nil

		if assetKind ~= "Model" or type(assetDomain) ~= "string" or assetDomain == "" or type(assetId) ~= "string" or assetId == "" then
			return Result.Err("UnsupportedBindingAsset", Errors.UNSUPPORTED_BINDING_ASSET, {
				AssetKind = assetKind,
				AssetDomain = assetDomain,
				AssetId = assetId,
			})
		end

		local familyId = self:_ResolveRenderFamilyId(assetDomain)
		if familyId == nil then
			return Result.Err("UnsupportedBindingAsset", Errors.UNSUPPORTED_BINDING_ASSET, {
				AssetKind = assetKind,
				AssetDomain = assetDomain,
				AssetId = assetId,
			})
		end

		local resolveResult = self._renderContext:ResolveAsset(familyId, assetId, nil)
		local resolvedPayload = if resolveResult.success and type(resolveResult.value) == "table" then resolveResult.value else nil
		local resolvedInstance = if resolvedPayload ~= nil then resolvedPayload.Value else nil
		if not resolveResult.success or typeof(resolvedInstance) ~= "Instance" then
			return Result.Err("UnsupportedBindingAsset", Errors.UNSUPPORTED_BINDING_ASSET, {
				AssetKind = assetKind,
				AssetDomain = assetDomain,
				AssetId = assetId,
				FamilyId = familyId,
				CauseType = resolveResult.type,
				CauseMessage = resolveResult.message,
			})
		end

		return Result.Ok(resolvedInstance)
	end, "EntityRuntimeAssetResolverService:ResolveAsset")
end

function EntityRuntimeAssetResolverService:_ResolveRenderFamilyId(assetDomain: string): string?
	if assetDomain == "Enemies" then
		return "EnemyModel"
	end
	if assetDomain == "Units" then
		return "UnitModel"
	end
	if assetDomain == "Structures" then
		return "StructureModel"
	end
	return nil
end

return EntityRuntimeAssetResolverService
