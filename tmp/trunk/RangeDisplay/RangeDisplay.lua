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
local SML = AceLibrary:HasInstance("Dewdrop-2.0") and AceLibrary("Dewdrop-2.0")
local L = AceLibrary("AceLocale-2.2"):new("RangeDisplay")

RangeDisplay = {}

-- hard-coded config stuff

local UpdateDelay = .1 -- update frequency == 1/UpdateDelay
local MinFontSize = 5
local MaxFontSize = 40
local DefaultFont = GameFontNormal:GetFont()

-- SavedVariables stuff

local DefaultDB = {
	Enabled = true,
	Font = DefaultFont,
	FontSize = 24,
	FontOutline = "",
	OutOfRangeDisplay = false,
	CheckVisibility = false,
	Locked = false,
	X = 0,
	Y = 0,
	ColorR = 1.0,
	ColorG = 0.82,
	ColorB = 0,
}

local function dupDefaultDB()
	local res = {}
	for k, v in pairs(DefaultDB) do
		res[k] = v
	end
	return res
end

RangeDisplayDB = RangeDisplayDB or dupDefaultDB()

-- cached stuff

local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost

local db = RangeDisplayDB

-- options table stuff

local Fonts = SML and SML:List("font") or { [DefaultFont] = L["Default"] }

local FontOutlines = {
	[""] = L["None"],
	["OUTLINE"] = L["Normal"],
	["THICKOUTLINE"] = L["Thick"],
}

