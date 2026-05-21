--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableRecycler = require(ReplicatedStorage.Utilities.TableRecycler)

local recycler = TableRecycler.new({
	Strict = true,
	DebugName = "AI.Scratch",
})

local ScratchRecycler = {}

function ScratchRecycler.AcquireArray(capacityHint: number?): { any }
	return recycler:AcquireArray(capacityHint)
end

function ScratchRecycler.AcquireMap(): { [any]: any }
	return recycler:AcquireMap()
end

function ScratchRecycler.ReleaseArray(tbl: { any })
	local didRelease, releaseError = recycler:ReleaseArray(tbl)
	assert(didRelease, releaseError)
end

function ScratchRecycler.ReleaseMap(tbl: { [any]: any })
	local didRelease, releaseError = recycler:ReleaseMap(tbl)
	assert(didRelease, releaseError)
end

return table.freeze(ScratchRecycler)
