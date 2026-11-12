-- ForeverSoundLibrary - Panneau du menu Options (Échap > Options > Add-ons)
-- Même direction artistique que le panneau de ForeverEgo.
local ADDON, ns = ...

local LOGO = "Interface\\AddOns\\ForeverSoundLibrary\\Media\\Logo"
local TITLE_FONT = "Fonts\\MORPHEUS.TTF"

local panel = CreateFrame("Frame")
panel.name = "ForeverSoundLibrary"
panel:Hide()

local function OpenMainWindow()
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then HideUIPanel(InterfaceOptionsFrame) end
    if ns.OpenLibrary then ns.OpenLibrary() end
end

local function Build()
    if panel.built then return end
    panel.built = true

    -- Bloc du haut : logo + nom de l'addon
    local head = CreateFrame("Frame", nil, panel)
    head:SetSize(1, 72)
    head:SetPoint("TOP", 0, -40)

    local logo = head:CreateTexture(nil, "ARTWORK")
    logo:SetSize(64, 64)
    logo:SetTexture(LOGO)

    local title = head:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    if not title:SetFont(TITLE_FONT, 40, "") then
        title:SetFontObject("GameFontNormalHuge")
    end
    title:SetText("ForeverSoundLibrary")
    title:SetTextColor(1, 0.82, 0)
    title:SetShadowOffset(2, -2)
    title:SetShadowColor(0, 0, 0, 1)

    -- Centre le logo et le titre ensemble
    local gap = 16
    local w = 64 + gap + title:GetStringWidth()
    head:SetWidth(w)
    logo:SetPoint("LEFT", head, "LEFT", 0, 0)
    title:SetPoint("LEFT", logo, "RIGHT", gap, -2)

    local version = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    version:SetPoint("TOP", head, "BOTTOM", 0, -14)
    panel.versionText = version

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    hint:SetPoint("TOP", version, "BOTTOM", 0, -10)
    hint:SetText("Ouvrez la bibliothèque avec |cffffd100/fsl|r ou le bouton de la minicarte")

    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(280, 34)
    open:SetPoint("TOP", hint, "BOTTOM", 0, -20)
    open:SetText("Ouvrir ForeverSoundLibrary")
    open:SetNormalFontObject("GameFontNormalLarge")
    open:SetHighlightFontObject("GameFontHighlightLarge")
    open:SetScript("OnClick", OpenMainWindow)

    -- Liste des commandes
    local box = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    box:SetPoint("TOP", open, "BOTTOM", 0, -28)
    box:SetPoint("LEFT", panel, "LEFT", 30, 0)
    box:SetPoint("RIGHT", panel, "RIGHT", -30, 0)
    if box.SetBackdrop then
        box:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        box:SetBackdropColor(0, 0, 0, 0.35)
        box:SetBackdropBorderColor(1, 0.82, 0, 0.35)
    end

    local header = box:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 14, -12)
    header:SetText("Commandes")

    local line = box:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.4)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 14, -34)
    line:SetPoint("TOPRIGHT", -14, -34)

    local CMD_W, ROW_H = 250, 20
    local y = -44
    for i, c in ipairs(ns.COMMANDS or {}) do
        if i % 2 == 0 then
            local stripe = box:CreateTexture(nil, "BACKGROUND", nil, 1)
            stripe:SetColorTexture(1, 1, 1, 0.04)
            stripe:SetPoint("TOPLEFT", 6, y + 2)
            stripe:SetPoint("TOPRIGHT", -6, y + 2)
            stripe:SetHeight(ROW_H)
        end
        local cmd = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cmd:SetPoint("TOPLEFT", 14, y)
        cmd:SetWidth(CMD_W)
        cmd:SetJustifyH("LEFT")
        cmd:SetWordWrap(false)
        cmd:SetText(c[1])
        local desc = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        desc:SetPoint("TOPLEFT", 14 + CMD_W + 10, y)
        desc:SetPoint("RIGHT", box, "RIGHT", -14, 0)
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(false)
        desc:SetText(c[2])
        y = y - ROW_H
    end
    box:SetHeight(-y + 12)
end

panel:SetScript("OnShow", function(self)
    Build()
    self.versionText:SetText("Version : " .. (ns.version or "?"))
end)

-- Enregistrement dans le menu Options
if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
end

function ns.OpenOptions()
    if ns.settingsCategory and Settings and Settings.OpenToCategory then
        local id = ns.settingsCategory.GetID and ns.settingsCategory:GetID() or ns.settingsCategory.ID
        Settings.OpenToCategory(id)
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end
