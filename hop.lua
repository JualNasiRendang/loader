--[[
    ============================================================================
    AUTO HOP — standalone server hopper
    Server dipilih RANDOM (exclude server saat ini + yang full), bisa prefer
    yang paling sepi. Auto Send Chat dengan rotasi 3 pesan + countdown.

    Auto-execute: pas hop, queueonteleport nge-download script dari URL
    (github raw) terus loadstring - jadi file ini cukup di-upload ke URL itu
    dan semua perubahan langsung ke-sync.

    Config: StealAnEgg/autoHop.json
    ============================================================================
]]

-- single-instance guard: instance lama langsung mati pas versi baru di-run
local MY_RUN = os.clock()
getgenv().__AUTOHOP_ACTIVE = MY_RUN

local Players      = game:GetService("Players")
local HS           = game:GetService("HttpService")
local TS           = game:GetService("TeleportService")
local LocalPlayer  = Players.LocalPlayer
local PLACE        = game.PlaceId

-- URL auto-execute (download ulang script dari sini setelah hop)
local LOADER_URL = "https://raw.githubusercontent.com/JualNasiRendang/loader/refs/heads/main/hop.lua"

-- ============================ config ============================
local CFG_FOLDER = "StealAnEgg"
local CFG_PATH   = CFG_FOLDER .. "/autoHop.json"

local S = {
    autoHop         = true,
    hopWhen         = "Any",          -- "After Steal Count" | "Interval" | "No Match" | "Any"
    hopNoMatchDelay = 60,             -- detik tanpa claim
    hopInterval     = 15,             -- menit
    hopSteals       = 50,             -- jumlah claim
    hopMinPlayers   = 3,              -- server target harus isi >= ini (0 = off)
    hopPreferEmpty  = true,
    autoChat        = false,
    chatText        = "",
    chatText2       = "",
    chatText3       = "",
    chatInterval    = 30,
}

local function saveConfig()
    pcall(function()
        if type(makefolder) == "function" then pcall(makefolder, CFG_FOLDER) end
        if type(writefile) == "function" then writefile(CFG_PATH, HS:JSONEncode(S)) end
    end)
end
local function loadConfig()
    if type(readfile) ~= "function" then return end
    local ok, data = pcall(readfile, CFG_PATH)
    if not (ok and data) then return end
    local ok2, tbl = pcall(function() return HS:JSONDecode(data) end)
    if ok2 and type(tbl) == "table" then for k, v in pairs(tbl) do S[k] = v end end
end
loadConfig()

-- ==================== steal tracker (claim counter) ====================
-- hitung claim via signal game (bukan counter panel) biar standalone
local claims, lastClaim = 0, os.clock()
pcall(function()
    local EggCmds = require(game.ReplicatedStorage.Library.Client.EggCmds)
    EggCmds.AreaEggClaimed:Connect(function()
        claims = claims + 1
        lastClaim = os.clock()
    end)
end)

