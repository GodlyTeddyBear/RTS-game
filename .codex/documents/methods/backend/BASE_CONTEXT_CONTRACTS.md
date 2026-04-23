# BaseContext Contracts

Method contracts for creating or migrating backend context entry modules with `BaseContext`.

Canonical architecture references:
- [../../architecture/backend/DDD.md](../../architecture/backend/DDD.md)
- [../../architecture/backend/ERROR_HANDLING.md](../../architecture/backend/ERROR_HANDLING.md)
- [CONTEXT_BOUNDARIES.md](CONTEXT_BOUNDARIES.md)
- [DEPENDENCY_REGISTRATION_CONTRACTS.md](DEPENDENCY_REGISTRATION_CONTRACTS.md)

---

## Core Rules

- Use `ReplicatedStorage.Utilities.BaseContext` for new backend context entry modules.
- Import BaseContext config and wrapper types from the public module path, such as `BaseContext.TModuleSpec`, `BaseContext.TModuleLayers`, and `BaseContext.TBaseContext`.
- Create one BaseContext wrapper per Knit service with `BaseContext.new(<ContextService>)`.
- Place the wrapper after the `Knit.CreateService(...)` service table and before lifecycle methods.
- Name module-level BaseContext config values with PascalCase.
- Delegate `KnitInit` to the BaseContext wrapper before context-specific init logging.
- Delegate `KnitStart` to the BaseContext wrapper before context-specific start logging.
- Declare context-owned modules on the service table with `Modules.Infrastructure`, `Modules.Domain`, and `Modules.Application`.
- Register only context-owned modules through `Modules`; use `ExternalServices` or `ExternalDependencies` for cross-context values.
- Use `Cache` or module `CacheAs` for service fields that public context methods, lifecycle handlers, or event handlers need.
- Keep public context methods bridge-only and preserve the Result contracts in [CONTEXT_BOUNDARIES.md](CONTEXT_BOUNDARIES.md).

---

## Service Configuration

- `Modules` owns context-local registry entries.
- `WorldService` is only for a context-owned JECS world service that also registers the raw `World` handle.
- `Cache` copies registry values or derived method results onto the Knit service table.
- `ExternalServices` resolves other Knit services during `KnitStart`.
- `ExternalDependencies` resolves values from already registered services during `KnitStart`; the source method must return a `Result`.
- `StartOrder` overrides registry start order and may contain only known layer names.
- `ProfileLifecycle` wires persistence loader, load, save, removing, and backfill behavior.
- `Teardown` declares cleanup hooks and fields for `baseContext:Destroy()`.

---

## Module Specs

- Every module spec must define `Name`.
- Every module spec must define exactly one source: `Module`, `Factory`, or `Instance`.
- Use `Module` when a module can be constructed with `.new(table.unpack(Args or {}))` or registered as-is.
- Use `Factory` when construction needs registry dependencies, service fields, or the BaseContext wrapper.
- Use `Instance` only for a prebuilt object that should be registered directly.
- Use `Category` only when the registry category must differ from the declared layer.
- Use `CacheAs` when the constructed module should also be assigned to a service field.
- Use `Args` only with `Module` sources that expose `.new(...)`.
- Type each layer array as `{ BaseContext.TModuleSpec }` before composing `BaseContext.TModuleLayers`.
- Do not rely on Luau to infer heterogeneous module spec arrays from the first entry.

---

## Examples

```lua
-- Correct: context-owned services and queries are declared on the service table.
local BaseContext = require(ReplicatedStorage.Utilities.BaseContext)

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "ExampleRuntimeService",
		Module = ExampleRuntimeService,
		CacheAs = "_runtimeService",
	},
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	{
		Name = "GetExampleQuery",
		Factory = function(_service, baseContext)
			local registry = baseContext:GetRegistry()
			return GetExampleQuery.new(registry:Get("ExampleRuntimeService"))
		end,
		CacheAs = "_getExampleQuery",
	},
}

local ExampleModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
	Application = ApplicationModules,
}

local ExampleContext = Knit.CreateService({
	Name = "ExampleContext",
	Client = {},
	Modules = ExampleModules,
})

local ExampleBaseContext = BaseContext.new(ExampleContext)

function ExampleContext:KnitInit()
	ExampleBaseContext:KnitInit()
end

function ExampleContext:KnitStart()
	ExampleBaseContext:KnitStart()
end
```

```lua
-- Wrong: the nested arrays may infer the first entry's shape too narrowly.
local ExampleModules: BaseContext.TModuleLayers = {
	Infrastructure = {
		{
			Name = "ExampleRuntimeService",
			Module = ExampleRuntimeService,
		},
		{
			Name = "ExampleOtherService",
			Module = ExampleOtherService,
			CacheAs = "_otherService",
		},
	},
}
```

```lua
-- Wrong: direct Registry and WrapContext setup duplicates BaseContext ownership.
local registry = Registry.new("Server")
registry:Register("ExampleRuntimeService", ExampleRuntimeService.new(), "Infrastructure")
registry:InitAll()
WrapContext(ExampleContext, "Example")
```

---

## Prohibitions

- Do not call `Registry.new(...)` directly in a context that uses `BaseContext`.
- Do not call `WrapContext(...)` directly in a context that uses `BaseContext`.
- Do not register cross-context Knit services in `Modules`.
- Do not resolve cross-context services in `KnitInit`.
- Do not use a `Factory` to run business logic or perform runtime mutations.
- Do not cache every module by default; cache only fields needed by public methods, lifecycle handlers, or event handlers.
- Do not expose the registry through public context methods.
- Do not create local duplicate module-spec types when BaseContext exports the contract type.

---

## Failure Signals

- A BaseContext-backed context still imports `Registry` or `WrapContext`.
- `KnitInit` manually registers modules instead of delegating to `baseContext:KnitInit()`.
- `KnitStart` resolves external dependencies before `baseContext:KnitStart()` without a documented reason.
- A module spec defines more than one of `Module`, `Factory`, or `Instance`.
- A second or later module spec entry has a type error because the layer array was not annotated as `{ BaseContext.TModuleSpec }`.
- A BaseContext wrapper call such as `ContextBase:KnitInit()` has a type error because `BaseContext.new` does not return `BaseContext.TBaseContext`.
- A context method fails because a required `_field` was never declared with `Cache` or `CacheAs`.
- A cross-context dependency is unavailable because it was declared in `Modules` instead of `ExternalServices` or `ExternalDependencies`.

---

## Checklist

- [ ] Service requires `ReplicatedStorage.Utilities.BaseContext`.
- [ ] Service module config uses BaseContext-exported types instead of local duplicate spec types.
- [ ] Layer arrays are typed as `{ BaseContext.TModuleSpec }`.
- [ ] Composed module config is typed as `BaseContext.TModuleLayers`.
- [ ] Exactly one `BaseContext.new(<ContextService>)` wrapper exists.
- [ ] BaseContext wrapper variable is PascalCase at module scope.
- [ ] `KnitInit` delegates to the BaseContext wrapper.
- [ ] `KnitStart` delegates to the BaseContext wrapper.
- [ ] Context-owned modules are declared under the correct `Modules` layer.
- [ ] Module specs use exactly one of `Module`, `Factory`, or `Instance`.
- [ ] Public method dependencies are cached with `Cache` or `CacheAs`.
- [ ] Cross-context dependencies are declared with `ExternalServices` or `ExternalDependencies`.
- [ ] Direct `Registry.new(...)` and `WrapContext(...)` calls are absent.
- [ ] Public context methods still satisfy [CONTEXT_BOUNDARIES.md](CONTEXT_BOUNDARIES.md).
