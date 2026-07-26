-- [[ MM2 VISUALS MODULE ]] --
local Visuals = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

Visuals.Config = {
    -- Основной ESP
    ESP_Enabled = false,
    ESP_Style = "Highlight", -- Highlight, Chams, Tag, Box
    ESP_Transparency = 0.5,
    ESP_TextSize = 14,
    RoleColors = true,
    Outlines = true,
    Chroma = false,

    -- Дополнительные ESP
    GunESP = false,
    SkeletonESP = false,
    Tracers = false,
    HealthBar = false,
    Distance = false,
    SoundVisuals = false,
    LootPointer = false,
    KnifeTrajectory = false,

    -- Окружение и Интерфейс
    NightMode = false,
    Radar2D = false,
    Crosshair = false,
    AliveCounter = false,
    RoundTimer = false,
    KillLog = false,
    Watermark = true
}

local Connections = {}

-- Основной цикл обновления визуалов
Connections.MainLoop = RunService.RenderStepped:Connect(function()
    -- Фильтр яркости (Night Mode)
    if Visuals.Config.NightMode then
        game:GetService("Lighting").ClockTime = 0
    end
end)

function Visuals.Init(GlobalConfig, UI, Lang)
    -- Словарь переводов
    local T = {
        RU = {
            Tab = "👁️ Визуалы",
            SecESP = "Игроки и Подсветки",
            ESP = "ESP на игроков",
            Style = "Стиль ESP (Highlight / Chams / Tag / Box)",
            Transp = "Прозрачность подсветок",
            TextSize = "Размер текста ESP",
            RoleColors = "Разные цвета для ролей (Chams)",
            Outlines = "Контуры сквозь стены",
            Chroma = "Chroma / Цветовой сдвиг",
            
            SecTrack = "Отслеживание и Линии",
            GunESP = "ESP на подборный пистолет",
            Skeleton = "Skeleton ESP (Скелет)",
            Tracers = "Tracer линии к игрокам",
            HealthBar = "Health Bar (Полоска HP)",
            Distance = "Дальномер (Дистанция)",
            SoundVis = "Визуализация звуков",
            LootPointer = "Указатель на пистолет/лут",
            KnifeTraj = "Траектория броска ножа",

            SecHUD = "Интерфейс и Эффекты",
            NightMode = "Night Mode (Ночной режим)",
            Radar = "2D Радар (Миникарта)",
            Crosshair = "Кастомный кроссхейр (Прицел)",
            AliveCount = "Счётчик живых игроков",
            Timer = "Таймер раунда",
            KillLog = "Лог убийств",
            Watermark = "Watermark (Название хака)"
        },
        EN = {
            Tab = "👁️ Visuals",
            SecESP = "Players & Highlights",
            ESP = "Player ESP",
            Style = "ESP Style (Highlight / Chams / Tag / Box)",
            Transp = "ESP Transparency",
            TextSize = "ESP Text Size",
            RoleColors = "Role Color Chams",
            Outlines = "Outlines through walls",
            Chroma = "Chroma / Color Shift",

            SecTrack = "Tracking & Lines",
            GunESP = "Dropped Gun ESP",
            Skeleton = "Skeleton ESP",
            Tracers = "Tracer Lines",
            HealthBar = "Health Bar",
            Distance = "Distance Tracker",
            SoundVis = "Sound Visualizer",
            LootPointer = "Loot / Gun Arrow Pointer",
            KnifeTraj = "Knife Throw Trajectory",

            SecHUD = "HUD & Environment",
            NightMode = "Night Mode",
            Radar = "2D Radar (Minimap)",
            Crosshair = "Custom Crosshair",
            AliveCount = "Alive Players Counter",
            Timer = "Round Timer",
            KillLog = "Kill Feed / Log",
            Watermark = "Watermark"
        }
    }

    local text = T[Lang] or T.RU
    local VisTab = UI:CreateTab(text.Tab)

    -- ----------------------------------------
    -- СЕКЦИЯ 1: ИГРОКИ И ПОДСВЕТКИ
    -- ----------------------------------------
    VisTab:AddSection(text.SecESP)

    VisTab:AddToggle({
        Title = text.ESP,
        Default = Visuals.Config.ESP_Enabled,
        Callback = function(state) Visuals.Config.ESP_Enabled = state end
    })

    VisTab:AddToggle({
        Title = text.RoleColors,
        Default = Visuals.Config.RoleColors,
        Callback = function(state) Visuals.Config.RoleColors = state end
    })

    VisTab:AddToggle({
        Title = text.Outlines,
        Default = Visuals.Config.Outlines,
        Callback = function(state) Visuals.Config.Outlines = state end
    })

    VisTab:AddToggle({
        Title = text.Chroma,
        Default = Visuals.Config.Chroma,
        Callback = function(state) Visuals.Config.Chroma = state end
    })

    VisTab:AddNumberInput({
        Title = text.TextSize,
        Min = 10,
        Max = 24,
        Default = Visuals.Config.ESP_TextSize,
        Callback = function(val) Visuals.Config.ESP_TextSize = val end
    })

    -- ----------------------------------------
    -- СЕКЦИЯ 2: ОТСЛЕЖИВАНИЕ И ЛИНИИ
    -- ----------------------------------------
    VisTab:AddSection(text.SecTrack)

    VisTab:AddToggle({
        Title = text.GunESP,
        Default = Visuals.Config.GunESP,
        Callback = function(state) Visuals.Config.GunESP = state end
    })

    VisTab:AddToggle({
        Title = text.Skeleton,
        Default = Visuals.Config.SkeletonESP,
        Callback = function(state) Visuals.Config.SkeletonESP = state end
    })

    VisTab:AddToggle({
        Title = text.Tracers,
        Default = Visuals.Config.Tracers,
        Callback = function(state) Visuals.Config.Tracers = state end
    })

    VisTab:AddToggle({
        Title = text.HealthBar,
        Default = Visuals.Config.HealthBar,
        Callback = function(state) Visuals.Config.HealthBar = state end
    })

    VisTab:AddToggle({
        Title = text.Distance,
        Default = Visuals.Config.Distance,
        Callback = function(state) Visuals.Config.Distance = state end
    })

    VisTab:AddToggle({
        Title = text.SoundVis,
        Default = Visuals.Config.SoundVisuals,
        Callback = function(state) Visuals.Config.SoundVisuals = state end
    })

    VisTab:AddToggle({
        Title = text.LootPointer,
        Default = Visuals.Config.LootPointer,
        Callback = function(state) Visuals.Config.LootPointer = state end
    })

    VisTab:AddToggle({
        Title = text.KnifeTraj,
        Default = Visuals.Config.KnifeTrajectory,
        Callback = function(state) Visuals.Config.KnifeTrajectory = state end
    })

    -- ----------------------------------------
    -- СЕКЦИЯ 3: ИНТЕРФЕЙС И ЭФФЕКТЫ
    -- ----------------------------------------
    VisTab:AddSection(text.SecHUD)

    VisTab:AddToggle({
        Title = text.NightMode,
        Default = Visuals.Config.NightMode,
        Callback = function(state) Visuals.Config.NightMode = state end
    })

    VisTab:AddToggle({
        Title = text.Radar,
        Default = Visuals.Config.Radar2D,
        Callback = function(state) Visuals.Config.Radar2D = state end
    })

    VisTab:AddToggle({
        Title = text.Crosshair,
        Default = Visuals.Config.Crosshair,
        Callback = function(state) Visuals.Config.Crosshair = state end
    })

    VisTab:AddToggle({
        Title = text.AliveCount,
        Default = Visuals.Config.AliveCounter,
        Callback = function(state) Visuals.Config.AliveCounter = state end
    })

    VisTab:AddToggle({
        Title = text.Timer,
        Default = Visuals.Config.RoundTimer,
        Callback = function(state) Visuals.Config.RoundTimer = state end
    })

    VisTab:AddToggle({
        Title = text.KillLog,
        Default = Visuals.Config.KillLog,
        Callback = function(state) Visuals.Config.KillLog = state end
    })

    VisTab:AddToggle({
        Title = text.Watermark,
        Default = Visuals.Config.Watermark,
        Callback = function(state) Visuals.Config.Watermark = state end
    })
end

return Visuals
