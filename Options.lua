local AceConfig = LibStub("AceConfig-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(RangeDisplay.AppName)
local SML = LibStub:GetLibrary("LibSharedMedia-3.0", true)
local rc = LibStub("LibRangeCheck-2.0")

local function getFonts()
	local fonts = SML and SML:List("font") or { [1] = DefaultFontName }
	local res = {}
	for i, v in ipairs(fonts) do
		res[v] = v
	end
	return res
end

local FontOutlines = {
	[""] = L["None"],
	["OUTLINE"] = L["Normal"],
	["THICKOUTLINE"] = L["Thick"],
}

local FrameStratas = {
	["HIGH"] = L["High"],
	["MEDIUM"] = L["Medium"],
	["LOW"] = L["Low"],
}

local options = {
	type = "group",
	name = RangeDisplay.AppName,
	handler = RangeDisplay,
	get = "getOption",
	set = "setOption",
	args = {
		locked = {
			type = 'toggle',
			name = L["Locked"],
			desc = L["Lock/Unlock display frame"],
			order = 110,
		},
		enemyOnly = {
			type = 'toggle',
			name = L["Enemy only"],
			desc = L["Show range for enemy targets only"],
			order = 115,
		},
		maxRangeOnly = {
			type = 'toggle',
			name = L["Max range only"],
			desc = L["Show the maximum range only"],
			order = 116,
		},
		outOfRangeDisplay = {
			type = 'toggle',
			name = L["Out of range display"],
			desc = L["Show/Hide display if the target is out of range"],
			order = 120,
		},
		checkVisibility = {
			type = 'toggle',
			name = L["Check visibility"],
			desc = L["If set, the max range to check will be 'visibility range'"],
			order = 130,
		},
		font = {
			type = 'select',
			name = L["Font"],
			desc = L["Font"],
			values = getFonts,
			order = 135
		},
		fontSize = {
			type = 'range',
			name = L["Font size"],
			desc = L["Font size"],
			min = MinFontSize,
			max = MaxFontSize,
			step = 1,
			order = 140,
		},
		fontOutline = {
			type = 'select',
			name = L["Font outline"],
			desc = L["Font outline"],
			values = FontOutlines,
			order = 150,
		},
		color = {
			type = 'color',
			hasAlpha = true,
			name = L["Default color"],
			desc = L["Default color"],
			set = "setColor",
			get = "getColor",
			order = 160,
		},
		oorSection = {
			type = 'group',
			name = L["Out of range section"],
			desc = L["Out of range section"],
			guiInline = true,
			order = 170,
			args = {
				enabled = {
					type = 'toggle',
					name = "", -- L["Enabled"],
					desc = L["Enable this color section"],
					set = "setSectionOption",
					get = "getSectionOption",
					width = 'half',
					order = 10,
				},
				color = {
					type = 'color',
					hasAlpha = true,
					name = L["Color"],
					desc = L["Color"],
					disabled = "isSectionDisabled",
					set = "setSectionColor",
					get = "getSectionColor",
					width = 'half',
					order = 20,
				},
				range = {
					type = 'range',
					name = L["Range limit"],
					desc = L["Range limit"],
					disabled = "isSectionDisabled",
					set = "setSectionOption",
					get = "getSectionOption",
					min = MinRangeLimit,
					max = MaxRangeLimit,
					step = 1,
					order = 30,
				},
			},
		},
		srSection = {
			type = 'group',
			name = L["Short range section"],
			desc = L["Short range section"],
			guiInline = true,
			order = 175,
			args = {
				enabled = {
					type = 'toggle',
					name = "", -- L["Enabled"],
					desc = L["Enable this color section"],
					set = "setSectionOption",
					get = "getSectionOption",
					width = 'half',
					order = 10,
				},
				color = {
					type = 'color',
					hasAlpha = true,
					name = L["Color"],
					desc = L["Color"],
					disabled = "isSectionDisabled",
					set = "setSectionColor",
					get = "getSectionColor",
					width = 'half',
					order = 20,
				},
				range = {
					type = 'range',
					name = L["Range limit"],
					desc = L["Range limit"],
					disabled = "isSectionDisabled",
					set = "setSectionOption",
					get = "getSectionOption",
					min = MinRangeLimit,
					max = MaxRangeLimit,
					step = 1,
					order = 30,
				},
			},
		},
		mrSection = {
			type = 'group',
			name = L["Melee range section"],
			desc = L["Melee range section"],
			guiInline = true,
			order = 180,
			args = {
				enabled = {
					type = 'toggle',
					name = "", -- L["Enabled"],
					desc = L["Enable this color section"],
					set = "setSectionOption",
					get = "getSectionOption",
					width = 'half',
					order = 10,
				},
				color = {
					type = 'color',
					hasAlpha = true,
					name = L["Color"],
					desc = L["Color"],
					disabled = "isSectionDisabled",
					set = "setSectionColor",
					get = "getSectionColor",
					width = 'half',
					order = 20,
				},
			},
		},
		dzSection = {
			type = 'group',
			name = L["Dead zone section"],
			desc = L["Dead zone section"],
			guiInline = true,
			order = 185,
			args = {
				enabled = {
					type = 'toggle',
					name = "", -- L["Enabled"],
					desc = L["Enable this color section"],
					set = "setSectionOption",
					get = "getSectionOption",
					width = 'half',
					order = 10,
				},
				color = {
					type = 'color',
					hasAlpha = true,
					name = L["Color"],
					desc = L["Color"],
					disabled = "isSectionDisabled",
					set = "setSectionColor",
					get = "getSectionColor",
					width = 'half',
					order = 20,
				},
			},
		},
		suffix = {
			type = 'input',
			name = L["Suffix"],
			desc = L["A free-form suffix to append to the range display when you are in range"],
			order = 190,
		},
		oorSuffix = {
			type = 'input',
			name = L["Out of range suffix"],
			desc = L["A free-form suffix to append to the range display when you are out of range"],
			order = 195,
		},
		strata = {
			type = 'select',
			name = L["Strata"],
			desc = L["Frame strata"],
			values = FrameStratas,
			order = 200,
		},
        config = {
            type = 'execute',
            name = L["Configure"],
            desc = L["Bring up GUI configure dialog"],
            guiHidden = true,
            order = 300,
            func = function() RangeDisplay:openConfigDialog() end,
        },
	},
}

function RangeDisplay:setupOptions()
	self:addConfigTab('main', options, 10, true)
	self:addConfigTab('profiles', AceDBOptions:GetOptionsTable(self.db), 20, false)
	if (self.db.profile.debug) then
		local debugOptions = {
			type = 'group',
			name = "Debug",
			args = {
				startMeasurement = {
					type = 'execute',
					name = "StartMeasurement",
					desc = "StartMeasurement",
					func = function()
						if (not self.db.profile.measurements) then
							self.db.profile.measurements = {}
						end
						self.db.profile.measurements[UnitName("player")] = {}
						rc:startMeasurement("target", self.db.profile.measurements[UnitName("player")])
					end,
				},
				stopMeasurement = {
					type = 'execute',
					name = "StopMeasurement",
					desc = "StopMeasurement",
					func = function()
						rc:stopMeasurement()
					end,
				},
				clearMeasurement = {
					type = 'execute',
					name = "ClearMeasurement",
					desc = "ClearMeasurement",
					func = function()
						self.db.profile.measurements = nil
					end,
				},
				cacheAllItems = {
					type = 'execute',
					name = "CacheAllItems",
					desc = "CacheAllItems",
					func = function()
						rc:cacheAllItems()
					end,
				},
				checkAllItems = {
					type = 'execute',
					name = "CheckAllItems",
					desc = "CheckAllItems",
					func = function()
						rc:checkAllItems()
					end,
				},
			},
		}
		self:addConfigTab('debug', debugOptions, 100, true)
	end
    AceConfig:RegisterOptionsTable(self.AppName, self.configOptions, "rangedisplay")
	ACD:SetDefaultSize(self.AppName, 400, 600)
	ACD:AddToBlizOptions(self.AppName)
	if (EarthFeature_AddButton) then
		EarthFeature_AddButton(
			{
				id= "RangeDisplay";
				name= L["Range Display"];
				subtext= "RangeDisplay";
				tooltip = L["Estimated range display"];
				icon= "Interface\\Icons\\Spell_Shadow_Charm";
				callback= function() RangeDisplay:openConfigDialog() end;
			}
		)
	end
end

function RangeDisplay:openConfigDialog()
    ACD:Open(self.AppName)
end

function RangeDisplay:getOption(info)
	return self.db.profile[info[#info]]
end

function RangeDisplay:setOption(info, value)
	self.db.profile[info[#info]] = value
	self:applySettings()
end

function RangeDisplay:getColor(info)
	local color = self.db.profile[info[#info]]
	return color.r, color.g, color.b, color.a
end

function RangeDisplay:setColor(info, r, g, b, a)
	local color = self.db.profile[info[#info]]
	color.r, color.g, color.b, color.a = r, g, b, a
	if (self:IsEnabled()) then
		self.rangeFrameText:SetTextColor(r, g, b, a)
	end
end

function RangeDisplay:getSectionOption(info)
	return self.db.profile[info[#info - 1]][info[#info]]
end

function RangeDisplay:setSectionOption(info, value)
	self.db.profile[info[#info - 1]][info[#info]] = value
	self:applySettings()
end

function RangeDisplay:getSectionColor(info)
	local color = self.db.profile[info[#info - 1]][info[#info]]
	return color.r, color.g, color.b, color.a
end

function RangeDisplay:setSectionColor(info, r, g, b, a)
	local color = self.db.profile[info[#info - 1]][info[#info]]
	color.r, color.g, color.b, color.a = r, g, b, a
	if (self:IsEnabled()) then
		self.rangeFrameText:SetTextColor(r, g, b, a)
	end
end

function RangeDisplay:isSectionDisabled(info)
	return (not self.db.profile[info[#info - 1]]["enabled"])
end

function RangeDisplay:addConfigTab(key, group, order, isCmdInline)
	if (not self.configOptions) then
		self.configOptions = {
			type = "group",
			name = self.AppName,
			childGroups = "tab",
			args = {},
		}
	end
	self.configOptions.args[key] = group
	self.configOptions.args[key].order = order
	self.configOptions.args[key].cmdInline = isCmdInline
end

