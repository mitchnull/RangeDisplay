--[[

	SpellCaster 2.0
		copyright 2007 by mitch
       
	Version History:
    
	 2.0 - Complete rewrite, other functionality :)
	 1.0 - Initial version
    	
]]

SpellCaster = { L = {}, Version = "2.0.1" };

-- Saved state

local DefaultState = {
	AutoBar = true,
	RangeCheck = true,
	GuildTooltip = true,
	RangeTooltip = true,
	RangeCheckHeight = 20,
	RangeCheckLocked = false
};

SpellCasterState = SpellCasterState or DefaultState; 

-- Some constants

local RED     = "|cffbe0303";
local GREEN   = "|cff6bb700";
local BLUE    = "|cff0863c3";
local MAGENTA = "|cffa800a8";
local YELLOW  = "|cffffd505";
local CYAN    = "|cff00b1b1";
local WHITE   = "|cffdedede";
local ORANGE  = "|cffd06c01";
local PEACH   = "|cffdec962";
local FIRE    = "|cffde2413";


local L = SpellCaster.L;

function SpellCaster.print(text)
	if ( DEFAULT_CHAT_FRAME ) then 
		DEFAULT_CHAT_FRAME:AddMessage(text);
	end
end

function SpellCaster:debug(text)
	if (not self.isDebug) then return; end
	self.print(tostring(text));
end

-- less typing ftw
local print = SpellCaster.print;

function SpellCaster:OnLoad()
	-- register our slash command
	SLASH_SPELLCASTER1 = "/spellcaster";
	SLASH_SPELLCASTER2 = "/spc";
	SlashCmdList["SPELLCASTER"] = function(msg)
		SpellCaster:SlashCmd(msg);
	end

	this:RegisterEvent("UPDATE_MOUSEOVER_UNIT");
	this:RegisterEvent("PLAYER_REGEN_DISABLED");
	this:RegisterEvent("VARIABLES_LOADED");
	this:RegisterEvent("LEARNED_SPELL_IN_TAB");
	this:RegisterEvent("CHARACTER_POINTS_CHANGED");
	this:RegisterEvent("PLAYER_TARGET_CHANGED");
	this:RegisterEvent("PLAYER_ALIVE");
--	this:RegisterEvent("SPELLS_CHANGED");
--	this:RegisterEvent("PLAYER_ENTERING_WORLD");
--	this:RegisterEvent("UNIT_SPELLCAST_SENT");
--	this:RegisterEvent("UNIT_SPELLCAST_START");
--	this:RegisterEvent("UNIT_SPELLCAST_STOP");
--	this:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED");
--	this:RegisterEvent("UNIT_SPELLCAST_FAILED");
--	this:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED");
--	this:RegisterEvent("SPELL_UPDATE_COOLDOWN");
end

-- event handlers

function SpellCaster:OnEvent(event, ...)
	if (type(self[event]) == 'function') then
		self[event](self, event, ...);
	else
		self:debug("unexpected event: " .. tostring(event));
	end
end

function SpellCaster:VARIABLES_LOADED()
	print("SpellCaster " .. self.Version .. " loaded. Type /spellcaster for help");
end

function SpellCaster:UPDATE_MOUSEOVER_UNIT()
	if (SpellCasterState.GuildTooltip) then
		local guildName, guildRankName, guildRankIndex = GetGuildInfo("mouseover");
		if (guildName ~= nil) then
		    GameTooltip:AddLine(GREEN .. "<" .. guildName .. ">",
		    	1.0, 1.0, 1.0, 0);
	        GameTooltip:SetHeight(GameTooltip:GetHeight() +
	        	GameTooltip:GetHeight() / GameTooltip:NumLines());
		end
	end
	if (SpellCasterState.RangeTooltip) then
		self.RangeCheck:init();
		local range = SpellCaster.RangeCheck:getRange("mouseover");
		if (range ~= nil) then
		    GameTooltip:AddLine(YELLOW .. range,
		    	1.0, 1.0, 1.0, 0);
	        GameTooltip:SetHeight(GameTooltip:GetHeight() +
	        	GameTooltip:GetHeight() / GameTooltip:NumLines());
		end
	end
end

function SpellCaster:PLAYER_REGEN_DISABLED()
	if (SpellCasterState.AutoBar) then
		ChangeActionBarPage(1);
	end
end

function SpellCaster:PLAYER_ALIVE()
-- talent info should be ready, but it's not :( [at least spell ranges are not updated]
-- we'll do RangeCheck:init() when first needed
-- self.RangeCheck:init();
end

function SpellCaster:LEARNED_SPELL_IN_TAB()
	self.RangeCheck:init(true);
end

function SpellCaster:CHARACTER_POINTS_CHANGED()
	self.RangeCheck:init(true);
end

function SpellCaster:PLAYER_TARGET_CHANGED()
	if (SpellCasterState.RangeCheck) then
		self.RangeCheck:init();
		self.RangeCheck:targetChanged();
	end
end

function SpellCaster:setStateVar(stateVar, flagstr)
	if (flagstr == "on" or flagstr == "enable" or flagstr == "1") then
		SpellCasterState[stateVar] = true;
		print(stateVar .. " enabled");
		return true;
	elseif (flagstr == "off" or flagstr == "disable" or flagstr == "0") then
		SpellCasterState[stateVar] = false;
		print(stateVar .. " disabled");
		return true;
	else
		self:showStatus();
		return nil;
	end
end

function SpellCaster:SlashCmd(args)
	if (args == nil) then return end;
	local _, _, cmd, cmdParam = string.find(string.lower(args), "^%s*(%S+)%s*(%S*)");
	if (cmd == "autobar" or cmd == "ab") then
		self:setStateVar("AutoBar", cmdParam);
	elseif (cmd == "guildtooltip" or cmd == "gtt") then
		self:setStateVar("GuildTooltip", cmdParam);
	elseif (cmd == "RangeTooltip" or cmd == "rtt") then
		self:setStateVar("RangeTooltip", cmdParam);
	elseif (cmd == "rangecheck" or cmd == "rc") then
		if (cmdParam == "lock") then
			SpellCasterState.RangeCheckLocked = true;
			self.RangeCheck:lock();
			print("RangeCheck locked");
		elseif (cmdParam == "unlock") then
			SpellCasterState.RangeCheckLocked = false;
			self.RangeCheck:unlock();
			print("RangeCheck is unlocked");
		elseif (cmdParam == "height" or cmdParam == "h") then
			local _, _, h = string.find(args, "(%d+\.?%d*)");
			if (h == nil) then
				self:showStatus();
				return;
			end
			local hh = tonumber(h);
			if (1 <= hh and hh < 31) then
				self.RangeCheck:setHeight(hh);
				SpellCasterState.RangeCheckHeight = hh;
				print("RangeCheckHeight set to " .. tostring(hh));
			end
		elseif (self:setStateVar("RangeCheck", cmdParam)) then
			if (SpellCasterState.RangeCheck) then
				self.RangeCheck:enable();
			else
				self.RangeCheck:disable();
			end
		end
	elseif (cmd == "reset") then
		SpellCasterState = DefaultState;
		self.RangeCheck:init(true);
		self.RangeCheck:resetPosition();
		self.RangeCheck:setHeight(SpellCasterState.RangeCheckHeight);
	else
		self:showStatus();
	end
end

function SpellCaster:showStatus()
	print("options: AutoBar on|off, RangeCheck lock|unlock|enable|disable|height XX, GuildTooltip on|off, RangeTooltip on|off, reset");
	for k, v in pairs(SpellCasterState) do
		print(k .. ": " .. tostring(v));
	end
end

