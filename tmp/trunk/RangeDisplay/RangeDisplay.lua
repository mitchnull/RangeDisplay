--[[
Name: RangeDisplay
Revision: $Revision$
Author(s): mitch0
Website: http://www.wowace.com/wiki/RangeDisplay
Documentation: http://www.wowace.com/wiki/RangeDisplay
SVN: http://svn.wowace.com/wowace/trunk/RangeDisplay/
Description: RangeDisplay displays the estimated range to the current target based on spell ranges and other measurable ranges
Dependencies: AceLibrary, Babble-2.2, GratuityLib, RangeCheck-1.0, DewdropLib(optional), Waterfall-1.0(optional), SharedMediaLib(optional)
License: Public Domain
]]

local VERSION = "RangeDisplay-r" .. ("$Revision$"):match("%d+")

if (not AceLibrary) then error(VERSION .. " requires AceLibrary.") end

local libRC = "RangeCheck-1.0"
local rc = AceLibrary:HasInstance(libRC) and AceLibrary(libRC)
if (not rc) then error(VERSION .. " requires " .. libRC) end
local dewdrop = AceLibrary:HasInstance("Dewdrop-2.0") and AceLibrary("Dewdrop-2.0")
local waterfall = AceLibrary:HasInstance("Waterfall-1.0") and AceLibrary("Waterfall-1.0")
local SML = AceLibrary:HasInstance("SharedMedia-1.0") and AceLibrary("SharedMedia-1.0")
local L = AceLibrary("AceLocale-2.2"):new("RangeDisplay")
local _ -- throwaway


RangeDisplay = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceEvent-2.0")
RangeDisplay.version = VERSION
RangeDisplay:RegisterDB("RangeDisplayDB")
local db

-- hard-coded config stuff

local UpdateDelay = .1 -- update frequency == 1/UpdateDelay
local MinFontSize = 5
local MaxFontSize = 40
local DefaultFontName = "Friz Quadrata TT"
local DefaultFontPath = GameFontNormal:GetFont()

-- Default DB stuff

local DefaultDB = {
	font = DefaultFontName,
	fontSize = 24,
	fontOutline = "",
	outOfRangeDisplay = false,
	checkVisibility = false,
	enemyOnly = false,
	locked = false,
	point = "CENTER",
	relPoint = "CENTER",
	x = 0,
	y = 0,
	colorR = 1.0,
	colorG = 0.82,
	colorB = 0,
	strata = "HIGH",
}

-- cached stuff

local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitCanAttack = UnitCanAttack
local UnitIsUnit = UnitIsUnit

-- options table stuff

local Fonts
if (SML) then
--	SML:Register("font", DefaultFontName, DefaultFontPath)
	Fonts = SML:List("font")
else
	Fonts = { [1] = DefaultFontName }
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
	name = "RangeDisplay",
	pass = true,
	handler = RangeDisplay,
	get = function(name) return db[name] end,
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
			type = 'text',
			name = L["Font"],
			desc = L["Font"],
			validate = Fonts,
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
			type = 'text',
			name = L["Font outline"],
			desc = L["Font outline"],
			validate = FontOutlines,
			order = 150,
		},
		color = {
			type = 'color',
			name = L["Color"],
			desc = L["Color"],
			set = "setColor",
			get = function() return db.colorR, db.colorG, db.colorB end,
			order = 160,
		},
		strata = {
			type = 'text',
			name = L["Strata"],
			desc = L["Frame strata"],
			validate = FrameStratas,
			order = 170,
		},
	},
}

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
	rangeFrame:SetFrameStrata(DefaultDB.strata)
	rangeFrame:EnableMouse(false)
	rangeFrame:SetClampedToScreen()
	rangeFrame:SetMovable(true)
	rangeFrame:SetWidth(120)
	rangeFrame:SetHeight(30)
	rangeFrame:SetPoint(DefaultDB.point, UIParent, DefaultDB.relPoint, DefaultDB.x, DefaultDB.y)
	self.rangeFrame = rangeFrame

	local rangeFrameBG = rangeFrame:CreateTexture("RangeDisplayFrameBG", "BACKGROUND")
	rangeFrameBG:SetTexture(0, 0, 0, 0.42)
	rangeFrameBG:SetWidth(rangeFrame:GetWidth())
	rangeFrameBG:SetHeight(rangeFrame:GetHeight())
	rangeFrameBG:SetPoint("CENTER", rangeFrame, "CENTER", 0, 0)
	self.rangeFrameBG = rangeFrameBG

	local rangeFrameText = rangeFrame:CreateFontString("RangeDisplayFrameText", "OVERLAY", "GameFontNormal")
	rangeFrameText:SetFont(DefaultFontPath, DefaultDB.fontSize, DefaultDB.fontOutline)
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
	rangeFrame:SetScript("OnUpdate", function(frame, elapsed) self:OnUpdate(elapsed) end)
