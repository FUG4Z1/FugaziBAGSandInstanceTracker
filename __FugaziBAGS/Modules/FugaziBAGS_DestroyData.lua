local A = select(2, ...)

-- Auto-extracted Destroy Data from TSM

A.DestroyData = {}

local L = setmetatable({}, { __index = function(t, k) return k end })
local WEAPON, ARMOR = 2, 4 -- Fallback constants

A.DestroyData.Disenchanting = {
	{
		desc = L["Dust"],
		["item:10940:0:0:0:0:0:0"] = {
			-- Strange Dust
			name = GetItemInfo("item:10940:0:0:0:0:0:0"),
			minLevel = 0,
			maxLevel = 24,
			itemTypes = {
				[ARMOR] = {
					[2] = {
						{
							minItemLevel = 5,
							maxItemLevel = 15,
							amountOfMats = 1.2
						},
						{
							minItemLevel = 16,
							maxItemLevel = 20,
							amountOfMats = 1.875
						},
						{
							minItemLevel = 21,
							maxItemLevel = 25,
							amountOfMats = 3.75
						},
					},
				},
				[WEAPON] = {
					[2] = {
						{
							minItemLevel = 5,
							maxItemLevel = 15,
							amountOfMats = 0.3
						},
						{
							minItemLevel = 16,
							maxItemLevel = 20,
							amountOfMats = 0.5
						},
						{
							minItemLevel = 21,
							maxItemLevel = 25,
							amountOfMats = 0.75
						},
					},
				},
			},
		},
		["item:11083:0:0:0:0:0:0"] = {
			-- Soul Dust
			name = GetItemInfo("item:11083:0:0:0:0:0:0"),
			minLevel = 20,
			maxLevel = 30,
			itemTypes = {
				[ARMOR] = {
					[2] = {
						{
							minItemLevel = 26,
							maxItemLevel = 30,
							amountOfMats = 1.125
						},
						{
							minItemLevel = 31,
							maxItemLevel = 35,
							amountOfMats = 2.625
						},
					},
				},
				[WEAPON] = {
					[2] = {
						{
							minItemLevel = 26,
							maxItemLevel = 30,
							amountOfMats = 0.3
						},
						{
							minItemLevel = 31,
							maxItemLevel = 35,
							amountOfMats = 0.7
						},
					},
				},
			},
		},
		["item:11137:0:0:0:0:0:0"] = {
			-- Vision Dust
			name = GetItemInfo("item:11137:0:0:0:0:0:0"),
			minLevel = 30,
			maxLevel = 40,
			itemTypes = {
				[ARMOR] = {
					[2] = {
						{
							minItemLevel = 36,
							maxItemLevel = 40,
							amountOfMats = 1.125
						},
						{
							minItemLevel = 41,
							maxItemLevel = 45,
							amountOfMats = 2.625
						},
					},
				},
				[WEAPON] = {
					[2] = {
						{
							minItemLevel = 36,
							maxItemLevel = 40,
							amountOfMats = 0.3
						},
						{
							minItemLevel = 41,
							maxItemLevel = 45,
							amountOfMats = 0.7
						},
					},
				},
			},
		},
		["item:11176:0:0:0:0:0:0"] = {
			-- Dream Dust
			name = GetItemInfo("item:11176:0:0:0:0:0:0"),
			minLevel = 41,
			maxLevel = 50,
			itemTypes = {
				[ARMOR] = {
					[2] = {
						{
							minItemLevel = 46,
							maxItemLevel = 50,
							amountOfMats = 1.125
						},
						{
							minItemLevel = 51,
							maxItemLevel = 55,
							amountOfMats = 2.625
						},
					},
				},
				[WEAPON] = {
					[2] = {
						{
							minItemLevel = 46,
							maxItemLevel = 50,
							amountOfMats = 0.3
						},
						{
							minItemLevel = 51,
							maxItemLevel = 55,
							amountOfMats = 0.77
						},
					},
				},
			},
		},
		["item:16204:0:0:0:0:0:0"] = {
			-- Illusion Dust
			name = GetItemInfo("item:16204:0:0:0:0:0:0"),
			minLevel = 51,
			maxLevel = 60,
			itemTypes = {
				[ARMOR] = {
					[2] = {
						{
							minItemLevel = 56,
							maxItemLevel = 60,
							amountOfMats = 1.125
						},
						{
							minItemLevel = 61,
							maxItemLevel = 65,
							amountOfMats = 2.625
						},
					},
				},
				[WEAPON] = {
					[2] = {
						{
							minItemLevel = 56,
							maxItemLevel = 60,
							amountOfMats = 0.33
						},
						{
							minItemLevel = 61,
							maxItemLevel = 65,
							amountOfMats = 0.77
						},
					},
				},
			},
		},
		["item:22445:0:0:0:0:0:0"] = {
			-- Arcane Dust
			name = GetItemInfo("item:22445:0:0:0:0:0:0"),
			minLevel = 57,
			maxLevel = 70,
			itemTypes = {
				[ARMOR] = {
					[2] = {
						{
							minItemLevel = 79,
							maxItemLevel = 79,
							amountOfMats = 1.5
						},
						{
							minItemLevel = 80,
							maxItemLevel = 99,
							amountOfMats = 1.875
						},
						{
							minItemLevel = 100,
							maxItemLevel = 120,
							amountOfMats = 2.625
						},
					},
				},
				[WEAPON] = {
					[2] = {
						{
							minItemLevel = 80,
							maxItemLevel = 99,
							amountOfMats = 0.55
						},
						{
							minItemLevel = 100,
							maxItemLevel = 120,
							amountOfMats = 0.77
						},
					},
				},
			},
		},
		["item:34054:0:0:0:0:0:0"] = {
			-- Infinite Dust
			name = GetItemInfo("item:34054:0:0:0:0:0:0"),
			minLevel = 67,
			maxLevel = 80,
			itemTypes = {
				[ARMOR] = {
					[2] = {
						{
							minItemLevel = 130,
							maxItemLevel = 151,
							-- amountOfMats = 1.5 
							amountOfMats = 1.875 -- 2-3, 75% chance = 2.5*0.75
						},
						{
							minItemLevel = 152,
							maxItemLevel = 200,
							-- amountOfMats = 3.375
							amountOfMats = 4.125 -- 4-7, 75% chance = 5.5*0.75	
						},
					},
				},
				[WEAPON] = {
					[2] = {
						{
							minItemLevel = 130,
							maxItemLevel = 151,
							-- amountOfMats = 0.55
							amountOfMats = 0.55 -- 2-3, 22% chance = 2.5*0.22
						},
						{
							minItemLevel = 152,
							maxItemLevel = 200,
							-- amountOfMats = 1.1
							amountOfMats = 1.21 -- 4-7, 22% chance = 5.5*0.22
						},
					},
				},
			},
		},
		-- ["item:52555:0:0:0:0:0:0"] = {
			-- -- Hypnotic Dust
			-- name = GetItemInfo("item:52555:0:0:0:0:0:0"),
			-- minLevel = 77,
			-- maxLevel = 85,
			-- itemTypes = {
				-- [ARMOR] = {
					-- [2] = {
						-- {
							-- minItemLevel = 272,
							-- maxItemLevel = 275,
							-- amountOfMats = 1.125
						-- },
						-- {
							-- minItemLevel = 276,
							-- maxItemLevel = 290,
							-- amountOfMats = 1.5
						-- },
						-- {
							-- minItemLevel = 291,
							-- maxItemLevel = 305,
							-- amountOfMats = 1.875
						-- },
						-- {
							-- minItemLevel = 306,
							-- maxItemLevel = 315,
							-- amountOfMats = 2.25
						-- },
						-- {
							-- minItemLevel = 316,
							-- maxItemLevel = 325,
							-- amountOfMats = 2.625
						-- },
						-- {
							-- minItemLevel = 326,
							-- maxItemLevel = 350,
							-- amountOfMats = 3
						-- },
					-- },
				-- },
				-- [WEAPON] = {
					-- [2] = {
						-- {
							-- minItemLevel = 272,
							-- maxItemLevel = 275,
							-- amountOfMats = 0.375
						-- },
						-- {
							-- minItemLevel = 276,
							-- maxItemLevel = 290,
							-- amountOfMats = 0.5
						-- },
						-- {
							-- minItemLevel = 291,
							-- maxItemLevel = 305,
							-- amountOfMats = 0.625
						-- },
						-- {
							-- minItemLevel = 306,
							-- maxItemLevel = 315,
							-- amountOfMats = 0.75
						-- },
						-- {
							-- minItemLevel = 316,
							-- maxItemLevel = 325,
							-- amountOfMats = 0.875
						-- },
						-- {
							-- minItemLevel = 326,
							-- maxItemLevel = 350,
							-- amountOfMats = 1
						-- },
					-- },
				-- },
			-- },
		-- },
		-- ["item:74249:0:0:0:0:0:0"] = {
			-- -- Spirit Dust
			-- name = GetItemInfo("item:74249:0:0:0:0:0:0"),
			-- minLevel = 83,
			-- maxLevel = 88,
			-- itemTypes = {
				-- [ARMOR] = {
					-- [2] = {
						-- {
							-- minItemLevel = 364,
							-- maxItemLevel = 390,
							-- amountOfMats = 2.125
						-- },
						-- {
							-- minItemLevel = 391,
							-- maxItemLevel = 410,
							-- amountOfMats = 2.55
						-- },
						-- {
							-- minItemLevel = 411,
							-- maxItemLevel = 450,
							-- amountOfMats = 3.4
						-- },
					-- },
				-- },
				-- [WEAPON] = {
					-- [2] = {
						-- {
							-- minItemLevel = 377,
							-- maxItemLevel = 390,
							-- amountOfMats = 2.125
						-- },
						-- {
							-- minItemLevel = 391,
							-- maxItemLevel = 410,
							-- amountOfMats = 2.55
						-- },
						-- {
							-- minItemLevel = 411,
							-- maxItemLevel = 450,
							-- amountOfMats = 3.4
						-- },
					-- },
				-- },
			-- },
		-- },
	},
	{
		desc = L["Essences"],
		["item:10939:0:0:0:0:0:0"] = {
			-- Greater Magic Essence
			name = GetItemInfo("item:10939:0:0:0:0:0:0"),
			minLevel = 1,
			maxLevel = 15,
			itemTypes = {
				[ARMOR] = {
					[2] = {
						{
							minItemLevel = 5,
							maxItemLevel = 15,
							amountOfMats = 0.1
						},
						{
							minItemLevel = 16,
							maxItemLevel = 20,
							amountOfMats = 0.3
						},
					},
				},
				[WEAPON] = {
					[2] = {
						{
							minItemLevel = 5,
							maxItemLevel = 15,
							amountOfMats = 0.4
						},
						{
							minItemLevel = 16,
							maxItemLevel = 20,
							amountOfMats = 1.125
						},
					},
				},
			},
		},
		["item:11082:0:0:0:0:0:0"] = {
			-- Greater Astral Essence
			name = GetItemInfo("item:11082:0:0:0:0:0:0"),
			minLevel = 16,
			maxLevel = 25,
			itemTypes = {
				[ARMOR] = {
					[2] = {
						{
							minItemLevel = 21,
							maxItemLevel = 25,
							amountOfMats = .075
						},
						{
							minItemLevel = 26,
							maxItemLevel = 30,
							amountOfMats = 0.3
						},
					},
				},
				[WEAPON] = {
					[2] = {
						{
							minItemLevel = 21,
							maxItemLevel = 25,
							amountOfMats = 0.375
						},
						{
							minItemLevel = 26,
							maxItemLevel = 30,
							amountOfMats = 1.125
						},
					},
				},
			},
		},
		["item:11135:0:0:0:0:0:0"] = {
			-- Greater Mystic Essence
			name = GetItemInfo("item:11135:0:0:0:0:0:0"),
			minLevel = 26,
			maxLevel = 35,
			itemTypes = {
				[ARMOR] = {
					[2] = {
						{
							minItemLevel = 31,
							maxItemLevel = 35,
							amountOfMats = 0.1
						},
						{
							minItemLevel = 36,
							maxItemLevel = 40,
							amountOfMats = 0.3
						},
					},
				},
				[WEAPON] = {
					[2] = {
						{
							minItemLevel = 31,
							maxItemLevel = 35,
							amountOfMats = 0.375
						},
						{
							minItemLevel = 36,
							maxItemLevel = 40,
							amountOfMats = 1.125
						},
					},
				},
			},
		},
		["item:11175:0:0:0:0:0:0"] = {
			-- Greater Nether Essence
			name = GetItemInfo("item:11175:0:0:0:0:0:0"),
			minLevel = 36,
			maxLevel = 45,
			itemTypes = {
				[ARMOR] = {
					[2] = {
						{
							minItemLevel = 41,
							maxItemLevel = 45,
							amountOfMats = 0.1
						},
						{
							minItemLevel = 46,
							maxItemLevel = 50,
							amountOfMats = 0.3
						},
					},
				},
				[WEAPON] = {
					[2] = {
						{
							minItemLevel = 41,
							maxItemLevel = 45,
							amountOfMats = 0.375
						},
						{
							minItemLevel = 46,
							maxItemLevel = 50,
							amountOfMats = 1.125
						},
					},
				},
			},
		},
		["item:16203:0:0:0:0:0:0"] = {
			-- Greater Eternal Essence
			name = GetItemInfo("item:16203:0:0:0:0:0:0"),
			minLevel = 46,
			maxLevel = 60,
			itemTypes = {
				[ARMOR] = {
					[2] = {
						{
							minItemLevel = 51,
							maxItemLevel = 55,
							amountOfMats = 0.1
						},
						{
							minItemLevel = 56,
							maxItemLevel = 60,
							amountOfMats = 0.3
						},
						{
							minItemLevel = 61,
							maxItemLevel = 65,
							amountOfMats = 0.5
						},
					},
				},
				[WEAPON] = {
					[2] = {
						{
							minItemLevel = 51,
							maxItemLevel = 55,
							amountOfMats = 0.375
						},
						{
							minItemLevel = 56,
							maxItemLevel = 60,
							amountOfMats = 0.125
						},
						{
							minItemLevel = 61,
							maxItemLevel = 65,
							amountOfMats = 1.875
						},
					},
				},
			},
		},
		["item:22446:0:0:0:0:0:0"] = {
			-- Greater Planar Essence
			name = GetItemInfo("item:22446:0:0:0:0:0:0"),
			minLevel = 58,
			maxLevel = 70,
			itemTypes = {
				[ARMOR] = {
					[2] = {
						{
							minItemLevel = 66,
							maxItemLevel = 99,
							amountOfMats = 0.167
						},
						{
							minItemLevel = 100,
							maxItemLevel = 120,
							amountOfMats = 0.3
						},
					},
				},
				[WEAPON] = {
					[2] = {
						{
							minItemLevel = 79,
							maxItemLevel = 79,
							amountOfMats = 0.625
						},
						{
							minItemLevel = 80,
							maxItemLevel = 99,
							amountOfMats = 0.625
						},
						{
							minItemLevel = 100,
							maxItemLevel = 120,
							amountOfMats = 1.125
						},
					},
				},
			},
		},
		["item:34055:0:0:0:0:0:0"] = {
			-- Greater Cosmic Essence
			name = GetItemInfo("item:34055:0:0:0:0:0:0"),
			minLevel = 67,
			maxLevel = 80,
			itemTypes = {
				[ARMOR] = {
					[2] = {
						{
							minItemLevel = 130,
							maxItemLevel = 151,
							-- amountOfMats = 0.1
							amountOfMats = 0.11 -- 1-2 Lesser, 22% Chance = 1.5*0.22/3
						},
						{
							minItemLevel = 152,
							maxItemLevel = 200,
							-- amountOfMats = 0.3
							amountOfMats = 0.33 -- 1-2 Greater, 22% Chance = 1.5*0.22
						},
					},
				},
				[WEAPON] = {
					[2] = {
						{
							minItemLevel = 130,
							maxItemLevel = 151,
							-- amountOfMats = 0.375
							amountOfMats = 0.375 -- 1-2 Lesser, 75% chance = 1.5*0.75/3
						},
						{
							minItemLevel = 152,
							maxItemLevel = 200,
							-- amountOfMats = 1.125
							amountOfMats = 1.125 -- 1-2 Greater, 75% chance = 1.5*0.75
						},
					},
				},
			},
		},
		-- ["item:52719:0:0:0:0:0:0"] = {
			-- -- Greater Celestial Essence
			-- name = GetItemInfo("item:52719:0:0:0:0:0:0"),
			-- minLevel = 77,
			-- maxLevel = 85,
			-- itemTypes = {
				-- [ARMOR] = {
					-- [2] = {
						-- {
							-- minItemLevel = 201,
							-- maxItemLevel = 275,
							-- amountOfMats = 0.125
						-- },
						-- {
							-- minItemLevel = 276,
							-- maxItemLevel = 290,
							-- amountOfMats = 0.167
						-- },
						-- {
							-- minItemLevel = 291,
							-- maxItemLevel = 305,
							-- amountOfMats = 0.208
						-- },
						-- {
							-- minItemLevel = 306,
							-- maxItemLevel = 315,
							-- amountOfMats = 0.375
						-- },
						-- {
							-- minItemLevel = 316,
							-- maxItemLevel = 325,
							-- amountOfMats = 0.625
						-- },
						-- {
							-- minItemLevel = 326,
							-- maxItemLevel = 350,
							-- amountOfMats = 0.75
						-- },
					-- },
				-- },
				-- [WEAPON] = {
					-- [2] = {
						-- {
							-- minItemLevel = 201,
							-- maxItemLevel = 275,
							-- amountOfMats = 0.375
						-- },
						-- {
							-- minItemLevel = 276,
							-- maxItemLevel = 290,
							-- amountOfMats = 0.5
						-- },
						-- {
							-- minItemLevel = 291,
							-- maxItemLevel = 305,
							-- amountOfMats = 0.625
						-- },
						-- {
							-- minItemLevel = 306,
							-- maxItemLevel = 315,
							-- amountOfMats = 1.125
						-- },
						-- {
							-- minItemLevel = 316,
							-- maxItemLevel = 325,
							-- amountOfMats = 1.875
						-- },
						-- {
							-- minItemLevel = 326,
							-- maxItemLevel = 350,
							-- amountOfMats = 2.25
						-- },
					-- },
				-- },
			-- },
		-- },
		-- ["item:74250:0:0:0:0:0:0"] = {
			-- -- Mysterious Essence
			-- name = GetItemInfo("item:74250:0:0:0:0:0:0"),
			-- minLevel = 83,
			-- maxLevel = 88,
			-- itemTypes = {
				-- [ARMOR] = {
					-- [2] = {
						-- {
							-- minItemLevel = 364,
							-- maxItemLevel = 390,
							-- amountOfMats = 0.15
						-- },
						-- {
							-- minItemLevel = 391,
							-- maxItemLevel = 410,
							-- amountOfMats = 0.225
						-- },
						-- {
							-- minItemLevel = 411,
							-- maxItemLevel = 450,
							-- amountOfMats = 0.3
						-- },
					-- },
				-- },
				-- [WEAPON] = {
					-- [2] = {
						-- {
							-- minItemLevel = 377,
							-- maxItemLevel = 390,
							-- amountOfMats = 0.15
						-- },
						-- {
							-- minItemLevel = 391,
							-- maxItemLevel = 410,
							-- amountOfMats = 0.225
						-- },
						-- {
							-- minItemLevel = 411,
							-- maxItemLevel = 450,
							-- amountOfMats = 0.3
						-- },
					-- },
				-- },
			-- },
		-- },
	},
	{
		desc = L["Shards"],
		["item:10978:0:0:0:0:0:0"] = {
			-- Small Glimmering Shard
			name = GetItemInfo("item:10978:0:0:0:0:0:0"),
			minLevel = 1,
			maxLevel = 20,
			itemTypes = {
				[ARMOR] = {
					[2] = {
						{
							minItemLevel = 1,
							maxItemLevel = 20,
							amountOfMats = 0.05
						},
						{
							minItemLevel = 21,
							maxItemLevel = 25,
							amountOfMats = 0.1
						},
					},
					[3] = {
						{
							minItemLevel = 1,
							maxItemLevel = 25,
							amountOfMats = 1.000
						},
					},
				},
				[WEAPON] = {
					[3] = {
						{
							minItemLevel = 1,
							maxItemLevel = 25,
							amountOfMats = 1.000
						},
					},
				},
			},
		},
		["item:11084:0:0:0:0:0:0"] = {
			-- Large Glimmering Shard
			name = GetItemInfo("item:11084:0:0:0:0:0:0"),
			minLevel = 16,
			maxLevel = 25,
			itemTypes = {
				[ARMOR] = {
					[2] = {
						{
							minItemLevel = 26,
							maxItemLevel = 30,
							amountOfMats = 0.05
						},
					},
					[3] = {
						{
							minItemLevel = 26,
							maxItemLevel = 30,
							amountOfMats = 1.000
						},
					},
				},
				[WEAPON] = {
					[3] = {
						{
							minItemLevel = 26,
							maxItemLevel = 30,
							amountOfMats = 1.000
						},
					},
				},
			},
		},
		["item:11138:0:0:0:0:0:0"] = {
			-- Small Glowing Shard
			name = GetItemInfo("item:11138:0:0:0:0:0:0"),
			minLevel = 26,
			maxLevel = 30,
			itemTypes = {
				[ARMOR] = {
					[2] = {
						{
							minItemLevel = 31,
							maxItemLevel = 35,
							amountOfMats = 0.05
						},
					},
					[3] = {
						{
							minItemLevel = 31,
							maxItemLevel = 35,
							amountOfMats = 1.000
						},
					},
				},
				[WEAPON] = {
					[2] = {
						{
							minItemLevel = 31,
							maxItemLevel = 35,
							amountOfMats = 0.05
						},
					},
					[3] = {
						{
							minItemLevel = 31,
							maxItemLevel = 35,
							amountOfMats = 1.000
						},
					},
				},
			},
		},
		["item:11139:0:0:0:0:0:0"] = {
			-- Large Glowing Shard
			name = GetItemInfo("item:11139:0:0:0:0:0:0"),
			minLevel = 31,
			maxLevel = 35,
			itemTypes = {
				[ARMOR] = {
					[2] = {
						{
							minItemLevel = 36,
							maxItemLevel = 40,
							amountOfMats = 0.05
						},
					},
					[3] = {
						{
							minItemLevel = 36,
							maxItemLevel = 40,
							amountOfMats = 1.000
						},
					},
				},
				[WEAPON] = {
					[2] = {
						{
							minItemLevel = 36,
							maxItemLevel = 40,
							amountOfMats = 0.05
						},
					},
					[3] = {
						{
							minItemLevel = 36,
							maxItemLevel = 40,
							amountOfMats = 1.000
						},
					},
				},
			},
		},
		["item:11177:0:0:0:0:0:0"] = {
			-- Small Radiant Shard
			name = GetItemInfo("item:11177:0:0:0:0:0:0"),
			minLevel = 36,
			maxLevel = 40,
			itemTypes = {
				[ARMOR] = {
					[2] = {
						{
							minItemLevel = 41,
							maxItemLevel = 45,
							amountOfMats = 0.05
						},
					},
					[3] = {
						{
							minItemLevel = 41,
							maxItemLevel = 45,
							amountOfMats = 1.000
						},
					},
					[4] = {
						{
							minItemLevel = 36,
							maxItemLevel = 40,
							amountOfMats = 3
						},
						{
							minItemLevel = 41,
							maxItemLevel = 45,
							amountOfMats = 3.5
						},
					},
				},
				[WEAPON] = {
					[2] = {
						{
							minItemLevel = 41,
							maxItemLevel = 45,
							amountOfMats = 0.05
						},
					},
					[3] = {
						{
							minItemLevel = 41,
							maxItemLevel = 45,
							amountOfMats = 1.000
						},
					},
					[4] = {
						{
							minItemLevel = 36,
							maxItemLevel = 40,
							amountOfMats = 3
						},
						{
							minItemLevel = 41,
							maxItemLevel = 45,
							amountOfMats = 3.5
						},
					},
				},
			},
		},
		["item:11178:0:0:0:0:0:0"] = {
			-- Large Radiant Shard
			name = GetItemInfo("item:11178:0:0:0:0:0:0"),
			minLevel = 41,
			maxLevel = 45,
			itemTypes = {
				[ARMOR] = {
					[2] = {
						{
							minItemLevel = 46,
							maxItemLevel = 50,
							amountOfMats = 0.05
						},
					},
					[3] = {
						{
							minItemLevel = 46,
							maxItemLevel = 50,
							amountOfMats = 1.000
						},
					},
					[4] = {
						{
							minItemLevel = 46,
							maxItemLevel = 50,
							amountOfMats = 3.5
						},
					},
				},
				[WEAPON] = {
					[2] = {
						{
							minItemLevel = 46,
							maxItemLevel = 50,
							amountOfMats = 0.05
						},
					},
					[3] = {
						{
							minItemLevel = 46,
							maxItemLevel = 50,
							amountOfMats = 1.000
						},
					},
					[4] = {
						{
							minItemLevel = 46,
							maxItemLevel = 50,
							amountOfMats = 3.5
						},
					},
				},
			},
		},
		["item:14343:0:0:0:0:0:0"] = {
			-- Small Brilliant Shard
			name = GetItemInfo("item:14343:0:0:0:0:0:0"),
			minLevel = 46,
			maxLevel = 50,
			itemTypes = {
				[ARMOR] = {
					[2] = {
						{
							minItemLevel = 51,
							maxItemLevel = 55,
							amountOfMats = 0.05
						},
					},
					[3] = {
						{
							minItemLevel = 51,
							maxItemLevel = 55,
							amountOfMats = 1.000
						},
					},
					[4] = {
						{
							minItemLevel = 51,
							maxItemLevel = 55,
							amountOfMats = 3.5
						},
					},
				},
				[WEAPON] = {
					[2] = {
						{
							minItemLevel = 51,
							maxItemLevel = 55,
							amountOfMats = 0.05
						},
					},
					[3] = {
						{
							minItemLevel = 51,
							maxItemLevel = 55,
							amountOfMats = 1.000
						},
					},
					[4] = {
						{
							minItemLevel = 51,
							maxItemLevel = 55,
							amountOfMats = 3.5
						},
					},
				},
			},
		},
		["item:14344:0:0:0:0:0:0"] = {
			-- Large Brilliant Shard
			name = GetItemInfo("item:14344:0:0:0:0:0:0"),
			minLevel = 56,
			maxLevel = 75,
			itemTypes = {
				[ARMOR] = {
					[2] = {
						{
							minItemLevel = 56,
							maxItemLevel = 65,
							amountOfMats = 0.05
						},
					},
					[3] = {
						{
							minItemLevel = 56,
							maxItemLevel = 65,
							amountOfMats = 0.995
						},
					},
				},
				[WEAPON] = {
					[2] = {
						{
							minItemLevel = 56,
							maxItemLevel = 65,
							amountOfMats = 0.05
						},
					},
					[3] = {
						{
							minItemLevel = 56,
							maxItemLevel = 65,
							amountOfMats = 0.995
						},
					},
				},
			},
		},
		["item:22449:0:0:0:0:0:0"] = {
			-- Large Prismatic Shard
			name = GetItemInfo("item:22449:0:0:0:0:0:0"),
			minLevel = 56,
			maxLevel = 70,
			itemTypes = {
				[ARMOR] = {
					[2] = {
						{
							minItemLevel = 66,
							maxItemLevel = 99,
							amountOfMats = 0.0167
						},
						{
							minItemLevel = 100,
							maxItemLevel = 120,
							amountOfMats = 0.05
						},
					},
					[3] = {
						{
							minItemLevel = 66,
							maxItemLevel = 99,
							amountOfMats = 0.33
						},
						{
							minItemLevel = 100,
							maxItemLevel = 120,
							amountOfMats = 1
						},
					},
				},
				[WEAPON] = {
					[2] = {
						{
							minItemLevel = 66,
							maxItemLevel = 99,
							amountOfMats = 0.0167
						},
						{
							minItemLevel = 100,
							maxItemLevel = 120,
							amountOfMats = 0.05
						},
					},
					[3] = {
						{
							minItemLevel = 66,
							maxItemLevel = 99,
							amountOfMats = 0.33
						},
						{
							minItemLevel = 100,
							maxItemLevel = 120,
							amountOfMats = 1
						},
					},
				},
			},
		},
		["item:34052:0:0:0:0:0:0"] = {
			-- Dream Shard
			-- 2 is uncommon, 3 is rare, 4 is epic
			name = GetItemInfo("item:34052:0:0:0:0:0:0"),
			minLevel = 68,
			maxLevel = 80,
			itemTypes = {
				[ARMOR] = {
					[2] = {
						{
							minItemLevel = 121,
							maxItemLevel = 151,
							-- amountOfMats = 0.0167
							amountOfMats = 0.01 -- 1 Small, 3% Chance = 1/3*0.03
						},
						{
							minItemLevel = 152,
							maxItemLevel = 200,
							-- amountOfMats = 0.05
							amountOfMats = 0.03 -- 1 Large, 3% Chance = 1*0.03
						},
					},
					[3] = {
						{
							minItemLevel = 121,
							maxItemLevel = 164,
							amountOfMats = 0.333 -- 1 Small, 100% Chance = 1/3*1
						},
						{
							minItemLevel = 165,
							maxItemLevel = 200,
							amountOfMats = 1 -- 1 Large, 100% Chance = 1*1
						},
					},
				},
				[WEAPON] = {
					[2] = {
						{
							minItemLevel = 121,
							maxItemLevel = 151,
							-- amountOfMats = 0.0167
							amountOfMats = 0.01 -- 1 Small, 3% Chance = 1/3*0.03
						},
						{
							minItemLevel = 152,
							maxItemLevel = 200,
							-- amountOfMats = 0.05
							amountOfMats = 0.03 -- 1 Large, 3% Chance = 1*0.03
						},
					},
					[3] = {
						{
							minItemLevel = 121,
							maxItemLevel = 164,
							amountOfMats = 0.333 -- 1 Small, 100% Chance = 1/3*1
						},
						{
							minItemLevel = 165,
							maxItemLevel = 200,
							amountOfMats = 1 -- 1 Large, 100% Chance = 1*1
						},
					},
				},
			},
		},
		-- ["item:52720:0:0:0:0:0:0"] = {
			-- -- Small Heavenly Shard
			-- name = GetItemInfo("item:52720:0:0:0:0:0:0"),
			-- minLevel = 78,
			-- maxLevel = 85,
			-- itemTypes = {
				-- [ARMOR] = {
					-- [3] = {
						-- {
							-- minItemLevel = 282,
							-- maxItemLevel = 316,
							-- amountOfMats = 1
						-- },
					-- },
				-- },
				-- [WEAPON] = {
					-- [3] = {
						-- {
							-- minItemLevel = 282,
							-- maxItemLevel = 316,
							-- amountOfMats = 1
						-- },
					-- },
				-- },
			-- },
		-- },
		-- ["item:52721:0:0:0:0:0:0"] = {
			-- -- Heavenly Shard
			-- name = GetItemInfo("item:52721:0:0:0:0:0:0"),
			-- minLevel = 78,
			-- maxLevel = 85,
			-- itemTypes = {
				-- [ARMOR] = {
					-- [3] = {
						-- {
							-- minItemLevel = 282,
							-- maxItemLevel = 316,
							-- amountOfMats = 0.33
						-- },
						-- {
							-- minItemLevel = 317,
							-- maxItemLevel = 377,
							-- amountOfMats = 1
						-- },
					-- },
				-- },
				-- [WEAPON] = {
					-- [3] = {
						-- {
							-- minItemLevel = 282,
							-- maxItemLevel = 316,
							-- amountOfMats = 0.33
						-- },
						-- {
							-- minItemLevel = 317,
							-- maxItemLevel = 377,
							-- amountOfMats = 1
						-- },
					-- },
				-- },
			-- },
		-- },
		-- ["item:74252:0:0:0:0:0:0"] = {
			-- --Small Ethereal Shard
			-- name = GetItemInfo("item:74252:0:0:0:0:0:0"),
			-- minLevel = 85,
			-- maxLevel = 90,
			-- itemTypes = {
				-- [ARMOR] = {
					-- [3] = {
						-- {
							-- minItemLevel = 384,
							-- maxItemLevel = 429,
							-- amountOfMats = 1
						-- },
					-- },
				-- },
				-- [WEAPON] = {
					-- [3] = {
						-- {
							-- minItemLevel = 384,
							-- maxItemLevel = 429,
							-- amountOfMats = 1
						-- },
					-- },
				-- },
			-- },
		-- },
		-- ["item:74247:0:0:0:0:0:0"] = {
			-- --Ethereal Shard
			-- name = GetItemInfo("item:74247:0:0:0:0:0:0"),
			-- minLevel = 85,
			-- maxLevel = 90,
			-- itemTypes = {
				-- [ARMOR] = {
					-- [3] = {
						-- {
							-- minItemLevel = 384,
							-- maxItemLevel = 429,
							-- amountOfMats = 0.33
						-- },
						-- {
							-- minItemLevel = 430,
							-- maxItemLevel = 500,
							-- amountOfMats = 1
						-- },
					-- },
				-- },
				-- [WEAPON] = {
					-- [3] = {
						-- {
							-- minItemLevel = 384,
							-- maxItemLevel = 429,
							-- amountOfMats = 0.33
						-- },
						-- {
							-- minItemLevel = 430,
							-- maxItemLevel = 500,
							-- amountOfMats = 1
						-- },
					-- },
				-- },
			-- },
		-- },
	},
	{
		desc = L["Crystals"],
		["item:20725:0:0:0:0:0:0"] = {
			-- Nexus Crystal
			name = GetItemInfo("item:20725:0:0:0:0:0:0"),
			minLevel = 56,
			maxLevel = 60,
			itemTypes = {
				[ARMOR] = {
					[4] = {
						{
							minItemLevel = 56,
							maxItemLevel = 60,
							amountOfMats = 1.000
						},
						{
							minItemLevel = 61,
							maxItemLevel = 94,
							amountOfMats = 1.5
						},
					},
				},
				[WEAPON] = {
					[4] = {
						{
							minItemLevel = 56,
							maxItemLevel = 60,
							amountOfMats = 1.000
						},
						{
							minItemLevel = 61,
							maxItemLevel = 94,
							amountOfMats = 1.5
						},
					},
				},
			},
		},
		["item:22450:0:0:0:0:0:0"] = {
			-- Void Crystal
			name = GetItemInfo("item:22450:0:0:0:0:0:0"),
			minLevel = 70,
			maxLevel = 70,
			itemTypes = {
				[ARMOR] = {
					[4] = {
						{
							minItemLevel = 95,
							maxItemLevel = 99,
							amountOfMats = 1
						},
						{
							minItemLevel = 100,
							maxItemLevel = 164,
							amountOfMats = 1.5
						},
					},
				},
				[WEAPON] = {
					[4] = {
						{
							minItemLevel = 95,
							maxItemLevel = 99,
							amountOfMats = 1
						},
						{
							minItemLevel = 100,
							maxItemLevel = 164,
							amountOfMats = 1.5
						},
					},
				},
			},
		},
		["item:34057:0:0:0:0:0:0"] = {
			-- Abyss Crystal
			name = GetItemInfo("item:34057:0:0:0:0:0:0"),
			minLevel = 80,
			maxLevel = 80,
			itemTypes = {
				[ARMOR] = {
					[4] = {
						{
							minItemLevel = 165,
							maxItemLevel = 299,
							amountOfMats = 1.000
						},
					},
				},
				[WEAPON] = {
					[4] = {
						{
							minItemLevel = 165,
							maxItemLevel = 299,
							amountOfMats = 1.000
						},
					},
				},
			},
		},
		-- ["item:52722:0:0:0:0:0:0"] = {
			-- -- Maelstrom Crystal
			-- name = GetItemInfo("item:52722:0:0:0:0:0:0"),
			-- minLevel = 85,
			-- maxLevel = 85,
			-- itemTypes = {
				-- [ARMOR] = {
					-- [4] = {
						-- {
							-- minItemLevel = 300,
							-- maxItemLevel = 419,
							-- amountOfMats = 1.000
						-- },
					-- },
				-- },
				-- [WEAPON] = {
					-- [4] = {
						-- {
							-- minItemLevel = 285,
							-- maxItemLevel = 419,
							-- amountOfMats = 1.000
						-- },
					-- },
				-- },
			-- },
		-- },
		-- ["item:74248:0:0:0:0:0:0"] = {
			-- -- Sha Crystal
			-- name = GetItemInfo("item:74248:0:0:0:0:0:0"),
			-- minLevel = 85,
			-- maxLevel = 90,
			-- itemTypes = {
				-- [ARMOR] = {
					-- [4] = {
						-- {
							-- minItemLevel = 420,
							-- maxItemLevel = 600,
							-- amountOfMats = 1.000
						-- },
					-- },
				-- },
				-- [WEAPON] = {
					-- [4] = {
						-- {
							-- minItemLevel = 420,
							-- maxItemLevel = 600,
							-- amountOfMats = 1.000
						-- },
					-- },
				-- },
			-- },
		-- },
	},
}

