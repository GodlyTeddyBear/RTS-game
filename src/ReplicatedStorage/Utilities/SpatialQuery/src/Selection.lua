--!strict

local Shared = require(script.Parent.Shared)
local Queries = require(script.Parent.Queries)
local Types = require(script.Parent.Types)

type TQueryOptions = Types.TQueryOptions
type TScoredCandidate<T> = Types.TScoredCandidate<T>

--[=[
    @class SpatialQuerySelection
    Higher-level candidate selection helpers built on top of the raw `SpatialQueryQueries` surface.
    @server
    @client
]=]

-- ── Private ───────────────────────────────────────────────────────────────────

local Selection = {}

-- Select the best candidate by score, breaking ties in favor of the closer item.
local function _FindBestScoredCandidate<T>(
	origin: Vector3,
	candidates: { T },
	getPosition: (T) -> Vector3?,
	score: (T, number) -> number?,
	maxRange: number?
): TScoredCandidate<T>?
	local bestCandidate = nil :: TScoredCandidate<T>?
	local maxRangeSquared = nil :: number?
	if maxRange ~= nil then
		if not Shared.IsPositiveNumber(maxRange) then
			return nil
		end
		maxRangeSquared = maxRange * maxRange
	end

	for _, candidate in ipairs(candidates) do
		local candidatePosition = getPosition(candidate)
		if candidatePosition == nil then
			continue
		end

		local distanceSquared = Shared.GetDistanceSquared(origin, candidatePosition)
		if maxRangeSquared ~= nil and distanceSquared > maxRangeSquared then
			continue
		end

		local distance = math.sqrt(distanceSquared)
		local candidateScore = score(candidate, distance)
		if candidateScore == nil then
			continue
		end

		if bestCandidate == nil
			or candidateScore > bestCandidate.Score
			or (candidateScore == bestCandidate.Score and distanceSquared < bestCandidate.DistanceSquared)
		then
			bestCandidate = {
				Candidate = candidate,
				DistanceSquared = distanceSquared,
				Score = candidateScore,
			}
		end
	end

	return bestCandidate
end

-- Reuses the scoring helper for nearest lookups by inverting distance into a score.
local function _FindNearestCandidate<T>(
	origin: Vector3,
	candidates: { T },
	getPosition: (T) -> Vector3?,
	maxRange: number?
): (T?, number?)
	local bestCandidate = _FindBestScoredCandidate(origin, candidates, getPosition, function(_candidate: T, distance: number): number?
		return -distance
	end, maxRange)

	if bestCandidate == nil then
		return nil, nil
	end

	return bestCandidate.Candidate, math.sqrt(bestCandidate.DistanceSquared)
end

-- ── Public ────────────────────────────────────────────────────────────────────

--[=[
    Finds the nearest part to an origin point.
    @within SpatialQuerySelection
    @param origin Vector3 -- Search origin.
    @param parts { BasePart } -- Candidate parts.
    @param maxRange number? -- Optional maximum distance.
    @return BasePart? -- Nearest part, or `nil` when no candidate matches.
    @return number? -- Distance to the returned part.
]=]
function Selection.FindNearestPart(origin: Vector3, parts: { BasePart }, maxRange: number?): (BasePart?, number?)
	return _FindNearestCandidate(origin, parts, function(part: BasePart): Vector3
		return part.Position
	end, maxRange)
end

--[=[
    Finds the nearest position in a list.
    @within SpatialQuerySelection
    @param origin Vector3 -- Search origin.
    @param positions { Vector3 } -- Candidate positions.
    @param maxRange number? -- Optional maximum distance.
    @return number? -- Index of the nearest position.
    @return Vector3? -- Nearest position value.
    @return number? -- Distance to the returned position.
]=]
function Selection.FindNearestPosition(origin: Vector3, positions: { Vector3 }, maxRange: number?): (number?, Vector3?, number?)
	local bestIndex = nil :: number?
	local bestPosition = nil :: Vector3?
	local bestDistanceSquared = math.huge
	local maxRangeSquared = nil :: number?
	if maxRange ~= nil then
		if not Shared.IsPositiveNumber(maxRange) then
			return nil, nil, nil
		end
		maxRangeSquared = maxRange * maxRange
	end

	for index, position in ipairs(positions) do
		local distanceSquared = Shared.GetDistanceSquared(origin, position)
		if maxRangeSquared ~= nil and distanceSquared > maxRangeSquared then
			continue
		end
		if distanceSquared < bestDistanceSquared then
			bestDistanceSquared = distanceSquared
			bestIndex = index
			bestPosition = position
		end
	end

	if bestIndex == nil or bestPosition == nil then
		return nil, nil, nil
	end

	return bestIndex, bestPosition, math.sqrt(bestDistanceSquared)
