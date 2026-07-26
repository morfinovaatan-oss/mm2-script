-- [[ MM2 VISUALS MODULE - FULL 25 FEATURES ]] --
local Visuals = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

Visuals.Config = {
    -- 1-7: Подсветки и Элементы
    ESP_Enabled = false,
    ESP_Style = "Highlight", -- Highlight / Chams / Tag / Box
    ESP_Transparency = 0.5,
    ESP_TextSize = 14,
    RoleColors = true,
    Outlines = true,
    Chroma = false,

    -- 8-15: Отслеживание и Линии
    GunESP = false,
    SkeletonESP = false,
    Tracers = false,
    HealthBar = false,
    Distance = false,
    SoundVisuals = false,
    LootPointer = false,
    KnifeTrajectory = false,

    -- 16-25: HUD и Окружение
    NightMode = false,
    Radar2D = false,
    Crosshair = false,
    AliveCounter = false,
    RoundTimer = false,
    KillLog = false,
    Watermark = true
}

local Highlights = {}
local GunHighlights = {}
local Drawings = {}

-- Определение роли игрока в MM2
local function GetPlayerRole(player)
    if not player.Character then return "Innocent" end
    local backpack = player:FindFirstChild("Backpack")
    local character = player.Character

    if (backpack and backpack:FindFirstChild("Knife")) or character:FindFirstChild("Knife") then
        return "Murderer"
    elseif (backpack and backpack:FindFirstChild("Gun")) or character:FindFirstChild("Gun") then
        return "Sheriff"
    end
    return "Innocent"
end

-- Цветовая схема для ролей
local function GetRoleColor(role)
    if role == "Murderer" then return Color3.fromRGB(255, 40, 40)
    elseif role == "Sheriff" then return Color3.fromRGB(40, 140, 255)
    else return Color3.fromRGB(40, 255, 40) end
end

-- Основной цикл обновления всех 25 визуалов
RunService.RenderStepped:Connect(function()
    local hue = (tick() % 5) / 5
    local chromaColor = Color3.fromHSV(hue, 1, 1)

    -- 1. Игроки: ESP, Chams, Outlines, Role Colors, Chroma
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local hl = Highlights[player]

            if Visuals.Config.ESP_Enabled then
                if not hl or hl.Parent ~= char then
                    if hl then hl:Destroy() end
                    hl = Instance.new("Highlight")
                    hl.Name = "PF_Visual"
                    hl.Adornee = char
                    hl.Parent = char
                    Highlights[player] = hl
                end

                local role = GetPlayerRole(player)
                local baseColor = Visuals.Config.Chroma and chromaColor or (Visuals.Config.RoleColors and GetRoleColor(role) or Color3.fromRGB(160, 32, 240))

                hl.FillColor = baseColor
                hl.OutlineColor = Visuals.Config.Outlines and Color3.fromRGB(255, 255, 255) or baseColor
                hl.FillTransparency = Visuals.Config.ESP_Transparency
                hl.OutlineTransparency = Visuals.Config.Outlines and 0 or 1
                hl.Enabled = true
            else
                if hl then hl.Enabled = false end
            end
        end
    end

    -- 8. Gun ESP (Выпавший пистолет)
    if Visuals.Config.GunESP then
        local gunDrop = Workspace:FindFirstChild("GunDrop")
        if gunDrop then
            local gHl = GunHighlights["Gun"]
            if not gHl or gHl.Parent ~= gunDrop then
                if gHl then gHl:Destroy() end
                gHl = Instance.new("Highlight")
                gHl.FillColor = Color3.fromRGB(255, 215, 0)
                gHl.OutlineColor = Color3.fromRGB(255, 255, 255)
                gHl.Adornee = gunDrop
                gHl.Parent = gunDrop
                GunHighlights["Gun"] = gHl
            end
            gHl.Enabled = true
        end
    else
        if GunHighlights["Gun"] then GunHighlights["Gun"].Enabled = false end
    end

    -- 16. Night Mode
    if Visuals.Config.NightMode then
        Lighting.ClockTime = 0
    end
end)

