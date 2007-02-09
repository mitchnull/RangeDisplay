-- English (default). Override these for other locales.

local L = SpellCaster.L

-- config dialog
L.CONFIG_AUTOBAR = 		 "Enable AutoBar";
L.CONFIG_TOOLTIP_GUILD = "Enable guild display in tooltip";
L.CONFIG_TOOLTIP_RANGE = "Enable range display in tooltip";
L.CONFIG_RANGECHECK = "Enable RangeCheck";

-- RangeCheck stuff
local L_RC = SpellCaster.RangeCheck.L;
-- L_RC.OutOfRange = "Out of range";
L_RC.RangePattern = "(%d+) yd range";
-- list of friendly spells that have different ranges
L_RC.FriendSpells = {};
-- list of harmful spells that have different ranges
L_RC.HarmSpells = {};
L_RC.FriendSpells["Mage"] = { "Remove Lesser Curse" };
L_RC.HarmSpells["Mage"] = { "Fire Blast", "Arcane Missiles", "Frostbolt", "Scorch", "Fireball", "Detect Magic" };