local options = {
	type = "group",
	name = L["RangeDisplay"],
	pass = true,
	handler = RangeDisplay,
	get = function(name) return db[name] end,
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
		OutOfRangeDisplay = {
			type = 'toggle',
			name = L["Out of range display"],
			desc = L["Show/Hide display if the target is out of range"],
			order = 120,
		},
		CheckVisibility = {
			type = 'toggle',
			name = L["Check visibility"],
			desc = L["If set, the max range to check will be 'visibility range'"],
			order = 130,
		},
		Font = {
			type = 'text',
			name = L["Font"],
			desc = L["Font"],
			validate = Fonts,
			order = 135
		},
		FontSize = {
			type = 'range',
			name = L["Font size"],
			desc = L["Font size"],
			min = MinFontSize,
			max = MaxFontSize,
			step = 1,
			order = 140,
		},
		FontOutline = {
			type = 'text',
			name = L["Font outline"],
			desc = L["Font outline"],
			validate = FontOutlines,
			order = 150,
		},
		Color = {
			type = 'color',
			name = L["Color"],
			desc = L["Color"],
			set = "setColor",
			get = function() return db.ColorR, db.ColorG, db.ColorB end,
			order = 160,
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
rangeFrameBG:SetTexture(0, 0, 0, 0.42)
rangeFrameBG:SetWidth(rangeFrame:GetWidth())
rangeFrameBG:SetHeight(rangeFrame:GetHeight())
rangeFrameBG:ClearAllPoints()
rangeFrameBG:SetPoint("CENTER", rangeFrame, "CENTER", 0, 0)

local rangeFrameText = rangeFrame:CreateFontString("RangeDisplayFrameText", "OVERLAY", "GameFontNormal")
rangeFrameText:SetJustifyH("CENTER")
rangeFrameText:SetPoint("CENTER", rangeFrame, "CENTER", 0, 0)

rangeFrame:SetScript("OnEvent", function(this, event, ...) RangeDisplay:OnEvent(event, ...) end)
rangeFrame:SetScript("OnMouseDown", function(this) this:StartMoving() end)
rangeFrame:SetScript("OnMouseUp", function(this) this:StopMovingOrSizing() end)
rangeFrame:SetScript("OnUpdate", function(this, elapsed) RangeDisplay:OnUpdate(elapsed) end)

rangeFrame:RegisterEvent("ADDON_LOADED")
rangeFrame:RegisterEvent("PLAYER_TARGET_CHANGED")

-- helper functions

local function print(text)
	if (DEFAULT_CHAT_FRAME) then 
		DEFAULT_CHAT_FRAME:AddMessage(text)
	end
end

local function isTargetValid(unit)
	return UnitExists(unit) and (not UnitIsDeadOrGhost(unit))
end

-- config stuff

function RangeDisplay:setOption(name, value)
	db[name] = value
	self:applySettings()
end

function RangeDisplay:setColor(name, r, g, b)
	db.ColorR, db.ColorG, db.ColorB = r, g, b
	rangeFrameText:SetTextColor(db.ColorR, db.ColorG, db.ColorB)
end

local function trySetFont()
	rangeFrameText:SetFont(db.Font, db.FontSize, db.FontOutline)
end

function RangeDisplay:applySettings()
	if (db.Enabled) then
		self:enable()
	else
		self:disable()
		return
	end
	if (db.Locked) then
		self:lock()
	else
		self:unlock()
	end
	rangeFrame:ClearAllPoints()
	rangeFrame:SetPoint("CENTER", UIParent, "CENTER", db.X, db.Y)
	local font, fontSize, fontOutline = rangeFrameText:getFont()
	fontOutline = fontOutline or ""
	if (db.Font ~= font or db.FontSize ~= fontSize or db.FontOutline ~= fontOutline) then
		if (not pcall(trySetFont)) then
		 	rangeFrameText:SetFont(DefaultDB.Font, DefaultDB.FontSize, DefaultDB.FontOutline)
		end
	end
	rangeFrameText:SetTextColor(db.ColorR, db.ColorG, db.ColorB)
end

function RangeDisplay:reset()
	RangeDisplayDB = dupDefaultDB()
	db = RangeDisplayDB
	self:applySettings()
	if (db.Enabled) then
		rc:init(true)
	end
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

function RangeDisplay:enable()
	self:targetChanged()
end

function RangeDisplay:disable()
	rangeFrame:Hide()
end

-- boring stuff

function RangeDisplay:OnEvent(event, ...)
	if (type(self[event]) == 'function') then
		self[event](self, event, ...)
	end
end

function RangeDisplay:ADDON_LOADED(event, name)
	if (name ~= "RangeDisplay") then return end
	-- register our slash command
	SLASH_RANGEDISPLAY1 = "/rangedisplay"
	SlashCmdList["RANGEDISPLAY"] = function(msg)
		RangeDisplay:SlashCmd(msg)
	end
	
	db = RangeDisplayDB
	-- make sure we have sensible values in db
	for k, v in pairs(DefaultDB) do
		if (db[k] == nil) then db[k] = v
	end
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
			'treeLevels', 1,
			'colorR', DefaultDB.ColorR, 'colorG', DefaultDB.ColorG, 'colorB', DefaultDB.ColorB
		)
	end
	self:applySettings()
	print(L["%s loaded. Type /rangedisplay for help"]:format(VERSION))
end

function RangeDisplay:PLAYER_TARGET_CHANGED()
	if (db.Enabled) then
		self:targetChanged()
	end
end

local lastUpdate = 0 -- time since last real update
local lastRange = nil
function RangeDisplay:OnUpdate(elapsed)
	lastUpdate = lastUpdate + elapsed
	if (lastUpdate < UpdateDelay) then return end
	lastUpdate = 0
	local range = rc:getRangeAsString("target", db.CheckVisibility, db.OutOfRangeDisplay)
	if (range == lastRange) then return end
	lastRange = range
	rangeFrameText:SetText(range)
end

function RangeDisplay:targetChanged()
	if (isTargetValid("target")) then
		rangeFrame:Show()
		lastUpdate = UpdateDelay -- to force update in next OnUpdate()
	elseif (db.Locked) then
		rangeFrame:Hide()
	end
end

local usage = "usage: /rangedisplay enable | disable | lock | unlock | fontsize XX | toggleord | togglecv | reset | config[dd|wf]"
function RangeDisplay:SlashCmd(args)
	args = args or ""
	local _, _, cmd, cmdParam = string.find(string.lower(args), "^%s*(%S+)%s*(%S*)")
	if (cmd == "enable") then
		db.Enabled = true
		rc:init(true)
	elseif (cmd == "disable") then
		db.Enabled = false
	elseif (cmd == "lock") then
		db.Locked = true
	elseif (cmd == "unlock") then
		db.Locked = false
	elseif (cmd == "fontsize") then
		local _, _, h = string.find(args, "(%d+\.?%d*)")
		if (not h) then
			print(usage)
			return
		end
		local hh = tonumber(h)
		if (hh < MinFontSize) then hh = MinFontSize end
		if (hh > MaxFontSize) then hh = MaxFontSize end
		db.FontSize = hh
	elseif (cmd == "toggleord") then
		db.OutOfRangeDisplay = not db.OutOfRangeDisplay
	elseif (cmd == "togglecv") then
		db.CheckVisibility = not db.CheckVisibility
	elseif (cmd == "reset") then
		self:reset()
		return
	elseif (cmd == "config") then
		if (waterfall) then
			waterfall:Open("RangeDisplay")
		elseif (dewdrop) then
			dewdrop:Open(rangeFrame)
		else
			print(L["Either Waterfall or Dewdrop is needed for this option"])
		end
		return
	elseif (cmd == "configdd") then
		if (dewdrop) then
			dewdrop:Open(rangeFrame)
		else
			print(L["Dewdrop is needed for this option"])
		end
		return
	elseif (cmd == "configwf") then
		if (waterfall) then
			waterfall:Open("RangeDisplay")
		else
			print(L["Waterfall is needed for this option"])
		end
		return
	elseif (cmd == "dumpdb") then
		self:dumpDB()
		return
	else
		print(usage)
		return
	end
	self:applySettings()
end

function RangeDisplay:dumpDB()
	for k, v in pairs(db) do
		print(k .. ": " .. tostring(v))
	end
end

