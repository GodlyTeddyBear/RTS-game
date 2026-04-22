if not game:IsLoaded() then
	game.Loaded:Wait()
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NevermoreFolder = ReplicatedStorage:WaitForChild("Nevermore")
local NevermoreLoader = NevermoreFolder:WaitForChild("loader") :: ModuleScript
require(NevermoreLoader).bootstrapGame(NevermoreFolder)

local Knit = require(ReplicatedStorage.Packages.Knit)

local Contexts: Folder = script.Parent.Contexts

for _, context in ipairs(Contexts:GetChildren()) do
	task.wait()
	if context:FindFirstChildOfClass("ModuleScript") then
		Knit.AddControllers(context)
	end
end

Knit.Start():catch(warn)

local StarterGui = game:GetService("StarterGui")
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
