--!strict

local BasicFactProviders = {
	EmptyFacts = {
		ProviderId = "EmptyFacts",
		BuildFacts = function(_context: any): any
			return {}
		end,
		Metadata = {
			Description = "Template fact provider that contributes no facts.",
		},
	},
}

return table.freeze(BasicFactProviders)
