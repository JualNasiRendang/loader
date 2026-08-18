-- ============================================================
-- FPS BOOST — standalone (tanpa UI)
-- Execute = langsung apply: strip semua beban render di workspace
-- (kecuali karakter sendiri), turunin kualitas, matiin shadow,
-- particle, post-fx + watcher buat instance baru (egg spawn terus).
-- Single-instance guard: execute ulang = instance lama mati.
-- Stop: getgenv().__FPSBOOST_STOP = true
--   (restore setting GLOBAL doang; per-instance strip permanen
--    sampe rejoin — decal/particle yang udah dimatiin dibiarin)
-- ============================================================

local MY_RUN = os.clock()
getgenv().__FPSBOOST_ACTIVE = MY_RUN
getgenv().__FPSBOOST_STOP = false

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local saved = {}
local function snapGlobals()
    if saved.done then return end
    saved.done = true
    pcall(function() saved.quality = settings().Rendering.QualityLevel end)
    pcall(function() saved.tech = Lighting.Technology end)
    pcall(function() saved.shadows = Lighting.GlobalShadows end)
    pcall(function() saved.fog = Lighting.FogEnd end)
    local terr = Workspace:FindFirstChildOfClass("Terrain")
    if terr then
        saved.terr = {}
        pcall(function()
            saved.terr.a = terr.WaterWaveSize
            saved.terr.b = terr.WaterWaveSpeed
            saved.terr.c = terr.WaterReflectance
            saved.terr.d = terr.WaterTransparency
            saved.terr.e = terr.Decoration
        end)
    end
end

local function stripOne(v)
    pcall(function()
        if v:IsA("BasePart") then
            v.Material = Enum.Material.Plastic
            v.Reflectance = 0
            v.CastShadow = false
            if v:IsA("MeshPart") then v.TextureID = "" end
        elseif v:IsA("Decal") or v:IsA("Texture") then
            v.Transparency = 1
        elseif v:IsA("SurfaceAppearance") then
            v:Destroy()
        elseif v:IsA("SpecialMesh") then
            v.TextureId = ""
        elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
            or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
            v.Enabled = false
        elseif v:IsA("PostEffect") then
            v.Enabled = false
        end
    end)
end

local function stripAll()
    snapGlobals()
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    pcall(function() Lighting.GlobalShadows = false end)
    pcall(function() Lighting.Technology = Enum.Technology.Compatibility end)
    pcall(function() Lighting.FogEnd = 9e9 end)
    for _, e in ipairs(Lighting:GetDescendants()) do
        if e:IsA("PostEffect") then pcall(function() e.Enabled = false end) end
    end
    local terr = Workspace:FindFirstChildOfClass("Terrain")
    if terr then
        pcall(function()
            terr.WaterWaveSize = 0
            terr.WaterWaveSpeed = 0
            terr.WaterReflectance = 0
            terr.WaterTransparency = 1
            terr.Decoration = false
        end)
    end
    local char = LP.Character
    local desc = Workspace:GetDescendants()
    for i = 1, #desc do
        local v = desc[i]
        if not (char and v:IsDescendantOf(char)) then stripOne(v) end
        if i % 800 == 0 then task.wait() end -- chunk biar ga freeze
    end
end

local function restoreGlobals()
    if not saved.done then return end
    pcall(function() if saved.quality then settings().Rendering.QualityLevel = saved.quality end end)
    pcall(function() if saved.tech then Lighting.Technology = saved.tech end end)
    pcall(function() if saved.shadows ~= nil then Lighting.GlobalShadows = saved.shadows end end)
    pcall(function() if saved.fog then Lighting.FogEnd = saved.fog end end)
    for _, e in ipairs(Lighting:GetDescendants()) do
        if e:IsA("PostEffect") then pcall(function() e.Enabled = true end) end
    end
    local terr = Workspace:FindFirstChildOfClass("Terrain")
    if terr and saved.terr then
        pcall(function()
            terr.WaterWaveSize = saved.terr.a
            terr.WaterWaveSpeed = saved.terr.b
            terr.WaterReflectance = saved.terr.c
            terr.WaterTransparency = saved.terr.d
            terr.Decoration = saved.terr.e
        end)
    end
end

local watchConn

task.spawn(function()
    stripAll()
    if type(setfpscap) == "function" then pcall(function() setfpscap(0) end) end
    watchConn = Workspace.DescendantAdded:Connect(function(v)
        if getgenv().__FPSBOOST_ACTIVE ~= MY_RUN then
            if watchConn then watchConn:Disconnect() end
            return
        end
        stripOne(v)
    end)
    print("[FPSBoost] aktif - beban render di-strip, watcher jalan.")
    print("[FPSBoost] stop: getgenv().__FPSBOOST_STOP = true")
end)

-- watcher stop
task.spawn(function()
    while getgenv().__FPSBOOST_ACTIVE == MY_RUN do
        if getgenv().__FPSBOOST_STOP then
            if watchConn then watchConn:Disconnect(); watchConn = nil end
            restoreGlobals()
            pcall(function() if type(setfpscap) == "function" then setfpscap(60) end end)
            getgenv().__FPSBOOST_ACTIVE = nil
            print("[FPSBoost] STOP - setting global di-restore")
            break
        end
        task.wait(1)
    end
end)
