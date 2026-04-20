--!strict

--[[
	Specification — Composable eligibility rule objects.

	A Specification encapsulates a single domain eligibility rule as a named,
	reusable, composable object. It answers one question: given current state,
	is this operation permitted to proceed?

	Specs are NOT for:
	  - Data validation (use domain validators + TryAll)
	  - Authorization (use Ensure before loading state)
	  - Invariants (use assert in value objects/constructors)

	INTEGRATION WITH RESULT:
	  IsSatisfiedBy returns Result<T> — a failed spec produces a structured Err
	  that propagates through Try/Catch like any other failure.

	CONSTRUCTION:
	  Specs are module-level constants, constructed once at require time.
	  Never construct a spec inside a function or per-call.

	CANDIDATE:
	  Each spec takes a purpose-built context type containing exactly the state
	  its predicate needs. All specs that compose together must share the same
	  candidate type.

	PRIMITIVES:
	  Spec.new(errType, message, predicate)  → create a spec
	  spec:IsSatisfiedBy(candidate)          → evaluate, returns Result<T>
	  spec:And(other)                        → both must pass (accumulates failures)
	  spec:Or(other)                         → either must pass (short-circuits)
	  spec:Not(errType, message)             → invert with new error info
	  spec:WithData(data)                    → attach context to failure
	  Spec.All({ ... })                      → all must pass (accumulates failures)
	  Spec.Any({ ... })                      → any must pass (short-circuits)

	EXAMPLE:
	  -- QuestSpecs.lua
	  local HasNoActiveExpedition = Spec.new("AlreadyOnExpedition", Errors.ALREADY_ON_EXPEDITION,
	      function(ctx: TQuestDepartureContext)
	          return ctx.QuestState.ActiveExpedition == nil
	      end
	  )

	  local HasEnoughAdventurers = Spec.new("NotEnoughAdventurers", Errors.NOT_ENOUGH_ADVENTURERS,
	      function(ctx: TQuestDepartureContext)
	          return #ctx.GuildState.AvailableAdventurers >= MIN_PARTY_SIZE
	      end
	  )

	  local CanDepartOnQuest = HasNoActiveExpedition:And(HasEnoughAdventurers)

	  -- In DepartOnQuest:Execute, inside a Catch boundary:
	  Try(CanDepartOnQuest:IsSatisfiedBy(context))
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

type Predicate<T> = (candidate: T) -> boolean

--[=[
	@class Specification
	Composable eligibility rule objects that encapsulate domain constraints.
	@server
	@client
]=]

--[=[
	@interface Specification
	@within Specification
	.IsSatisfiedBy (self: Specification<T>, candidate: T) -> Result.Result<T> -- Evaluate the rule
	.And <B>(self: Specification<T>, other: Specification<B>) -> Specification<B> -- Combine with AND logic
	.Or <B>(self: Specification<T>, other: Specification<B>) -> Specification<B> -- Combine with OR logic
	.Not (self: Specification<T>, errType: string, message: string) -> Specification<T> -- Invert the rule
	.WithData (self: Specification<T>, data: { [string]: any }) -> Specification<T> -- Attach context to failures
]=]

export type Specification<T> = {
	IsSatisfiedBy: (self: Specification<T>, candidate: T) -> Result.Result<T>,
	And: <B>(self: Specification<T>, other: Specification<B>) -> Specification<B>,
	Or: <B>(self: Specification<T>, other: Specification<B>) -> Specification<B>,
	Not: (self: Specification<T>, errType: string, message: string) -> Specification<T>,
	WithData: (self: Specification<T>, data: { [string]: any }) -> Specification<T>,
}

-- Shared metatable — methods allocated once, not per instance
local SpecMeta = {}
SpecMeta.__index = SpecMeta

--[=[
	Evaluate whether the specification is satisfied by the given candidate.
	@within Specification
	@param candidate T -- The context object to evaluate
	@return Result.Result<T> -- Ok if satisfied, Err with failure details if not
]=]
function SpecMeta:IsSatisfiedBy(candidate: any): Result.Result<any>
	return self._evaluate(candidate)
end

--[=[
	Combine this specification with another using AND logic.
	Both specs must pass. Failures are accumulated so the caller receives all violations at once.
	@within Specification
	@param other Specification<B> -- The spec to combine with
	@return Specification<B> -- A new composite spec requiring both to pass
]=]
function SpecMeta:And(other: Specification<any>): Specification<any>
	return fromEvaluator(function(candidate)
		return Result.TryAll(
			self:IsSatisfiedBy(candidate),
			other:IsSatisfiedBy(candidate)
		) :: any
	end)
end

--[=[
	Combine this specification with another using OR logic.
	Either spec must pass. Short-circuits on first success; if both fail, returns the second spec's error.
	@within Specification
	@param other Specification<B> -- The spec to combine with
	@return Specification<B> -- A new composite spec requiring at least one to pass
]=]
function SpecMeta:Or(other: Specification<any>): Specification<any>
	return fromEvaluator(function(candidate)
		local result = self:IsSatisfiedBy(candidate)
		if result.success then return result end
		return other:IsSatisfiedBy(candidate)
	end)
end

--[=[
	Invert the specification logic.
	Requires new error info since the original message does not make sense when negated.
	@within Specification
	@param errType string -- Error type for the inverted rule
	@param message string -- Error message for the inverted rule
	@return Specification<T> -- A new spec with inverted logic
]=]
function SpecMeta:Not(errType: string, message: string): Specification<any>
	return fromEvaluator(function(candidate)
		if not self:IsSatisfiedBy(candidate).success then
			return Result.Ok(candidate)
		end
		return Result.Err(errType, message)
	end)
end

--[=[
	Attach contextual data to failure results.
	The predicate is unchanged — only the Err payload is extended. Useful when the spec is generic but the call site has specific context to surface (e.g. `{ has = playerGold, needs = cost }`).
	@within Specification
	@param data { [string]: any } -- Context data to attach on failure
	@return Specification<T> -- A new spec that includes data in its Err payload
]=]
function SpecMeta:WithData(data: { [string]: any }): Specification<any>
	return fromEvaluator(function(candidate)
		local result = self:IsSatisfiedBy(candidate)
		if result.success then return result end
		local err = (result :: any) :: Result.Err
		return Result.Err(err.type, err.message, data)
	end)
end

-- Internal constructor — builds a Specification from a raw evaluate function.
-- All public constructors (new, And, Or, Not, All, Any) produce specs via this.
function fromEvaluator<T>(evaluate: (candidate: T) -> Result.Result<T>): Specification<T>
	return setmetatable({ _evaluate = evaluate }, SpecMeta) :: any
end

--[=[
	@class Spec
	Constructor functions for composable eligibility specifications.
	@server
	@client
]=]

local Spec = {}

--[=[
	Create a Specification from a predicate function.
	The predicate returns true if the rule is satisfied, false otherwise.
	Construct specs as module-level constants — never inside functions or per-call.
	@within Spec
	@param errType string -- Error type when predicate returns false
	@param message string -- Error message when predicate returns false
	@param predicate function -- Predicate function returning boolean
	@return Specification<T> -- A new specification
]=]
function Spec.new<T>(errType: string, message: string, predicate: Predicate<T>): Specification<T>
	return fromEvaluator(function(candidate: T)
		if predicate(candidate) then
			return Result.Ok(candidate)
		end
		return Result.Err(errType, message)
	end)
end

--[=[
	Combine multiple specifications with AND logic.
	All specs must pass. Failures are accumulated so the caller receives every violation at once.
	Equivalent to chaining `:And()` across the list.
	@within Spec
	@param specs { Specification<T> } -- Array of specifications to combine
	@return Specification<T> -- A new spec requiring all to pass
]=]
function Spec.All<T>(specs: { Specification<T> }): Specification<T>
	return fromEvaluator(function(candidate: T)
		local results = {}
		for _, spec in ipairs(specs) do
			table.insert(results, spec:IsSatisfiedBy(candidate))
		end
		return Result.TryAll(table.unpack(results)) :: any
	end)
end

--[=[
	Combine multiple specifications with OR logic.
	Any spec must pass. Short-circuits on first success; if all fail, returns the last spec's error.
	@within Spec
	@param specs { Specification<T> } -- Array of specifications to combine
	@return Specification<T> -- A new spec requiring at least one to pass
]=]
function Spec.Any<T>(specs: { Specification<T> }): Specification<T>
	return fromEvaluator(function(candidate: T)
		local lastResult: Result.Result<T> = Result.Err("NoneSatisfied", "No specifications were satisfied")
		for _, spec in ipairs(specs) do
			local result = spec:IsSatisfiedBy(candidate)
			if result.success then return result end
			lastResult = result
		end
		return lastResult
	end)
end

return table.freeze(Spec)
