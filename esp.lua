local Module = {}

function Module:Init(Firola)
    local Services = Firola.Services
    local Players = Services.Players
    local Workspace = Services.Workspace
    local Lighting = Services.Lighting
    local CoreGui = Services.CoreGui
    local LocalPlayer = Firola.LocalPlayer
    local UI = Firola.UI
    local tabName = "ESP"

    local Config = {
        ESP = false,
        GunESP = false,
        NightMode = false,
        Fullbright = false,
    }

    -- ... (код ESP из старых visuals.lua, перенесённый сюда с созданием Highlight и BillboardGui)
end

return Module
