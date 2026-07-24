--[[
    Nasi Rendang LUA — Free Script Loader
    ------------------------------------------------------------------
    Single-file loader. Two views inside one window:
      HOME  -> brand card + "Choose Game"
      GAMES -> scrollable game list, click to fetch + run

    Visual language matches the GAG2 panel (glass dark-green, Gotham,
    Quad/Quint/Back tweens) so both products read as one brand.

    Every fetch is pcall-wrapped; a failed HttpGet or a script that
    errors on run surfaces as a toast and resets the row, it never
    kills the loader.
--]]

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer

-- Prefer the executor's hidden GUI container so the panel is invisible to
-- game-side scans of PlayerGui / CoreGui.
local CoreParent = LocalPlayer:WaitForChild("PlayerGui")
pcall(function() if gethui then CoreParent = gethui() end end)

local LOGO   = "rbxassetid://124947058155926"
local TITLE  = "Nasi Rendang LUA"
local SUB    = "Free Script Loader"
local DISCORD = "https://discord.gg/vrzg9YaNPj"

-- ============================== Catalog =================================
-- `match` is matched case-insensitively against the current place name so the
-- loader can flag which entry belongs to the game you are actually in. No
-- hardcoded PlaceIds — place ids get re-published, names don't.

local GAMES = {
    {
        name  = "Evomon",
        desc  = "Auto hunt / evolve",
        icon  = "rbxassetid://130560455657984",
        match = { "evomon" },
        url   = "https://raw.githubusercontent.com/JualNasiRendang/nasirendang-evomon/refs/heads/main/nasirendang-evomon.lua",
    },
    {
        name  = "Grow A Garden",
        desc  = "Auto farm / shop / sell",
        icon  = "rbxassetid://99059513244042",
        match = { "grow a garden", "garden" },
        url   = "https://raw.githubusercontent.com/JualNasiRendang/gag2/refs/heads/main/gag2.lua",
    },
    {
        name  = "Tap Heroes: Pet Simulator 99",
        desc  = "Auto tap / farm",
        icon  = "rbxassetid://105448686912619",
        match = { "pet simulator", "tap heroes" },
        url   = "https://raw.githubusercontent.com/JualNasiRendang/tap-heroes-pet-99/refs/heads/main/tapheroes.lua",
    },
    {
        name  = "Haze Seas",
        desc  = "Auto punch / farm",
        icon  = "rbxassetid://105345745320241",
        match = { "haze seas", "haze" },
        url   = "https://api.jnkie.com/api/v1/luascripts/public/22f48663c6746ee37619da35213c1fe72cdb0ec30bdfbba83773d2b2f595a53d/download",
        -- Set on getgenv() before the chunk runs (keyless auth for this provider).
        genv  = { SCRIPT_KEY = "KEYLESS" },
    },
    {
        name  = "Build a Ring Farm",
        desc  = "Auto farm",
        icon  = "rbxassetid://130560455657984",
        match = { "build a ring", "ring farm" },
        url   = "https://raw.githubusercontent.com/JualNasiRendang/nasirendang-barf/refs/heads/main/nasirendang-barf.lua",
    },
}

-- ============================== Theme ===================================

local Theme = {
    Window    = Color3.fromRGB(14, 16, 15),
    TopBar    = Color3.fromRGB(18, 21, 20),
    Panel     = Color3.fromRGB(11, 13, 12),
    Control   = Color3.fromRGB(24, 28, 26),
    Border    = Color3.fromRGB(38, 44, 41),
    Accent    = Color3.fromRGB(160, 95, 245),
    AccentDim = Color3.fromRGB(58, 34, 92),
    Text      = Color3.fromRGB(228, 232, 229),
    SubText   = Color3.fromRGB(120, 128, 124),
    Danger    = Color3.fromRGB(220, 90, 90),
}

local WIN_T, CTRL_T = 0.12, 0.2

local T_FAST  = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local T_VIEW  = TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local T_POP   = TweenInfo.new(0.18, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)
local T_FADE  = TweenInfo.new(0.30, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)

