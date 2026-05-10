--!strict

local Traversal = {}

function Traversal.GetChildren(root: Instance): { Instance }
	return root:GetChildren()
end

function Traversal.WalkBreadthFirst(root: Instance, maxDepth: number?): { Instance }
	local results = {}
	local queue = {}
	local head = 1

	for _, child in root:GetChildren() do
		queue[#queue + 1] = {
			Instance = child,
			Depth = 1,
		}
	end

	while head <= #queue do
		local current = queue[head]
		head += 1

		local instance = current.Instance :: Instance
		local depth = current.Depth :: number
		results[#results + 1] = instance

		if maxDepth == nil or depth < maxDepth then
			for _, child in instance:GetChildren() do
				queue[#queue + 1] = {
					Instance = child,
					Depth = depth + 1,
				}
			end
		end
	end

	return results
end

function Traversal.FindFirst(root: Instance, maxDepth: number?, predicate: (Instance) -> boolean): Instance?
	local queue = {}
	local head = 1

	for _, child in root:GetChildren() do
		queue[#queue + 1] = {
			Instance = child,
			Depth = 1,
		}
	end

	while head <= #queue do
		local current = queue[head]
		head += 1

		local instance = current.Instance :: Instance
		local depth = current.Depth :: number
		if predicate(instance) then
			return instance
		end

		if maxDepth == nil or depth < maxDepth then
			for _, child in instance:GetChildren() do
				queue[#queue + 1] = {
					Instance = child,
					Depth = depth + 1,
				}
			end
		end
	end

	return nil
end

function Traversal.CollectAll(root: Instance, maxDepth: number?, predicate: (Instance) -> boolean): { Instance }
	local matches = {}

	for _, instance in Traversal.WalkBreadthFirst(root, maxDepth) do
		if predicate(instance) then
			matches[#matches + 1] = instance
		end
	end

	return matches
end

return table.freeze(Traversal)
