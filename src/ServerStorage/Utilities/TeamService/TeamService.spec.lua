--!strict

local ServerStorage = game:GetService("ServerStorage")
local Teams = game:GetService("Teams")

local TeamService = require(ServerStorage.Utilities.TeamService)

local function clearTeams()
	for _, child in ipairs(Teams:GetChildren()) do
		child:Destroy()
	end
end

return function()
	describe("TeamService", function()
		beforeEach(function()
			clearTeams()
		end)

		afterEach(function()
			clearTeams()
		end)

		it("registers teams and returns frozen clones", function()
			local manager = TeamService.new()
			local registeredDefinition = manager:RegisterTeam({
				TeamId = "Player",
				DisplayName = "Players",
			})

			local fetchedDefinition = manager:GetTeam("Player")
			expect(registeredDefinition.TeamId).to.equal("Player")
			expect(fetchedDefinition).to.be.ok()
			expect(fetchedDefinition.TeamId).to.equal("Player")
			expect(table.isfrozen(fetchedDefinition)).to.equal(true)
			expect(function()
				(fetchedDefinition :: any).TeamId = "Changed"
			end).to.throw()

			manager:Destroy()
		end)

		it("keeps relationships based on primary team only when groups are present", function()
			local manager = TeamService.new()
			local playerOne = Instance.new("Folder")
			playerOne:SetAttribute("TeamMemberId", "player:1")
			local npcRoot = Instance.new("Folder")
			npcRoot:SetAttribute("TeamMemberId", "npc:wave_1_grunt_3")

			manager:RegisterTeams({
				{ TeamId = "Player" },
				{ TeamId = "Enemy" },
			})
			manager:SetRelationship("Player", "Enemy", TeamService.Relationship.Hostile)

			manager:AssignMember(playerOne, "Player")
			manager:AssignMember(npcRoot, "Enemy")
			manager:AddMemberToGroup(playerOne, "selection:1")
			manager:AddMemberToGroup(npcRoot, "selection:1")

			expect(manager:AreHostile(playerOne, npcRoot)).to.equal(true)
			expect(manager:IsMemberInGroup(playerOne, "selection:1")).to.equal(true)
			expect(manager:IsMemberInGroup(npcRoot, "selection:1")).to.equal(true)

			manager:Destroy()
			playerOne:Destroy()
			npcRoot:Destroy()
		end)

		it("supports bulk assign and unassign behavior", function()
			local manager = TeamService.new()
			local memberA = {
				Kind = "npc",
				Id = "a",
			}
			local memberB = {
				Kind = "npc",
				Id = "b",
			}

			manager:RegisterTeam({
				TeamId = "Enemy",
			})

			expect(manager:AssignMembers({ memberA, memberB }, "Enemy")).to.equal(2)
			expect(manager:GetMemberCount("Enemy")).to.equal(2)
			expect(manager:UnassignMembers({ memberA, memberB })).to.equal(2)
			expect(manager:GetMemberCount("Enemy")).to.equal(0)

			manager:Destroy()
		end)

		it("updates team metadata and refreshes Roblox projection", function()
			local manager = TeamService.new()

			manager:RegisterTeam({
				TeamId = "Alpha",
				DisplayName = "Alpha Display",
				Roblox = {
					Name = "AlphaTeam",
					TeamColor = BrickColor.new("Bright blue"),
				},
			})

			local initialProjection = manager:EnsureRobloxTeam("Alpha")
			expect(initialProjection).to.be.ok()
			expect(initialProjection.Name).to.equal("AlphaTeam")

			manager:UpdateTeam("Alpha", {
				DisplayName = "Alpha Updated",
				Roblox = {
					Name = "AlphaNew",
					TeamColor = BrickColor.new("Bright red"),
					AutoAssignable = true,
				},
			})

			local updatedProjection = manager:EnsureRobloxTeam("Alpha")
			expect(Teams:FindFirstChild("AlphaTeam")).never.to.be.ok()
			expect(updatedProjection).to.be.ok()
			expect(updatedProjection.Name).to.equal("AlphaNew")
			expect(updatedProjection.AutoAssignable).to.equal(true)
			expect(updatedProjection.TeamColor).to.equal(BrickColor.new("Bright red"))

			manager:Destroy()
		end)

		it("exports and imports round-trip state with groups", function()
			local sourceManager = TeamService.new()
			local targetManager = TeamService.new()
			local member = {
				Kind = "npc",
				Id = "snapshot",
			}

			sourceManager:RegisterTeams({
				{ TeamId = "Player" },
				{ TeamId = "Enemy" },
			})
			sourceManager:SetRelationship("Player", "Enemy", TeamService.Relationship.Hostile)
			sourceManager:AssignMember(member, "Enemy")
			sourceManager:AddMemberToGroup(member, "wave:1")

			local snapshot = sourceManager:ExportState()
			local summary = targetManager:ImportState(snapshot)

			expect(summary.TeamCount).to.equal(2)
			expect(summary.MemberCount).to.equal(1)
			expect(summary.GroupCount).to.equal(1)
			expect(targetManager:GetMemberTeam(member).TeamId).to.equal("Enemy")
			expect(targetManager:IsMemberInGroup(member, "wave:1")).to.equal(true)
			expect(targetManager:GetRelationshipByTeamIds("Player", "Enemy")).to.equal(TeamService.Relationship.Hostile)

			sourceManager:Destroy()
			targetManager:Destroy()
		end)

		it("resolves ownership membership compatibility output", function()
			local manager = TeamService.new()
			local resolvedMembership = manager:ResolveOwnershipMembership({
				Faction = "Player",
				OwnerKind = "PlayerBase",
				OwnerId = "123",
			})

			expect(resolvedMembership.PrimaryTeamId).to.equal("Player")
			expect(#resolvedMembership.GroupIds).to.equal(1)
			expect(resolvedMembership.GroupIds[1]).to.equal("PlayerBase:123")

			manager:Destroy()
		end)

		it("rejects invalid import data without mutating existing state", function()
			local manager = TeamService.new()

			manager:RegisterTeam({
				TeamId = "Player",
			})

			expect(function()
				manager:ImportState({
					Teams = {
						{
							TeamId = "Player",
						},
					},
					Relationships = {},
					Members = {
						{
							MemberKey = "npc:a",
							PrimaryTeamId = "Missing",
							GroupIds = {},
						},
					},
				} :: any)
			end).to.throw()

			expect(manager:HasTeam("Player")).to.equal(true)
			manager:Destroy()
		end)

		it("rejects duplicate teams and team removal with active members unless forced", function()
			local manager = TeamService.new()
			local member = Instance.new("Folder")
			member:SetAttribute("TeamMemberId", "player:2")

			manager:RegisterTeam({
				TeamId = "Player",
			})

			expect(function()
				manager:RegisterTeam({
					TeamId = "Player",
				})
			end).to.throw()

			manager:AssignMember(member, "Player")
			manager:AddMemberToGroup(member, "selection:1")

			expect(function()
				manager:RemoveTeam("Player")
			end).to.throw()

			local removedDefinition = manager:RemoveTeam("Player", {
				Force = true,
			})
			expect(removedDefinition.TeamId).to.equal("Player")
			expect(manager:GetMemberTeam(member)).never.to.be.ok()
			expect(manager:IsMemberInGroup(member, "selection:1")).to.equal(true)

			manager:Destroy()
			member:Destroy()
		end)

		it("rejects raw instances without TeamMemberId when no custom resolver exists", function()
			local manager = TeamService.new()
			local instance = Instance.new("Folder")

			expect(function()
				manager:GetMemberKey(instance)
			end).to.throw()

			manager:Destroy()
			instance:Destroy()
		end)
	end)
end