A.DestroyData.Conversions = {
	-- Epic WotLK gems
	["item:36919:0:0:0:0:0:0"] = { -- Cardinal Ruby
		["item:36910:0:0:0:0:0:0"] = {rate=.03, source="prospect"},
	},
	["item:36922:0:0:0:0:0:0"] = { -- King's Amber
		["item:36910:0:0:0:0:0:0"] = {rate=.03, source="prospect"},
	},
	["item:36925:0:0:0:0:0:0"] = { -- Majestic Zircon
		["item:36910:0:0:0:0:0:0"] = {rate=.03, source="prospect"},
	},
	["item:36928:0:0:0:0:0:0"] = { -- Dreadstone
		["item:36910:0:0:0:0:0:0"] = {rate=.03, source="prospect"},
	},
	["item:36931:0:0:0:0:0:0"] = { -- Ametrine
		["item:36910:0:0:0:0:0:0"] = {rate=.03, source="prospect"},
	},
	["item:36934:0:0:0:0:0:0"] = { -- Eye of Zul
		["item:36910:0:0:0:0:0:0"] = {rate=.03, source="prospect"},
	},
	-- common pigments (inks)
	["item:39151:0:0:0:0:0:0"] = { -- Alabaster Pigment (Ivory / Moonglow Ink)
		["item:765:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:2447:0:0:0:0:0:0"] = {rate=.6, source="mill"},
		["item:2449:0:0:0:0:0:0"] = {rate=.6, source="mill"},
	},
	["item:39343:0:0:0:0:0:0"] = { -- Azure Pigment (Ink of the Sea)
		["item:39969:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:36904:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:36907:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:36901:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:39970:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:37921:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:36905:0:0:0:0:0:0"] = {rate=.6, source="mill"},
		["item:36906:0:0:0:0:0:0"] = {rate=.6, source="mill"},
		["item:36903:0:0:0:0:0:0"] = {rate=.6, source="mill"},
	},
	["item:61979:0:0:0:0:0:0"] = { -- Ashen Pigment (Blackfallow Ink)
		["item:52983:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:52984:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:52985:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:52986:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:52987:0:0:0:0:0:0"] = {rate=.6, source="mill"},
		["item:52988:0:0:0:0:0:0"] = {rate=.6, source="mill"},
	},
	["item:39334:0:0:0:0:0:0"] = { -- Dusky Pigment (Midnight Ink)
		["item:785:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:2450:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:2452:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:2453:0:0:0:0:0:0"] = {rate=.6, source="mill"},
		["item:3820:0:0:0:0:0:0"] = {rate=.6, source="mill"},
	},
	["item:39339:0:0:0:0:0:0"] = { -- Emerald Pigment (Jadefire Ink)
		["item:3818:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:3821:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:3358:0:0:0:0:0:0"] = {rate=.6, source="mill"},
		["item:3819:0:0:0:0:0:0"] = {rate=.6, source="mill"},
	},
	["item:39338:0:0:0:0:0:0"] = { -- Golden Pigment (Lion's Ink)
		["item:3355:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:3369:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:3356:0:0:0:0:0:0"] = {rate=.6, source="mill"},
		["item:3357:0:0:0:0:0:0"] = {rate=.6, source="mill"},
	},
	["item:39342:0:0:0:0:0:0"] = { -- Nether Pigment (Ethereal Ink)
		["item:22786:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:22785:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:22789:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:22787:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:22790:0:0:0:0:0:0"] = {rate=.6, source="mill"},
		["item:22793:0:0:0:0:0:0"] = {rate=.6, source="mill"},
		["item:22791:0:0:0:0:0:0"] = {rate=.6, source="mill"},
		["item:22792:0:0:0:0:0:0"] = {rate=.6, source="mill"},
	},
	["item:79251:0:0:0:0:0:0"] = { -- Shadow Pigment (Ink of Dreams)
		["item:72237:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:72234:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:79010:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:72235:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:79011:0:0:0:0:0:0"] = {rate=.6, source="mill"},
		["item:89639:0:0:0:0:0:0"] = {rate=.5, source="mill"},
	},
	["item:39341:0:0:0:0:0:0"] = { -- Silvery Pigment (Shimmering Ink)
		["item:13464:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:13463:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:13465:0:0:0:0:0:0"] = {rate=.6, source="mill"},
		["item:13466:0:0:0:0:0:0"] = {rate=.6, source="mill"},
		["item:13467:0:0:0:0:0:0"] = {rate=.6, source="mill"},
	},
	["item:39340:0:0:0:0:0:0"] = { -- Violet Pigment (Celestial Ink)
		["item:4625:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:8831:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:8838:0:0:0:0:0:0"] = {rate=.5, source="mill"},
		["item:8839:0:0:0:0:0:0"] = {rate=.6, source="mill"},
		["item:8845:0:0:0:0:0:0"] = {rate=.6, source="mill"},
		["item:8846:0:0:0:0:0:0"] = {rate=.6, source="mill"},
	},
	
	-- rare pigments (inks)
	["item:43109:0:0:0:0:0:0"] = { -- Icy Pigment (Snowfall Ink)
		["item:39969:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:36904:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:36907:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:36901:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:39970:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:37921:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:36905:0:0:0:0:0:0"] = {rate=.1, source="mill"},
		["item:36906:0:0:0:0:0:0"] = {rate=.1, source="mill"},
		["item:36903:0:0:0:0:0:0"] = {rate=.1, source="mill"},
	},
	["item:61980:0:0:0:0:0:0"] = { -- Burning Embers (Inferno Ink)
		["item:52983:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:52984:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:52985:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:52986:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:52987:0:0:0:0:0:0"] = {rate=.1, source="mill"},
		["item:52988:0:0:0:0:0:0"] = {rate=.1, source="mill"},
	},
	["item:43104:0:0:0:0:0:0"] = { -- Burnt Pigment (Dawnstar Ink)
		["item:3356:0:0:0:0:0:0"] = {rate=.1, source="mill"},
		["item:3357:0:0:0:0:0:0"] = {rate=.1, source="mill"},
		["item:3369:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:3355:0:0:0:0:0:0"] = {rate=.05, source="mill"},
	},
	["item:43108:0:0:0:0:0:0"] = { -- Ebon Pigment (Darkflame Ink)
		["item:22792:0:0:0:0:0:0"] = {rate=.1, source="mill"},
		["item:22790:0:0:0:0:0:0"] = {rate=.1, source="mill"},
		["item:22791:0:0:0:0:0:0"] = {rate=.1, source="mill"},
		["item:22793:0:0:0:0:0:0"] = {rate=.1, source="mill"},
		["item:22786:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:22785:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:22787:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:22789:0:0:0:0:0:0"] = {rate=.05, source="mill"},
	},
	["item:43105:0:0:0:0:0:0"] = { -- Indigo Pigment (Royal Ink)
		["item:3358:0:0:0:0:0:0"] = {rate=.1, source="mill"},
		["item:3819:0:0:0:0:0:0"] = {rate=.1, source="mill"},
		["item:3821:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:3818:0:0:0:0:0:0"] = {rate=.05, source="mill"},
	},
	["item:79253:0:0:0:0:0:0"] = { -- Misty Pigment (Starlight Ink)
		["item:72237:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:72234:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:79010:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:72235:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:79011:0:0:0:0:0:0"] = {rate=.1, source="mill"},
		["item:89639:0:0:0:0:0:0"] = {rate=.05, source="mill"},
	},
	["item:43106:0:0:0:0:0:0"] = { -- Ruby Pigment (Fiery Ink)
		["item:4625:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:8838:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:8831:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:8845:0:0:0:0:0:0"] = {rate=.1, source="mill"},
		["item:8846:0:0:0:0:0:0"] = {rate=.1, source="mill"},
		["item:8839:0:0:0:0:0:0"] = {rate=.1, source="mill"},
	},
	["item:43107:0:0:0:0:0:0"] = { -- Sapphire Pigment (Ink of the Sky)
		["item:13463:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:13464:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:13465:0:0:0:0:0:0"] = {rate=.1, source="mill"},
		["item:13466:0:0:0:0:0:0"] = {rate=.1, source="mill"},
		["item:13467:0:0:0:0:0:0"] = {rate=.1, source="mill"},
	},
	["item:43103:0:0:0:0:0:0"] = { -- Verdant Pigment (Hunter's Ink)
		["item:2453:0:0:0:0:0:0"] = {rate=.1, source="mill"},
		["item:3820:0:0:0:0:0:0"] = {rate=.1, source="mill"},
		["item:2450:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:785:0:0:0:0:0:0"] = {rate=.05, source="mill"},
		["item:2452:0:0:0:0:0:0"] = {rate=.05, source="mill"},
	},

	--Vanilla Gems
	["item:774:0:0:0:0:0:0"] = { -- malachite
		["item:2770:0:0:0:0:0:0"] = {rate=.5, source="prospect"},
	},
	["item:818:0:0:0:0:0:0"] = { -- Tigerseye
		["item:2770:0:0:0:0:0:0"] = {rate=.5, source="prospect"},
	},
	["item:1210:0:0:0:0:0:0"] = { -- Shadowgem
		["item:2771:0:0:0:0:0:0"] = {rate=.4, source="prospect"},
		["item:2770:0:0:0:0:0:0"] = {rate=.1, source="prospect"},
	},
	["item:1206:0:0:0:0:0:0"] = { -- Moss Agate
		["item:2771:0:0:0:0:0:0"] = {rate=.3, source="prospect"},
	},
	["item:1705:0:0:0:0:0:0"] = { -- Lesser moonstone
		["item:2771:0:0:0:0:0:0"] = {rate=.4, source="prospect"},
		["item:2772:0:0:0:0:0:0"] = { rate=.3, source="prospect"},
	},
	["item:1529:0:0:0:0:0:0"] = { -- Jade
		["item:2772:0:0:0:0:0:0"] = {rate=.4, source="prospect"},
		["item:2771:0:0:0:0:0:0"] = {rate=.03, source="prospect"},
	},
	["item:3864:0:0:0:0:0:0"] = { -- Citrine
		["item:2772:0:0:0:0:0:0"] = {rate=.4, source="prospect"}, --	iron
		["item:3858:0:0:0:0:0:0"] = {rate=.3, source="prospect"}, -- mith
		["item:2771:0:0:0:0:0:0"] = {rate=.03, source="prospect"}, -- tin
	},
	["item:7909:0:0:0:0:0:0"] = { -- Aquamarine
		["item:3858:0:0:0:0:0:0"] = {rate=.3, source="prospect"},
		["item:2772:0:0:0:0:0:0"] = {rate=.05, source="prospect"},
		["item:2771:0:0:0:0:0:0"] = {rate=.03, source="prospect"},
	},
	["item:7910:0:0:0:0:0:0"] = { -- Star Ruby
		["item:3858:0:0:0:0:0:0"] = {rate=.4, source="prospect"},
		["item:10620:0:0:0:0:0:0"] = {rate=.1, source="prospect"},
		["item:2772:0:0:0:0:0:0"] = {rate=.05, source="prospect"},
	},
	["item:12361:0:0:0:0:0:0"] = { -- Blue Sapphire
		["item:10620:0:0:0:0:0:0"] = {rate=.3, source="prospect"},
		["item:3858:0:0:0:0:0:0"] = {rate=.03, source="prospect"},
	},
	["item:12799:0:0:0:0:0:0"] = { -- Large Opal
		["item:10620:0:0:0:0:0:0"] = {rate =.3, source="prospect"}, -- thorium
		["item:3858:0:0:0:0:0:0"] = {rate=.03, source="prospect"}, -- Mith
	},
	["item:12800:0:0:0:0:0:0"] = { -- Azerothian Diamond
		["item:10620:0:0:0:0:0:0"] = {rate=.3, source="prospect"},
		["item:3858:0:0:0:0:0:0"] = {rate=.02, source="prospect"},
	},
	["item:12364:0:0:0:0:0:0"] = { -- Huge Emerald
		["item:10620:0:0:0:0:0:0"] = {rate=.3, source="prospect"},
		["item:3858:0:0:0:0:0:0"] = {rate=.02, source="prospect"},
	},

	-- uncommon gems
	["item:23117:0:0:0:0:0:0"] = { -- Azure Moonstone
		["item:23424:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
		["item:23425:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
	},
	["item:23077:0:0:0:0:0:0"] = { -- Blood Garnet
		["item:23424:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
		["item:23425:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
	},
	["item:23079:0:0:0:0:0:0"] = { -- Deep Peridot
		["item:23424:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
		["item:23425:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
	},
	["item:21929:0:0:0:0:0:0"] = { -- Flame Spessarite
		["item:23424:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
		["item:23425:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
	},
	["item:23112:0:0:0:0:0:0"] = { -- Golden Draenite
		["item:23424:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
		["item:23425:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
	},
	["item:23107:0:0:0:0:0:0"] = { -- Shadow Draenite
		["item:23424:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
		["item:23425:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
	},
	["item:36917:0:0:0:0:0:0"] = { -- Bloodstone
		["item:36909:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
		["item:36912:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
		["item:36910:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
	},
	["item:36923:0:0:0:0:0:0"] = { -- Chalcedony
		["item:36909:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
		["item:36912:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
		["item:36910:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
	},
	["item:36932:0:0:0:0:0:0"] = { -- Dark Jade
		["item:36909:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
		["item:36912:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
		["item:36910:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
	},
	["item:36929:0:0:0:0:0:0"] = { -- Huge Citrine
		["item:36909:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
		["item:36912:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
		["item:36910:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
	},
	["item:36926:0:0:0:0:0:0"] = { -- Shadow Crystal
		["item:36909:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
		["item:36912:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
		["item:36910:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
	},
	["item:36920:0:0:0:0:0:0"] = { -- Sun Crystal
		["item:36909:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
		["item:36912:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
		["item:36910:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
	},
	-- ["item:52182:0:0:0:0:0:0"] = { -- Jasper
		-- ["item:53038:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
		-- ["item:52185:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
		-- ["item:52183:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
	-- },
	-- ["item:52180:0:0:0:0:0:0"] = { -- Nightstone
		-- ["item:53038:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
		-- ["item:52185:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
		-- ["item:52183:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
	-- },
	-- ["item:52178:0:0:0:0:0:0"] = { -- Zephyrite
		-- ["item:53038:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
		-- ["item:52185:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
		-- ["item:52183:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
	-- },
	-- ["item:52179:0:0:0:0:0:0"] = { -- Alicite
		-- ["item:53038:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
		-- ["item:52185:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
		-- ["item:52183:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
	-- },
	-- ["item:52177:0:0:0:0:0:0"] = { -- Carnelian
		-- ["item:53038:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
		-- ["item:52185:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
		-- ["item:52183:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
	-- },
	-- ["item:52181:0:0:0:0:0:0"] = { -- Hessonite
		-- ["item:53038:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
		-- ["item:52185:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
		-- ["item:52183:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
	-- },
	-- ["item:76130:0:0:0:0:0:0"] = { -- Tiger Opal
		-- ["item:72092:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
		-- ["item:72093:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
		-- ["item:72103:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
		-- ["item:72094:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
	-- },
	-- ["item:76133:0:0:0:0:0:0"] = { -- Lapis Lazuli
		-- ["item:72092:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
		-- ["item:72093:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
		-- ["item:72103:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
		-- ["item:72094:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
	-- },
	-- ["item:76134:0:0:0:0:0:0"] = { -- Sunstone
		-- ["item:72092:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
		-- ["item:72093:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
		-- ["item:72103:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
		-- ["item:72094:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
	-- },
	-- ["item:76135:0:0:0:0:0:0"] = { -- Roguestone
		-- ["item:72092:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
		-- ["item:72093:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
		-- ["item:72103:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
		-- ["item:72094:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
	-- },
	-- ["item:76136:0:0:0:0:0:0"] = { -- Pandarian Garnet
		-- ["item:72092:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
		-- ["item:72093:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
		-- ["item:72103:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
		-- ["item:72094:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
	-- },
	-- ["item:76137:0:0:0:0:0:0"] = { -- Alexandrite
		-- ["item:72092:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
		-- ["item:72093:0:0:0:0:0:0"] = {rate=.25, source="prospect"},
		-- ["item:72103:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
		-- ["item:72094:0:0:0:0:0:0"] = {rate=.2, source="prospect"},
	-- },

	--Rare Gems
	["item:23440:0:0:0:0:0:0"] = { -- Dawnstone
		["item:23424:0:0:0:0:0:0"] = {rate=.01, source="prospect"},
		["item:23425:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
	},
	["item:23436:0:0:0:0:0:0"] = { -- Living Ruby
		["item:23424:0:0:0:0:0:0"] = {rate=.01, source="prospect"},
		["item:23425:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
	},
	["item:23441:0:0:0:0:0:0"] = { -- Nightseye
		["item:23424:0:0:0:0:0:0"] = {rate=.01, source="prospect"},
		["item:23425:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
	},
	["item:23439:0:0:0:0:0:0"] = { -- Noble Topaz
		["item:23424:0:0:0:0:0:0"] = {rate=.01, source="prospect"},
		["item:23425:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
	},
	["item:23438:0:0:0:0:0:0"] = { -- Star of Elune
		["item:23424:0:0:0:0:0:0"] = {rate=.01, source="prospect"},
		["item:23425:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
	},
	["item:23437:0:0:0:0:0:0"] = { -- Talasite
		["item:23424:0:0:0:0:0:0"] = {rate=.01, source="prospect"},
		["item:23425:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
	},
	["item:36921:0:0:0:0:0:0"] = { -- Autumn's Glow
		["item:36909:0:0:0:0:0:0"] = {rate=.01, source="prospect"},
		["item:36912:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
		["item:36910:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
	},
	["item:36933:0:0:0:0:0:0"] = { -- Forest Emerald
		["item:36909:0:0:0:0:0:0"] = {rate=.01, source="prospect"},
		["item:36912:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
		["item:36910:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
	},
	["item:36930:0:0:0:0:0:0"] = { -- Monarch Topaz
		["item:36909:0:0:0:0:0:0"] = {rate=.01, source="prospect"},
		["item:36912:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
		["item:36910:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
	},
	["item:36918:0:0:0:0:0:0"] = { -- Scarlet Ruby
		["item:36909:0:0:0:0:0:0"] = {rate=.01, source="prospect"},
		["item:36912:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
		["item:36910:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
	},
	["item:36924:0:0:0:0:0:0"] = { -- Sky Sapphire
		["item:36909:0:0:0:0:0:0"] = {rate=.01, source="prospect"},
		["item:36912:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
		["item:36910:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
	},
	["item:36927:0:0:0:0:0:0"] = { -- Twilight Opal
		["item:36909:0:0:0:0:0:0"] = {rate=.01, source="prospect"},
		["item:36912:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
		["item:36910:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
	},
	-- ["item:52192:0:0:0:0:0:0"] = { -- Dream Emerald
		-- ["item:53038:0:0:0:0:0:0"] = {rate=.08, source="prospect"},
		-- ["item:52185:0:0:0:0:0:0"] = {rate=.05, source="prospect"},
		-- ["item:52183:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
	-- },
	-- ["item:52193:0:0:0:0:0:0"] = { -- Ember Topaz
		-- ["item:53038:0:0:0:0:0:0"] = {rate=.08, source="prospect"},
		-- ["item:52185:0:0:0:0:0:0"] = {rate=.05, source="prospect"},
		-- ["item:52183:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
	-- },
	-- ["item:52190:0:0:0:0:0:0"] = { -- Inferno Ruby
		-- ["item:53038:0:0:0:0:0:0"] = {rate=.08, source="prospect"},
		-- ["item:52185:0:0:0:0:0:0"] = {rate=.05, source="prospect"},
		-- ["item:52183:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
	-- },
	-- ["item:52195:0:0:0:0:0:0"] = { -- Amberjewel
		-- ["item:53038:0:0:0:0:0:0"] = {rate=.08, source="prospect"},
		-- ["item:52185:0:0:0:0:0:0"] = {rate=.05, source="prospect"},
		-- ["item:52183:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
	-- },
	-- ["item:52194:0:0:0:0:0:0"] = { -- Demonseye
		-- ["item:53038:0:0:0:0:0:0"] = {rate=.08, source="prospect"},
		-- ["item:52185:0:0:0:0:0:0"] = {rate=.05, source="prospect"},
		-- ["item:52183:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
	-- },
	-- ["item:52191:0:0:0:0:0:0"] = { -- Ocean Sapphire
		-- ["item:53038:0:0:0:0:0:0"] = {rate=.08, source="prospect"},
		-- ["item:52185:0:0:0:0:0:0"] = {rate=.05, source="prospect"},
		-- ["item:52183:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
	-- },
	-- ["item:76131:0:0:0:0:0:0"] = { -- Primordial Ruby
		-- ["item:72092:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
		-- ["item:72093:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
		-- ["item:72103:0:0:0:0:0:0"] = {rate=.15, source="prospect"},
		-- ["item:72094:0:0:0:0:0:0"] = {rate=.15, source="prospect"},
	-- },
	-- ["item:76138:0:0:0:0:0:0"] = { -- River's Heart
		-- ["item:72092:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
		-- ["item:72093:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
		-- ["item:72103:0:0:0:0:0:0"] = {rate=.15, source="prospect"},
		-- ["item:72094:0:0:0:0:0:0"] = {rate=.15, source="prospect"},
	-- },
	-- ["item:76139:0:0:0:0:0:0"] = { -- Wild Jade
		-- ["item:72092:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
		-- ["item:72093:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
		-- ["item:72103:0:0:0:0:0:0"] = {rate=.15, source="prospect"},
		-- ["item:72094:0:0:0:0:0:0"] = {rate=.15, source="prospect"},
	-- },
	-- ["item:76140:0:0:0:0:0:0"] = { -- Vermillion Onyx
		-- ["item:72092:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
		-- ["item:72093:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
		-- ["item:72103:0:0:0:0:0:0"] = {rate=.15, source="prospect"},
		-- ["item:72094:0:0:0:0:0:0"] = {rate=.15, source="prospect"},
	-- },
	-- ["item:76141:0:0:0:0:0:0"] = { -- Imperial Amethyst
		-- ["item:72092:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
		-- ["item:72093:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
		-- ["item:72103:0:0:0:0:0:0"] = {rate=.15, source="prospect"},
		-- ["item:72094:0:0:0:0:0:0"] = {rate=.15, source="prospect"},
	-- },
	-- ["item:76142:0:0:0:0:0:0"] = { -- Sun's Radiance
		-- ["item:72092:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
		-- ["item:72093:0:0:0:0:0:0"] = {rate=.04, source="prospect"},
		-- ["item:72103:0:0:0:0:0:0"] = {rate=.15, source="prospect"},
		-- ["item:72094:0:0:0:0:0:0"] = {rate=.15, source="prospect"},
	-- },

	--transformations
	-- ["item:52719:0:0:0:0:0:0"] = { -- Greater Celestial Essence
		-- ["item:52718:0:0:0:0:0:0"] = {rate=1/3, source="transform"},
	-- },
	["item:52718:0:0:0:0:0:0"] = { -- Lesser Celestial Essence
		["item:52719:0:0:0:0:0:0"] = {rate=3, source="transform"},
	},
	["item:34055:0:0:0:0:0:0"] = { -- Greater Cosmic Essence
		["item:34056:0:0:0:0:0:0"] = {rate=1/3, source="transform"},
	},
	["item:34056:0:0:0:0:0:0"] = { -- Lesser Cosmic Essence
		["item:34055:0:0:0:0:0:0"] = {rate=3, source="transform"},
	},
	["item:22446:0:0:0:0:0:0"] = { -- Greater Planar Essence
		["item:22447:0:0:0:0:0:0"] = {rate=1/3, source="transform"},
	},
	["item:22447:0:0:0:0:0:0"] = { -- Lesser Planar Essence
		["item:22446:0:0:0:0:0:0"] = {rate=3, source="transform"},
	},
	["item:16203:0:0:0:0:0:0"] = { -- Greater Eternal Essence
		["item:16202:0:0:0:0:0:0"] = {rate=1/3, source="transform"},
	},
	["item:16202:0:0:0:0:0:0"] = { -- Lesser Eternal Essence
		["item:16203:0:0:0:0:0:0"] = {rate=3, source="transform"},
	},
	["item:11175:0:0:0:0:0:0"] = { -- Greater Nether Essence
		["item:11174:0:0:0:0:0:0"] = {rate=1/3, source="transform"},
	},
	["item:11174:0:0:0:0:0:0"] = { -- Lesser Nether Essence
		["item:11175:0:0:0:0:0:0"] = {rate=3, source="transform"},
	},
	["item:11135:0:0:0:0:0:0"] = { -- Greater Mystic Essence
		["item:11134:0:0:0:0:0:0"] = {rate=1/3, source="transform"},
	},
	["item:11134:0:0:0:0:0:0"] = { -- Lesser Mystic Essence
		["item:11135:0:0:0:0:0:0"] = {rate=3, source="transform"},
	},
	["item:11082:0:0:0:0:0:0"] = { -- Greater Astral Essence
		["item:10998:0:0:0:0:0:0"] = {rate=1/3, source="transform"},
	},
	["item:10998:0:0:0:0:0:0"] = { -- Lesser Astral Essence
		["item:11082:0:0:0:0:0:0"] = {rate=3, source="transform"},
	},
	["item:10939:0:0:0:0:0:0"] = { -- Greater Magic Essence
		["item:10938:0:0:0:0:0:0"] = {rate=3, source="transform"},
	},
	["item:10938:0:0:0:0:0:0"] = { -- Lesser Magic Essence
		["item:10939:0:0:0:0:0:0"] = {rate=1/3, source="transform"},
	},
	["item:52721:0:0:0:0:0:0"] = { -- Heavenly Shard
		["item:52720:0:0:0:0:0:0"] = {rate=1/3, source="transform"},
	},
	["item:34052:0:0:0:0:0:0"] = { -- Dream Shard
		["item:34053:0:0:0:0:0:0"] = {rate=1/3, source="transform"},
	},
	-- ["item:74247:0:0:0:0:0:0"] = { -- Ethereal Shard
		-- ["item:74252:0:0:0:0:0:0"] = {rate=1/3, source="transform"},
	-- },
	["item:22578:0:0:0:0:0:0"] = { -- Mote of Water
		["item:21885:0:0:0:0:0:0"] = {rate=10, source="transform"},
	},
	["item:21885:0:0:0:0:0:0"] = { -- Primal Water
		["item:22578:0:0:0:0:0:0"] = {rate=1/10, source="transform"},
	},
	["item:22577:0:0:0:0:0:0"] = { -- Mote of Shadow
		["item:22456:0:0:0:0:0:0"] = {rate=10, source="transform"},
	},
	["item:22456:0:0:0:0:0:0"] = { -- Primal Shadow
		["item:22577:0:0:0:0:0:0"] = {rate=1/10, source="transform"},
	},
	["item:22576:0:0:0:0:0:0"] = { -- Mote of Mana
		["item:22457:0:0:0:0:0:0"] = {rate=10, source="transform"},
	},
	["item:22457:0:0:0:0:0:0"] = { -- Primal Mana
		["item:22576:0:0:0:0:0:0"] = {rate=1/10, source="transform"},
	},
	["item:22575:0:0:0:0:0:0"] = { -- Mote of Life
		["item:21886:0:0:0:0:0:0"] = {rate=10, source="transform"},
	},
	["item:21886:0:0:0:0:0:0"] = { -- Primal Life
		["item:22575:0:0:0:0:0:0"] = {rate=1/10, source="transform"},
	},
	["item:22573:0:0:0:0:0:0"] = { -- Mote of Earth
		["item:22452:0:0:0:0:0:0"] = {rate=10, source="transform"},
	},
	["item:22452:0:0:0:0:0:0"] = { -- Primal Earth
		["item:22573:0:0:0:0:0:0"] = {rate=1/10, source="transform"},
	},
	["item:22574:0:0:0:0:0:0"] = { -- Mote of Air
		["item:21884:0:0:0:0:0:0"] = {rate=10, source="transform"},
	},
	["item:21884:0:0:0:0:0:0"] = { -- Primal Air
		["item:22574:0:0:0:0:0:0"] = {rate=1/10, source="transform"},
	},
	["item:37700:0:0:0:0:0:0"] = { -- Crystallized Air
		["item:35623:0:0:0:0:0:0"] = {rate=10, source="transform"},
	},
	["item:35623:0:0:0:0:0:0"] = { -- Eternal Air
		["item:37700:0:0:0:0:0:0"] = {rate=1/10, source="transform"},
	},
	["item:37701:0:0:0:0:0:0"] = { -- Crystallized Earth
		["item:35624:0:0:0:0:0:0"] = {rate=10, source="transform"},
	},
	["item:35624:0:0:0:0:0:0"] = { -- Eternal Earth
		["item:37701:0:0:0:0:0:0"] = {rate=1/10, source="transform"},
	},
	["item:37702:0:0:0:0:0:0"] = { -- Crystallized Fire
		["item:36860:0:0:0:0:0:0"] = {rate=10, source="transform"},
	},
	["item:36860:0:0:0:0:0:0"] = { -- Eternal Fire
		["item:37702:0:0:0:0:0:0"] = {rate=1/10, source="transform"},
	},
	["item:37703:0:0:0:0:0:0"] = { -- Crystallized Shadow
		["item:35627:0:0:0:0:0:0"] = {rate=10, source="transform"},
	},
	["item:35627:0:0:0:0:0:0"] = { -- Eternal Shadow
		["item:37703:0:0:0:0:0:0"] = {rate=1/10, source="transform"},
	},
	["item:37704:0:0:0:0:0:0"] = { -- Crystallized Life
		["item:35625:0:0:0:0:0:0"] = {rate=10, source="transform"},
	},
	["item:35625:0:0:0:0:0:0"] = { -- Eternal Life
		["item:37704:0:0:0:0:0:0"] = {rate=1/10, source="transform"},
	},
	["item:37705:0:0:0:0:0:0"] = { -- Crystallized Water
		["item:35622:0:0:0:0:0:0"] = {rate=10, source="transform"},
	},
	["item:35622:0:0:0:0:0:0"] = { -- Eternal Water
		["item:37705:0:0:0:0:0:0"] = {rate=1/10, source="transform"},
	},

	--vendor trades
	["item:37101:0:0:0:0:0:0"] = { -- Ivory Ink
		["item:79254:0:0:0:0:0:0"] = {rate=1, source="vendortrade"},
	},
	["item:39469:0:0:0:0:0:0"] = { -- Moonglow Ink
		["item:79254:0:0:0:0:0:0"] = {rate=1, source="vendortrade"},
	},
	["item:39774:0:0:0:0:0:0"] = { -- Midnight Ink
		["item:79254:0:0:0:0:0:0"] = {rate=1, source="vendortrade"},
	},
	["item:43116:0:0:0:0:0:0"] = { -- Lion's Ink
		["item:79254:0:0:0:0:0:0"] = {rate=1, source="vendortrade"},
	},
	["item:43118:0:0:0:0:0:0"] = { -- Jadefire Ink
		["item:79254:0:0:0:0:0:0"] = {rate=1, source="vendortrade"},
	},
	["item:43120:0:0:0:0:0:0"] = { -- Celestial Ink
		["item:79254:0:0:0:0:0:0"] = {rate=1, source="vendortrade"},
	},
	["item:43122:0:0:0:0:0:0"] = { -- Shimmering Ink
		["item:79254:0:0:0:0:0:0"] = {rate=1, source="vendortrade"},
	},
	["item:43124:0:0:0:0:0:0"] = { -- Ethereal Ink
		["item:79254:0:0:0:0:0:0"] = {rate=1, source="vendortrade"},
	},
	["item:43126:0:0:0:0:0:0"] = { -- Ink of the Sea
		["item:79254:0:0:0:0:0:0"] = {rate=1, source="vendortrade"},
	},
	["item:43127:0:0:0:0:0:0"] = { -- Snowfall Ink
		["item:79254:0:0:0:0:0:0"] = {rate=1/10, source="vendortrade"},
	},
	-- ["item:61978:0:0:0:0:0:0"] = { -- Blackfallow Ink
		-- ["item:79254:0:0:0:0:0:0"] = {rate=1, source="vendortrade"},
	-- },
	-- ["item:61981:0:0:0:0:0:0"] = { -- Inferno Ink
		-- ["item:79254:0:0:0:0:0:0"] = {rate=1/10, source="vendortrade"},
	-- },
	-- ["item:79255:0:0:0:0:0:0"] = { -- Starlight Ink
		-- ["item:79254:0:0:0:0:0:0"] = {rate=1/10, source="vendortrade"},
	-- },
}

A.DestroyData.Inks = {
	-- uncommon inks
	["item:37101:0:0:0:0:0:0"] = {pigment="item:39151:0:0:0:0:0:0", pigmentPerInk=1}, -- Ivory Ink
	["item:39469:0:0:0:0:0:0"] = {pigment="item:39151:0:0:0:0:0:0", pigmentPerInk=2}, -- Moonglow Ink
	["item:39774:0:0:0:0:0:0"] = {pigment="item:39334:0:0:0:0:0:0", pigmentPerInk=2}, -- Midnight Ink
	["item:43116:0:0:0:0:0:0"] = {pigment="item:39338:0:0:0:0:0:0", pigmentPerInk=2}, -- Lion's Ink
	["item:43118:0:0:0:0:0:0"] = {pigment="item:39339:0:0:0:0:0:0", pigmentPerInk=2}, -- Jadefire Ink
	["item:43120:0:0:0:0:0:0"] = {pigment="item:39340:0:0:0:0:0:0", pigmentPerInk=2}, -- Celestial Ink
	["item:43122:0:0:0:0:0:0"] = {pigment="item:39341:0:0:0:0:0:0", pigmentPerInk=2}, -- Shimmering Ink
	["item:43124:0:0:0:0:0:0"] = {pigment="item:39342:0:0:0:0:0:0", pigmentPerInk=2}, -- Ethereal Ink
	["item:43126:0:0:0:0:0:0"] = {pigment="item:39343:0:0:0:0:0:0", pigmentPerInk=2}, -- Ink of the Sea
	-- ["item:61978:0:0:0:0:0:0"] = {pigment="item:61979:0:0:0:0:0:0", pigmentPerInk=2}, -- Blackfallow Ink
	-- ["item:79254:0:0:0:0:0:0"] = {pigment="item:79251:0:0:0:0:0:0", pigmentPerInk=2}, -- Ink of Dreams
	
	-- rare inks
	["item:43115:0:0:0:0:0:0"] = {pigment="item:43103:0:0:0:0:0:0", pigmentPerInk=1}, -- Hunter's Ink
	["item:43117:0:0:0:0:0:0"] = {pigment="item:43104:0:0:0:0:0:0", pigmentPerInk=1}, -- Dawnstar Ink
	["item:43119:0:0:0:0:0:0"] = {pigment="item:43105:0:0:0:0:0:0", pigmentPerInk=1}, -- Royal Ink
	["item:43121:0:0:0:0:0:0"] = {pigment="item:43106:0:0:0:0:0:0", pigmentPerInk=1}, -- Fiery Ink
	["item:43123:0:0:0:0:0:0"] = {pigment="item:43107:0:0:0:0:0:0", pigmentPerInk=1}, -- Ink of the Sky
	["item:43125:0:0:0:0:0:0"] = {pigment="item:43108:0:0:0:0:0:0", pigmentPerInk=1}, -- Darkflame Ink
	["item:43127:0:0:0:0:0:0"] = {pigment="item:43109:0:0:0:0:0:0", pigmentPerInk=2}, -- Snowfall Ink
	-- ["item:61981:0:0:0:0:0:0"] = {pigment="item:61980:0:0:0:0:0:0", pigmentPerInk=2}, -- Inferno Ink
	-- ["item:79255:0:0:0:0:0:0"] = {pigment="item:79253:0:0:0:0:0:0", pigmentPerInk=2}, -- Starlight Ink
}

--------------------------------------------------------------------------------
-- Phase 4: Disenchant range index
-- Build once: class -> quality -> { min, max, matID, amount }[]
-- Avoids nested full-table scan on every GetInternalDisenchantValue call.
--------------------------------------------------------------------------------
local deRangeIndex = nil
local internalDEValueCache = {} -- "class:quality:ilvl" -> { gen, value }
local internalDEValueGen = 0

function A.BuildDisenchantIndex()
    deRangeIndex = {}
    if not A.DestroyData or not A.DestroyData.Disenchanting then return end
    for _, data in ipairs(A.DestroyData.Disenchanting) do
        for matString, itemData in pairs(data) do
            if type(matString) == "string" and type(itemData) == "table" and itemData.itemTypes then
                local matID = tonumber(matString:match("item:(%d+)"))
                if matID then
                    for class, qualities in pairs(itemData.itemTypes) do
                        if type(qualities) == "table" then
                            for q, ranges in pairs(qualities) do
                                if type(ranges) == "table" then
                                    deRangeIndex[class] = deRangeIndex[class] or {}
                                    deRangeIndex[class][q] = deRangeIndex[class][q] or {}
                                    local bucket = deRangeIndex[class][q]
                                    for i = 1, #ranges do
                                        local deData = ranges[i]
                                        bucket[#bucket + 1] = {
                                            minItemLevel = deData.minItemLevel,
                                            maxItemLevel = deData.maxItemLevel,
                                            matID = matID,
                                            amountOfMats = deData.amountOfMats or 0,
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function A.InvalidateInternalDECache()
    internalDEValueGen = internalDEValueGen + 1
    wipe(internalDEValueCache)
end

-- Utility function to get disenchant value from our internal table
function A.GetInternalDisenchantValue(itemLink, itemID, quality, iLvl, itemClass)
    if not itemID then return 0 end
    if itemClass ~= ARMOR and itemClass ~= WEAPON then return 0 end
    iLvl = iLvl or 0
    quality = quality or 0

    if not deRangeIndex then
        A.BuildDisenchantIndex()
    end

    local cacheKey = tostring(itemClass) .. ":" .. tostring(quality) .. ":" .. tostring(iLvl)
    local cached = internalDEValueCache[cacheKey]
    if cached and cached.gen == internalDEValueGen then
        return cached.value
    end

    local value = 0
    local ranges = deRangeIndex[itemClass] and deRangeIndex[itemClass][quality]
    if ranges then
        for i = 1, #ranges do
            local deData = ranges[i]
            if iLvl >= deData.minItemLevel and iLvl <= deData.maxItemLevel then
                local matLink = "item:" .. deData.matID .. ":0:0:0:0:0:0"
                local matPrice = A.GetAuctionPriceFromAPI and A.GetAuctionPriceFromAPI(matLink) or 0
                value = value + (matPrice * deData.amountOfMats)
            end
        end
    end

    internalDEValueCache[cacheKey] = { gen = internalDEValueGen, value = value }
    return value
end

-- Utility function to get prospect/mill value
function A.GetInternalConversionValue(itemID, source)
    if not itemID then return 0 end
    local itemString = "item:" .. itemID .. ":0:0:0:0:0:0"
    
    local conversions = A.DestroyData.Conversions[itemString]
    if not conversions then return 0 end
    
    local totalValue = 0
    for targetString, info in pairs(conversions) do
        if info.source == source then
            local targetID = tonumber(targetString:match("item:(%d+)"))
            if targetID then
                local targetPrice = A.GetAuctionPriceFromAPI and A.GetAuctionPriceFromAPI(targetID) or 0
                -- Typically we get 1 / info.rate of the target item per source item
                totalValue = totalValue + (targetPrice / (info.rate or 1))
            end
        end
    end
    
    -- In TSM, for milling/prospecting, typically you get the inverse rate? 
    -- Actually TSM API uses price / info.rate. Example: 5 herbs -> 1 pigment (rate 5?), so rate = 5, price of 1 herb = price_pigment / 5.
    -- We need to check if rate is how many source items per target item, or target items per source item.
    -- Wait, TSM code says: tinsert(prices, price/info.rate). This means cost of source item is min(price of target / rate).
    -- Wait, so value of source item is targetPrice * rate, if rate was target_yield. 
    -- Let's look at rate in TSM: TSM has rate=.5 for Alabaster Pigment from Peacebloom. That means 1 Peacebloom yields 0.5 Pigment.
    -- So value of 1 Peacebloom = value of Pigment * 0.5. So `targetPrice * info.rate`.
    return totalValue
end
