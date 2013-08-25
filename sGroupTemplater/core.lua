--------------------------------------------------------------------------------
-- sGroupTemplater (c) 2013 by Siarkowy
-- Released under the terms of BSD 2-Clause license.
--------------------------------------------------------------------------------

sGroupTemplater = LibStub("AceAddon-3.0"):NewAddon(
    "sGroupTemplater",

    -- embeds:
    "AceEvent-3.0",
    "AceConsole-3.0"
)

local Templater = sGroupTemplater
local GetNumPartyMembers = GetNumPartyMembers
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid
local UnitName = UnitName
local pairs = pairs
local tinsert = tinsert
local tremove = tremove

local INVITE_TIMEOUT    = 30
local MAX_RAID_SUBGROUP = 8

-- Template management actions
local ACTION_NONE       = 0
local ACTION_DISBAND    = 1
local ACTION_RESTORE    = 2
local ACTION_INVITE     = 3
local ACTION_SHUFFLE    = 4
local ACTION_LOOT       = 5
local ACTION_ASSISTANTS = 6
local ACTION_LEADER     = 7

local ACTION_LABELS = {
    "disband",
    "restore",
    "invite",
    "shuffle",
    "loot",
    "assistants",
    "leader",
    [0] = "none",
}

Templater.ACTION_LABELS = ACTION_LABELS

local ACTION = ACTION_NONE
local TPL               -- current template
local invtimes = {}     -- invite times

-- Template format -------------------------------------------------------------

--[[

The following format is used to specify a group template array:

template = {
    -- general:

    __leader = string,      -- group leader name
    __raid = true|nil,      -- set for raid templates
    __time = number,        -- template creation time

    -- loot:

    __loot = string,        -- looting method
    __master = string,      -- name of the loot master if any
    __threshold = number,   -- threshold: 0 (poor) to 5 (legendary)

    -- special:

    __nextAction = number,  -- action to set addon to when finished operating
    __nextTpl = string|table, -- template to set when finished
                            -- above can be used combined to chain
                            -- move players between groups

    -- for each player in group:

    [string] = number,      -- character name <-> raid subgroup pairs
    ...                     -- negative number means player is an assistant
                            -- in party mode, number has no meaning
                            -- in raid mode, 0 means any party when shuffling
}

All fields are optional. Empty table is also a valid void template.

--]]

-- Utils -----------------------------------------------------------------------

function Templater:IsInGroup()
    return UnitInRaid("player") or GetNumPartyMembers() > 0
end

function Templater:UnitInGroup(name)
    return UnitInRaid(name) or UnitInParty(name)
end

-- Core ------------------------------------------------------------------------

do -- table management
    local pool = {}

    local function wipe(t)
        for k in pairs(t) do
            t[k] = nil
        end

        return t
    end

    function Templater.table()
        return tremove(pool) or {}
    end

    function Templater.dispose(t)
        tinsert(pool, wipe(t))
    end

    Templater.wipe = wipe
end

function Templater:OnEnable()
    if ACTION == ACTION_NONE then
        return self:Disable()
    end

    TPL = TPL or self.db.profile.templates[DEFAULT]
    self:Print("Enabled", self:GetTemplateName(), "in", ACTION_LABELS[ACTION], "mode.")
    self:RegisterEvent("PARTY_MEMBERS_CHANGED")
    self:PARTY_MEMBERS_CHANGED()
end

function Templater:OnDisable()
    self.wipe(invtimes)

    if ACTION ~= ACTION_NONE then
        self:Print("Disabled", self:GetTemplateName(), "in", ACTION_LABELS[ACTION], "mode.")
    end

    if TPL and TPL.__nextTpl then
        ACTION = TPL.__nextAction or ACTION_NONE
        TPL = assert(self.db.profile.templates[TPL.__nextTpl], "Non-existent template name in __nextTpl.")
    else
        ACTION = ACTION_NONE
        TPL = nil -- clear current template reference
    end
end

function Templater:PARTY_MEMBERS_CHANGED()
    if ACTION == ACTION_DISBAND and self:IsInGroup() then
        return self:Disband(true)
    end

    if not TPL then
        return self:Disable()
    end

    if UnitInRaid("player") then
        self:UpdateNumSubgroupMembers()
    elseif TPL.__raid and GetNumPartyMembers() > 0 then
        return ConvertToRaid()
    end

    if not (ACTION == ACTION_RESTORE or ACTION == ACTION_INVITE) or self:Reinvite() then
        if not (ACTION == ACTION_RESTORE or ACTION == ACTION_SHUFFLE) or self:Shuffle() then
            if not (ACTION == ACTION_RESTORE or ACTION == ACTION_LOOT) or self:SetLoot() then
                if not (ACTION == ACTION_RESTORE or ACTION == ACTION_ASSISTANTS) or self:PromoteAssistants() then
                    if not (ACTION == ACTION_RESTORE or ACTION == ACTION_LEADER) or self:SetLeader() then
                        return self:Disable()
                    end
                end
            end
        end
    end