end

--[=[
    Finds the nearest model to an origin point.
    @within SpatialQuerySelection
    @param origin Vector3 -- Search origin.
    @param models { Model } -- Candidate models.
    @param maxRange number? -- Optional maximum distance.
    @return Model? -- Nearest model, or `nil` when no candidate matches.
    @return number? -- Distance to the returned model.
]=]
function Selection.FindNearestModel(origin: Vector3, models: { Model }, maxRange: number?): (Model?, number?)
	return _FindNearestCandidate(origin, models, Shared.ResolveModelPosition, maxRange)
end

--[=[
    Finds the nearest attachment to an origin point.
    @within SpatialQuerySelection
    @param origin Vector3 -- Search origin.
    @param attachments { Attachment } -- Candidate attachments.
    @param maxRange number? -- Optional maximum distance.
    @return Attachment? -- Nearest attachment, or `nil` when no candidate matches.
    @return number? -- Distance to the returned attachment.
]=]
function Selection.FindNearestAttachment(origin: Vector3, attachments: { Attachment }, maxRange: number?): (Attachment?, number?)
	return _FindNearestCandidate(origin, attachments, Shared.ResolveAttachmentPosition, maxRange)
end

--[=[
    Returns the indices of all positions inside range.
    @within SpatialQuerySelection
    @param origin Vector3 -- Search origin.
    @param positions { Vector3 } -- Candidate positions.
    @param maxRange number -- Maximum distance.
    @return { number } -- Indices of the positions that are inside range.
]=]
function Selection.FindAllInRange(origin: Vector3, positions: { Vector3 }, maxRange: number): { number }
	if not Shared.IsPositiveNumber(maxRange) then
		return {}
	end

	local indices = {} :: { number }
	local maxRangeSquared = maxRange * maxRange
	for index, position in ipairs(positions) do
		if Shared.GetDistanceSquared(origin, position) <= maxRangeSquared then
			table.insert(indices, index)
		end
	end

	return indices
end

--[=[
    Returns the parts inside range.
    @within SpatialQuerySelection
    @param origin Vector3 -- Search origin.
    @param parts { BasePart } -- Candidate parts.
    @param maxRange number -- Maximum distance.
    @return { BasePart } -- Parts that are inside range.
]=]
function Selection.FindAllPartsInRange(origin: Vector3, parts: { BasePart }, maxRange: number): { BasePart }
	if not Shared.IsPositiveNumber(maxRange) then
		return {}
	end

	local partsInRange = {} :: { BasePart }
	local maxRangeSquared = maxRange * maxRange
	for _, part in ipairs(parts) do
		if Shared.GetDistanceSquared(origin, part.Position) <= maxRangeSquared then
			table.insert(partsInRange, part)
		end
	end

	return partsInRange
end

--[=[
    Sorts parts by distance from an origin point.
    @within SpatialQuerySelection
    @param origin Vector3 -- Sort origin.
    @param parts { BasePart } -- Parts to sort.
    @return { BasePart } -- Parts sorted from nearest to farthest.
]=]
function Selection.SortPartsByDistance(origin: Vector3, parts: { BasePart }): { BasePart }
	local sortedParts = table.clone(parts)
	table.sort(sortedParts, function(left: BasePart, right: BasePart): boolean
		return Shared.GetDistanceSquared(origin, left.Position) < Shared.GetDistanceSquared(origin, right.Position)
	end)
	return sortedParts
end

