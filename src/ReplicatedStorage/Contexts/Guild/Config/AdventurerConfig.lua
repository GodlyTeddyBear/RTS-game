--!strict

return table.freeze({
	Warrior = table.freeze({
		Type = "Warrior",
		DisplayName = "Warrior",
		Description = "A balanced fighter with solid HP and ATK.",
		BaseHP = 100,
		BaseATK = 12,
		BaseDEF = 8,
		HireCost = 200,
	}),
	Scout = table.freeze({
		Type = "Scout",
		DisplayName = "Scout",
		Description = "A fast striker with high ATK but low DEF.",
		BaseHP = 70,
		BaseATK = 15,
		BaseDEF = 5,
		HireCost = 150,
	}),
	Guardian = table.freeze({
		Type = "Guardian",
		DisplayName = "Guardian",
		Description = "A defensive tank with the highest HP and DEF.",
		BaseHP = 120,
		BaseATK = 6,
		BaseDEF = 14,
		HireCost = 250,
	}),
	Berserker = table.freeze({
		Type = "Berserker",
		DisplayName = "Berserker",
		Description = "A glass cannon with devastating ATK.",
		BaseHP = 80,
		BaseATK = 18,
		BaseDEF = 4,
		HireCost = 300,
	}),
})
