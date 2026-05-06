--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local AppAtom = require(script.Parent.Parent.Parent.Infrastructure.AppAtom)

local function useAppState()
	return ReactCharm.useAtom(AppAtom.GetAtom())
end

return useAppState
