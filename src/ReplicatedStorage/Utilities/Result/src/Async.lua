--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)

local Async = {}

local Core = require(script.Parent.Core)

function Async.Apply(Result: any)
	--[=[
		Runs a yielding function and resolves with a timeout `Err` if it takes too long.
		@within Result
	]=]
	function Result.timeout(fn: () -> Core.Result<any>, seconds: number, errType: string?): any
		return Promise.race({
			Promise.new(function(resolve)
				resolve(fn())
			end),
			Promise.delay(seconds):andThen(function()
				return Promise.resolve(Result.Err(errType or "Timeout", "Operation exceeded " .. seconds .. "s"))
			end),
		})
	end

	--[=[
		Runs yielding functions concurrently and resolves with the first Result.
		@within Result
	]=]
	function Result.race(fns: { () -> Core.Result<any> }): any
		local promises = table.create(#fns)
		for i, fn in fns do
			promises[i] = Promise.new(function(resolve)
				resolve(fn())
			end)
		end
		return Promise.race(promises)
	end

	--[=[
		Runs yielding functions concurrently and resolves with all Results.
		@within Result
	]=]
	function Result.all(fns: { () -> Core.Result<any> }): any
		return Promise.new(function(resolve)
			local count = #fns
			local results: { any } = table.create(count)
			local completed = 0

			for i, fn in fns do
				task.spawn(function()
					results[i] = fn()
					completed += 1
					if completed == count then
						resolve(Result.Ok(results))
					end
				end)
			end
		end)
	end
end

return Async