end

do
    local counts

    function Templater:UpdateNumSubgroupMembers()
        counts = self.wipe(counts or self.table())

        local name, rank, group

        for i = 1, GetNumRaidMembers() do
            name, rank, group = GetRaidRosterInfo(i)
            counts[group] = (counts[group] or 0) + 1
        end
    end

    function Templater:GetNumSubgroupMembers(group)
        return counts[group] or 0
    end

    function Templater:GetLastIncompleteSubgroup()
        for group = MAX_RAID_SUBGROUP, 1, -1 do
            if not counts[group] then
                return group
            end
        end
    end
end

function Templater:Run(tpl, action)
    tpl = assert(self.db.profile.templates[tpl] or type(tpl) == "table" and tpl, "Missing template table or name to run.")
    assert(action, "Missing template action to run.")

    if self:IsEnabled() then
        error("Already running.", 0)
    end

    self:SetAction(action)
    self:SetTemplate(tpl)
    self:Enable()
end

-- Template management ---------------------------------------------------------

function Templater:GetGroupTemplate(tpl)
    if not self:IsInGroup() then
        error("You have to be in a group.", 0)
    end

    tpl = self.wipe(type(tpl) == "table" and tpl or self.table())

    local isRaid = UnitInRaid("player") and true or nil --> true|nil
    local loot, partyMl, raidMl = GetLootMethod()

    -- set some fields
    tpl.__time = time()
    tpl.__raid = isRaid
    tpl.__loot = loot
    tpl.__threshold = GetLootThreshold()
    tpl.__master = loot == "master" and (
        raidMl and UnitName("raid" .. raidMl) or
        partyMl and UnitName("party" .. partyMl) or
        UnitName("player")
    ) or nil

    -- save raid players
    if isRaid then
        local name, rank, subgroup

        for i = 1, GetNumRaidMembers() do
            name, rank, subgroup = GetRaidRosterInfo(i)

            tpl[name] = subgroup * (rank > 0 and -1 or 1) -- negate assistants

            if rank == 2 then -- raid leader found
                tpl.__leader = UnitName("raid" .. i)
            end
        end

    -- or save party members
    else
        local unit, name

        for i = 1, GetNumPartyMembers() do
            unit = "party" .. i
            name = UnitName(unit)

            tpl[name] = 0 -- any raid subgroup when converted to raid template

            if UnitIsPartyLeader(unit) then -- party leader found
                tpl.__leader = name
            end
        end
    end

    -- set leader when in party
    tpl.__leader = tpl.__leader or UnitName("player")

    return tpl
end

function Templater:GetTemplate()
    return TPL
end

function Templater:GetTemplateByName(name)
    return self.db.profile.templates[name]
end

function Templater:SetTemplate(tpl, acceptNil)
    assert(tpl or acceptNil, "Usage: SetTemplate(tpl_table[, accept_nil])")
    TPL = tpl
    return self
end

function Templater:SaveGroupTemplate(name)
    name = name or DEFAULT

    local tpl = self:GetGroupTemplate(self.db.profile.templates[name])
    self.db.profile.templates[name] = tpl

    return tpl
end

function Templater:SaveTemplate(name, tpl)
    assert(name, "SaveTemplate: Name missing.")
    assert(tpl and type(tpl) == "table", "SaveTemplate: Template missing.")

    self.db.profile.templates[name] = tpl
end

Templater.Save = Templater.SaveTemplate

function Templater:DeleteTemplate(name)
    local tpl = self.db.profile.templates[name]
    assert(tpl, "DeleteTemplate: Template does not exist.")

    -- check if it's the current template
    if tpl == TPL then
        TPL = nil
    end

    -- unset reference
    self.db.profile.templates[name] = nil

    -- wipe and recycle
    self.dispose(tpl)
end

-- Action handlers -------------------------------------------------------------

function Templater:GetAction()
    return ACTION
end

function Templater:SetAction(id)
    ACTION = assert(id, "Usage: SetAction(action_id)")
    return self
end

local function IsName(str)
    return strsub(str, 1, 2) ~= "__"
end