local function new(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = inst end
    return inst
end
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r or 8) }) end
local function stroke(c, t, tr)
    return new("UIStroke", {
        Color = c or Theme.Border, Thickness = t or 1, Transparency = tr or 0.2,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

-- ============================== Root ====================================
-- Re-injecting REPLACES the loader instead of stacking copies.
do
    local seen, roots = {}, { CoreParent, LocalPlayer:FindFirstChildOfClass("PlayerGui") }
    pcall(function() if gethui then roots[#roots + 1] = gethui() end end)
    pcall(function() roots[#roots + 1] = game:GetService("CoreGui") end)
    for _, root in ipairs(roots) do
        if root and not seen[root] then
            seen[root] = true
            for _, g in ipairs(root:GetChildren()) do
                if g.Name == "NR_Loader" then pcall(function() g:Destroy() end) end
            end
        end
    end
end

local ScreenGui = new("ScreenGui", {
    Name = "NR_Loader", Parent = CoreParent, ResetOnSpawn = false,
    IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1000,
})
pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(ScreenGui)
    elseif protectgui then protectgui(ScreenGui) end
end)

local W, H = 420, 300

local Window = new("Frame", {
    Name = "Window", Parent = ScreenGui, Active = true,
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(W, H), BackgroundColor3 = Theme.Window,
    BackgroundTransparency = WIN_T, BorderSizePixel = 0, ClipsDescendants = true,
}, { corner(14), stroke(Theme.Border, 1) })

-- Responsive scale, recomputed on rotate/resize.
local WindowScale = new("UIScale", { Parent = Window })
local function fitWindow()
    local cam = workspace.CurrentCamera
    local vp = (cam and cam.ViewportSize) or Vector2.new(800, 600)
    local s = math.min((vp.X - 20) / W, (vp.Y - 20) / H)
    if UserInputService.TouchEnabled then s = s * 0.78 end
    WindowScale.Scale = math.clamp(s, 0.34, 1)
end
fitWindow()
local function hookViewport()
    local cam = workspace.CurrentCamera
    if cam then pcall(function() cam:GetPropertyChangedSignal("ViewportSize"):Connect(fitWindow) end) end
end
hookViewport()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() fitWindow(); hookViewport() end)

-- Intro: scale + fade the whole window in.
do
    -- Animate WindowScale itself — a second UIScale under the same frame would
    -- fight it (Roblox only honours one) and snap on cleanup.
    local target = WindowScale.Scale
    WindowScale.Scale = target * 0.9
    Window.BackgroundTransparency = 1
    Window.UIStroke.Transparency = 1
    TweenService:Create(WindowScale, T_POP, { Scale = target }):Play()
    TweenService:Create(Window, T_FADE, { BackgroundTransparency = WIN_T }):Play()
    TweenService:Create(Window.UIStroke, T_FADE, { Transparency = 0.2 }):Play()
end

-- ============================== Toasts ==================================

local ToastHost = new("Frame", {
    Name = "Toasts", Parent = ScreenGui, AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -12, 1, -12), Size = UDim2.new(0, 250, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
})
new("UIListLayout", {
    Parent = ToastHost, Padding = UDim.new(0, 6),
    VerticalAlignment = Enum.VerticalAlignment.Bottom,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    SortOrder = Enum.SortOrder.LayoutOrder,
})

local function showToast(text, isError, life)
    local accent = isError and Theme.Danger or Theme.Accent
    local card = new("Frame", {
        Parent = ToastHost, Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Theme.Window,
        BackgroundTransparency = 0.05, BorderSizePixel = 0,
    }, { corner(8), stroke(accent, 1) })
    new("Frame", {
        Parent = card, Size = UDim2.new(0, 3, 1, -12), Position = UDim2.new(0, 6, 0.5, -16),
        BackgroundColor3 = accent, BorderSizePixel = 0,
    }, { corner(2) })
    local lbl = new("TextLabel", {
        Parent = card, Position = UDim2.new(0, 16, 0, 0), Size = UDim2.new(1, -26, 1, 0),
        BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = text, TextColor3 = Theme.Text,
        TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    })

    local sc = new("UIScale", { Parent = card, Scale = 0.85 })
    TweenService:Create(sc, T_POP, { Scale = 1 }):Play()

    task.delay(life or 5, function()
        if not card.Parent then return end
        TweenService:Create(card, T_FADE, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(card.UIStroke, T_FADE, { Transparency = 1 }):Play()
        TweenService:Create(lbl, T_FADE, { TextTransparency = 1 }):Play()
        task.wait(0.32)
        if card.Parent then card:Destroy() end
    end)
end

-- ============================== Top bar =================================

local TopBar = new("Frame", {
    Name = "TopBar", Parent = Window, Size = UDim2.new(1, 0, 0, 52),
    BackgroundColor3 = Theme.TopBar, BackgroundTransparency = 0.1, BorderSizePixel = 0,
}, { corner(14) })
-- square the bottom edge of the rounded bar
new("Frame", {
    Parent = TopBar, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14),
    BackgroundColor3 = Theme.TopBar, BackgroundTransparency = 0.1, BorderSizePixel = 0,
})

local BackButton = new("TextButton", {
    Parent = TopBar, Name = "Back", Size = UDim2.fromOffset(26, 26),
    Position = UDim2.new(0, 12, 0.5, -13), BackgroundColor3 = Theme.Control,
    BackgroundTransparency = 1, AutoButtonColor = false, Text = "<",
    Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.SubText,
    Visible = false,
}, { corner(8) })

local BarLogo = new("ImageLabel", {
    Parent = TopBar, Size = UDim2.fromOffset(32, 32), Position = UDim2.new(0, 14, 0.5, -16),
    BackgroundTransparency = 1, Image = LOGO,
}, { corner(8) })

local BarTitle = new("TextLabel", {
    Parent = TopBar, Size = UDim2.new(1, -160, 0, 17), Position = UDim2.new(0, 56, 0, 10),
    BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = TITLE,
    TextColor3 = Theme.Text, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
})
local BarSub = new("TextLabel", {
    Parent = TopBar, Size = UDim2.new(1, -160, 0, 13), Position = UDim2.new(0, 56, 0, 27),
    BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = SUB,
    TextColor3 = Theme.SubText, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
})

local CloseButton = new("TextButton", {
    Parent = TopBar, Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -36, 0.5, -13),
    BackgroundColor3 = Theme.Control, BackgroundTransparency = CTRL_T, Text = "x",
    Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.SubText, AutoButtonColor = false,
}, { corner(8) })

-- Hover feedback shared by the small square bar buttons.
local function hoverable(btn, hi, lo)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, T_FAST, { TextColor3 = hi or Theme.Text }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, T_FAST, { TextColor3 = lo or Theme.SubText }):Play()
    end)
end
hoverable(CloseButton, Theme.Danger)
hoverable(BackButton, Theme.Text)

-- ============================== Drag ====================================
-- Mouse + touch. Position is written directly (no tween) so the window tracks
-- the pointer 1:1; scale is irrelevant because we move the parent frame.
do
    local dragging, dragStart, startPos, dragInput
    TopBar.Active = true
    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, Window.Position
            local conn
            conn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    conn:Disconnect()
                end
            end)
        end
    end)
    TopBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local d = input.Position - dragStart
            Window.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- ============================== View host ===============================
