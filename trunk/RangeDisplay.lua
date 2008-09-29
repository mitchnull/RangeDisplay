--[[
Name: RangeDisplay
Revision: $Revision$
Author(s): mitch0
Website: http://www.wowace.com/wiki/RangeDisplay
Documentation: http://www.wowace.com/wiki/RangeDisplay
SVN: http://svn.wowace.com/wowace/trunk/RangeDisplay/
Description: RangeDisplay displays the estimated range to the current target based on spell ranges and other measurable ranges
Dependencies: LibStub, LibRangeCheck-2.0, Ace3, LibSharedMedia-3.0(optional)
License: Public Domain
]]

local AppName = "RangeDisplay"
local VERSION = AppName .. "-r" .. ("$Revision$"):match("%d+")

local rc = LibStub("LibRangeCheck-2.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(AppName)
local SML = LibStub:GetLibrary("LibSharedMedia-3.0", true)

-- internal vars

local db
local lastUpdate = 0 -- time since last real update
local lastMinRange, lastMaxRange
local _ -- throwaway

-- cached stuff

local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitCanAttack = UnitCanAttack
local UnitIsUnit = UnitIsUnit

-- hard-coded config stuff

local UpdateDelay = .1 -- update frequency == 1/UpdateDelay
local MinFontSize = 5
local MaxFontSize = 40
local DefaultFontName = "Friz Quadrata TT"
local DefaultFontPath = GameFontNormal:GetFont()

---------------------------------

RangeDisplay = LibStub("AceAddon-3.0"):NewAddon(AppName, "AceConsole-3.0", "AceEvent-3.0")
RangeDisplay:SetDefaultModuleState(false)

RangeDisplay.version = VERSION

-- Default DB stuff

local defaults = {
	profile = {
		font = DefaultFontName,
		fontSize = 24,
		fontOutline = "",
		outOfRangeDisplay = false,
		checkVisibility = false,
		enemyOnly = false,
		maxRangeOnly = false,
		locked = false,
		point = "CENTER",
		relPoint = "CENTER",
		x = 0,
		y = 0,
		colorR = 1.0,
		colorG = 0.82,
		colorB = 0,
		oorColorR = 1.0,
		oorColorG = 0.82,
		oorColorB = 0,
		suffix = "",
		oorSuffix = " +",
		strata = "HIGH",
	},
}

-- options table stuff

local Fonts = SML and SML:List("font") or { [1] = DefaultFontName }

local function getFonts()
	local res = {}
	for i, v in ipairs(Fonts) do
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
	name = AppName,
	handler = RangeDisplay,
	get = function(info) return db[info[#info]] end,
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
			name = L["Color"],
			desc = L["Color"],
			set = "setColor",
			get = "getColor",
			order = 160,
		},
		oorColor = {
			type = 'color',
			name = L["Out of range color"],
			desc = L["Out of range color"],
			set = "setColor",
			get = "getColor",
			order = 161,
		},
		suffix = {
			type = 'input',
			name = L["Suffix"],
			desc = L["A free-form suffix to append to the range display when you are in range"],
			order = 165,
		},
		oorSuffix = {
			type = 'input',
			name = L["Out of range suffix"],
			desc = L["A free-form suffix to append to the range display when you are out of range"],
			order = 166,
		},
		strata = {
			type = 'select',
			name = L["Strata"],
			desc = L["Frame strata"],
			values = FrameStratas,
			order = 170,
		},
        config = {
            type = 'execute',
            name = L["Configure"],
            desc = L["Bring up GUI configure dialog"],
            guiHidden = true,
            order = 300,
            func = function() RangeDisplay:OpenConfigDialog() end,
        },
	},
}

function RangeDisplay:OpenConfigDialog()
    local f = ACD.OpenFrames[AppName]
    ACD:Open(AppName)
    if not f then
        f = ACD.OpenFrames[AppName]
        f:SetWidth(400)
        f:SetHeight(600)
    end
end

-- helper functions

local function isTargetValid(unit)
	return UnitExists(unit) and (not UnitIsDeadOrGhost(unit))
			and (not db.enemyOnly or UnitCanAttack("player", unit))
			and (not UnitIsUnit(unit, "player"))
end

-- frame stuff