end

-- config stuff

function RangeDisplay:setOption(name, value)
	db[name] = value
	self:applySettings()
end

function RangeDisplay:setColor(r, g, b)
	db.colorR, db.colorG, db.colorB = r, g, b
	if (self:IsActive()) then
		self.rangeFrameText:SetTextColor(db.colorR, db.colorG, db.colorB)
	end
end

function RangeDisplay:applySettings()
	if (not self:IsActive()) then return end
	if (db.locked) then
		self:lock()
	else
		self:unlock()
	end
	self.rangeFrame:ClearAllPoints()
	self.rangeFrame:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
	self.rangeFrame:SetFrameStrata(db.strata)
	local dbFontPath = SML and SML:Fetch("font", db.font) or DefaultFontPath
	local fontPath, fontSize, fontOutline = self.rangeFrameText:GetFont()
	fontOutline = fontOutline or ""
	if (dbFontPath ~= fontPath or db.fontSize ~= fontSize or db.fontOutline ~= fontOutline) then
		self.rangeFrameText:SetFont(dbFontPath, db.fontSize, db.fontOutline)
	end
	self.rangeFrameText:SetTextColor(db.colorR, db.colorG, db.colorB)
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

function RangeDisplay:OnEnable(first)
	self:OnProfileEnable()
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "targetChanged")
	self:targetChanged()
end

function RangeDisplay:OnDisable()
	if (self.rangeFrame) then
		self.rangeFrame:Hide()
	end
end

function RangeDisplay:OnProfileEnable()
	db = self.db.profile
	self:applySettings()
end

-- boring stuff

function RangeDisplay:OnInitialize(event, name)
	if (not self.rangeFrame) then
		self:createFrame()
	end
	self:RegisterDefaults("profile", DefaultDB)
	db = self.db.profile

	if (dewdrop) then
		dewdrop:Register(self.rangeFrame, 'children', function()
			dewdrop:AddLine('text', "RangeDisplay", 'isTitle', true)
			dewdrop:FeedAceOptionsTable(options)
		end)
		options.args.configdd = {
			type = 'execute',
			name = L["ConfigDD"],
			desc = L["Configure via DewDrop"],
			func = function() dewdrop:Open(self.rangeFrame) end,
			guiHidden = true,
			order = 800,
		}
	end

	if (waterfall) then
		waterfall:Register("RangeDisplay", 
			'aceOptions', options,
			'title', "RangeDisplay",
			'treeLevels', 1,
			'colorR', DefaultDB.colorR, 'colorG', DefaultDB.colorG, 'colorB', DefaultDB.colorB
		)
		options.args.configwf = {
			type = 'execute',
			name = L["ConfigWF"],
			desc = L["Configure via Waterfall"],
			func = function() waterfall:Open("RangeDisplay") end,
			guiHidden = true,
			order = 810,
		}
	end
	self:RegisterChatCommand({"/rangedisplay"}, options)
end

local lastUpdate = 0 -- time since last real update
local lastRange = nil
function RangeDisplay:OnUpdate(elapsed)
	lastUpdate = lastUpdate + elapsed
	if (lastUpdate < UpdateDelay) then return end
	lastUpdate = 0
	local range = rc:getRangeAsString("target", db.checkVisibility, db.outOfRangeDisplay)
	if (range == lastRange) then return end
	lastRange = range
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

