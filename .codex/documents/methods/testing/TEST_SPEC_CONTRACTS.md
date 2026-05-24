# Test Spec Contracts

Defines the required structure for repository test spec files.

Canonical references:
- [../../HARNESS_PRINCIPLES.md](../../HARNESS_PRINCIPLES.md)
- [../../coding-style/CODING_STYLE_GUIDE.md](../../coding-style/CODING_STYLE_GUIDE.md)

---

## Core Rules

- Test spec files must be named `*.spec.lua`.
- Each spec file must return a single function from the module body.
- The returned function must register the spec cases with `describe(...)`, `beforeEach(...)`, `afterEach(...)`, and `it(...)` as needed.
- Keep subject setup, test doubles, and cleanup inside the returned function or local helpers it calls.
- Keep top-level module scope limited to `require` statements, constants, and helper functions.
- Use `--!strict` at the top of the file when the spec module participates in typed code.
- Keep each `it(...)` block focused on one behavior or one failure path.

---

## File Shape

- The module must return a function and nothing else.
- The returned function must own all test registration.
- Shared setup that applies to every case belongs in `beforeEach(...)` or local helpers.
- Shared teardown that applies to every case belongs in `afterEach(...)` or local helpers.
- Test helpers should stay local to the spec file unless the same helper already exists in a canonical shared test utility.

---

## Examples

```lua
-- Correct
--!strict

local ServerStorage = game:GetService("ServerStorage")

local TeamService = require(ServerStorage.Utilities.TeamService)

return function()
	describe("TeamService", function()
		it("registers teams", function()
			local manager = TeamService.new()

			expect(manager).never.toBeNil()
		end)
	end)
end
```

```lua
-- Wrong
--!strict

local ServerStorage = game:GetService("ServerStorage")
local TeamService = require(ServerStorage.Utilities.TeamService)

describe("TeamService", function()
	it("registers teams", function()
		local manager = TeamService.new()
		expect(manager).never.toBeNil()
	end)
end)

return {
	run = true,
}
```

---

## Prohibitions

- Do not return a table, boolean, or constructor from a spec module.
- Do not register tests at top level outside the returned function.
- Do not put assertions at module scope.
- Do not leave mutable shared state outside the returned function when the spec can own it locally.
- Do not mix production code paths into a spec file.

---

## Failure Signals

- `require(<spec module>)` returns anything other than a function.
- `describe(...)` or `it(...)` runs before the spec module function is invoked.
- One test changes state that the next test observes without an explicit reset.
- The spec file needs an external wrapper to register or execute its tests.

---

## Checklist

- [ ] The spec file name ends with `.spec.lua`.
- [ ] The module returns exactly one function.
- [ ] All `describe(...)` and `it(...)` calls are inside the returned function.
- [ ] All mutable test state is owned locally or reset in hooks.
- [ ] Assertions live inside test cases, not at module scope.
- [ ] Top-level code is limited to imports, constants, and helper definitions.

