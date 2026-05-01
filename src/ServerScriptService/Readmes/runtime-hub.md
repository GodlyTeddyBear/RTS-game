# Runtime Hub

Runtime code under `Infrastructure/Runtime/` is context-owned support code.

It is not a shared mini-context and it is not a second owner of actor behavior. The owning bounded context still owns the runtime policy. `Runtime/` only gives that context a clean place to keep profile and resolver modules out of adapters and sync services.

## Core Rule

Use this split inside a context-owned `Infrastructure/Runtime/` folder:

- `Runtime/Profiles/` for variant selection and projection policy
- `Runtime/Resolvers/` for adapter-built callback factories and service proxies

The owning context still owns:

- the adapter service
- the behavior definitions and executor packages it registers
- the runtime profiles
- the resolver factories
- the entity and instance lifecycle

The shared runtime system does not own any of those.

## Ownership

`Profiles/` owns:

- `GetByVariant(...)`
- `ResolveAnimationState(...)`
- context-specific fallback policy
- runtime profile construction data
- table-driven action and animation mapping
- tick-interval or runtime-timing policy when it varies by context variant

`Resolvers/` owns:

- `Create(dependencies)`
- hit target resolution
- projectile, melee, targeting, and proxy helpers
- callback tables that would otherwise bloat adapter files

Adapters and sync services consume the runtime hub. They do not own profile policy or resolver implementation details.

## Action Flow

```text
Owning context creates or loads an entity
  -> adapter resolves the runtime profile from Runtime/Profiles
  -> adapter resolves proxy and callback helpers from Runtime/Resolvers
  -> adapter registers the actor with the shared runtime
  -> shared runtime evaluates the actor each frame
  -> sync service reads resulting action state
  -> sync service uses Runtime/Profiles to resolve projected animation state
```

## Constraints

- Do not place context adapters under `Runtime/`.
- Do not place behavior-tree definitions under a shared runtime service layer when they are actor-family specific.
- Do not let `Runtime/Profiles/` mutate ECS or create instances.
- Do not let `Runtime/Resolvers/` become orchestration services.
- Do not duplicate profile-selection logic inside adapters once `Runtime/Profiles/` already owns it.
- Do not duplicate callback-construction logic inside adapters once `Runtime/Resolvers/` already owns it.

## Layout

```text
Infrastructure/
  Runtime/
    Profiles/
    Resolvers/
  Persistence/
  Services/
```

## Placement Rule

Use this test:

- If the module decides variant behavior or projected animation state, it belongs in `Runtime/Profiles/`.
- If the module builds proxies or callback helpers for runtime execution, it belongs in `Runtime/Resolvers/`.
- If the module registers actors with a shared runtime, it belongs in `Services/` as a context-owned adapter.
- If the module owns generic frame execution or actor bookkeeping across contexts, it belongs in the shared runtime context, not here.
