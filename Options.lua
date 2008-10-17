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
		main = {
			type = 'group',
			childGroups = 'tab',
			inline = true,
			name = RangeDisplay.AppName,
			handler = RangeDisplay,
			get = "getOption",
			set = "setOption",
			order = 10,
			args = {
				locked = {
					type = 'toggle',
					name = L["Locked"],
					desc = L["Lock/Unlock display frame"],
					order = 110,
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
		},
	},
}

local function addUnitOptions(unit, order)
	local opts = {
		type = 'group',
		name = L[unit],
		handler = RangeDisplay,
		get = "getUnitOption",
		set = "setUnitOption",
		order = order or 200,
		args = {
			enabled = {
				type = 'toggle',
				name = L["Enabled"],
				order = 114,
			},
			enemyOnly = {
				type = 'toggle',
				disabled = "isUnitDisabled",
				name = L["Enemy only"],
				desc = L["Show range for enemy targets only"],
				order = 115,
			},
			maxRangeOnly = {
				type = 'toggle',
				disabled = "isUnitDisabled",
				name = L["Max range only"],
				desc = L["Show the maximum range only"],
				order = 116,
			},
			outOfRangeDisplay = {
				type = 'toggle',
				disabled = "isUnitDisabled",
				name = L["Out of range display"],
				desc = L["Show/Hide display if the target is out of range"],
				order = 120,
			},
			checkVisibility = {
				type = 'toggle',
				disabled = "isUnitDisabled",
				name = L["Check visibility"],
				desc = L["If set, the max range to check will be 'visibility range'"],
				order = 130,
			},
			font = {
				type = 'select',
				disabled = "isUnitDisabled",
				name = L["Font"],
				desc = L["Font"],
				values = getFonts,
				order = 135
			},
			fontSize = {
				type = 'range',
				disabled = "isUnitDisabled",
				name = L["Font size"],
				desc = L["Font size"],
				min = MinFontSize,
				max = MaxFontSize,
				step = 1,
				order = 140,
			},
			fontOutline = {
				type = 'select',
				disabled = "isUnitDisabled",
				name = L["Font outline"],
				desc = L["Font outline"],
				values = FontOutlines,
				order = 150,
			},
			-- we monkey around a bit with default color for nicer gui/cmd line
			defaultSection = {
				type = 'group',
				name = L["Default section"],
				name = L["Default section"],
				inline = true,
				cmdHidden = true,
				disabled = "isUnitDisabled",
				order = 160,
				args = {
					enabled = {
						type = 'toggle',
						width = 'half',
						disabled = true,
						cmdHidden = true,
						name = "",
						set = function() end,
						get = function() return true end,
						order = 10,
					},
					color = {
						type = 'color',
						disabled = "isUnitDisabled",
						width = 'half',
						hasAlpha = true,
						name = L["Color"],
						desc = L["Color"],
						set = "setUnitColor",
						get = "getUnitColor",
						order = 20,
					},
				},
			},
			color = {
				type = 'color',
				disabled = "isUnitDisabled",
				guiHidden = true,
				width = 'half',
				hasAlpha = true,
				name = L["Color"],
				desc = L["Color"],
				set = "setUnitColor",
				get = "getUnitColor",
				order = 160,
			},
			oorSection = {
				type = 'group',
				disabled = "isUnitDisabled",
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
			mrSection = {
				type = 'group',
				disabled = "isUnitDisabled",
				name = L["Medium range section"],
				desc = L["Medium range section"],
				guiInline = true,
				order = 173,
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
				disabled = "isUnitDisabled",
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
			mlrSection = {
				type = 'group',
				disabled = "isUnitDisabled",
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
			suffix = {
				type = 'input',
				disabled = "isUnitDisabled",
				name = L["Suffix"],
				desc = L["A free-form suffix to append to the range display when you are in range"],
				order = 190,
			},
			oorSuffix = {
				type = 'input',
				disabled = "isUnitDisabled",
				name = L["Out of range suffix"],
				desc = L["A free-form suffix to append to the range display when you are out of range"],
				order = 195,
			},
			strata = {
				type = 'select',
				disabled = "isUnitDisabled",
				name = L["Strata"],
				desc = L["Frame strata"],
				values = FrameStratas,
				order = 200,
			},
		},
	}
	options.args[unit] = opts
	return opts
end

function RangeDisplay:registerSubOptions(name, opts)
	local appName = self.AppName .. "." .. name
	AceConfig:RegisterOptionsTable(appName, opts)
	return ACD:AddToBlizOptions(appName, opts.name or name, self.AppName)
end

function RangeDisplay:setupOptions()
	AceConfig:RegisterOptionsTable(self.AppName, options.args.main)
	self.opts = ACD:AddToBlizOptions(self.AppName, self.AppName)
	for unit, ud in pairs(self.units) do
		local unitOpts = addUnitOptions(unit, ud.order)
		ud.opts = self:registerSubOptions(unit, unitOpts)
	end
	local profiles =  AceDBOptions:GetOptionsTable(self.db)
	profiles.order = 900
	options.args.profiles = profiles
	self.profiles = self:registerSubOptions('profiles', profiles)
	if (self.db.profile.debug) then
		local debugOptions = {
			type = 'group',
			name = "Debug",
			inline = true,
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
		options.args.debug = debugOptions
		self:registerSubOptions('debug', debugOptions)
	end
    AceConfig:RegisterOptionsTable(self.AppName .. 'Cmd', options, "rangedisplay")
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

function RangeDisplay:openConfigDialog(ud)
	if (ud) then
		InterfaceOptionsFrame_OpenToCategory(ud.opts)
	else
		InterfaceOptionsFrame_OpenToCategory(self.opts)
	end
end

function RangeDisplay:getOption(info)
	return self.db.profile[info[#info]]
end

function RangeDisplay:setOption(info, value)
	self.db.profile[info[#info]] = value
	self:applySettings()
end

function RangeDisplay:getUnitOption(info)
	local udb = self.db.profile.units[info[#info - 1]]
	return udb[info[#info]]
end

function RangeDisplay:setUnitOption(info, value)
	local udb = self.db.profile.units[info[#info - 1]]
	udb[info[#info]] = value
	self:applySettings()
end

function RangeDisplay:getUnitColor(info)
	local udb = self.db.profile.units[info[#info - 1]]
	local color = udb[info[#info]]
	return color.r, color.g, color.b, color.a
end

function RangeDisplay:setUnitColor(info, r, g, b, a)
	local unit = info[#info - 1]
	local udb = self.db.profile.units[unit]
	local color = udb[info[#info]]
	color.r, color.g, color.b, color.a = r, g, b, a
	if (self:IsEnabled()) then
		local ud = self.units[unit]
		if (ud.db.enabled) then
			ud.rangeFrameText:SetTextColor(r, g, b, a)
		end
	end
end

function RangeDisplay:getSectionOption(info)
	local udb = self.db.profile.units[info[#info - 2]]
	return udb[info[#info - 1]][info[#info]]
end

function RangeDisplay:setSectionOption(info, value)
	local udb = self.db.profile.units[info[#info - 2]]
	udb[info[#info - 1]][info[#info]] = value
	self:applySettings()
end

function RangeDisplay:getSectionColor(info)
	local udb = self.db.profile.units[info[#info - 2]]
	local color = udb[info[#info - 1]][info[#info]]
	return color.r, color.g, color.b, color.a
end

function RangeDisplay:setSectionColor(info, r, g, b, a)
	local unit = info[#info - 2]
	local udb = self.db.profile.units[unit]
	local color = udb[info[#info - 1]][info[#info]]
	color.r, color.g, color.b, color.a = r, g, b, a
	if (self:IsEnabled()) then
		local ud = self.units[unit]
		if (ud.db.enabled) then
			ud.rangeFrameText:SetTextColor(r, g, b, a)
		end
	end
end

function RangeDisplay:isUnitDisabled(info)
	--local udb = self.db.profile.units[info[#info - 1]]
	--return (not (udb["enabled"]))
end

function RangeDisplay:isSectionDisabled(info)
	--local udb = self.db.profile.units[info[#info - 2]]
	--return (not (udb["enabled"] and udb[info[#info - 1]]["enabled"]))
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