-- Two sibling frames slid horizontally. ContentHost clips the overflow.

local ContentHost = new("Frame", {
    Name = "Content", Parent = Window, Position = UDim2.new(0, 0, 0, 52),
    Size = UDim2.new(1, 0, 1, -52), BackgroundTransparency = 1, ClipsDescendants = true,
})

local HomeView = new("Frame", {
    Name = "Home", Parent = ContentHost, Size = UDim2.fromScale(1, 1),
    Position = UDim2.fromScale(0, 0), BackgroundTransparency = 1,
})
local GamesView = new("Frame", {
    Name = "Games", Parent = ContentHost, Size = UDim2.fromScale(1, 1),
    Position = UDim2.fromScale(1, 0), BackgroundTransparency = 1, Visible = false,
})

local currentView = "home"
local function goTo(view)
    if currentView == view then return end
    currentView = view
    local toGames = (view == "games")

    GamesView.Visible = true
    HomeView.Visible = true
    TweenService:Create(HomeView,  T_VIEW, { Position = UDim2.fromScale(toGames and -1 or 0, 0) }):Play()
    TweenService:Create(GamesView, T_VIEW, { Position = UDim2.fromScale(toGames and 0 or 1, 0) }):Play()

    BackButton.Visible = toGames
    TweenService:Create(BarLogo, T_VIEW, {
        Position = UDim2.new(0, toGames and 44 or 14, 0.5, -16),
    }):Play()
    local textX = toGames and 86 or 56
    TweenService:Create(BarTitle, T_VIEW, { Position = UDim2.new(0, textX, 0, 10) }):Play()
    TweenService:Create(BarSub,   T_VIEW, { Position = UDim2.new(0, textX, 0, 27) }):Play()
    BarSub.Text = toGames and "Choose a game" or SUB

    task.delay(0.28, function()
        if currentView == "games" then HomeView.Visible = false
        else GamesView.Visible = false end
    end)