-- ==================== server list ====================
local function fetchServers()
    local list = {}
    local ok, body = pcall(function()
        return game:HttpGet(("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(PLACE))
    end)
    if not ok then return list end
    local ok2, data = pcall(function() return HS:JSONDecode(body) end)
    if ok2 and type(data) == "table" and type(data.data) == "table" then
        for _, s in ipairs(data.data) do
            if s.id and s.id ~= game.JobId and type(s.playing) == "number" and s.playing < (s.maxPlayers or 999) then
                -- filter min player (0 = off), selain itu random
                if (S.hopMinPlayers or 0) <= 0 or s.playing >= (S.hopMinPlayers or 0) then
                    list[#list + 1] = s
                end
            end
        end
    end
    return list
end

-- ==================== hop ====================
local hopping = false
local function doHop()
    if hopping then return false end
    hopping = true
    armAutoExec() -- re-inject diri sendiri di server baru via URL
    local cands = fetchServers()
    if #cands == 0 then
        -- min-player aktif tapi ga ada yang cocok: jangan matchmake ke server
        -- kecil - skip, loop retry lagi 5 detik kemudian
        if (S.hopMinPlayers or 0) > 0 then
            hopping = false
            return false
        end
        hopping = false
        pcall(function() TS:Teleport(PLACE, LocalPlayer) end)
        return true
    end
    -- Prefer empty: ambil tier paling sepi (min player +1) terus shuffle biar
    -- ga nyangkut di job mati yang sama terus. Kalo off: shuffle semua kandidat.
    if S.hopPreferEmpty then
        table.sort(cands, function(a, b) return a.playing < b.playing end)
        local minP = cands[1].playing
        local tier = {}
        for _, s in ipairs(cands) do if s.playing <= minP + 1 then tier[#tier + 1] = s end end
        cands = tier
    end
    for i = #cands, 2, -1 do local j = math.random(i); cands[i], cands[j] = cands[j], cands[i] end
    -- Coba kandidat satu-satu; TeleportInitFailed (server stale/penuh) -> next.
    local idx, conn = 0, nil
    local function tryNext()
        idx = idx + 1
        local s = cands[idx]
        if not s then
            if conn then conn:Disconnect() end
            hopping = false
            pcall(function() TS:Teleport(PLACE, LocalPlayer) end)
            return
        end
        pcall(function() TS:TeleportToPlaceInstance(PLACE, s.id, LocalPlayer) end)
    end
    conn = TS.TeleportInitFailed:Connect(function(plr)
        if plr == LocalPlayer then tryNext() end
    end)
    tryNext()
    return true
end

-- ==================== kondisi hop ====================
local hopStart, hopBaseClaims = os.clock(), claims
local function hopReady()
    local m = S.hopWhen
    if m == "After Steal Count" then
        return (claims - hopBaseClaims) >= (S.hopSteals or 50)
    elseif m == "Interval" then
        return (os.clock() - hopStart) >= (S.hopInterval or 15) * 60
    elseif m == "No Match" then
        return (os.clock() - lastClaim) >= (S.hopNoMatchDelay or 60)
    else -- Any
        return (claims - hopBaseClaims) >= (S.hopSteals or 50)
            or (os.clock() - hopStart) >= (S.hopInterval or 15) * 60
    end
end
local function resetBaselines()
    hopStart, hopBaseClaims = os.clock(), claims
end

-- ==================== auto-execute (URL) ====================
local function loaderSrc()
    return ([[
if getgenv().__AUTOHOP_RUN then return end
getgenv().__AUTOHOP_RUN = true
task.spawn(function()
    pcall(function() if not game:IsLoaded() then game.Loaded:Wait() end end)
    task.wait(2)
    local src
    for i = 1, 4 do
        local ok, res = pcall(game.HttpGet, game, %q)
        if ok and type(res) == "string" and #res > 0 then src = res break end
        task.wait(2)
    end
    if src then pcall(function() loadstring(src)() end) end
end)
]]):format(LOADER_URL)
end
function armAutoExec()
    if type(queueonteleport) == "function" then pcall(queueonteleport, loaderSrc()) end
end

-- ==================== auto send chat ====================
local chatCountLbl
local function sendChat(text)
    pcall(function()
        local tcs = game:GetService("TextChatService")
        local ch = nil
        -- channel general bisa di Folder "TextChannels" ATAU di property
        -- TextChannels - cek dua-duanya (di game ini channel-nya beda struktur)
        for _, f in ipairs(tcs:GetChildren()) do
            if f.Name == "TextChannels" and f:IsA("Folder") then
                ch = f:FindFirstChild("RBXGeneral") or f:FindFirstChild("General")
                if not ch then
                    for _, c in ipairs(f:GetChildren()) do
                        if c:IsA("TextChannel") and c.Name ~= "GameSystem" then ch = c break end
                    end
                end
                if ch then break end
            end
        end
        if not ch then
            pcall(function() ch = tcs.TextChannels and tcs.TextChannels:FindFirstChild("RBXGeneral") end)
        end
        if ch and ch.SendAsync then
            ch:SendAsync(text)
        else
            pcall(function() game:GetService("Players"):Chat(text) end)
        end
    end)
end
task.spawn(function()
    local lastSent = 0
    local chatIdx = 0
    while getgenv().__AUTOHOP_ACTIVE == MY_RUN do
        -- cek tiap 1 detik biar langsung kirim pas toggle dinyalain.
        -- ROTASI 3 pesan biar ga ke-sensor spam (pesan kosong dilewatin).
        if S.autoChat and (os.clock() - lastSent) >= math.max(5, S.chatInterval or 30) then
            local msgs = {}
            for _, t in ipairs({ S.chatText, S.chatText2, S.chatText3 }) do
                if tostring(t or "") ~= "" then msgs[#msgs + 1] = t end
            end
            if #msgs > 0 then
                lastSent = os.clock()
                chatIdx = chatIdx % #msgs + 1
                sendChat(msgs[chatIdx])
            end
        end
        -- countdown label
        if chatCountLbl then
            if S.autoChat then
                local hasMsg = false
                for _, t in ipairs({ S.chatText, S.chatText2, S.chatText3 }) do
                    if tostring(t or "") ~= "" then hasMsg = true break end
                end
                if not hasMsg then
                    chatCountLbl.Text = "chat on - isi pesan dulu!"
                else
                    local remain = math.max(0, math.ceil(math.max(5, S.chatInterval or 30) - (os.clock() - lastSent)))
                    chatCountLbl.Text = "next chat in " .. remain .. "s"
                end
            else
                chatCountLbl.Text = "chat off"
            end
        end
        task.wait(1)
    end
end)

-- ==================== main loop ====================
task.spawn(function()
    while getgenv().__AUTOHOP_ACTIVE == MY_RUN do
        if S.autoHop and hopReady() then
            local started = doHop()
            if started then
                resetBaselines()
                task.wait(10) -- biar teleport keburu proses
            end
            -- kalo hop di-skip, loop bakal cek lagi 5 detik kemudian
        end
        task.wait(5)
    end
end)

-- ==================== UI (kompak) ====================
local function new(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    for _, child in ipairs(children or {}) do child.Parent = inst end
    return inst
end
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r or 8) }) end

local THEME = {
    Window = Color3.fromRGB(13, 15, 18), Control = Color3.fromRGB(22, 26, 34),
    Border = Color3.fromRGB(36, 42, 54), Accent = Color3.fromRGB(58, 140, 255),
    Text = Color3.fromRGB(228, 232, 238), Sub = Color3.fromRGB(120, 128, 140),
}

local CoreParent = LocalPlayer:WaitForChild("PlayerGui")
pcall(function()
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui and hui ~= game:FindService("CoreGui") then CoreParent = hui end
    end
end)
do -- bunuh SEMUA panel lama di semua root (PlayerGui + CoreGui + gethui),
   -- biar ga ada 2 panel numpuk yang satu nulis status versi lama
    local seen = {}
    local roots = { CoreParent, LocalPlayer:FindFirstChildOfClass("PlayerGui"), game:GetService("CoreGui") }
    pcall(function() if gethui then roots[#roots + 1] = gethui() end end)
    for _, root in ipairs(roots) do
        if root and not seen[root] then
            seen[root] = true
            for _, g in ipairs(root:GetChildren()) do
                if g.Name == "AutoHop_Panel" then pcall(function() g:Destroy() end) end
            end
        end
    end
end

local ScreenGui = new("ScreenGui", { Name = "AutoHop_Panel", Parent = CoreParent, ResetOnSpawn = false,
    IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
pcall(function() if protectgui then protectgui(ScreenGui) end end)

local Window = new("Frame", { Name = "Window", Parent = ScreenGui, AnchorPoint = Vector2.new(0.5, 0.5),
    Size = UDim2.new(0, 300, 0, 430), Position = UDim2.new(0.5, 0, 0.5, 0),
    BackgroundColor3 = THEME.Window, BackgroundTransparency = 0.08, BorderSizePixel = 0,
    Active = true }, { corner(12), new("UIStroke", { Color = THEME.Accent, Thickness = 1.5,
    Transparency = 0.25, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
new("Frame", { Name = "TopBar", Parent = Window, Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = THEME.Control,
    BackgroundTransparency = 0.4, BorderSizePixel = 0 }, { corner(12) })
new("TextLabel", { Parent = Window, Size = UDim2.new(1, -80, 0, 38), Position = UDim2.new(0, 14, 0, 0),
    BackgroundTransparency = 1, Font = Enum.Font.BuilderSansBold, Text = "Auto Hop",
    TextColor3 = THEME.Text, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left })
new("TextButton", { Parent = Window, Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(1, -36, 0, 5),
    BackgroundColor3 = THEME.Control, BackgroundTransparency = 0.3, BorderSizePixel = 0,
    Font = Enum.Font.BuilderSansBold, Text = "x", TextSize = 14, TextColor3 = THEME.Sub,
    AutoButtonColor = false }, { corner(8) }).MouseButton1Click:Connect(function()
    ScreenGui.Enabled = not ScreenGui.Enabled
end)

-- drag handle: top bar doang (biar slider/button di bawah tetap normal)
do
    local DS = { on = false, start = nil, pos = nil }
    local UIS = game:GetService("UserInputService")
    Window.TopBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            DS.on = true; DS.start = inp.Position; DS.pos = Window.Position
        end
    end)
    Window.TopBar.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            DS.on = false
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if DS.on and inp.UserInputType == Enum.UserInputType.MouseMovement and DS.start then
            local d = inp.Position - DS.start
            Window.Position = UDim2.new(DS.pos.X.Scale, DS.pos.X.Offset + d.X, DS.pos.Y.Scale, DS.pos.Y.Offset + d.Y)
        end
    end)
end

local List = new("ScrollingFrame", { Parent = Window, Size = UDim2.new(1, -16, 1, -46), Position = UDim2.new(0, 8, 0, 42),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
    CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y })
new("UIListLayout", { Parent = List, Padding = UDim.new(0, 5) })

local function section(text)
    new("TextLabel", { Parent = List, Size = UDim2.new(1, -12, 0, 18), BackgroundTransparency = 1,
        Font = Enum.Font.BuilderSansBold, Text = text:upper(), TextColor3 = THEME.Sub, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left })
end

local function toggle(label, key)
    local row = new("Frame", { Parent = List, Size = UDim2.new(1, -12, 0, 26), BackgroundTransparency = 1 })
    new("TextLabel", { Parent = row, Size = UDim2.new(1, -50, 1, 0), Position = UDim2.new(0, 2, 0, 0),
        BackgroundTransparency = 1, Font = Enum.Font.BuilderSansMedium, Text = label,
        TextColor3 = THEME.Text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left })
    local pill = new("Frame", { Parent = row, Size = UDim2.new(0, 40, 0, 20), Position = UDim2.new(1, -42, 0.5, -10),
        BackgroundColor3 = S[key] and THEME.Accent or THEME.Border, BorderSizePixel = 0 }, { corner(10) })
    local knob = new("Frame", { Parent = pill, Size = UDim2.new(0, 14, 0, 14), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = S[key] and UDim2.new(1, -7, 0.5, 0) or UDim2.new(0, 7, 0.5, 0),
        BackgroundColor3 = S[key] and Color3.new(0, 0, 0) or THEME.Text, BorderSizePixel = 0 }, { corner(7) })
    new("TextButton", { Parent = row, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false }).MouseButton1Click:Connect(function()
        S[key] = not S[key]
        pill.BackgroundColor3 = S[key] and THEME.Accent or THEME.Border
        knob.Position = S[key] and UDim2.new(1, -7, 0.5, 0) or UDim2.new(0, 7, 0.5, 0)
        knob.BackgroundColor3 = S[key] and Color3.new(0, 0, 0) or THEME.Text
        saveConfig()
    end)
end

local function slider(label, key, minV, maxV, step)
    local row = new("Frame", { Parent = List, Size = UDim2.new(1, -12, 0, 40), BackgroundTransparency = 1 })
    local val = S[key]
    new("TextLabel", { Parent = row, Size = UDim2.new(1, -50, 0, 16), Position = UDim2.new(0, 2, 0, 0),
        BackgroundTransparency = 1, Font = Enum.Font.BuilderSansMedium, Text = label,
        TextColor3 = THEME.Text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left })
    local valLbl = new("TextLabel", { Parent = row, Size = UDim2.new(0, 44, 0, 16), Position = UDim2.new(1, -44, 0, 0),
        BackgroundTransparency = 1, Font = Enum.Font.BuilderSansBold, Text = tostring(val),
        TextColor3 = THEME.Accent, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right })
    local track = new("Frame", { Parent = row, Size = UDim2.new(1, -6, 0, 6), Position = UDim2.new(0, 3, 0, 26),
        BackgroundColor3 = THEME.Border, BorderSizePixel = 0 }, { corner(3) })
    local knob = new("Frame", { Parent = track, Size = UDim2.new(0, 14, 0, 14), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new((val - minV) / math.max(1, maxV - minV), 0, 0.5, 0),
        BackgroundColor3 = THEME.Text, BorderSizePixel = 0 }, { corner(7) })
    local hit = new("TextButton", { Parent = row, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, 20),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false })
    hit.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            local rel = math.clamp((inp.Position.X - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
            local v = math.floor(minV + rel * (maxV - minV) + 0.5)
            if step then v = math.floor(v / step + 0.5) * step end
            S[key] = math.clamp(v, minV, maxV)
            valLbl.Text = tostring(S[key])
            knob.Position = UDim2.new((S[key] - minV) / math.max(1, maxV - minV), 0, 0.5, 0)
            saveConfig()
        end
    end)
end

local function textbox(label, key)
    local row = new("Frame", { Parent = List, Size = UDim2.new(1, -12, 0, 26), BackgroundTransparency = 1 })
    new("TextLabel", { Parent = row, Size = UDim2.new(0, 130, 1, 0), BackgroundTransparency = 1,
        Font = Enum.Font.BuilderSansMedium, Text = label, TextColor3 = THEME.Text, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left })
    local box = new("TextBox", { Parent = row, Size = UDim2.new(1, -134, 1, 0), Position = UDim2.new(0, 134, 0, 0),
        BackgroundColor3 = THEME.Control, BackgroundTransparency = 0.2, BorderSizePixel = 0,
        Font = Enum.Font.BuilderSansMedium, Text = S[key] or "", PlaceholderText = "isi pesan...",
        TextColor3 = THEME.Text, PlaceholderColor3 = THEME.Sub, TextSize = 12,
        ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left }, { corner(6) })
    box.FocusLost:Connect(function()
        S[key] = box.Text
        saveConfig()
    end)
end

local function dropdown(label, key, options)
    local row = new("Frame", { Parent = List, Size = UDim2.new(1, -12, 0, 26), BackgroundTransparency = 1 })
    new("TextLabel", { Parent = row, Size = UDim2.new(0, 130, 1, 0), BackgroundTransparency = 1,
        Font = Enum.Font.BuilderSansMedium, Text = label, TextColor3 = THEME.Text, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left })
    local btn = new("TextButton", { Parent = row, Size = UDim2.new(1, -134, 1, 0), Position = UDim2.new(0, 134, 0, 0),
        BackgroundColor3 = THEME.Control, BackgroundTransparency = 0.2, BorderSizePixel = 0,
        Font = Enum.Font.BuilderSansMedium, Text = S[key], TextSize = 12, TextColor3 = THEME.Text,
        AutoButtonColor = false }, { corner(6) })
    btn.MouseButton1Click:Connect(function()
        local i = table.find(options, S[key]) or 1
        S[key] = options[i % #options + 1]
        btn.Text = S[key]
        saveConfig()
    end)
end

local statusLbl
local hopCountLbl
local function button(label, onClick)
    local b = new("TextButton", { Parent = List, Size = UDim2.new(1, -12, 0, 30), BackgroundColor3 = THEME.Accent,
        BackgroundTransparency = 0.75, BorderSizePixel = 0, Font = Enum.Font.BuilderSansBold,
        Text = label, TextSize = 13, TextColor3 = THEME.Text, AutoButtonColor = false }, { corner(8) })
    b.MouseButton1Click:Connect(function() pcall(onClick) end)
    return b
end

section("Server Hop")
toggle("Auto Server Hop", "autoHop")
dropdown("Hop When", "hopWhen", { "Any", "After Steal Count", "Interval", "No Match" })
slider("No Match Delay (s)", "hopNoMatchDelay", 3, 180, 1)
slider("Hop Interval (min)", "hopInterval", 1, 120, 1)
slider("Steals Before Hop", "hopSteals", 10, 200, 5)
slider("Min Players (0=off)", "hopMinPlayers", 0, 30, 1)
toggle("Prefer Emptiest Server", "hopPreferEmpty")
button("Hop Now", function() doHop() end)
hopCountLbl = new("TextLabel", { Parent = List, Size = UDim2.new(1, -12, 0, 16), BackgroundTransparency = 1,
    Font = Enum.Font.BuilderSansMedium, Text = "hop off", TextColor3 = THEME.Sub, TextSize = 12 })
statusLbl = new("TextLabel", { Parent = List, Size = UDim2.new(1, -12, 0, 16), BackgroundTransparency = 1,
    Font = Enum.Font.BuilderSansMedium, Text = "claims: 0", TextColor3 = THEME.Sub, TextSize = 12 })
section("Auto Send Chat")
toggle("Auto Send Chat", "autoChat")
textbox("Chat Text 1", "chatText")
textbox("Chat Text 2", "chatText2")
textbox("Chat Text 3", "chatText3")
slider("Chat Interval (s)", "chatInterval", 5, 600, 5)
chatCountLbl = new("TextLabel", { Parent = List, Size = UDim2.new(1, -12, 0, 16), BackgroundTransparency = 1,
    Font = Enum.Font.BuilderSansMedium, Text = "chat off", TextColor3 = THEME.Sub, TextSize = 12 })

-- status updater (claims + countdown hop)
task.spawn(function()
    while getgenv().__AUTOHOP_ACTIVE == MY_RUN do
        if statusLbl then
            statusLbl.Text = ("claims: %d | last: %ds ago"):format(claims, math.floor(os.clock() - lastClaim))
        end
        if hopCountLbl then
            if not S.autoHop then
                hopCountLbl.Text = "hop off"
            else
                local m = S.hopWhen
                if m == "After Steal Count" then
                    local n = math.max(0, (S.hopSteals or 50) - (claims - hopBaseClaims))
                    hopCountLbl.Text = ("next hop: %d steals lagi"):format(n)
                elseif m == "No Match" then
                    hopCountLbl.Text = ("next hop in %ds"):format(math.max(0, math.ceil((S.hopNoMatchDelay or 60) - (os.clock() - lastClaim))))
                elseif m == "Interval" then
                    hopCountLbl.Text = ("next hop in %ds"):format(math.max(0, math.ceil((S.hopInterval or 15) * 60 - (os.clock() - hopStart))))
                else
                    local t1 = math.max(0, (S.hopInterval or 15) * 60 - (os.clock() - hopStart))
                    hopCountLbl.Text = ("next hop in %ds"):format(math.ceil(t1))
                end
            end
        end
        task.wait(1)
    end
end)

print("[AutoHop] loaded - standalone server hopper (URL auto-execute)")