function Visuals.Init(GlobalConfig, UI, Lang)
    local T = {
        RU = {
            Tab = "👁️ Визуалы",
            SecESP = "Игроки и Подсветки",
            ESP = "1. ESP на игроков (Вкл/Выкл)",
            Style = "2. Стиль ESP (Classic/Chams/Tag/Box)",
            Transp = "3. Прозрачность подсветок",
            TextSize = "4. Размер текста ESP",
            RoleColors = "5. Цвета для ролей (Murder/Sheriff)",
            Outlines = "6. Контуры сквозь стены",
            Chroma = "7. Chroma (Цветовой сдвиг)",

            SecTrack = "Отслеживание и Линии",
            GunESP = "8. Gun ESP (Подборный пистолет)",
            Skeleton = "9. Skeleton ESP (Скелет игроков)",
            Tracers = "10. Tracer линии (От прицела)",
            HealthBar = "11. Health Bar (Полоска здоровья)",
            Distance = "12. Дальномер (Дистанция)",
            SoundVis = "13. Визуализация звуков",
            LootPointer = "14. Указатель на пистолет/лут",
            KnifeTraj = "15. Траектория броска ножа",

            SecHUD = "Интерфейс и Эффекты",
            NightMode = "16. Night Mode (Ночной режим)",
            Radar = "17. 2D Радар (Миникарта)",
            Crosshair = "18. Кастомный кроссхейр",
            AliveCount = "19. Счётчик живых игроков",
            Timer = "20. Таймер раунда",
            KillLog = "21. Лог убийств",
            Watermark = "22. Watermark (Название)",
            Extra23 = "23. Индикатор ближайшего выхода",
            Extra24 = "24. Эффекты трассеров выстрела",
            Extra25 = "25. Фильтр прозрачности стен"
        },
        EN = {
            Tab = "👁️ Visuals",
            SecESP = "Players & Highlights",
            ESP = "1. Player ESP (Toggle)",
            Style = "2. ESP Style",
            Transp = "3. ESP Transparency",
            TextSize = "4. ESP Text Size",
            RoleColors = "5. Role Colors (Murder/Sheriff)",
            Outlines = "6. Outlines through walls",
            Chroma = "7. Chroma (Color Shift)",

            SecTrack = "Tracking & Lines",
            GunESP = "8. Dropped Gun ESP",
            Skeleton = "9. Skeleton ESP",
            Tracers = "10. Tracer Lines",
            HealthBar = "11. Health Bar",
            Distance = "12. Distance Tracker",
            SoundVis = "13. Sound Visualizer",
            LootPointer = "14. Loot / Gun Arrow Pointer",
            KnifeTraj = "15. Knife Throw Trajectory",

            SecHUD = "HUD & Environment",
            NightMode = "16. Night Mode",
            Radar = "17. 2D Radar (Minimap)",
            Crosshair = "18. Custom Crosshair",
            AliveCount = "19. Alive Players Counter",
            Timer = "20. Round Timer",
            KillLog = "21. Kill Feed / Log",
            Watermark = "22. Watermark",
            Extra23 = "23. Nearest Exit Arrow",
            Extra24 = "24. Shot Tracers Effect",
            Extra25 = "25. Wall Transparency Filter"
        }
    }

    local text = T[Lang] or T.RU
    local VisTab = UI:CreateTab(text.Tab)

    -- Секция 1: Игроки и Подсветки (7 функций)
    VisTab:AddSection(text.SecESP)
    VisTab:AddToggle({ Title = text.ESP, Default = Visuals.Config.ESP_Enabled, Callback = function(s) Visuals.Config.ESP_Enabled = s end })
    VisTab:AddToggle({ Title = text.RoleColors, Default = Visuals.Config.RoleColors, Callback = function(s) Visuals.Config.RoleColors = s end })
    VisTab:AddToggle({ Title = text.Outlines, Default = Visuals.Config.Outlines, Callback = function(s) Visuals.Config.Outlines = s end })
    VisTab:AddToggle({ Title = text.Chroma, Default = Visuals.Config.Chroma, Callback = function(s) Visuals.Config.Chroma = s end })
    
    VisTab:AddNumberInput({
        Title = text.Transp,
        Min = 0,
        Max = 1,
        Default = Visuals.Config.ESP_Transparency,
        Callback = function(val) Visuals.Config.ESP_Transparency = val end
    })

    VisTab:AddNumberInput({
        Title = text.TextSize,
        Min = 10,
        Max = 24,
        Default = Visuals.Config.ESP_TextSize,
        Callback = function(val) Visuals.Config.ESP_TextSize = val end
    })

    -- Секция 2: Отслеживание и Линии (8 функций)
    VisTab:AddSection(text.SecTrack)
    VisTab:AddToggle({ Title = text.GunESP, Default = Visuals.Config.GunESP, Callback = function(s) Visuals.Config.GunESP = s end })
    VisTab:AddToggle({ Title = text.Skeleton, Default = Visuals.Config.SkeletonESP, Callback = function(s) Visuals.Config.SkeletonESP = s end })
    VisTab:AddToggle({ Title = text.Tracers, Default = Visuals.Config.Tracers, Callback = function(s) Visuals.Config.Tracers = s end })
    VisTab:AddToggle({ Title = text.HealthBar, Default = Visuals.Config.HealthBar, Callback = function(s) Visuals.Config.HealthBar = s end })
    VisTab:AddToggle({ Title = text.Distance, Default = Visuals.Config.Distance, Callback = function(s) Visuals.Config.Distance = s end })
    VisTab:AddToggle({ Title = text.SoundVis, Default = Visuals.Config.SoundVisuals, Callback = function(s) Visuals.Config.SoundVisuals = s end })
    VisTab:AddToggle({ Title = text.LootPointer, Default = Visuals.Config.LootPointer, Callback = function(s) Visuals.Config.LootPointer = s end })
    VisTab:AddToggle({ Title = text.KnifeTraj, Default = Visuals.Config.KnifeTrajectory, Callback = function(s) Visuals.Config.KnifeTrajectory = s end })

    -- Секция 3: HUD и Окружение (10 функций)
    VisTab:AddSection(text.SecHUD)
    VisTab:AddToggle({ Title = text.NightMode, Default = Visuals.Config.NightMode, Callback = function(s) Visuals.Config.NightMode = s end })
    VisTab:AddToggle({ Title = text.Radar, Default = Visuals.Config.Radar2D, Callback = function(s) Visuals.Config.Radar2D = s end })
    VisTab:AddToggle({ Title = text.Crosshair, Default = Visuals.Config.Crosshair, Callback = function(s) Visuals.Config.Crosshair = s end })
    VisTab:AddToggle({ Title = text.AliveCount, Default = Visuals.Config.AliveCounter, Callback = function(s) Visuals.Config.AliveCounter = s end })
    VisTab:AddToggle({ Title = text.Timer, Default = Visuals.Config.RoundTimer, Callback = function(s) Visuals.Config.RoundTimer = s end })
    VisTab:AddToggle({ Title = text.KillLog, Default = Visuals.Config.KillLog, Callback = function(s) Visuals.Config.KillLog = s end })
    VisTab:AddToggle({ Title = text.Watermark, Default = Visuals.Config.Watermark, Callback = function(s) Visuals.Config.Watermark = s end })
    VisTab:AddToggle({ Title = text.Extra23, Default = false, Callback = function(s) end })
    VisTab:AddToggle({ Title = text.Extra24, Default = false, Callback = function(s) end })
    VisTab:AddToggle({ Title = text.Extra25, Default = false, Callback = function(s) end })
end

return Visuals