function RangeDisplay:createFrame()
	self.isMoving = false
	local rangeFrame = CreateFrame("Frame", "RangeDisplayFrame", UIParent)
	rangeFrame:Hide()
	rangeFrame:SetFrameStrata(defaults.profile.strata)
	rangeFrame:EnableMouse(false)
	rangeFrame:SetClampedToScreen()
	rangeFrame:SetMovable(true)
	rangeFrame:SetWidth(120)
	rangeFrame:SetHeight(30)
	rangeFrame:SetPoint(defaults.profile.point, UIParent, defaults.profile.relPoint, defaults.profile.x, defaults.profile.y)
	self.rangeFrame = rangeFrame

	local rangeFrameBG = rangeFrame:CreateTexture("RangeDisplayFrameBG", "BACKGROUND")
	rangeFrameBG:SetTexture(0, 0, 0, 0.42)
	rangeFrameBG:SetWidth(rangeFrame:GetWidth())
	rangeFrameBG:SetHeight(rangeFrame:GetHeight())
	rangeFrameBG:SetPoint("CENTER", rangeFrame, "CENTER", 0, 0)
	self.rangeFrameBG = rangeFrameBG

	local rangeFrameText = rangeFrame:CreateFontString("RangeDisplayFrameText", "OVERLAY", "GameFontNormal")
	rangeFrameText:SetFont(DefaultFontPath, defaults.profile.fontSize, defaults.profile.fontOutline)
	rangeFrameText:SetJustifyH("CENTER")
	rangeFrameText:SetPoint("CENTER", rangeFrame, "CENTER", 0, 0)
	self.rangeFrameText = rangeFrameText

	rangeFrame:SetScript("OnMouseDown", function(frame, button)
		if (not button) then
			-- some addon is hooking us but doesn't pass button. argh...
			button = arg1
		end
		if (button == "LeftButton") then
			self.rangeFrame:StartMoving()
			self.isMoving = true
        elseif (button == "RightButton") then
            self:OpenConfigDialog()
		end
	end)
	rangeFrame:SetScript("OnMouseUp", function(frame, button)
		if (not button) then
			-- some addon is hooking us but doesn't pass button. argh...
			button = arg1
		end
		if (self.isMoving and button == "LeftButton") then
			self.rangeFrame:StopMovingOrSizing()
			self.isMoving = false
			db.point, _, db.relPoint, db.x, db.y = rangeFrame:GetPoint()
		end
	end)
	rangeFrame:SetScript("OnUpdate", function(frame, elapsed)
		lastUpdate = lastUpdate + elapsed
		if (lastUpdate < UpdateDelay) then return end
		lastUpdate = 0
		self:OnUpdate(elapsed)
	end)
end

-- config stuff

