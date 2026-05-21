--!strict

--[=[
	@class MuchachoHitbox
	Shared facade for scheduler-driven hitbox instances and runners.
	High-level callers should require this file; low-level behavior lives under `src/`.
	@server
	@client
]=]

local MuchachoHitbox = require(script.src)

return MuchachoHitbox
