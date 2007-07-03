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

RangeDisplay = {}

local DefaultDB = {
	Enabled = true,
	Height = 24,
	ShowOutOfRange = nil,
	CheckVisible = nil,
	Locked = false
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
			name = "Enabled",
			desc = "Enable/Disable the mod",
			order = 100,
		},
		Locked = {
			type = 'toggle',
			name = "Locked",
			desc = "Lock/Unlock display frame",
			order = 110,
		},
		ShowOutOfRange = {
			type = 'toggle',
			name = "Show out of range",
			desc = "Display minRange if the unit is out of range, or hide the display",
			order = 120,
		},
		CheckVisible = {
			type = 'toggle',
			name = "Check visibility",
			desc = "If set, the max range will be 'visibility range'",
			order = 130,
		},
		Height = {
			type = 'range',
			name = "Font size",
			desc = "Font size",
			min = MinHeight,
			max = MaxHeight,
			step = 1,
			order = 140,
		},
		Reset = {
			type = 'execute',
			name = "Reset",
			desc = "Restore default settings",
			func = "reset",
			order = 999,
		},
	},
}

-- cached stuff
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local db = RangeDisplayDB
local rangeText = RangeDisplayFrameText
local rangeFrameBG = RangeDisplayFrameBG
local rangeFrame = RangeDisplayFrame

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

function RangeDisplay:OnUpdate(elapsed)
	lastUpdate = lastUpdate + elapsed
	if (lastUpdate < UpdateDelay) then return end
	lastUpdate = 0
	local range = rc:getRangeAsString("target", db.CheckVisible, db.ShowOutOfRange)
	if (range == lastRange) then return end
	lastRange = range
	rangeText:SetText(range)
end

-- config stuff

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
	if (db.Height) then
		self:setHeight(db.Height)
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
	if (dewdrop) then
		dewdrop:Unregister(rangeFrame)
	end
	rangeFrame:EnableMouse(false)
	rangeFrameBG:Hide()
	if (not isTargetValid("target")) then
		rangeFrame:Hide()
	end
end

function RangeDisplay:unlock()
	if (dewdrop) then
		dewdrop:Register(rangeFrame, 'children', function()
				dewdrop:FeedAceOptionsTable(options)
			end)
	end
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

function RangeDisplay:setHeight(height)
	local path, _, flags = rangeText:GetFont()
	rangeText:SetFont(path, height, flags)
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
	print(VERSION .. " loaded. Type /rangedisplay for help")
	self:applySettings()
end

function RangeDisplay:PLAYER_TARGET_CHANGED()
	if (db.Enabled) then
		self:targetChanged()
	end
end

function RangeDisplay:SlashCmd(args)
	if (dewdrop) then
		dewdrop:Open(rangeFrame, 'children', function()
				dewdrop:FeedAceOptionsTable(options)
			end)
		return
	end
	if (args == nil) then return end
	local _, _, cmd, cmdParam = string.find(string.lower(args), "^%s*(%S+)%s*(%S*)")
	if (cmd == "on" or cmd == "enable") then
		db.Enabled = true
		rc:init(true)
		self:enable()
		print("RangeDisplay enabled")
	elseif (cmd == "off" or cmd == "disable") then
		db.Enabled = false
		self:disable()
		print("RangeDisplay disabled")
	elseif (cmd == "lock") then
		db.Locked = true
		self:lock()
		print("RangeDisplay locked")
	elseif (cmd == "unlock") then
		db.Locked = false
		self:unlock()
		print("RangeDisplay is unlocked")
	elseif (cmd == "height" or cmdParam == "h") then
			local _, _, h = string.find(args, "(%d+\.?%d*)")
			if (h == nil) then
				self:showStatus()
				return
			end
			local hh = tonumber(h)
			if (MinHeight <= hh and hh < MaxHeight) then
				self:setHeight(hh)
				db.Height = hh
				print("RangeDisplayHeight set to " .. tostring(hh))
			end
	elseif (cmd == "reset") then
		self:reset()
	else
		self:showStatus()
	end
end

function RangeDisplay:showStatus()
	print("usage: /rangedisplay lock | unlock | enable | disable | height XX | reset")
	for k, v in pairs(db) do
		print(k .. ": " .. tostring(v))
	end
end

