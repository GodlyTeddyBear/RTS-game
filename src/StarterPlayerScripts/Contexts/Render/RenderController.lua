--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local RenderProfileService = require(script.Parent.Infrastructure.Services.RenderProfileService)

local RenderController = Knit.CreateController({
	Name = "RenderController",
})

function RenderController:KnitInit()
	self._renderProfileService = RenderProfileService.new()
end

function RenderController:KnitStart()
	self._renderProfileService:Start()
end

function RenderController:Destroy()
	if self._renderProfileService == nil then
		return
	end

	self._renderProfileService:Destroy()
	self._renderProfileService = nil
end

return RenderController