end

BackButton.MouseButton1Click:Connect(function() goTo("home") end)

-- ============================== Home view ===============================

local BigLogo = new("ImageLabel", {
    Parent = HomeView, Size = UDim2.fromOffset(72, 72), AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 14), BackgroundTransparency = 1, Image = LOGO,
}, { corner(16) })
-- Soft accent ring behind the mark, breathing on a slow loop.
local LogoRing = new("UIStroke", {
    Parent = BigLogo, Color = Theme.Accent, Thickness = 1.5, Transparency = 0.55,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
})

new("TextLabel", {
    Parent = HomeView, Size = UDim2.new(1, -32, 0, 20), Position = UDim2.new(0, 16, 0, 96),
    BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = TITLE .. " Free Script",
    TextColor3 = Theme.Text, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center,
})
local PlaceLabel = new("TextLabel", {
    Parent = HomeView, Size = UDim2.new(1, -32, 0, 14), Position = UDim2.new(0, 16, 0, 118),
    BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = "Detecting game...",
    TextColor3 = Theme.SubText, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center,
    TextTruncate = Enum.TextTruncate.AtEnd,
})

local ChooseButton = new("TextButton", {
    Parent = HomeView, Size = UDim2.new(1, -80, 0, 40), Position = UDim2.new(0, 40, 0, 148),
    BackgroundColor3 = Theme.AccentDim, BackgroundTransparency = 0.1, BorderSizePixel = 0,
    AutoButtonColor = false, Font = Enum.Font.GothamBold, Text = "CHOOSE GAME",
    TextSize = 13, TextColor3 = Theme.Text,
}, { corner(10), stroke(Theme.Accent, 1, 0.15) })
do
    local sc = new("UIScale", { Parent = ChooseButton })
    ChooseButton.MouseEnter:Connect(function()
        TweenService:Create(sc, T_FAST, { Scale = 1.03 }):Play()
        TweenService:Create(ChooseButton, T_FAST, { BackgroundTransparency = 0 }):Play()
    end)
    ChooseButton.MouseLeave:Connect(function()
        TweenService:Create(sc, T_FAST, { Scale = 1 }):Play()
        TweenService:Create(ChooseButton, T_FAST, { BackgroundTransparency = 0.1 }):Play()
    end)
    ChooseButton.MouseButton1Down:Connect(function()
        TweenService:Create(sc, T_FAST, { Scale = 0.97 }):Play()
    end)
    ChooseButton.MouseButton1Up:Connect(function()
        TweenService:Create(sc, T_FAST, { Scale = 1.03 }):Play()
    end)
end
ChooseButton.MouseButton1Click:Connect(function() goTo("games") end)

local DiscordButton = new("TextButton", {
    Parent = HomeView, Size = UDim2.new(1, -80, 0, 18), Position = UDim2.new(0, 40, 0, 198),
    BackgroundTransparency = 1, AutoButtonColor = false, Font = Enum.Font.Gotham,
    Text = "discord.gg/vrzg9YaNPj — click to copy", TextSize = 10, TextColor3 = Theme.Accent,
})
DiscordButton.MouseButton1Click:Connect(function()
    local ok = pcall(setclipboard, DISCORD)
    showToast(ok and "Invite link copied to clipboard" or "setclipboard unavailable", not ok)
end)

new("TextLabel", {
    Parent = HomeView, Size = UDim2.new(1, -32, 0, 12), AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 16, 1, -8), BackgroundTransparency = 1, Font = Enum.Font.Gotham,
    Text = ("%d scripts available  |  %s"):format(#GAMES, (function()
        local ok, id = pcall(function() return identifyexecutor() end)
        return ok and id or "Volt"
    end)()),
    TextColor3 = Theme.SubText, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center,
})

