--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)

local BuildingSyncClient = require(script.Parent.Infrastructure.BuildingSyncClient)

--[=[
	@class BuildingController
	Client-side controller managing buildings state, sync, and mutations.
	@client
]=]
local BuildingController = Knit.CreateController({
	Name = "BuildingController",
})

function BuildingController:KnitInit()
	local registry = Registry.new("Client")
	self.Registry = registry

	self.BuildingSyncClient = BuildingSyncClient.new()
	registry:Register("BuildingSyncClient", self.BuildingSyncClient, "Infrastructure")

	registry:InitAll()
end

function BuildingController:KnitStart()
	local registry = self.Registry

	local BuildingContext = Knit.GetService("BuildingContext")
	registry:Register("BuildingContext", BuildingContext)
	self.BuildingContext = BuildingContext

	registry:StartOrdered({ "Infrastructure" })

	-- Request initial buildings state with a small delay to allow context initialization
	task.delay(0.3, function()
		self:RequestBuildingsState()
	end)
end

--[=[
	Retrieves the buildings atom for subscription in UI components.
	@within BuildingController
	@return Charm.Atom -- The reactive buildings state atom
]=]
function BuildingController:GetBuildingsAtom()
	return self.BuildingSyncClient:GetBuildingsAtom()
end

--[=[
	Requests fresh buildings state from the server and syncs the atom.
	@within BuildingController
	@return Result<{ [string]: any }> -- The updated buildings data
	@yields
]=]
function BuildingController:RequestBuildingsState()
	return self.BuildingContext:GetBuildings()
		:andThen(function(buildings)
			local atom = self.BuildingSyncClient:GetBuildingsAtom()
			atom(buildings or {})
		end)
		:catch(function(err)
			warn("[BuildingController:RequestBuildingsState]", err.type, err.message)
		end)
end

--[=[
	Constructs a new building in a zone slot.
	@within BuildingController
	@param zoneName string -- The zone where the building will be placed
	@param slotIndex number -- The slot index in the zone
	@param buildingType string -- The type of building to construct
	@return Result<any> -- Success status of the construction request
	@yields
]=]
function BuildingController:ConstructBuilding(zoneName: string, slotIndex: number, buildingType: string)
	return self.BuildingContext:ConstructBuilding(zoneName, slotIndex, buildingType)
		:catch(function(err)
			warn("[BuildingController:ConstructBuilding]", err.type, err.message)
		end)
end

--[=[
	Upgrades a building to the next level.
	@within BuildingController
	@param zoneName string -- The zone containing the building
	@param slotIndex number -- The slot index of the building
	@return Result<any> -- Success status of the upgrade request
	@yields
]=]
function BuildingController:UpgradeBuilding(zoneName: string, slotIndex: number)
	return self.BuildingContext:UpgradeBuilding(zoneName, slotIndex)
		:catch(function(err)
			warn("[BuildingController:UpgradeBuilding]", err.type, err.message)
		end)
end

return BuildingController
