--!strict

--[[
	Building unlock definitions. Owning context: Building.
]]

local buildings = {}

for _, mod in {
	require(script.Forge),
	require(script.Brewery),
	require(script.TailorShop),
	require(script.Farm),
	require(script.Garden),
	require(script.Forest),
	require(script.Mines),
} do
	for k, v in mod do
		buildings[k] = v
	end
end

return buildings