--[=[
    Sorts position indices by distance from an origin point.
    @within SpatialQuerySelection
    @param origin Vector3 -- Sort origin.
    @param positions { Vector3 } -- Positions to sort.
    @return { number } -- Indices sorted from nearest to farthest.
]=]
function Selection.SortPositionsByDistance(origin: Vector3, positions: { Vector3 }): { number }
	local indices = Shared.ResolvePositionIndices(positions)
	table.sort(indices, function(leftIndex: number, rightIndex: number): boolean
		return Shared.GetDistanceSquared(origin, positions[leftIndex]) < Shared.GetDistanceSquared(origin, positions[rightIndex])
	end)
	return indices
end

--[=[
    Finds the closest visible part to an origin point.
    @within SpatialQuerySelection
    @param origin Vector3 -- Search origin.
    @param parts { BasePart } -- Candidate parts.
    @param maxRange number? -- Optional maximum distance.
    @param options TQueryOptions? -- Visibility query configuration.
    @return BasePart? -- Closest visible part, or `nil` when nothing is visible.
    @return number? -- Distance to the returned part.
]=]
function Selection.FindClosestVisiblePart(
	origin: Vector3,
	parts: { BasePart },
	maxRange: number?,
	options: TQueryOptions?
): (BasePart?, number?)
	for _, part in ipairs(Selection.SortPartsByDistance(origin, parts)) do
		-- Check closer parts first so the first visible hit is the best visible candidate.
		local distanceSquared = Shared.GetDistanceSquared(origin, part.Position)
		if maxRange ~= nil then
			if not Shared.IsPositiveNumber(maxRange) then
				return nil, nil
			end
			if distanceSquared > maxRange * maxRange then
				continue
			end
		end

		if Queries.HasLineOfSight(origin, part.Position, options) then
			return part, math.sqrt(distanceSquared)
		end
	end

	return nil, nil
end

--[=[
    Finds the closest visible model to an origin point.
    @within SpatialQuerySelection
    @param origin Vector3 -- Search origin.
    @param models { Model } -- Candidate models.
    @param maxRange number? -- Optional maximum distance.
    @param options TQueryOptions? -- Visibility query configuration.
    @return Model? -- Closest visible model, or `nil` when nothing is visible.
    @return number? -- Distance to the returned model.
]=]
function Selection.FindClosestVisibleModel(
	origin: Vector3,
	models: { Model },
	maxRange: number?,
	options: TQueryOptions?
): (Model?, number?)
	local nearestVisibleModel = nil :: Model?
	local nearestVisibleDistanceSquared = math.huge

	for _, model in ipairs(models) do
		-- Compare every visible model so the helper can return the closest unobstructed candidate.
		local modelPosition = Shared.ResolveModelPosition(model)
		local distanceSquared = Shared.GetDistanceSquared(origin, modelPosition)
		if maxRange ~= nil then
			if not Shared.IsPositiveNumber(maxRange) then
				return nil, nil
			end
			if distanceSquared > maxRange * maxRange then
				continue
			end
		end

		if Queries.HasLineOfSight(origin, modelPosition, options) and distanceSquared < nearestVisibleDistanceSquared then
			nearestVisibleModel = model
			nearestVisibleDistanceSquared = distanceSquared
		end
	end

	if nearestVisibleModel == nil then
		return nil, nil
	end

	return nearestVisibleModel, math.sqrt(nearestVisibleDistanceSquared)
end

--[=[
    Finds the best-scoring candidate in a generic candidate list.
    @within SpatialQuerySelection
    @param origin Vector3 -- Search origin.
    @param candidates { T } -- Candidate values.
    @param getPosition function -- Returns the candidate position, or `nil` when it should be skipped.
    @param score function -- Returns the candidate score from the candidate and its distance.
    @param maxRange number? -- Optional maximum distance.
    @return T? -- Best candidate, or `nil` when no candidate matches.
    @return number? -- Distance to the returned candidate.
]=]
function Selection.FindBestCandidate<T>(
	origin: Vector3,
	candidates: { T },
	getPosition: (T) -> Vector3?,
	score: (T, number) -> number?,
	maxRange: number?
): (T?, number?)
	local bestCandidate = _FindBestScoredCandidate(origin, candidates, getPosition, score, maxRange)
	if bestCandidate == nil then
		return nil, nil
	end

	return bestCandidate.Candidate, math.sqrt(bestCandidate.DistanceSquared)
end

return table.freeze(Selection)
