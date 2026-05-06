--!strict

local AppAtom = require(script.Parent.Parent.Parent.Infrastructure.AppAtom)

local function useAppActions()
	return {
		SetSelectedTab = function(selectedTab)
			AppAtom.SetSelectedTab(selectedTab)
		end,
	}
end

return useAppActions
