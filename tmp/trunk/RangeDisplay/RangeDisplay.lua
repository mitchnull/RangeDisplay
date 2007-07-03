--[[

  RangeDisplay displays the estimated range to the current target based on spell ranges and other measurable ranges
  copyright 2007 by mitch
       
]]

local VERSION = "RangeDisplay-r" .. ("$Revision$"):match("%d+")

if (not AceLibrary) then error(VERSION .. " requires AceLibrary.") end

local libRC = "RangeCheck-1.0"
local rc = AceLibrary:HasInstance(libRC) and AceLibrary(libRC)
if (not rc) then error(VERSION .. " requires " .. libRC) end
local dewdrop = AceLibrary:HasInstance("Dewdrop-2.0") and AceLibrary("Dewdrop-2.0")
local waterfall = AceLibrary:HasInstance("Waterfall-1.0") and AceLibrary("Waterfall-1.0")
local L = AceLibrary("AceLocale-2.2"):new("RangeDisplay")

RangeDisplay = {}

local DefaultDB = {
	Enabled = true,
	FontSize = 24,
	ShowOutOfRange = nil,
	CheckVisible = nil,
	Locked = false,
	X = 0,
	Y = 0,
}

RangeDisplayDB = RangeDisplayDB or DefaultDB

local UpdateDelay = .1 -- update frequency == 1/UpdateDelay
local MinHeight = 5
local MaxHeight = 40

-- options table
-- TODO: localization
local options = {
	type = "group",
	pass = true,
	handler = RangeDisplay,
	get = "getOption",
	set = "setOption",
	args = {
		Enabled = {
			type = 'toggle',
			name = L["Enabled"],
			desc = L["Enable/Disable the mod"],
			order = 100,
		},
		Locked = {
			type = 'toggle',
			name = L["Locked"],
			desc = L["Lock/Unlock display frame"],
			order = 110,
		},
		ShowOutOfRange = {
			type = 'toggle',
			name = L["Show out of range"],
			desc = L["Display max checked range if the unit is out of range, or hide the display"],
			order = 120,
		},
		CheckVisible = {
			type = 'toggle',
			name = L["Check visibility"],
			desc = L["If set, the max range will be 'visibility range'"],
			order = 130,
		},
		FontSize = {
			type = 'range',
			name = L["Font size"],
			desc = L["Set the font size"],
			min = MinHeight,
			max = MaxHeight,
			step = 1,
			order = 140,
		},
		Reset = {
			type = 'execute',
			name = L["Reset"],
			desc = L["Restore default settings"],
			func = "reset",
			order = 999,
		},
	},
}

-- cached stuff
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local db = RangeDisplayDB

-- frame stuff

local rangeFrame = CreateFrame("Frame", "RangeDisplayFrame", UIParent)
rangeFrame:SetFrameStrata("HIGH")
rangeFrame:EnableMouse(false)
rangeFrame:SetMovable(true)
rangeFrame:SetWidth(120)
rangeFrame:SetHeight(30)
rangeFrame:ClearAllPoints()
rangeFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

local rangeFrameBG = rangeFrame:CreateTexture("RangeDisplayFrameBG", "BACKGROUND")
rangeFrameBG:SetTexture(0, 0, 0, 0.33)

local rangeFrameText = rangeFrame:CreateTexture("RangeDisplayFrameText", "OVERLAY", "MasterFont")
rangeFrameText:SetJustifyH("CENTER")
rangeFrameText:SetPoint("CENTER", rangeFrame, "CENTER", -1, 0)

rangeFrame:SetScript("OnLoad", function() RangeDisplay:OnLoad() end)
rangeFrame:SetScript("OnEvent", function(this, event, ...) RangeDisplay:OnEvent(event, ...) end)
rangeFrame:SetScript("OnMouseDown", function(this) this:StartMoving() end)
rangeFrame:SetScript("OnMouseUp", function(this) this:StopMovingOrSizing() end)
rangeFrame:SetScript("OnUpdate", function(this, elapsed) RangeDisplay:OnUpdate(elapsed) end)


local lastUpdate = 0 -- time since last real update
local lastRange = nil

-- helper functions

local function print(text)
	if (DEFAULT_CHAT_FRAME) then 
		DEFAULT_CHAT_FRAME:AddMessage(text)
	end
end

local function isTargetValid(unit)
	return UnitExists(unit) and (not UnitIsDeadOrGhost(unit))
end

function RangeDisplay:setupFrame()
	db.X = db.X or 0
	db.Y = db.Y or 0
	rangeFrame:ClearAllPoints()
	rangeFrame:SetPoint("CENTER", UIParent, "CENTER", db.X, db.Y)

	-- TODO: make font and style configurable
	local font = GameFontNormal:GetFont()
	db.FontSize = db.FontSize or DefaultDB.FontSize
	rangeFrameText:SetFont(font, db.FontSize, "OUTLINE")
end

function RangeDisplay:getOption(name)
	return db[name]
end

function RangeDisplay:setOption(name, value)
	db[name] = value
	self:applySettings()
end

function RangeDisplay:applySettings()
	if (db.Enabled) then
		self:enable()
	else
		self:disable()
	end
	if (db.Locked) then
		self:lock()
	else
		self:unlock()
	end
	if (db.FontSize) then
		self:setFontSize(db.FontSize)
	end
