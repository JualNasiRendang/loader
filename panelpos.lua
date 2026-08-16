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

if getgenv().__PANELPOS_RUN then return end
getgenv().__PANELPOS_RUN = true

local LOADER_URL = "https://raw.githubusercontent.com/JualNasiRendang/loader/refs/heads/main/panelpos.lua"

local function keepPos(win)
    pcall(function()
        win.AnchorPoint = Vector2.new(1, 1)
        win.Position = UDim2.new(1, -12, 1, -12) -- pojok kanan bawah
    end)
end

task.spawn(function()
    while true do
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
                        if win and win:IsA("GuiObject") then keepPos(win) end
                    end
                end
            end
        end
        task.wait(0.5)
    end
end)

-- auto-execute: pas hop, download ulang dari URL terus loadstring
if type(queueonteleport) == "function" then
    pcall(queueonteleport, ([[
if getgenv().__PANELPOS_RUN then return end
getgenv().__PANELPOS_RUN = true
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
