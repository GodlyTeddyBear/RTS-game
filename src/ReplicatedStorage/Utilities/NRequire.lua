local ReplicatedStorage = game:GetService("ReplicatedStorage")

type TNRequire = (request: string | ModuleScript) -> any

local cachedNevermoreRequire: TNRequire? = nil

local function _ResolveNRequire(): TNRequire
	if cachedNevermoreRequire then
		return cachedNevermoreRequire
	end

	local nevermoreFolder = ReplicatedStorage:WaitForChild("Nevermore")
	local nevermoreLoaderModule = nevermoreFolder:WaitForChild("loader") :: ModuleScript
	local nevermoreLoader = require(nevermoreLoaderModule)
	local nevermoreRequire = nevermoreLoader.load(nevermoreFolder)

	cachedNevermoreRequire = nevermoreRequire
	return nevermoreRequire
end

local function NRequire(request: string | ModuleScript): any
	return _ResolveNRequire()(request)
end

return NRequire
