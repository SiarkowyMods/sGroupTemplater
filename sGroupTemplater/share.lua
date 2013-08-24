--------------------------------------------------------------------------------
-- sGroupTemplater (c) 2013 by Siarkowy
-- Released under the terms of BSD 2-Clause license.
--------------------------------------------------------------------------------

local Templater = sGroupTemplater

Templater.share = {
    name = "sGroupTemplater Share",
    handler = Templater,
    type = "group",
    args = {
        help = {
            name = "To export a template, go to main sGroupTemplater window, then select a template, press Export button and copy the contents of Template box. To import a template, enter template name, paste code into Template box and press Accept.",
            type = "description",
            order = 5
        },
        name = {
            name = "Name",
            type = "input",
            get = "GetShareName",
            set = "SetShareName",
            width = "full",
            order = 10
        },
        code = {
            name = "Template",
            type = "input",
            get = "GetShareCode",
            set = "SetShareCode",
            multiline = 8,
            width = "full",
            order = 15
        },
    }
}

do
    local code = ""
    local name = ""

    function Templater:GetShareCode(info) return code end
    function Templater:SetShareCode(info, v) code = string.trim(v or "") end

    function Templater:GetShareName(info) return name end
    function Templater:SetShareName(info, v) name = string.trim(v or "") end
end

function Templater:Export(info)
    local name = info.uiType == "cmd" and info.input:match("%s(.+)") or self:GetTemplateName() or DEFAULT
    local tpl = self:GetTemplateByName(name)

    if tpl then
        local tmp = self.table()

        for k, v in pairs(tpl) do
            tinsert(tmp, format(type(v) == "string" and "%s = %q" or "%s = %d",
                k, type(v) == "boolean" and (v and 1 or 0) or v))
        end

        sort(tmp)

        self:SetShareName(nil, name)
        self:SetShareCode(nil, "{ " .. strjoin(", ", unpack(tmp)) .. " }")

        self.dispose(tmp)

        InterfaceOptionsFrame_OpenToFrame(self.options_share)
    end
end
