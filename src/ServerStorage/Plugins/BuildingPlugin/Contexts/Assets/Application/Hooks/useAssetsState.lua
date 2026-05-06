--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local AssetsAtom = require(script.Parent.Parent.Parent.Infrastructure.AssetsAtom)

local function useAssetsState()
	return ReactCharm.useAtom(AssetsAtom.GetAtom())
end

return useAssetsState