-- Breathing ring on the logo. Stored so it can be killed on close.
local ringAlive = true
task.spawn(function()
    while ringAlive do
        TweenService:Create(LogoRing, TweenInfo.new(1.1, Enum.EasingStyle.Sine), { Transparency = 0.85 }):Play()
        task.wait(1.15)
        if not ringAlive then break end
        TweenService:Create(LogoRing, TweenInfo.new(1.1, Enum.EasingStyle.Sine), { Transparency = 0.45 }):Play()
        task.wait(1.15)
    end
end)

-- ============================== Games view ==============================

local List = new("ScrollingFrame", {
    Parent = GamesView, Size = UDim2.new(1, -20, 1, -12), Position = UDim2.new(0, 10, 0, 6),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3,
    ScrollBarImageColor3 = Theme.Border, ScrollBarImageTransparency = 0.3,
})
new("UIListLayout", { Parent = List, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
new("UIPadding", { Parent = List, PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6),
    PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 6) })

-- Current place name, used to flag the matching row.
local placeName = ""
task.spawn(function()
    local ok, info = pcall(function()
        return MarketplaceService:GetProductInfo(game.PlaceId)
    end)
    placeName = (ok and info and info.Name) or ""
    PlaceLabel.Text = placeName ~= "" and ("In game: " .. placeName) or "Game not identified"
end)

local busy = false  -- one load at a time; a second click while fetching is ignored

local function runScript(entry, row, statusLbl, spinner)
    if busy then return end
    busy = true

    statusLbl.Text = "Fetching..."
    statusLbl.TextColor3 = Theme.SubText
    spinner.Visible = true

    -- Spinner runs on Heartbeat until the load settles.
    local spinning = true
    task.spawn(function()
        while spinning and spinner.Parent do
            spinner.Rotation = (spinner.Rotation + 6) % 360
            RunService.Heartbeat:Wait()
        end
    end)

    local function finish(okState, msg)
        spinning = false
        spinner.Visible = false
        statusLbl.Text = msg
        statusLbl.TextColor3 = okState and Theme.Accent or Theme.Danger
        TweenService:Create(row.UIStroke, T_FAST, {
            Color = okState and Theme.Accent or Theme.Danger, Transparency = 0.1,
        }):Play()
        busy = false
    end

    task.spawn(function()
        local okFetch, src = pcall(function() return game:HttpGet(entry.url, true) end)
        if not okFetch or type(src) ~= "string" or src == "" then
            finish(false, "Fetch failed")
            showToast(("HttpGet failed for %s — check the raw URL or your connection."):format(entry.name), true)
            return
        end
        if src:sub(1, 15):lower():find("<!doctype") or src:lower():find("^404: not found") then
            finish(false, "Bad URL")
            showToast(("%s returned a web page, not Lua. The raw link is wrong or the file is missing."):format(entry.name), true)
            return
        end

        statusLbl.Text = "Loading..."

        -- Some providers gate the script behind a global set on getgenv()
        -- (e.g. keyless auth). Apply before the chunk runs.
        if entry.genv then
            local env = getgenv()
            for k, v in pairs(entry.genv) do env[k] = v end
        end

        local chunk, compileErr = loadstring(src, "@" .. entry.name)
        if not chunk then
            finish(false, "Compile error")
            showToast(("loadstring: %s"):format(tostring(compileErr)), true, 8)
            return
        end

        local okRun, runErr = pcall(chunk)
        if not okRun then
            finish(false, "Runtime error")
            showToast(("%s errored: %s"):format(entry.name, tostring(runErr)), true, 8)
            return
        end

        finish(true, "Loaded")
        showToast(("%s loaded."):format(entry.name))
        -- The loaded script owns the screen now — fold the loader away.
        task.delay(0.6, function()
            TweenService:Create(Window, T_FADE, { BackgroundTransparency = 1 }):Play()
            TweenService:Create(WindowScale, T_FADE, { Scale = WindowScale.Scale * 0.92 }):Play()
            task.wait(0.32)
            ringAlive = false
            if ScreenGui.Parent then ScreenGui:Destroy() end
        end)
    end)
end

