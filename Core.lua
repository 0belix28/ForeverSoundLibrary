-- ForeverSoundLibrary : bibliothèque de tous les sons et musiques du jeu.
local ADDON, ns = ...
local D = ForeverSoundLibrary_Data

local PREFIX = "|cff33ccffForeverSoundLibrary|r : "
local ICON = "Interface\\AddOns\\ForeverSoundLibrary\\Media\\Logo"
local ROW_H = 18
local MAX_RESULTS = 2000          -- résultats max dans « Tous les résultats »
local CHANNELS = { "Master", "SFX", "Ambience", "Dialog" }
local KIT_FOLDER = "_soundkit (sons d'interface)"

local DEFAULTS = {
    favs = {},             -- [clé] = { cat, id, name, dir, kit }
    channel = "Master",    -- canal audio des sons
    volume = 1,            -- volume de la bibliothèque, 0 à 2 (0 à 200 %)
    minimap = { hide = false, angle = 200 },
}

local db
local floor, max, min = math.floor, math.max, math.min

local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg) end

local function Version()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return (get and get(ADDON, "Version")) or "?"
end

local function Fmt(n) return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n) end

------------------------------------------------------------------------
-- Données
------------------------------------------------------------------------
local prepared = false
local totals = { sound = 0, music = 0 }

local function FolderCount(f)
    if not f.n then
        local _, bars = f[2]:gsub("|", "")
        f.n = bars + 1
    end
    return f.n
end

