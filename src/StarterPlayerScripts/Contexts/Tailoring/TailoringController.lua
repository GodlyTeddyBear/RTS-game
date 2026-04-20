--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)

local TailoringController = Knit.CreateController({
	Name = "TailoringController",
})

---
-- Knit Lifecycle
---

function TailoringController:KnitInit()
	local registry = Registry.new("Client")
	self.Registry = registry

	registry:InitAll()
end

function TailoringController:KnitStart()
	local registry = self.Registry

	-- Resolve cross-context dependencies
	local TailoringContext = Knit.GetService("TailoringContext")
	registry:Register("TailoringContext", TailoringContext)

	self.TailoringContext = TailoringContext
end

---
-- Public API Methods
---

--- Tailor an item by recipe ID
function TailoringController:TailItem(recipeId: string)
	return self.TailoringContext:TailItem(recipeId)
		:catch(function(err)
			warn("[TailoringController:TailItem]", err.type, err.message)
		end)
end

--- Get all available tailoring recipes from the server
function TailoringController:GetTailoringRecipes()
	return self.TailoringContext:GetTailoringRecipes()
		:catch(function(err)
			warn("[TailoringController:GetTailoringRecipes]", err.type, err.message)
		end)
end

return TailoringController
