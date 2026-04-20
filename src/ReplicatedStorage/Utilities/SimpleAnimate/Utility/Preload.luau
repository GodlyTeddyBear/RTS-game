local BASE_URL = "rbxassetid://"

local Preload = {}

function Preload.preloadAnimArray(animator, anims, name: string, priority: Enum.AnimationPriority, looped: boolean)
	local tbl = {}
	for e, x in anims do
		local anim = Instance.new("Animation")
		anim.AnimationId = BASE_URL..tostring(x.id)

		local track = animator:LoadAnimation(anim)
		track.Priority = priority
		track.Looped = if x.looped ~= nil then x.looped else looped
		track.Name = name

		tbl[#tbl + 1] = {
			anim = track,
			weight = x.weight,
			fadeTime = x.fadeTime,
			speed = x.speed
		}
	end

	return tbl
end

function Preload.preloadAnimList(animator, anims, name: string, priority: Enum.AnimationPriority, looped: boolean)
	local tbl = {}
	for i, v in anims do
		tbl[i] = Preload.preloadAnimArray(animator, v, name, priority, looped)
	end

	return tbl
end

return Preload