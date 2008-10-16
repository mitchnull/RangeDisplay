--[[
Name: RangeDisplay
Revision: $Revision$
Author(s): mitch0
Website: http://www.wowace.com/projects/range-display/
SVN: svn://svn.wowace.com/wow/range-display/maguiInline/trunk
Description: RangeDisplay displays the estimated range to the current target based on spell ranges and other measurable ranges
Dependencies: LibStub, LibRangeCheck-2.0, Ace3, LibSharedMedia-3.0(optional)
License: Public Domain
]]

local AppName = "RangeDisplay"
local VERSION = AppName .. "-r" .. ("$Revision$"):match("%d+")

local rc = LibStub("LibRangeCheck-2.0")
local SML = LibStub:GetLibrary("LibSharedMedia-3.0", true)

-- internal vars

local db
local playerHasDeadZone
local _ -- throwaway
-- these will be moved to the per-frame data
local targetDeadZoneCheck
local lastUpdate = 0 -- time since last real update
local lastMinRange, lastMaxRange, lastIsInDeadZone

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
RangeDisplay.AppName = AppName

-- Default DB stuff

local function makeColor(r, g, b, a)
	a = a or 1.0
	return { ["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a }
end

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
		color = makeColor(1.0, 0.82, 0),
		oorSection = {
			enabled = true,
			color = makeColor(0.8, 0, 0),
			range = 35,
		},
		srSection = {
			enabled = true,
			color = makeColor(0, 0.8, 0),
			range = 20,
		},
		mrSection = {
			enabled = true,
			color = makeColor(0.9, 0.9, 0.9),
		},
		dzSection = {
			enabled = true,
			color = makeColor(0.4, 0.6, 0.9),
		},
		suffix = "",
		oorSuffix = " +",
		strata = "HIGH",
	},
}

function RangeDisplay:OnInitialize()
	playerHasDeadZone = rc:hasDeadZone()
    self.db = LibStub("AceDB-3.0"):New("RangeDisplayDB3", defaults)
	self.db.RegisterCallback(self, "OnProfileChanged", "profileChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "profileChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "profileChanged")
    db = self.db.profile
	self:setupOptions()
end

function RangeDisplay:OnEnable(first)
	self:profileChanged()
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "targetChanged")
	self:targetChanged()
end

function RangeDisplay:OnDisable()
	if (self.rangeFrame) then
		self.rangeFrame:Hide()
	end
	self:UnregisterAllEvents()
end

local function isTargetValid(unit)
	return UnitExists(unit) and (not UnitIsDeadOrGhost(unit))
			and (not db.enemyOnly or UnitCanAttack("player", unit))
			and (not UnitIsUnit(unit, "player"))
end

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
		if (button == "LeftButton") then
			self.rangeFrame:StartMoving()
			self.isMoving = true
        elseif (button == "RightButton") then
            self:openConfigDialog()
		end
	end)
	rangeFrame:SetScript("OnMouseUp", function(frame, button)
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
		self:update(elapsed)
	end)
end

function RangeDisplay:update(elapsed)
	local minRange, maxRange, isInDeadZone = rc:getRange("target", db.checkVisibility)
	if (targetDeadZoneCheck) then
		isInDeadZone = (maxRange and maxRange <= 8 and minRange >= 5)
	end
	if (minRange == lastMinRange and maxRange == lastMaxRange and isInDeadZone == lastIsInDeadZone) then return end
	lastMinRange, lastMaxRange, lastIsInDeadZone = minRange, maxRange, isInDeadZone
	local range = nil
	local color = nil
	if (minRange) then
		if (maxRange) then
			if (db.maxRangeOnly) then
				range = maxRange .. db.suffix
			else
				range = minRange .. " - " .. maxRange .. db.suffix
			end
			if (isInDeadZone and db.dzSection.enabled) then
				color = db.dzSection.color
			elseif (maxRange <= 5 and db.mrSection.enabled) then
				color = db.mrSection.color
			elseif (db.srSection.enabled and maxRange <= db.srSection.range) then
				color = db.srSection.color
			elseif (db.oorSection.enabled and minRange >= db.oorSection.range) then
				color = db.oorSection.color
			else
				color = db.color
			end
		elseif (db.outOfRangeDisplay) then
			color = (db.oorSection.enabled and minRange >= db.oorSection.range) and db.oorSection.color or db.color
			range = minRange .. db.oorSuffix
		end
	end
	self.rangeFrameText:SetText(range)
	if (color) then
		self.rangeFrameText:SetTextColor(color.r, color.g, color.b, color.a)
	end
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

function RangeDisplay:applySettings()
	if (not self:IsEnabled()) then
		if (self.rangeFrame) then
			self.rangeFrame:Hide()
		end
		return
	end
	if (not self.rangeFrame) then
		self:createFrame()
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

function RangeDisplay:profileChanged()
	db = self.db.profile
	self:applySettings()
end

function RangeDisplay:targetChanged()
	targetDeadZoneCheck = (not playerHasDeadZone) and db.dzSection.enabled and rc:hasDeadZone("target")
	if (isTargetValid("target")) then
		self.rangeFrame:Show()
		lastUpdate = UpdateDelay -- to force update in next onUpdate()
	elseif (db.locked) then
		self.rangeFrame:Hide()
	end
end

