--[[

  RangeCheck displays the estimated range to the current target based on spell ranges and other measurable ranges
  copyright 2007 by mitch
       
]]

local VERSION = "RangeCheck-r" .. ("$Revision$"):match("%d+")

if (not AceLibrary) then error(VERSION .. " requires AceLibrary.") end

local libRC = "RangeCheck-1.0"
local rc = AceLibrary:HasInstance(libRC) and AceLibrary(libRC)
if (not rc) then error(VERSION .. " requires " .. libRC) end
RangeCheck = {}

local DefaultDB = {
	Enabled = true,
	Height = 24,
	Locked = false
}

RangeCheckDB = RangeCheckDB or DefaultDB

-- cached stuff
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local db = RangeCheckDB
local rangeText = RangeCheckFrameText
local rangeFrameBG = RangeCheckFrameBG
local rangeFrame = RangeCheckFrame

local UpdateDelay = .05 -- update frequency == 1/UpdateDelay
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

function RangeCheck:applySettings()
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

function RangeCheck:OnUpdate(elapsed)
	lastUpdate = lastUpdate + elapsed
	if (lastUpdate < UpdateDelay) then return end
	lastUpdate = 0
	local range = rc:getRangeAsString("target")
	if (range == lastRange) then return end
	lastRange = range
	rangeText:SetText(range)
end

-- frame setup stuff

function RangeCheck:resetPosition()
	rangeFrame:ClearAllPoints()
	rangeFrame:SetPoint("CENTER", UIParent, "CENTER")
end

function RangeCheck:lock()
	rangeFrame:EnableMouse(false)
	rangeFrameBG:Hide()
	if (not isTargetValid("target")) then
		rangeFrame:Hide()
	end
end

function RangeCheck:unlock()
	rangeFrame:EnableMouse(true)
	rangeFrame:Show()
	rangeFrameBG:Show()
end

function RangeCheck:targetChanged()
	if (isTargetValid("target")) then
		rangeFrame:Show()
		lastUpdate = UpdateDelay -- to force update in next OnUpdate()
	elseif (db.Locked) then
		rangeFrame:Hide()
	end
end

function RangeCheck:enable()
	self:targetChanged()
end

function RangeCheck:disable()
	rangeFrame:Hide()
end

function RangeCheck:setHeight(height)
	local path, _, flags = rangeText:GetFont()
	rangeText:SetFont(path, height, flags)
end


-- boring stuff

function RangeCheck:OnLoad()
	-- register our slash command
	SLASH_RANGECHECK1 = "/rangecheck"
	SlashCmdList["RANGECHECK"] = function(msg)
		RangeCheck:SlashCmd(msg)
	end

	this:RegisterEvent("VARIABLES_LOADED")
	this:RegisterEvent("PLAYER_TARGET_CHANGED")
end

function RangeCheck:OnEvent(event, ...)
	if (type(self[event]) == 'function') then
		self[event](self, event, ...)
	end
end

function RangeCheck:VARIABLES_LOADED()
	db = RangeCheckDB
	print(VERSION .. " loaded. Type /rangecheck for help")
	self:applySettings()
end

function RangeCheck:PLAYER_TARGET_CHANGED()
	if (db.Enabled) then
		self:targetChanged()
	end
end

function RangeCheck:SlashCmd(args)
	if (args == nil) then return end
	local _, _, cmd, cmdParam = string.find(string.lower(args), "^%s*(%S+)%s*(%S*)")
	if (cmd == "on" or cmd == "enable") then
		db.Enabled = true
		rc:init(true)
		self:enable()
		print("RangeCheck enabled")
	elseif (cmd == "off" or cmd == "disable") then
		db.Enabled = false
		self:disable()
		print("RangeCheck disabled")
	elseif (cmd == "lock") then
		db.Locked = true
		self:lock()
		print("RangeCheck locked")
	elseif (cmd == "unlock") then
		db.Locked = false
		self:unlock()
		print("RangeCheck is unlocked")
	elseif (cmd == "height" or cmdParam == "h") then
			local _, _, h = string.find(args, "(%d+\.?%d*)")
			if (h == nil) then
				self:showStatus()
				return
			end
			local hh = tonumber(h)
			if (5 <= hh and hh < 40) then
				self:setHeight(hh)
				db.Height = hh
				print("RangeCheckHeight set to " .. tostring(hh))
			end
	elseif (cmd == "reset") then
		RangeCheckDB = DefaultDB
		db = RangeCheckDB
		self:resetPosition()
		self:setHeight(db.Height)
		if (db.Enabled) then
			rc:init(true)
		else
			self:disable()
		end
	else
		self:showStatus()
	end
end

function RangeCheck:showStatus()
	print("usage: /rangecheck lock | unlock | enable | disable | height XX | reset")
	for k, v in pairs(db) do
		print(k .. ": " .. tostring(v))
	end
end