end

function RangeDisplay:reset()
	RangeDisplayDB = DefaultDB
	db = RangeDisplayDB
	self:resetPosition()
	self:applySettings()
	if (db.Enabled) then
		rc:init(true)
	end
end

function RangeDisplay:resetPosition()
	rangeFrame:ClearAllPoints()
	rangeFrame:SetPoint("CENTER", UIParent, "CENTER")
end

function RangeDisplay:lock()
	rangeFrame:EnableMouse(false)
	rangeFrameBG:Hide()
	if (not isTargetValid("target")) then
		rangeFrame:Hide()
	end
	_, _, _ , db.X, db.Y = rangeFrame:GetPoint()
end

function RangeDisplay:unlock()
	rangeFrame:EnableMouse(true)
	rangeFrame:Show()
	rangeFrameBG:Show()
end

function RangeDisplay:targetChanged()
	if (isTargetValid("target")) then
		rangeFrame:Show()
		lastUpdate = UpdateDelay -- to force update in next OnUpdate()
	elseif (db.Locked) then
		rangeFrame:Hide()
	end
end

function RangeDisplay:enable()
	self:targetChanged()
end

function RangeDisplay:disable()
	rangeFrame:Hide()
end

function RangeDisplay:setFontSize(fontSize)
	local path, _, flags = rangeFrameText:GetFont()
	rangeFrameText:SetFont(path, fontSize, flags)
end

-- boring stuff

function RangeDisplay:OnLoad()
	-- register our slash command
	SLASH_RANGEDISPLAY1 = "/rangedisplay"
	SlashCmdList["RANGEDISPLAY"] = function(msg)
		RangeDisplay:SlashCmd(msg)
	end

	this:RegisterEvent("VARIABLES_LOADED")
	this:RegisterEvent("PLAYER_TARGET_CHANGED")
end

function RangeDisplay:OnEvent(event, ...)
	if (type(self[event]) == 'function') then
		self[event](self, event, ...)
	end
end

function RangeDisplay:VARIABLES_LOADED()
	db = RangeDisplayDB
	setupFrame()
	if (dewdrop) then
		dewdrop:Register(rangeFrame, 'children', function()
			dewdrop:AddLine('text', L["RangeDisplay"], 'isTitle', true)
			dewdrop:FeedAceOptionsTable(options)
		end)
	end
	if (waterfall) then
		waterfall:Register("RangeDisplay", 
			'aceOptions', options,
			'title', L["RangeDisplay"],
			'treeLevels', 1);
	end
	print(VERSION .. " loaded. Type /rangedisplay for help")
	self:applySettings()
end

function RangeDisplay:PLAYER_TARGET_CHANGED()
	if (db.Enabled) then
		self:targetChanged()
	end
end

function RangeDisplay:OnUpdate(elapsed)
	lastUpdate = lastUpdate + elapsed
	if (lastUpdate < UpdateDelay) then return end
	lastUpdate = 0
	local range = rc:getRangeAsString("target", db.CheckVisible, db.ShowOutOfRange)
	if (range == lastRange) then return end
	lastRange = range
	rangeFrameText:SetText(range)
end

function RangeDisplay:SlashCmd(args)
	args = args or ""
	local _, _, cmd, cmdParam = string.find(string.lower(args), "^%s*(%S+)%s*(%S*)")
	if (cmd == "enable") then
		db.Enabled = true
		rc:init(true)
		self:enable()
	elseif (cmd == "disable") then
		db.Enabled = false
		self:disable()
	elseif ("lock") then
		db.Locked = true
		self:lock()
	elseif ("unlock") then
		db.Locked = false
		self:unlock()
	elseif ("fontsize") then
		local _, _, h = string.find(args, "(%d+\.?%d*)")
		if (h == nil) then
			self:showStatus()
			return
		end
		local hh = tonumber(h)
		if (MinHeight <= hh and hh <= MaxHeight) then
			self:setFontSize(hh)
			db.FontSize = hh
		end
	elseif (cmd == "togglesor") then
		db.ShowOutOfRange = ~db.ShowOutOfRange
	elseif (cmd == "togglecv") then
		db.CheckVisible = ~db.CheckVisible
	elseif (cmd == "reset") then
		self:reset()
	elseif (cmd == "config") then
		if (waterfall) then
			waterfall:Open("RangeDisplay")
		elseif (dewdrop) then
			dewdrop:Open(rangeFrame)
		else
			print("Either Waterfall or Dewdrop is needed for this option")
		end
	elseif (cmd == "configdd") then
		if (dewdrop) then
			dewdrop:Open(rangeFrame)
		else
			print("Dewdrop is needed for this option")
		end
	elseif (cmd == "configwf") then
		if (waterfall) then
			waterfall:Open("RangeDisplay")
		else
			print("Waterfall is needed for this option")
		end
	else
		if (waterfall) then
			waterfall:Open("RangeDisplay")
		elseif (dewdrop) then
			dewdrop:Open(rangeFrame)
		else
			self:showStatus()
		end
	end
end

function RangeDisplay:showStatus()
	print("usage: /rangedisplay enable | disable | lock | unlock | fontsize XX | togglesor | togglecv | reset | config[dd|wf]")
	for k, v in pairs(db) do
		print(k .. ": " .. tostring(v))
	end
end