function Templater:Disband(force)
    if not self:IsInGroup() then
        self:Disable()
        -- error("You have to be in a group.", 0)
    end

    if IsInInstance() and not force then
        StaticPopup_Show("SGT_GROUP_DISBAND")
        return
    end

    UninviteUnit(UnitInRaid("player") and "raid1" or "party1")
end

function Templater:Reinvite(tpl)
    tpl = assert(tpl or TPL, "Reinvite: Template missing.")

    for name in pairs(tpl) do
        if IsName(name) and not self:UnitInGroup(name) then
            if time() - (invtimes[name] or 0) >= INVITE_TIMEOUT then
                invtimes[name] = time()
                InviteUnit(name)
            end

            if not self:IsInGroup() then
                return false
            end
        end
    end

    return self:IsPartyComplete(tpl)
end

function Templater:IsPartyComplete(tpl)
    tpl = assert(tpl or TPL, "IsPartyComplete: Template missing.")

    for name in pairs(tpl) do
        if IsName(name) and not self:UnitInGroup(name) then
            return false
        end
    end

    return true
end

function Templater:Shuffle(tpl)
    tpl = assert(tpl or TPL, "Shuffle: Template missing.")

    local name, current, correct, _correct, _

    if UnitInRaid("player") then
        for i = 1, GetNumRaidMembers() do
            name, _, current = GetRaidRosterInfo(i)
            correct = abs(tpl[name] or 0)

            if current ~= correct and correct > 0 then -- player in wrong group
                if self:GetNumSubgroupMembers(correct) < 5 then
                    return SetRaidSubgroup(i, correct)
                else
                    for j = 1, GetNumRaidMembers() do
                        name, _, current = GetRaidRosterInfo(j)
                        _correct = abs(tpl[name] or 0)

                        if current == correct and current ~= _correct then
                            return SetRaidSubgroup(j, self:GetNumSubgroupMembers(_correct) < 5
                                and _correct or self:GetLastIncompleteSubgroup())
                        end
                    end
                end
            end
        end
    end

    return true
end

function Templater:SetLoot(tpl)
    tpl = assert(tpl or TPL, "SetLoot: Template missing.")

    if GetLootMethod() ~= tpl.__loot and tpl.__loot then
        return SetLootMethod(tpl.__loot, tpl.__master)
    elseif GetLootThreshold() ~= tpl.__threshold and tpl.__threshold then
        return SetLootThreshold(tpl.__threshold)
    end

    return true
end

function Templater:PromoteAssistants(tpl)
    tpl = assert(tpl or TPL, "PromoteAssistants: Template missing.")

    if not UnitInRaid("player") then
        return true
    end

    for name, subgroup in pairs(tpl) do
        if IsName(name) and subgroup < 0 and UnitInRaid(name)
        and select(2, GetRaidRosterInfo(UnitInRaid(name) + 1)) == 0 then
            return PromoteToAssistant(name)
        end
    end

    return true
end

function Templater:SetLeader(tpl)
    tpl = assert(tpl or TPL, "SetLeader: Template missing.")

    if tpl.__leader and tpl.__leader ~= UnitName("player") then
        PromoteToLeader(tpl.__leader)
    end

    return true
end

-- Init ------------------------------------------------------------------------

StaticPopupDialogs.AGU_GROUP_DISBAND = {
    text = "Are you sure you want to disband group? Bear in mind that if you don't have an ID on the current instance, instance boot timer will start for all players.",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function()
        Templater:Disable()
        Templater:SetAction(ACTION_DISBAND)
        Templater:Enable()
    end,
    timeout = 0,
    exclusive = 0,
    hideOnEscape = 1,
    showAlert = 1,
    whileDead = 1,
}

function Templater:OnInitialize()
    local defaults = {
        profile = {
            templates = {
                [DEFAULT] = { }
            }
        }
    }

    self.author = GetAddOnMetadata("sGroupTemplater", "Author")
    self.version = GetAddOnMetadata("sGroupTemplater", "Version")
    self.db = LibStub("AceDB-3.0"):New("sGTDB", defaults, DEFAULT)

    LibStub("AceConfig-3.0"):RegisterOptionsTable("sGroupTemplater", self.slash)
    self:RegisterChatCommand("sgt", "OnSlashCmd")
    self:RegisterChatCommand("gtemplate", "OnSlashCmd")
    self:RegisterChatCommand("sgrouptemplater", "OnSlashCmd")

    self.options = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("sGroupTemplater", "sGroupTemplater")
    self.options.default = function() self.db:ResetProfile() end

    LibStub("AceConfig-3.0"):RegisterOptionsTable("sGroupTemplater_Share", self.slash.args.share)
    self.share = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("sGroupTemplater_Share", "Share", "sGroupTemplater")
end