function RangeDisplay:setOption(info, value)
	db[info[#info]] = value
	self:applySettings()
end

function RangeDisplay:getColor(info)
	local prefix = info[#info]
	return db[prefix .. 'R'], db[prefix .. 'G'], db[prefix .. 'B']
end

function RangeDisplay:setColor(info, r, g, b)
	local prefix = info[#info]
	db[prefix .. 'R'], db[prefix .. 'G'], db[prefix .. 'B'] = r, g, b
	if (self:IsEnabled()) then
		self.rangeFrameText:SetTextColor(r, g, b)
	end
end

function RangeDisplay:applyFontSettings(isCallback)
	local dbFontPath
	if (SML) then
		dbFontPath = SML:Fetch("font", db.font, true)
		if (not dbFontPath) then
			if (isCallback) then
				return
			end
			SML.RegisterCallback(self, "LibSharedMedia_Registered", "applyFontSettings", true)
			dbFontPath = DefaultFontPath
		else
			SML.UnregisterCallback(self, "LibSharedMedia_Registered")
		end
	else
		dbFontPath = DefaultFontPath
	end
	local fontPath, fontSize, fontOutline = self.rangeFrameText:GetFont()
	fontOutline = fontOutline or ""
	if (dbFontPath ~= fontPath or db.fontSize ~= fontSize or db.fontOutline ~= fontOutline) then
		self.rangeFrameText:SetFont(dbFontPath, db.fontSize, db.fontOutline)
	end
end

function RangeDisplay:applySettings()
	if (not self:IsEnabled()) then
		return
	end
	if (db.locked) then
		self:lock()
	else
		self:unlock()
	end
	self.rangeFrame:ClearAllPoints()
	self.rangeFrame:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
	self.rangeFrame:SetFrameStrata(db.strata)
	self.rangeFrameText:SetTextColor(db.colorR, db.colorG, db.colorB)
	self:applyFontSettings()
	lastMinRange, lastMaxRange = false, false -- to force update
	self:targetChanged()
end

function RangeDisplay:lock()
	self.rangeFrame:EnableMouse(false)
	self.rangeFrameBG:Hide()
	if (not isTargetValid("target")) then
		self.rangeFrame:Hide()
	end
end

function RangeDisplay:unlock()
	self.rangeFrame:EnableMouse(true)
	self.rangeFrame:Show()
	self.rangeFrameBG:Show()
end

function RangeDisplay:addConfigTab(key, group, order, isCmdInline)
	if (not self.configOptions) then
		self.configOptions = {
			type = "group",
			name = AppName,
			childGroups = "tab",
			args = {},
		}
	end
	self.configOptions.args[key] = group
	self.configOptions.args[key].order = order
	self.configOptions.args[key].cmdInline = isCmdInline
end

function RangeDisplay:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("RangeDisplayDB3", defaults)
	self.db.RegisterCallback(self, "OnProfileChanged")
    db = self.db.profile
	self:addConfigTab('main', options, 10, true)
	self:addConfigTab('profiles', AceDBOptions:GetOptionsTable(self.db), 20, false)
	if (db.debug) then
		local debugOptions = {
			type = 'group',
			name = "Debug",
			args = {
				startMeasurement = {
					type = 'execute',
					name = "StartMeasurement",
					desc = "StartMeasurement",
					func = function()
						if (not db.measurements) then
							db.measurements = {}
						end
						db.measurements[UnitName("player")] = {}
						rc:startMeasurement("target", db.measurements[UnitName("player")])
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
						db.measurements = nil
					end,
				},
			},
		}
		self:addConfigTab('debug', debugOptions, 100, true)
	end
    AceConfig:RegisterOptionsTable(AppName, self.configOptions, "rangedisplay")
	ACD:AddToBlizOptions(AppName)
	if (not self.rangeFrame) then
		self:createFrame()
	end
	if ( EarthFeature_AddButton ) then
		EarthFeature_AddButton(
			{
				id= "RangeDisplay";
				name= L["Range Display"];
				subtext= "RangeDisplay";
				tooltip = L["Estimated range display"];
				icon= "Interface\\Icons\\Spell_Shadow_Charm";
				callback= function() RangeDisplay:OpenConfigDialog() end;
			}
		);
	end
end

function RangeDisplay:OnEnable(first)
	self:OnProfileChanged()
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "targetChanged")
	self:targetChanged()
end

function RangeDisplay:OnDisable()
	if (self.rangeFrame) then
		self.rangeFrame:Hide()
	end
	self:UnregisterAllEvents()
end

function RangeDisplay:OnProfileChanged()
	db = self.db.profile
	self:applySettings()
end

function RangeDisplay:OnUpdate(elapsed)
	local minRange, maxRange = rc:getRange("target", db.checkVisibility)
	if (minRange == lastMinRange and maxRange == lastMaxRange) then return end
	lastMinRange, lastMaxRange = minRange, maxRange
	local range = nil
	if (minRange) then
		if (maxRange) then
			if (db.maxRangeOnly) then
				range = maxRange .. db.suffix
			else
				range = minRange .. " - " .. maxRange .. db.suffix
			end
			self.rangeFrameText:SetTextColor(db.colorR, db.colorG, db.colorB)
		elseif (db.outOfRangeDisplay) then
			range = minRange .. db.oorSuffix
			self.rangeFrameText:SetTextColor(db.oorColorR, db.oorColorG, db.oorColorB)
		end
	end
	self.rangeFrameText:SetText(range)
end

function RangeDisplay:targetChanged()
	if (isTargetValid("target")) then
		self.rangeFrame:Show()
		lastUpdate = UpdateDelay -- to force update in next OnUpdate()
	elseif (db.locked) then
		self.rangeFrame:Hide()
	end
end