local function gameRow(entry, order)
    local row = new("TextButton", {
        Parent = List, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 58),
        BackgroundColor3 = Theme.Control, BackgroundTransparency = CTRL_T,
        BorderSizePixel = 0, AutoButtonColor = false, Text = "",
    }, { corner(10), stroke(Theme.Border, 1) })

    new("ImageLabel", {
        Parent = row, Size = UDim2.fromOffset(34, 34), Position = UDim2.new(0, 12, 0.5, -17),
        BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.3, Image = entry.icon,
    }, { corner(8) })

    new("TextLabel", {
        Parent = row, Size = UDim2.new(1, -140, 0, 16), Position = UDim2.new(0, 56, 0, 12),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = entry.name,
        TextColor3 = Theme.Text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    new("TextLabel", {
        Parent = row, Size = UDim2.new(1, -140, 0, 14), Position = UDim2.new(0, 56, 0, 29),
        BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = entry.desc,
        TextColor3 = Theme.SubText, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local status = new("TextLabel", {
        Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -34, 0.5, 0),
        Size = UDim2.fromOffset(78, 16), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
        Text = "", TextColor3 = Theme.SubText, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local spinner = new("ImageLabel", {
        Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1, Visible = false,
        Image = "rbxasset://textures/loading/robloxTiltRight.png", ImageColor3 = Theme.Accent,
    })
    local arrow = new("TextLabel", {
        Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(10, 16), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
        Text = ">", TextColor3 = Theme.SubText, TextSize = 12,
    })

    -- Flag the row that matches the place we're in, once the name resolves.
    task.spawn(function()
        local waited = 0
        while placeName == "" and waited < 5 do task.wait(0.2); waited = waited + 0.2 end
        local lower = placeName:lower()
        for _, kw in ipairs(entry.match) do
            if lower:find(kw, 1, true) then
                status.Text = "CURRENT GAME"
                status.TextColor3 = Theme.Accent
                -- Float the matching game to the top of the list. LayoutOrder < 1
                -- sorts it above every other row (built with order 1..N).
                row.LayoutOrder = -1
                local sc = row:FindFirstChildOfClass("UIScale")
                if sc then
                    sc.Scale = 0.97
                    TweenService:Create(sc, T_POP, { Scale = 1 }):Play()
                end
                TweenService:Create(row.UIStroke, T_FAST, { Color = Theme.AccentDim, Transparency = 0.1 }):Play()
                break
            end
        end
    end)

    local sc = new("UIScale", { Parent = row })
    row.MouseEnter:Connect(function()
        TweenService:Create(row, T_FAST, { BackgroundTransparency = 0.05 }):Play()
        TweenService:Create(sc, T_FAST, { Scale = 1.015 }):Play()
        TweenService:Create(arrow, T_FAST, { TextColor3 = Theme.Accent }):Play()
    end)
    row.MouseLeave:Connect(function()
        TweenService:Create(row, T_FAST, { BackgroundTransparency = CTRL_T }):Play()
        TweenService:Create(sc, T_FAST, { Scale = 1 }):Play()
        TweenService:Create(arrow, T_FAST, { TextColor3 = Theme.SubText }):Play()
    end)
    row.MouseButton1Click:Connect(function()
        if busy then
            showToast("Another script is still loading.", true, 3)
            return
        end
        arrow.Visible = false
        runScript(entry, row, status, spinner)
    end)

    -- Staggered entrance so the list cascades in.
    row.BackgroundTransparency = 1
    sc.Scale = 0.96
    task.delay(0.04 * order, function()
        if not row.Parent then return end
        TweenService:Create(row, T_FAST, { BackgroundTransparency = CTRL_T }):Play()
        TweenService:Create(sc, T_POP, { Scale = 1 }):Play()
    end)

    return row
end

for i, entry in ipairs(GAMES) do
    gameRow(entry, i)
end

-- ============================== Close ===================================

local function closeLoader()
    ringAlive = false
    TweenService:Create(Window, T_FADE, { BackgroundTransparency = 1 }):Play()
    TweenService:Create(Window.UIStroke, T_FADE, { Transparency = 1 }):Play()
    TweenService:Create(WindowScale, T_FADE, { Scale = WindowScale.Scale * 0.9 }):Play()
    task.wait(0.32)
    if ScreenGui.Parent then ScreenGui:Destroy() end
end

CloseButton.MouseButton1Click:Connect(function() task.spawn(closeLoader) end)

-- RightShift toggles visibility without tearing the loader down.
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift and ScreenGui.Parent then
        Window.Visible = not Window.Visible
    end
end)

showToast("Nasi Rendang loader ready. Pick a game.")
