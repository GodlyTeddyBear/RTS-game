local LoadPackage = require("../Utility/LoadPackage")

local loadAnimPackage = Instance.new("RemoteFunction")
loadAnimPackage.Name = "LoadAnimPackage"
loadAnimPackage.Parent = script.Parent
script.Parent = loadAnimPackage

loadAnimPackage.OnServerInvoke = LoadPackage.getPlayerAnimPackage