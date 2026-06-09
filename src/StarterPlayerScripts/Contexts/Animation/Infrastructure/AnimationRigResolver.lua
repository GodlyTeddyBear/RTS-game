--!strict

local AnimationRigResolver = {}

local function _ResolveHumanoid(model: Model): any?
	local humanoid = model:FindFirstChildWhichIsA("Humanoid", true)
	if humanoid == nil then
		return nil
	end

	local animator = humanoid:FindFirstChildWhichIsA("Animator", true)
	if animator == nil then
		return nil
	end

	return {
		AdapterId = "Humanoid",
		Animator = animator,
		Humanoid = humanoid,
	}
end

local function _ResolveAnimationController(model: Model): any?
	local animationController = model:FindFirstChildWhichIsA("AnimationController", true)
	if animationController == nil then
		return nil
	end

	local animator = animationController:FindFirstChildWhichIsA("Animator", true)
	if animator == nil then
		return nil
	end

	return {
		AdapterId = "AnimationController",
		AnimationController = animationController,
		Animator = animator,
		Humanoid = nil,
	}
end

function AnimationRigResolver.Resolve(model: Model, adapterId: string): any?
	if adapterId == "Humanoid" then
		return _ResolveHumanoid(model)
	end
	if adapterId == "AnimationController" then
		return _ResolveAnimationController(model)
	end

	return _ResolveAnimationController(model) or _ResolveHumanoid(model)
end

return AnimationRigResolver