local function Prepare()
    if prepared then return end
    prepared = true
    -- Sons d'interface nommés (table SOUNDKIT du client), joués via PlaySound.
    if type(SOUNDKIT) == "table" then
        local list = {}
        for name, id in pairs(SOUNDKIT) do
            if type(name) == "string" and type(id) == "number" then
                list[#list + 1] = { id, name:lower() }
            end
        end
        if #list > 0 then
            table.sort(list, function(a, b) return a[2] < b[2] end)
            for i, e in ipairs(list) do list[i] = e[1] .. ":" .. e[2] end
            table.insert(D.sound, 1, { KIT_FOLDER, table.concat(list, "|"), "kit" })
        end
    end
    for cat, folders in pairs(D) do
        local t = 0
        for _, f in ipairs(folders) do t = t + FolderCount(f) end
        totals[cat] = t
    end
end

local function MakeEntry(cat, f, id, name)
    return { cat = cat, id = tonumber(id), name = name, dir = f[1], kit = f[3] == "kit" }
end

-- Fichiers d'un dossier, filtrés par la recherche q (minuscules) si fournie.
local function ParseFolder(cat, f, q)
    local out = {}
    local all = not q or f[1]:find(q, 1, true)
    for id, name in f[2]:gmatch("(%d+):([^|]+)") do
        if all or id == q or name:find(q, 1, true) then
            out[#out + 1] = MakeEntry(cat, f, id, name)
        end
    end
    return out
end

local function Key(e) return (e.kit and "k" or "f") .. e.id end

local function FullPath(e)
    if e.kit then return "SOUNDKIT." .. e.name:upper() end
    local base = e.cat == "music" and "sound/music/" or "sound/"
    if e.dir == "(racine)" then return base .. e.name end
    return base .. e.dir .. "/" .. e.name
end

------------------------------------------------------------------------
-- Lecture
------------------------------------------------------------------------
local current, soundHandle, soundHandle2, musicPlaying
local UI = {}

------------------------------------------------------------------------
-- Volume (0 à 200 %)
-- WoW ne permet pas de régler le volume d'un son précis. On règle donc le
-- volume du canal utilisé (Master, Effets, Musique...) uniquement pendant
-- l'écoute, puis on remet la valeur du joueur. Au-delà de 100 %, le son est
-- joué deux fois en même temps (deux copies identiques = amplitude doublée).
------------------------------------------------------------------------
local VOL_CVAR = {
    Master = "Sound_MasterVolume", SFX = "Sound_SFXVolume", Ambience = "Sound_AmbienceVolume",
    Dialog = "Sound_DialogVolume", Music = "Sound_MusicVolume",
}
local boost        -- { cvar, orig, set } : canal modifié pendant l'écoute
local copies = 1   -- 2 quand le son est doublé (volume > 100 %)

local function RestoreVolume()
    if not boost then return end
    local cur = tonumber(GetCVar(boost.cvar))
    -- Si le joueur a changé son volume entre-temps, on garde son choix.
    if cur and boost.set and math.abs(cur - boost.set) < 0.01 then
        pcall(SetCVar, boost.cvar, boost.orig)
    end
    boost = nil
    if db then db.boost = nil end
end

local function ApplyVolume(channel)
    local cvar = VOL_CVAR[channel]
    if not cvar then return end
    if db.volume == 1 and copies == 1 then RestoreVolume() return end
    if not boost or boost.cvar ~= cvar then
        RestoreVolume()
        local orig = tonumber(GetCVar(cvar))
        if not orig then return end
        boost = { cvar = cvar, orig = orig }
        db.boost = boost -- pour remettre le volume au prochain chargement en cas de crash
    end
    local target = max(0, min(1, boost.orig * db.volume / copies))
    if pcall(SetCVar, cvar, target) then boost.set = target end
    if db.volume > 1 and copies == 1 and boost.orig * db.volume > 1.001 then
        UI.capped = true
    else
        UI.capped = false
    end
end

local function CurrentChannel()
    if not current then return nil end
    return current.cat == "music" and "Music" or db.channel
end

local function StopAll()
    if soundHandle then StopSound(soundHandle, 0); soundHandle = nil end
    if soundHandle2 then StopSound(soundHandle2, 0); soundHandle2 = nil end
    if musicPlaying then StopMusic(); musicPlaying = false end
    current = nil
    RestoreVolume()
    if UI.RefreshPlaying then UI.RefreshPlaying() end
end

local function Play(e)
    if not e then return end
    StopAll()
    local isMusic = e.cat == "music"
    copies = (not isMusic and db.volume > 1) and 2 or 1
    ApplyVolume(isMusic and "Music" or db.channel)
    local ok, handle, h2, _
    if isMusic then
        -- La musique remplace celle de la zone, en boucle, jusqu'à « Stop ».
        PlayMusic(e.id)
        ok, musicPlaying = true, true
        if GetCVar and GetCVar("Sound_EnableMusic") == "0" then
            Print("la musique du jeu est désactivée dans les options audio : rien ne sera entendu.")
        end
    elseif e.kit then
        ok, handle = PlaySound(e.id, db.channel, false)
        if ok and copies == 2 then _, h2 = PlaySound(e.id, db.channel, false) end
    else
        ok, handle = PlaySoundFile(e.id, db.channel)
        if ok and copies == 2 then _, h2 = PlaySoundFile(e.id, db.channel) end
    end
    if not ok then
        RestoreVolume()
        Print("|cffff6060impossible de jouer|r " .. e.name .. " (" .. e.id .. ") : fichier absent de ce client ou canal audio coupé.")
        return
    end
    soundHandle, soundHandle2, current = handle, h2, e
    UI.RefreshPlaying()
end

-- Fin d'un son : on remet le volume du joueur (si le client sait le détecter).
local watcher = CreateFrame("Frame")
local elapsedSince = 0
watcher:SetScript("OnUpdate", function(_, dt)
    elapsedSince = elapsedSince + dt
    if elapsedSince < 0.25 then return end
    elapsedSince = 0
    if soundHandle and not musicPlaying and C_Sound and C_Sound.IsPlaying then
        local ok, playing = pcall(C_Sound.IsPlaying, soundHandle)
        if ok and playing == false then
            soundHandle, soundHandle2, current = nil, nil, nil
            RestoreVolume()
            UI.RefreshPlaying()
        end
    end
end)

local function SetVolume(v)
    db.volume = max(0, min(2, floor(v * 20 + 0.5) / 20)) -- pas de 5 %
    if current then ApplyVolume(CurrentChannel()) end
    if UI.RefreshVolume then UI.RefreshVolume() end
end

local function IsFav(e) return db.favs[Key(e)] ~= nil end

local function ToggleFav(e)
    local k = Key(e)
    if db.favs[k] then
        db.favs[k] = nil
    else
        db.favs[k] = { cat = e.cat, id = e.id, name = e.name, dir = e.dir, kit = e.kit }
    end
    UI.Refresh(true)
end

local function InsertInChat(text)
    local insert = ChatEdit_InsertLink or (ChatFrameUtil and ChatFrameUtil.InsertLink)
    if insert and insert(text) then return end
    local open = ChatFrame_OpenChat or (ChatFrameUtil and ChatFrameUtil.OpenChat)
    if open then open(text) else Print(text) end
end

------------------------------------------------------------------------
-- Liste défilante générique
------------------------------------------------------------------------
local function CreateList(parent, w, h, setup, click)
    local L = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    L:SetSize(w, h)
    L:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    L:SetBackdropColor(0, 0, 0, 0.35)
    L:SetBackdropBorderColor(1, 1, 1, 0.12)
    L.data, L.rows, L.offset = {}, {}, 0

    local bar = CreateFrame("Slider", nil, L, "BackdropTemplate")
    bar:SetPoint("TOPRIGHT", -2, -2)
    bar:SetPoint("BOTTOMRIGHT", -2, 2)
    bar:SetWidth(10)
    bar:SetOrientation("VERTICAL")
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    bar:SetBackdropColor(1, 1, 1, 0.05)
    bar:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    local thumb = bar:GetThumbTexture()
    thumb:SetSize(10, 36)
    thumb:SetVertexColor(0.2, 0.8, 1, 0.6)
    bar:SetScript("OnValueChanged", function(_, v)
        v = floor(v + 0.5)
        if v ~= L.offset then L.offset = v; L:Update() end
    end)
    L.bar = bar

    L:EnableMouseWheel(true)
    L:SetScript("OnMouseWheel", function(_, d) bar:SetValue(L.offset - d * 3) end)

    local n = floor((h - 4) / ROW_H)
    for i = 1, n do
        local r = CreateFrame("Button", nil, L)
        r:SetSize(w - 16, ROW_H)
        r:SetPoint("TOPLEFT", 2, -2 - (i - 1) * ROW_H)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.03 or 0)
        r.sel = r:CreateTexture(nil, "BORDER")
        r.sel:SetAllPoints()
        r.sel:Hide()
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(0.2, 0.8, 1, 0.15)
        r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.text:SetJustifyH("LEFT")
        r.text:SetWordWrap(false)
        r:SetScript("OnClick", function(self, btn) if self.item then click(self, self.item, btn) end end)
        L.rows[i] = r
    end

    function L:Update()
        for i, r in ipairs(self.rows) do
            local item = self.data[self.offset + i]
            r.item = item
            if item then setup(r, item); r:Show() else r:Hide() end
        end
    end

    function L:SetData(data, keep)
        self.data = data
        local m = max(0, #data - #self.rows)
        if not keep then self.offset = 0 end
        self.offset = min(self.offset, m)
        bar:SetMinMaxValues(0, m)
        bar:SetValue(self.offset)
        bar:SetShown(m > 0)
        self:Update()
    end

    return L
end

------------------------------------------------------------------------
-- Fenêtre
------------------------------------------------------------------------
local frame
local state = { tab = "sound", query = nil, folders = {}, sel = 1 }

-- Mode « choix d'un son » ouvert par un autre addon (voir ForeverSoundLibrary_Pick).
-- pick = { callback, label, chosen } ; chosen = dernier son cliqué.
local pick

local function FavList()
    local out = {}
    for _, e in pairs(db.favs) do out[#out + 1] = e end
    table.sort(out, function(a, b)
        if a.cat ~= b.cat then return a.cat > b.cat end
        return a.name < b.name
    end)
    return out
end

local function FavCount()
    local n = 0
    for _ in pairs(db.favs) do n = n + 1 end
    return n
end

-- Construit la liste de dossiers de l'onglet courant (filtrée par la recherche).
local function BuildFolders()
    local list, q, cat = {}, state.query, state.tab
    if cat == "fav" then
        local favs = FavList()
        if q then
            local keep = {}
            for _, e in ipairs(favs) do
                if e.name:find(q, 1, true) or e.dir:find(q, 1, true) or tostring(e.id) == q then keep[#keep + 1] = e end
            end
            favs = keep
        end
        list[1] = { label = "Favoris", files = favs, count = #favs }
        return list
    end
    if not q then
        for _, f in ipairs(D[cat]) do list[#list + 1] = { f = f } end
        return list
    end
    local all, total = {}, 0
    list[1] = { label = "|cffffd100Tous les résultats|r", files = all }
    for _, f in ipairs(D[cat]) do
        local n = 0
        if f[1]:find(q, 1, true) then
            n = FolderCount(f)
            if #all < MAX_RESULTS then
                for _, e in ipairs(ParseFolder(cat, f)) do
                    if #all >= MAX_RESULTS then break end
                    all[#all + 1] = e
                end
            end
        elseif f[2]:find(q, 1, true) then
            for id, name in f[2]:gmatch("(%d+):([^|]+)") do
                if id == q or name:find(q, 1, true) then
                    n = n + 1
                    if #all < MAX_RESULTS then all[#all + 1] = MakeEntry(cat, f, id, name) end
                end
            end
        end
        if n > 0 then
            list[#list + 1] = { f = f, count = n }
            total = total + n
        end
    end
    list[1].count = total
    return list
end

local function SelectFolder(i, keep)
    state.sel = i
    local item = state.folders[i]
    local files
    if not item then
        files = {}
    elseif item.files then
        files = item.files
    else
        files = ParseFolder(state.tab, item.f, state.query)
    end
    frame.files:SetData(files, keep)
    frame.folders:Update()
    local label = item and (item.label or item.f[1]) or ""
    local shown = #files
    local extra = (item and item.files and item.count and item.count > shown) and (" (affichés : " .. Fmt(shown) .. " sur " .. Fmt(item.count) .. ")") or ""
    frame.listTitle:SetText(label .. "  |cff888888" .. Fmt(shown) .. " fichier(s)" .. extra .. "|r")
end

function UI.Refresh(keep)
    if not frame then return end
    state.folders = BuildFolders()
    frame.folders:SetData(state.folders, keep)
    SelectFolder(keep and min(state.sel, max(1, #state.folders)) or 1, keep)
    frame.tabs.sound:SetText("Sons (" .. Fmt(totals.sound) .. ")")
    frame.tabs.music:SetText("Musique (" .. Fmt(totals.music) .. ")")
    frame.tabs.fav:SetText("Favoris (" .. FavCount() .. ")")
    for k, b in pairs(frame.tabs) do
        if k == state.tab then b:LockHighlight() else b:UnlockHighlight() end
    end
    frame.channel:SetText("Canal : " .. db.channel)
end

function UI.RefreshPick()
    if not frame then return end
    frame.pickBtn:SetShown(pick ~= nil)
    if not pick then
        frame.title:SetText("|cff33ccffForeverSoundLibrary|r |cff888888v" .. Version() .. "|r")
        return
    end
    frame.title:SetText("|cff33ccffChoisir un son|r pour : |cffffffff" .. (pick.label or "?") .. "|r")
    local c = pick.chosen
    if c then
        frame.pickBtn:SetText("Choisir : " .. c.name)
        frame.pickBtn:Enable()
    else
        frame.pickBtn:SetText("Cliquez un son pour l'écouter")
        frame.pickBtn:Disable()
    end
end

function UI.RefreshPlaying()
    if not frame then return end
    if pick and not current then
        frame.playing:SetText("|cffffd100Mode choix|r - Clic gauche : écouter et sélectionner  •  bouton en haut : valider  •  Échap : annuler")
        frame.files:Update()
        if UI.RefreshVolume then UI.RefreshVolume() end
        return
    end
    if current then
        local kind = current.cat == "music" and "Musique" or "Son"
        frame.playing:SetText("|cff00ff00En lecture|r - " .. kind .. " : |cffffffff" .. current.name .. "|r  |cff888888(" .. (current.kit and "SoundKit " or "FileID ") .. current.id .. ")|r")
    else
        frame.playing:SetText("|cff888888Clic gauche : écouter  •  Clic droit : favori  •  Maj+clic : ID dans le chat|r")
    end
    frame.files:Update()
    if UI.RefreshVolume then UI.RefreshVolume() end
end

local function SetTab(tab)
    state.tab = tab
    UI.Refresh()
end

local function CreateMainFrame()
    Prepare()
    local f = CreateFrame("Frame", "ForeverSoundLibraryFrame", UIParent, "BackdropTemplate")
    frame = f
    f:SetSize(900, 580)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
    f:SetBackdropBorderColor(0.2, 0.8, 1, 0.5)
    tinsert(UISpecialFrames, f:GetName())

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("|cff33ccffForeverSoundLibrary|r |cff888888v" .. Version() .. "|r")
    f.title = title

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    -- Bouton de validation du mode choix (caché sinon)
    local pickBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    pickBtn:SetSize(300, 24)
    pickBtn:SetPoint("RIGHT", close, "LEFT", -4, 0)
    pickBtn:SetScript("OnClick", function()
        if not pick or not pick.chosen then return end
        local cb, c = pick.callback, pick.chosen
        pick = nil
        StopAll()
        f:Hide()
        local ok, err = pcall(cb, { id = c.id, kit = c.kit and true or false, name = c.name, dir = c.dir })
        if not ok then Print("|cffff6060erreur de l'addon appelant :|r " .. tostring(err)) end
    end)
    pickBtn:Hide()
    f.pickBtn = pickBtn

    -- Fermer la fenêtre annule le mode choix.
    f:SetScript("OnHide", function()
        if pick then
            pick = nil
            StopAll()
        end
        f:SetFrameStrata("HIGH")
        UI.RefreshPick()
    end)

    -- Onglets
    f.tabs = {}
    local prev
    for _, t in ipairs({ "sound", "music", "fav" }) do
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(150, 24)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", 12, -40) end
        b:SetScript("OnClick", function() SetTab(t) end)
        f.tabs[t] = b
        prev = b
    end

    -- Recherche
    local search = CreateFrame("EditBox", nil, f, "SearchBoxTemplate")
    search:SetSize(260, 22)
    search:SetPoint("TOPRIGHT", -16, -41)
    search:SetAutoFocus(false)
    local timer
    search:HookScript("OnTextChanged", function(self)
        if timer then timer:Cancel() end
        timer = C_Timer.NewTimer(0.35, function()
            local q = strtrim(self:GetText() or ""):lower()
            if #q < 2 then q = nil end
            if q ~= state.query then state.query = q; UI.Refresh() end
        end)
    end)
    search:SetScript("OnEnterPressed", search.ClearFocus)
    f.search = search

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("RIGHT", search, "LEFT", -8, 0)
    hint:SetText("nom, dossier ou ID")

    -- Liste des dossiers
    local LIST_H = 580 - 76 - 46
    f.folders = CreateList(f, 300, LIST_H,
        function(r, item)
            r.text:ClearAllPoints()
            r.text:SetPoint("LEFT", 4, 0)
            r.text:SetPoint("RIGHT", -4, 0)
            local count = item.count or (item.f and FolderCount(item.f)) or 0
            r.text:SetText((item.label or item.f[1]) .. " |cff888888(" .. Fmt(count) .. ")|r")
            local selected = state.folders[state.sel] == item
            r.sel:SetColorTexture(0.2, 0.8, 1, 0.3)
            r.sel:SetShown(selected)
        end,
        function(r)
            for i = 1, #state.folders do
                if state.folders[i] == r.item then SelectFolder(i) break end
            end
        end)
    f.folders:SetPoint("TOPLEFT", 12, -76)

    -- Liste des fichiers
    f.listTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.listTitle:SetPoint("BOTTOMLEFT", f.folders, "TOPRIGHT", 12, 4)
    f.listTitle:SetPoint("RIGHT", search, "RIGHT")
    f.listTitle:SetJustifyH("LEFT")
    f.listTitle:SetWordWrap(false)
    f.listTitle:Hide() -- (titre affiché dans la barre du bas, voir plus loin)

    f.files = CreateList(f, 900 - 300 - 36, LIST_H,
        function(r, e)
            if not r.star then
                r.star = r:CreateTexture(nil, "OVERLAY")
                r.star:SetSize(13, 13)
                r.star:SetPoint("LEFT", 4, 0)
                r.idText = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                r.idText:SetPoint("RIGHT", -4, 0)
                r.idText:SetJustifyH("RIGHT")
                r.text:ClearAllPoints()
                r.text:SetPoint("LEFT", r.star, "RIGHT", 6, 0)
                r.text:SetPoint("RIGHT", r.idText, "LEFT", -8, 0)
                r:SetScript("OnEnter", function(self)
                    local it = self.item
                    if not it then return end
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(it.name, 1, 1, 1)
                    GameTooltip:AddLine(FullPath(it), 0.6, 0.6, 0.6, true)
                    GameTooltip:AddLine((it.kit and "SoundKit ID : " or "FileDataID : ") .. it.id, 0.2, 0.8, 1)
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Clic gauche : écouter", 0.8, 0.8, 0.8)
                    GameTooltip:AddLine("Clic droit : ajouter / retirer des favoris", 0.8, 0.8, 0.8)
                    GameTooltip:AddLine("Maj + clic : insérer l'ID dans le chat", 0.8, 0.8, 0.8)
                    GameTooltip:Show()
                end)
                r:SetScript("OnLeave", GameTooltip_Hide)
            end
            if IsFav(e) then
                r.star:SetAtlas("auctionhouse-icon-favorite")
                r.star:SetAlpha(1)
            else
                r.star:SetAtlas("auctionhouse-icon-favorite-off")
                r.star:SetAlpha(0.35)
            end
            local playing = current and current.id == e.id and current.kit == e.kit and current.cat == e.cat
            local prefix = ""
            if state.tab == "fav" or (state.folders[state.sel] and state.folders[state.sel].files) then
                prefix = "|cff888888" .. (e.cat == "music" and "[M] " or "") .. e.dir .. "/|r"
            end
            r.text:SetText(prefix .. (playing and "|cff00ff00" or "") .. e.name)
            r.idText:SetText((e.kit and "kit " or "") .. e.id)
            r.sel:SetColorTexture(0.1, 0.9, 0.3, 0.18)
            r.sel:SetShown(playing)
        end,
        function(r, e, btn)
            if btn == "RightButton" then
                ToggleFav(e)
            elseif IsShiftKeyDown() then
                InsertInChat(tostring(e.id))
            else
                Play(e)
                if pick then
                    if e.cat == "music" then
                        Print("une musique ne peut pas être choisie ici : prenez un son de l'onglet Sons.")
                    else
                        pick.chosen = e
                    end
                    UI.RefreshPick()
                end
            end
        end)
    f.files:SetPoint("TOPLEFT", f.folders, "TOPRIGHT", 12, 0)

    -- Barre du bas
    local stop = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    stop:SetSize(80, 24)
    stop:SetPoint("BOTTOMRIGHT", -12, 12)
    stop:SetText("Stop")
    stop:SetScript("OnClick", StopAll)

    local rnd = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    rnd:SetSize(90, 24)
    rnd:SetPoint("RIGHT", stop, "LEFT", -6, 0)
    rnd:SetText("Aléatoire")
    rnd:SetScript("OnClick", function()
        local data = f.files.data
        if #data > 0 then
            local i = math.random(#data)
            Play(data[i])
            f.files.bar:SetValue(i - 1)
        end
    end)

    local chan = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    chan:SetSize(130, 24)
    chan:SetPoint("RIGHT", rnd, "LEFT", -6, 0)
    chan:SetScript("OnClick", function()
        local idx = 1
        for i, c in ipairs(CHANNELS) do if c == db.channel then idx = i end end
        db.channel = CHANNELS[idx % #CHANNELS + 1]
        chan:SetText("Canal : " .. db.channel)
    end)
    chan:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Canal audio des sons")
        GameTooltip:AddLine("Master : s'entend même si les effets sonores sont coupés. La musique utilise toujours le canal Musique.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    chan:SetScript("OnLeave", GameTooltip_Hide)
    f.channel = chan

    -- Barre de volume 0 - 200 %
    local vol = CreateFrame("Slider", nil, f, "BackdropTemplate")
    vol:SetSize(170, 10)
    vol:SetPoint("RIGHT", chan, "LEFT", -14, -6)
    vol:SetOrientation("HORIZONTAL")
    vol:SetMinMaxValues(0, 200)
    vol:SetValueStep(5)
    vol:SetObeyStepOnDrag(true)
    vol:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    vol:SetBackdropColor(0, 0, 0, 0.5)
    vol:SetBackdropBorderColor(1, 1, 1, 0.2)
    vol:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    local vthumb = vol:GetThumbTexture()
    vthumb:SetSize(8, 16)
    vthumb:SetVertexColor(1, 1, 1, 0.9)
    local fill = vol:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMLEFT", 1, 1)
    fill:SetColorTexture(1, 1, 1, 1)
    local mark = vol:CreateTexture(nil, "OVERLAY")
    mark:SetSize(1, 14)
    mark:SetPoint("CENTER")
    mark:SetColorTexture(1, 1, 1, 0.5)
    local vlabel = vol:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    vlabel:SetPoint("BOTTOM", vol, "TOP", 0, 3)
    local updating = false
    vol:SetScript("OnValueChanged", function(_, v)
        if updating then return end
        SetVolume(v / 100)
    end)
    vol:EnableMouseWheel(true)
    vol:SetScript("OnMouseWheel", function(_, d) SetVolume(db.volume + d * 0.05) end)
    vol:SetScript("OnMouseUp", function(_, btn) if btn == "RightButton" then SetVolume(1) end end)
    vol:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Volume de la bibliothèque : " .. floor(db.volume * 100 + 0.5) .. " %")
        GameTooltip:AddLine("Glisser ou molette : régler (0 à 200 %). Clic droit : 100 %.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Le volume du canal choisi est modifié seulement pendant l'écoute, puis remis comme avant. Au-delà de 100 %, le son est joué en double.", 0.6, 0.6, 0.6, true)
        GameTooltip:AddLine("Musique : au-delà de 100 %, limité au maximum du canal Musique.", 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    vol:SetScript("OnLeave", GameTooltip_Hide)

    function UI.RefreshVolume()
        local pct = floor(db.volume * 100 + 0.5)
        updating = true
        vol:SetValue(pct)
        updating = false
        local r, g, b = 0.2, 0.8, 1
        if pct > 100 then r, g, b = 1, 0.6 - (pct - 100) / 250, 0.1 end
        if pct == 0 then r, g, b = 0.5, 0.5, 0.5 end
        fill:SetWidth(max(1, (vol:GetWidth() - 2) * pct / 200))
        fill:SetVertexColor(r, g, b, 0.8)
        local note = (UI.capped and current and current.cat == "music") and " |cffff8800(max atteint)|r" or ""
        vlabel:SetText("Volume : " .. pct .. " %" .. note)
    end

    f.playing = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.playing:SetPoint("BOTTOMLEFT", 14, 30)
    f.playing:SetPoint("RIGHT", vol, "LEFT", -12, 0)
    f.playing:SetJustifyH("LEFT")
    f.playing:SetWordWrap(false)

    f.listTitle:ClearAllPoints()
    f.listTitle:SetPoint("BOTTOMLEFT", 14, 14)
    f.listTitle:SetPoint("RIGHT", vol, "LEFT", -12, 0)
    f.listTitle:SetFontObject("GameFontNormalSmall")
    f.listTitle:Show()

    UI.Refresh()
    UI.RefreshPlaying()
    UI.RefreshVolume()
    UI.RefreshPick()
end

function ForeverSoundLibrary_Toggle()
    if not frame then CreateMainFrame(); frame:Show(); return end
    frame:SetShown(not frame:IsShown())
end

-- API pour les autres addons : ouvre la bibliothèque en mode « choix d'un son ».
-- callback(son) est appelé quand le joueur valide ; rien n'est appelé s'il ferme la fenêtre.
-- son = { id = nombre, kit = vrai si SoundKit (PlaySound) / faux si FileDataID (PlaySoundFile), name, dir }
-- label : texte affiché dans le titre (ex. « Guilde »).
function ForeverSoundLibrary_Pick(callback, label)
    if type(callback) ~= "function" or not db then return false end
    if not frame then CreateMainFrame() end
    if pick then frame:Hide() end   -- annule un choix précédent
    pick = { callback = callback, label = label }
    if state.tab == "music" then SetTab("sound") end
    frame:SetFrameStrata("FULLSCREEN_DIALOG")   -- au-dessus du menu Options
    frame:Show()
    frame:Raise()
    UI.RefreshPick()
    UI.RefreshPlaying()
    return true
end

-- Compartiment d'addons (bouton de la minicarte de Blizzard)
function ForeverSoundLibrary_OnCompartmentClick() ForeverSoundLibrary_Toggle() end

BINDING_HEADER_FOREVERSOUNDLIBRARY = "ForeverSoundLibrary"
BINDING_NAME_FOREVERSOUNDLIBRARY_TOGGLE = "Ouvrir / fermer la bibliothèque"

------------------------------------------------------------------------
-- Bouton de minicarte
------------------------------------------------------------------------
local mmb

local function PlaceMinimapButton()
    local a = math.rad(db.minimap.angle)
    local r = (Minimap:GetWidth() / 2) + 8
    mmb:ClearAllPoints()
    mmb:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function CreateMinimapButton()
    mmb = CreateFrame("Button", "ForeverSoundLibraryMinimapButton", Minimap)
    mmb:SetSize(31, 31)
    mmb:SetFrameStrata("MEDIUM")
    mmb:SetFrameLevel(8)
    mmb:RegisterForClicks("AnyUp")
    mmb:RegisterForDrag("LeftButton")
    mmb:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local bg = mmb:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)
    local icon = mmb:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetTexture(ICON)
    icon:SetPoint("TOPLEFT", 7, -6)
    local border = mmb:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")
    mmb:SetScript("OnClick", ForeverSoundLibrary_Toggle)
    mmb:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            db.minimap.angle = math.deg(math.atan2(py / s - my, px / s - mx))
            PlaceMinimapButton()
        end)
    end)
    mmb:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    mmb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff33ccffForeverSoundLibrary|r")
        GameTooltip:AddLine("Clic : ouvrir la bibliothèque", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Glisser : déplacer le bouton", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    mmb:SetScript("OnLeave", GameTooltip_Hide)
    PlaceMinimapButton()
    mmb:SetShown(not db.minimap.hide)
end

------------------------------------------------------------------------
-- Initialisation et commandes
------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGOUT" then
        -- Remet le volume du joueur avant la sauvegarde (déconnexion, /reload).
        RestoreVolume()
        return
    end
    if name ~= ADDON then return end
    ForeverSoundLibraryDB = ForeverSoundLibraryDB or {}
    db = ForeverSoundLibraryDB
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = type(v) == "table" and CopyTable(v) or v end
    end
    if db.minimap.angle == nil then db.minimap.angle = DEFAULTS.minimap.angle end
    -- Volume resté modifié après un crash : on le remet.
    if type(db.boost) == "table" and db.boost.cvar then
        boost = db.boost
        RestoreVolume()
    end
    CreateMinimapButton()
    ev:UnregisterEvent("ADDON_LOADED")
end)

-- Liste des commandes (aide du chat + panneau du menu Options)
ns.COMMANDS = {
    { "/fsl", "Ouvrir / fermer la bibliothèque" },
    { "/fsl options", "Ouvrir ce panneau d'options" },
    { "/fsl search <texte>", "Ouvrir la bibliothèque et rechercher" },
    { "/fsl stop", "Arrêter le son / la musique en cours" },
    { "/fsl play <FileID>", "Jouer un son par son ID" },
    { "/fsl music <FileID>", "Jouer une musique par son ID" },
    { "/fsl vol <0-200>", "Régler le volume de la bibliothèque" },
    { "/fsl minimap", "Afficher / masquer le bouton de la minicarte" },
    { "/fsl version", "Afficher la version de l'addon" },
}
ns.version = Version()
function ns.OpenLibrary()
    if not frame then CreateMainFrame() end
    frame:Show()
end

SLASH_FOREVERSOUNDLIBRARY1 = "/fsl"
SLASH_FOREVERSOUNDLIBRARY2 = "/soundlib"
SlashCmdList.FOREVERSOUNDLIBRARY = function(input)
    if not db then return end
    local cmd, arg = strtrim(input or ""):lower():match("^(%S*)%s*(.-)$")
    if cmd == "" then
        ForeverSoundLibrary_Toggle()
    elseif cmd == "stop" then
        StopAll()
    elseif cmd == "minimap" then
        db.minimap.hide = not db.minimap.hide
        mmb:SetShown(not db.minimap.hide)
        Print("bouton de minicarte " .. (db.minimap.hide and "|cffff0000masqué|r" or "|cff00ff00affiché|r"))
    elseif (cmd == "play" or cmd == "music") and tonumber(arg) then
        Play({ cat = cmd == "music" and "music" or "sound", id = tonumber(arg), name = "ID " .. arg, dir = "?" })
    elseif cmd == "vol" or cmd == "volume" then
        local v = tonumber((arg:gsub("%%", "")))
        if v then SetVolume(v / 100) end
        Print("volume : " .. floor(db.volume * 100 + 0.5) .. " %")
    elseif cmd == "search" or cmd == "cherche" then
        if not frame then CreateMainFrame() end
        frame:Show()
        frame.search:SetText(arg)
    elseif cmd == "options" or cmd == "config" then
        if ns.OpenOptions then ns.OpenOptions() end
    elseif cmd == "version" then
        Print("version " .. Version())
    else
        Print("v" .. Version() .. " - commandes :")
        for _, c in ipairs(ns.COMMANDS) do Print(c[1] .. " : " .. c[2]) end
    end
end
