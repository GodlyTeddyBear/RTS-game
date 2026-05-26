--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local EntityPhases = require(ReplicatedStorage.Contexts.Entity.Config.EntityPhases)
local Errors = require(script.Parent.Parent.Parent.Errors)

type TSystemSpec = {
	Name: string,
	Phase: string,
	Factory: (entityFactory: any, compiledSchemas: any) -> any,
	Reads: { string }?,
	Writes: { string }?,
}

local EntitySystemRegistry = {}
EntitySystemRegistry.__index = EntitySystemRegistry

function EntitySystemRegistry.new()
	local systemsByPhase = {}
	local knownPhases = {}

	for _, phaseName in ipairs(EntityPhases.Ordered) do
		systemsByPhase[phaseName] = {}
		knownPhases[phaseName] = true
	end

	local self = setmetatable({}, EntitySystemRegistry)
	self._entityFactory = nil
	self._isRegistrationClosed = false
	self._schemaRegistry = nil
	self._knownPhases = knownPhases
	self._orderedPhases = EntityPhases.Ordered
	self._systemsByPhase = systemsByPhase
	self._systemsByName = {}
	return self
end

function EntitySystemRegistry:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("EntityEntityFactory")
	self._schemaRegistry = registry:Get("EntitySchemaRegistry")
end

function EntitySystemRegistry:RegisterSystem(phaseName: string, systemSpec: TSystemSpec): Result.Result<boolean>
	return Result.Catch(function()
		if self._isRegistrationClosed then
			return Result.Err("InvalidSystem", Errors.INVALID_SYSTEM, {
				PhaseName = phaseName,
				Reason = "RegistrationClosed",
			})
		end

		if self._knownPhases[phaseName] ~= true then
			return Result.Err("UnknownPhase", Errors.UNKNOWN_PHASE, {
				PhaseName = phaseName,
			})
		end

		if type(systemSpec) ~= "table" then
			return Result.Err("InvalidSystem", Errors.INVALID_SYSTEM, {
				PhaseName = phaseName,
			})
		end

		if type(systemSpec.Name) ~= "string" or systemSpec.Name == "" or type(systemSpec.Factory) ~= "function" then
			return Result.Err("InvalidSystem", Errors.INVALID_SYSTEM, {
				PhaseName = phaseName,
				SystemName = systemSpec.Name,
			})
		end

		if self._systemsByName[systemSpec.Name] ~= nil then
			return Result.Err("DuplicateSystem", Errors.DUPLICATE_SYSTEM, {
				PhaseName = phaseName,
				SystemName = systemSpec.Name,
			})
		end

		local runner = systemSpec.Factory(self._entityFactory, self._schemaRegistry:GetCompiledSchemas())
		if type(runner) ~= "function" and not (type(runner) == "table" and type(runner.Run) == "function") then
			return Result.Err("InvalidSystem", Errors.INVALID_SYSTEM, {
				PhaseName = phaseName,
				SystemName = systemSpec.Name,
				Reason = "FactoryDidNotReturnRunner",
			})
		end

		local compiledSystem = table.freeze({
			Name = systemSpec.Name,
			Phase = phaseName,
			Reads = table.freeze(table.clone(systemSpec.Reads or {})),
			Writes = table.freeze(table.clone(systemSpec.Writes or {})),
			Runner = runner,
		})
		table.insert(self._systemsByPhase[phaseName], compiledSystem)
		self._systemsByName[systemSpec.Name] = compiledSystem
		return Result.Ok(true)
	end, "EntitySystemRegistry:RegisterSystem")
end

function EntitySystemRegistry:GetRegisteredSystems(phaseName: string): { any }
	return self._systemsByPhase[phaseName] or {}
end

function EntitySystemRegistry:CloseRegistration(): Result.Result<boolean>
	return Result.Catch(function()
		self._isRegistrationClosed = true
		return Result.Ok(true)
	end, "EntitySystemRegistry:CloseRegistration")
end

function EntitySystemRegistry:ValidateReady(): Result.Result<boolean>
	if not self._isRegistrationClosed then
		return Result.Err("InvalidSystem", Errors.INVALID_SYSTEM, {
			Reason = "RegistrationStillOpen",
		})
	end

	return Result.Ok(true)
end

function EntitySystemRegistry:GetStatus(): any
	local registeredSystemCount = 0
	for _ in pairs(self._systemsByName) do
		registeredSystemCount += 1
	end

	return table.freeze({
		RegistrationClosed = self._isRegistrationClosed,
		KnownPhases = table.freeze(table.clone(self._orderedPhases)),
		RegisteredSystemCount = registeredSystemCount,
	})
end

function EntitySystemRegistry:RunPhase(phaseName: string): Result.Result<boolean>
	return Result.Catch(function()
		if self._knownPhases[phaseName] ~= true then
			return Result.Err("UnknownPhase", Errors.UNKNOWN_PHASE, {
				PhaseName = phaseName,
			})
		end

		for _, compiledSystem in ipairs(self._systemsByPhase[phaseName]) do
			local runner = compiledSystem.Runner
			if type(runner) == "function" then
				runner()
			else
				runner:Run()
			end
		end

		return Result.Ok(true)
	end, "EntitySystemRegistry:RunPhase")
end

function EntitySystemRegistry:RunAllPhases(): Result.Result<boolean>
	return Result.Catch(function()
		for _, phaseName in ipairs(self._orderedPhases) do
			local runResult = self:RunPhase(phaseName)
			if not runResult.success then
				return runResult
			end
		end

		return Result.Ok(true)
	end, "EntitySystemRegistry:RunAllPhases")
end

return EntitySystemRegistry
