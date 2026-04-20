--!strict

--[[
	Eldric/Greeting - Default dialogue tree for Eldric the Elder

	This tree demonstrates:
	- Conditional branching based on HasMet flag (first vs return visit)
	- Flag mutation via flagSetter callbacks
	- Valued flags (ElderTrust incremented on positive interactions)
	- Conditional options (secret dialogue unlocked at trust >= 3)

	Factory function receives:
	- flagReader(name) -> reads current flag value from client atom
	- flagSetter(name, value) -> fires remote to server to set flag
	- npcId -> the NPC identifier for context
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DH = require(ReplicatedStorage.Contexts.NPC.DialogueHelpers)

return function(flagReader: (string) -> any, flagSetter: (string, any) -> (), _npcId: string)
	return DH.CreateTree({
		-- Node 1: Check if player has met Eldric before
		DH.CreateCondition(
			function()
				return flagReader("HasMet_Eldric") == true
			end,
			-- Returning visitor greeting
			DH.CreateNode("Welcome back, adventurer! It's good to see a familiar face.", {
				DH.CreateOption("What's new in the village?", nil, 4),
				DH.CreateCondition(function()
					local trust = flagReader("ElderTrust")
					return trust ~= nil and type(trust) == "number" and trust >= 3
				end, DH.CreateOption("I need your counsel on something important...", nil, 6)),
				DH.CreateOption("Just passing through. Farewell!", nil, -1),
			})
		),

		-- Node 2: First meeting (shown when HasMet_Eldric is false/nil — condition above fails)
		DH.CreateNode(
			"Ah, a new face in our village! I am Eldric, elder of this settlement. What brings you to our humble home?",
			{
				DH.CreateOption("Pleased to meet you, Eldric. I'm an adventurer.", function()
					flagSetter("HasMet_Eldric", true)
				end, 3, "An adventurer! We don't see many of your kind around here."),
				DH.CreateOption("Just looking around. Who are you?", function()
					flagSetter("HasMet_Eldric", true)
				end, 3, "I've watched over this village for many years now."),
				DH.CreateOption("I don't have time to chat. Goodbye.", nil, -1),
			}
		),

		-- Node 3: After introduction
		DH.CreateNode("Tell me, what would you like to know? I've lived here long enough to know a thing or two.", {
			DH.CreateOption("Tell me about this village.", nil, 4),
			DH.CreateOption("Do you have any work for me?", nil, 5),
			DH.CreateOption("Nothing for now. Farewell.", nil, -1),
		}),

		-- Node 4: Village lore
		DH.CreateNode(
			"This village has stood for over three centuries. We were once a thriving trading post, but the old roads fell into disrepair long ago. Now we keep to ourselves, mostly.",
			{
				DH.CreateOption("Fascinating! Tell me more.", function()
					local currentTrust = flagReader("ElderTrust")
					local newTrust = (type(currentTrust) == "number" and currentTrust or 0) + 1
					flagSetter("ElderTrust", newTrust)
				end, 7, "I appreciate your genuine interest, young one."),
				DH.CreateOption("Sounds quiet. Anything exciting happen?", nil, 5),
				DH.CreateOption("I see. I should be going.", nil, -1),
			}
		),

		-- Node 5: Quest hook (placeholder — no quest system yet)
		DH.CreateNode(
			"Well... there have been strange noises coming from the old mines to the north. Nobody dares investigate. Perhaps someday, a brave soul might look into it.",
			{
				DH.CreateOption("I might check that out.", function()
					flagSetter("EldricMinesHint", true)
				end, -1, "Be careful if you do. The mines have been abandoned for good reason."),
				DH.CreateOption("Sounds dangerous. Maybe later.", nil, -1),
			}
		),

		-- Node 6: Secret dialogue (unlocked when ElderTrust >= 3)
		DH.CreateNode(
			"You've shown a kind heart and genuine curiosity. There is something I've kept secret for many years... an ancient map, hidden beneath the village well. It leads to a place of great power.",
			{
				DH.CreateOption("Tell me more about this map.", function()
					flagSetter("EldricSecretRevealed", true)
				end, -1, "In time, perhaps. For now, know that it exists. When you are ready, come find me again."),
				DH.CreateOption("I'll keep your secret safe.", function()
					flagSetter("EldricSecretRevealed", true)
				end, -1, "Thank you, friend. I knew I could trust you."),
			}
		),

		-- Node 7: Additional lore (after trust increase)
		DH.CreateNode(
			"In the old days, travelers would bring news from distant lands. We heard tales of dragons in the eastern peaks and enchanted forests to the south. Those were exciting times.",
			{
				DH.CreateOption("Do you miss those days?", function()
					local currentTrust = flagReader("ElderTrust")
					local newTrust = (type(currentTrust) == "number" and currentTrust or 0) + 1
					flagSetter("ElderTrust", newTrust)
				end, -1, "More than you know, young one. More than you know."),
				DH.CreateOption("Thanks for sharing. I'll be on my way.", nil, -1),
			}
		),
	})
end
