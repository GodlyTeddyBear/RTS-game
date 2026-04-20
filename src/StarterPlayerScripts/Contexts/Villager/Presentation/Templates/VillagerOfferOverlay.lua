--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local useVillagerOfferController = require(script.Parent.Parent.Parent.Application.Hooks.useVillagerOfferController)
local VillagerOfferPanel = require(script.Parent.Parent.Organisms.VillagerOfferPanel)

local e = React.createElement

local function VillagerOfferOverlay()
	local controller = useVillagerOfferController()
	if not controller.isOpen or not controller.viewModel then
		return nil
	end

	return e("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(1, 1),
	}, {
		Panel = e(VillagerOfferPanel, {
			ViewModel = controller.viewModel,
			OnAccept = controller.onAccept,
			OnDecline = controller.onDecline,
			OnClose = controller.onClose,
		}),
	})
end

return VillagerOfferOverlay
