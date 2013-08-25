--------------------------------------------------------------------------------
-- sGroupTemplater (c) 2013 by Siarkowy
-- Released under the terms of BSD 2-Clause license.
--------------------------------------------------------------------------------

local Templater = sGroupTemplater

Templater.slash.args.share = {
    name = "sGroupTemplater Share",
    handler = Templater,
    type = "group",
    inline = true,
    guiHidden = true,
    args = {
        help = {
            name = "To export a template, go to main sGroupTemplater window, then select a template, press Export button and copy the contents of Template box.\n\nTo import a template, enter template name, hit Enter or Okay, paste code into Template box and press Accept.",
            type = "description",
            cmdHidden = true,
            order = 5
        },
        sharename = {
            name = "Name",
            type = "input",
            get = "GetShareName",
            set = "SetShareName",
            width = "full",
            cmdHidden = true,
            order = 10
        },
        import = {
            name = "Template",
            type = "input",
            get = "GetShareCode",
            set = "Import",
            multiline = 8,
            width = "full",
            order = 15
        },
    }
}

do
    local code = ""
    local name = DEFAULT

    function Templater:GetShareCode(info) return code end
    function Templater:SetShareCode(info, v) code = string.trim(v or "") end

    function Templater:GetShareName(info) return name end
    function Templater:SetShareName(info, v) name = string.trim(v or "") end
end

function Templater:GetTemplateCode(tpl)
    assert(tpl, "GetTemplateCode: Template object is required.")

    local tmp = self.table()

    for k, v in pairs(tpl) do
        tinsert(tmp, format(type(v) == "string" and "%s = %q" or "%s = %d",
            k, type(v) == "boolean" and (v and 1 or 0) or v))
    end

    sort(tmp)
    local code = "{ " .. table.concat(tmp, ", ") .. " }"
    self.dispose(tmp)

    return code
end

function Templater:GetTemplateFromCode(code)
    return assert(loadstring("return " .. code, "Template"))()
end

function Templater:Import(info, code)
    local name = string.trim(info.uiType == "cmd" and info.input:match("%s[^{]+") or self:GetShareName())
    local tpl = assert(self:GetTemplateFromCode(code), "Import: Invalid template.")
    name = name ~= "" and name or DEFAULT

    self:SetShareCode(nil, self:GetTemplateCode(tpl))
    self.db.profile.templates[name] = tpl
    self:Print(("Template successfully imported as %s."):format(name))
end

function Templater:Export(info)
    local name = info.uiType == "cmd" and info.input:match("%s(.+)") or self:GetTemplateName() or DEFAULT
    local tpl = self:GetTemplateByName(name)

    if not tpl then
        return self:Print(("Template %s does not exist."):format(name))
    end

    self:SetShareName(nil, name)
    self:SetShareCode(nil, self:GetTemplateCode(tpl))

    if info.uiType == "cmd" then
        InterfaceOptionsFrame_OpenToFrame(self.share)
    else
        -- hack for AceGUI complaining when hiding options frame while still
        -- having button in pressed state --> use AceTimer-3.0 -- fix it later!
        if LibStub("AceTimer-3.0", true) then
            LibStub("AceTimer-3.0", true).ScheduleTimer(self, function() InterfaceOptionsFrame_OpenToFrame(self.share) end, 0)
        end
    end
end
