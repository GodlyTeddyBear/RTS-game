--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local RenderRegistryClientService = require(script.Parent.Infrastructure.Services.RenderRegistryClientService)
local RenderProfileService = require(script.Parent.Infrastructure.Services.RenderProfileService)
local RenderVisualReplacementService = require(script.Parent.Infrastructure.Services.RenderVisualReplacementService)

local RenderController = Knit.CreateController({
	Name = "RenderController",
})

function RenderController:KnitInit()
	self._renderRegistryClientService = RenderRegistryClientService.new()
	self._renderProfileService = RenderProfileService.new(self._renderRegistryClientService)
	self._renderVisualReplacementService = RenderVisualReplacementService.new(self._renderRegistryClientService)
end

function RenderController:KnitStart()
	self._renderRegistryClientService:Start()
	self._renderProfileService:Start()
	self._renderVisualReplacementService:Start()
end

function RenderController:Destroy()
	if self._renderProfileService == nil then
		if self._renderVisualReplacementService ~= nil then
			self._renderVisualReplacementService:Destroy()
			self._renderVisualReplacementService = nil
		end
		if self._renderRegistryClientService ~= nil then
			self._renderRegistryClientService:Destroy()
			self._renderRegistryClientService = nil
		end
		return
	end

	self._renderProfileService:Destroy()
	self._renderProfileService = nil

	if self._renderVisualReplacementService ~= nil then
		self._renderVisualReplacementService:Destroy()
		self._renderVisualReplacementService = nil
	end

	if self._renderRegistryClientService ~= nil then
		self._renderRegistryClientService:Destroy()
		self._renderRegistryClientService = nil
	end
end

return RenderController
