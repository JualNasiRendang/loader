--[[
    ============================================================================
    PANEL POS — posisi keeper
    Naro SEMUA window panel (AutoHop, StealAnEgg, dll yang namanya *_Panel)
    ke pojok kanan bawah, dicek tiap 0.5 detik - jadi pas auto hop selesai
    dan panel muncul di tengah, langsung ke-geser ke pojok.

    Ga nyentuh script lain. Auto-execute via URL (github raw) - upload file
    ini ke URL di bawah, perubahan langsung ke-sync tiap hop.

    Jalanin file ini sekali aja (bisa barengan auto-execute file lain).
    ============================================================================
]]

-- version guard (bukan boolean): execute ulang = instance baru, instance
-- lama mati. Boolean guard bikin execute ulang di server yang sama ga jalan.
local MY_RUN = os.clock()
getgenv().__PANELPOS_ACTIVE = MY_RUN

local LOADER_URL = "https://raw.githubusercontent.com/JualNasiRendang/loader/refs/heads/main/panelpos.lua"

local function keepPos(win)
    pcall(function()
        win.AnchorPoint = Vector2.new(1, 1)
        win.Position = UDim2.new(1, -12, 1, -12) -- pojok kanan bawah
    end)
end

-- snap SEKALI per panel (waktu pertama kali keliatan) - abis itu bebas
-- di-drag ke mana aja, ga ditarik balik tiap 0.5 detik.
local snapped = {}
task.spawn(function()
    while getgenv().__PANELPOS_ACTIVE == MY_RUN do
        local roots = {
            game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui"),
            game:GetService("CoreGui"),
        }
        pcall(function()
            if gethui then
                local hui = gethui()
                if hui and hui ~= roots[2] then roots[#roots + 1] = hui end
            end
        end)
        local seen = {}
        for _, root in ipairs(roots) do
            if root and not seen[root] then
                seen[root] = true
                for _, g in ipairs(root:GetChildren()) do
                    if g:IsA("ScreenGui") and tostring(g.Name):find("_Panel") then
                        local win = g:FindFirstChild("Window")
                        if win and win:IsA("GuiObject") and not snapped[win] then
                            snapped[win] = true
                            keepPos(win)
                        end
                    end
                end
            end
        end
        task.wait(0.5)
    end
end)

-- ==================== CAMERA LOCK (kamera GAME, bukan UI) ====================
-- Pas di-run, POV kamera game saat itu di-capture dan dikunci: kamera
-- ngikutin karakter tapi sudut + jarak + zoom tetep. Toggle: RightControl.
local UIS        = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LP         = game:GetService("Players").LocalPlayer
local cam        = game.Workspace.CurrentCamera

local camOn = true
local camOffset, camLook, camFov

local function getHrp()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function captureCam()
    local r = getHrp()
    if not (r and cam) then return false end
    camOffset = cam.CFrame.Position - r.Position
    camLook   = cam.CFrame.LookVector
    camFov    = cam.FieldOfView
    return true
end
task.spawn(function()
    local r = LP.Character or LP.CharacterAdded:Wait()
    pcall(function() r:WaitForChild("HumanoidRootPart", 10) end)
    captureCam()
end)
UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.RightControl then
        camOn = not camOn
        if camOn then captureCam() end
        print("[PanelPos] camera lock " .. (camOn and "ON" or "OFF"))
    end
end)
RunService.RenderStepped:Connect(function()
    if not (camOn and cam) then return end
    local r = getHrp()
    if not r then return end
    cam.CameraType = Enum.CameraType.Custom
    cam.FieldOfView = camFov or 70
    if camOffset and camLook then
        cam.CFrame = CFrame.lookAt(r.Position + camOffset, (r.Position + camOffset) + camLook)
    end
end)

-- auto-execute: pas hop, download ulang dari URL terus loadstring
if type(queueonteleport) == "function" then
    pcall(queueonteleport, ([[
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
]]):format(LOADER_URL))
end

print("[PanelPos] keeper aktif - semua panel diparkir pojok kanan bawah")
