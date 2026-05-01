--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spec = require(ReplicatedStorage.Utilities.Specification)

export type TFactorySurfaceCandidate = {
	SurfaceName: string,
	SurfaceValue: any,
}

export type TResolvableFactoryMethodCandidate = {
	MethodName: string,
	MethodValue: any,
	SurfaceName: string,
}

local HasSupportedFactorySurfaceType = Spec.new(
	"InvalidFactorySurface",
	"AiAdapterFactory factory surface must be a method-name string or function",
	function(candidate: TFactorySurfaceCandidate): boolean
		local surfaceType = type(candidate.SurfaceValue)
		return surfaceType == "string" or surfaceType == "function"
	end
)

local HasResolvableFactoryMethod = Spec.new(
	"MissingFactoryMethod",
	"AiAdapterFactory factory method must resolve to a function",
	function(candidate: TResolvableFactoryMethodCandidate): boolean
		return type(candidate.MethodValue) == "function"
	end
)

return table.freeze({
	HasSupportedFactorySurfaceType = HasSupportedFactorySurfaceType,
	HasResolvableFactoryMethod = HasResolvableFactoryMethod,
})
