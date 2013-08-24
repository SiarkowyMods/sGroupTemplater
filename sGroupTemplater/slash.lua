--------------------------------------------------------------------------------
-- sGroupTemplater (c) 2013 by Siarkowy
-- Released under the terms of BSD 2-Clause license.
--------------------------------------------------------------------------------

local Templater = sGroupTemplater

local ACTION_NONE       = 0
local ACTION_DISBAND    = 1
local ACTION_RESTORE    = 2
local ACTION_INVITE     = 3
local ACTION_SHUFFLE    = 4
local ACTION_LOOT       = 5
local ACTION_ASSISTANTS = 6
local ACTION_LEADER     = 7

Templater.slash = {
    name = "sGroupTemplater",
    handler = Templater,
    type = "group",
    args = {
        gui = {
            name = "GUI",
            desc = "Displays graphical user interface.",
            type = "execute",
            func = "ShowOptionsFrame",
            guiHidden = true,
            order = 1
        },
        templates = {
            name = "Templates",
            type = "header",
            cmdHidden = true,
            order = 2
        },
        save = {
            name = "New template",
            desc = "Saves current group as template of specified name. If no name is specified, template will be saved as Default.",
            type = "input",
            get = function(info) return "" end,
            set = function(info, v)
                local status, msg = pcall(Templater.SaveGroupTemplate, Templater, v ~= "" and v)

                if not status then
                    Templater:Print(msg)
                end
            end,
            width = "full",
            order = 4
        },
        tpl = {
            name = "Select template",
            desc = "Sets template for use with controls below.",
            type = "select",
            values = "GetTemplateNames",
            get = function(info)
                return Templater:GetTemplateName() or DEFAULT
            end,
            set = "SetTemplateByName",
            width = "full",
            order = 6
        },
        delete = {
            name = "Delete",
            desc = "Deletes given template.",
            type = "execute",
            func = function(info)
                local tpl = info.uiType == "cmd" and info.input:match("%s(.+)") or Templater:GetTemplateName()

                if tpl then
                    local status, msg = pcall(Templater.DeleteTemplate, Templater, tpl)

                    if not status then
                        Templater:Print(msg)
                    end
                end
            end,
            confirm = true,
            confirmText = "Are you sure you really want to delete selected template?",
            width = "half",
            order = 8
        },
        export = {
            name = "Export",
            desc = "Exports template as Lua code.",
            type = "execute",
            func = "Export",
            width = "half",
            order = 9
        },
        stop = {
            name = "|cffffffffStop addon|r",
            desc = "Stops all operations and disables the addon.",
            type = "execute",
            func = "Disable",
            disabled = function() return not Templater:IsEnabled() end,
            order = 10
        },
        actions = {
            name = "Actions",
            type = "header",
            cmdHidden = true,
            order = 20,
        },
        disband = {
            name = "|cffffffffDisband group|r",
            desc = "Disbands your group. You should be the leader.",
            type = "execute",
            disabled = function() return not Templater:IsInGroup() end,
            func = function(info)
                Templater:Disable()
                Templater:SetAction(ACTION_DISBAND)
                Templater:Enable()
            end,
            order = 25
        },
        restore = {
            name = "|cffffffffRestore|r",
            desc = "Performs complete restore of the selected template.",
            type = "execute",
            func = function(info)
                local tpl = info.uiType == "cmd" and info.input:match("%s(.+)")

                if tpl then
                    Templater:SetTemplateByName(nil, tpl)
                end

                Templater:SetAction(ACTION_RESTORE)
                Templater:Enable()
            end,
            order = 30
        },
        invite = {
            name = "Invite",
            desc = "Invites all players present in the selected template who are outside of your current group.",
            type = "execute",
            func = function(info)
                local tpl = info.uiType == "cmd" and info.input:match("%s(.+)")

                if tpl then
                    Templater:SetTemplateByName(nil, tpl)
                end

                Templater:SetAction(ACTION_INVITE)
                Templater:Enable()
            end,
            order = 35
        },
        shuffle = {
            name = "Shuffle",
            desc = "Shuffles the players between subgroups according to the template.",
            type = "execute",
            func = function(info)
                local tpl = info.uiType == "cmd" and info.input:match("%s(.+)")

                if tpl then
                    Templater:SetTemplateByName(nil, tpl)
                end

                Templater:SetAction(ACTION_SHUFFLE)
                Templater:Enable()
            end,
            order = 40
        },
        assistants = {
            name = "Assists",
            desc = "Promotes assistants according to the template.",
            type = "execute",
            func = function(info)
                local tpl = info.uiType == "cmd" and info.input:match("%s(.+)")

                if tpl then
                    Templater:SetTemplateByName(nil, tpl)
                end

                Templater:SetAction(ACTION_ASSISTANTS)
                Templater:Enable()
            end,
            order = 45
        },
        loot = {
            name = "Loot",
            desc = "Sets proper looting method and threshold.",
            type = "execute",
            func = function(info)
                local tpl = info.uiType == "cmd" and info.input:match("%s(.+)")

                if tpl then
                    Templater:SetTemplateByName(nil, tpl)
                end

                Templater:SetAction(ACTION_LOOT)
                Templater:Enable()
            end,
            order = 50
        },
        leader = {
            name = "Leader",
            desc = "Promotes new leader according to the template.",
            type = "execute",
            func = function(info)
                local tpl = info.uiType == "cmd" and info.input:match("%s(.+)")

                if tpl then
                    Templater:SetTemplateByName(nil, tpl)
                end

                Templater:SetAction(ACTION_LEADER)
                Templater:Enable()
            end,
            order = 55
        },
        share = {
            name = "Share",
            desc = "Template importing and exporting window.",
            type = "execute",
            func = function()
                InterfaceOptionsFrame_OpenToFrame(Templater.options_share)
            end,
            guiHidden = true,
            order = 60
        },
    }
}

function Templater:OnSlashCmd(input)
    if not input then
        self:ShowOptionsFrame()
    else
        LibStub("AceConfigCmd-3.0").HandleCommand(self, "sgt", "sGroupTemplater", input)
    end
end

function Templater:ShowOptionsFrame()
    InterfaceOptionsFrame_OpenToFrame(self.options)
end

local tpls = {}

function Templater:GetTemplateName()
    local TPL = self:GetTemplate()

    if TPL then
        for name, tpl in pairs(self.db.profile.templates) do
            if tpl == TPL then
                return name
            end
        end

        return "Custom"
    end

    return nil
end

function Templater:GetTemplateNames()
    for k in pairs(tpls) do
        tpls[k] = nil
    end

    for tpl in pairs(self.db.profile.templates) do
        tpls[tpl] = tpl
    end

    return tpls
end

function Templater:SetTemplateByName(info, v)
    assert(v, "SetTemplateByName: You have to specify the template name.")

    local tpl = self.db.profile.templates[v]

    if tpl then
        return self:SetTemplate(tpl)
    end

    self:Print(("Template %s does not exist."):format(v))
end
