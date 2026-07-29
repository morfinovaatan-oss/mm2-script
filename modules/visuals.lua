-- [[ MM2 VISUALS MODULE – адаптированный под UILibrary ]] --
local Visuals = {}

-- ... весь предыдущий код до функции Init остаётся без изменений ...
-- (т.е. все строки от "local Players = ..." до "end" перед "function Visuals.Init")

-- ====================== Инициализация UI ======================
function Visuals.Init(GlobalConfig, parentTab, Lang)
    local T = {
        RU = {
            SubMain = "Визуалы",
            SecESP = "Игроки и ESP",
            ESP = "Включить ESP",
            RoleColors = "Цвета ролей (Murder/Sheriff)",
            Chroma = "Радужный ESP (Chroma)",
            Outlines = "Контуры (Outlines)",
            Health = "Полоска здоровья (Health Bar)",
            Distance = "Дистанция (Метры)",
            Tracers = "Линии к игрокам (Tracers)",
            Transp = "Прозрачность заливки",
            TextSize = "Размер текста",

            SecTrack = "Лут и Предметы",
            GunESP = "ESP на пистолет (GunDrop)",
            CoinESP = "Подсветка монет (В разработке)",

            SecHUD = "Интерфейс (HUD)",
            NightMode = "Ночной режим",
            Fullbright = "Максимальная яркость",
            Crosshair = "Прицел в центре экрана",
            AliveCount = "Счетчик живых игроков"
        },
        EN = {
            SubMain = "Visuals",
            SecESP = "Players & ESP",
            ESP = "Enable ESP",
            RoleColors = "Role Colors",
            Chroma = "Rainbow ESP (Chroma)",
            Outlines = "Outlines",
            Health = "Health Bar",
            Distance = "Distance",
            Tracers = "Tracers",
            Transp = "Fill Transparency",
            TextSize = "Text Size",

            SecTrack = "Items",
            GunESP = "Gun Drop ESP",
            CoinESP = "Coin ESP (WIP)",

            SecHUD = "HUD",
            NightMode = "Night Mode",
            Fullbright = "Fullbright",
            Crosshair = "Crosshair",
            AliveCount = "Alive Counter"
        }
    }
    local text = T[Lang] or T.RU
    local SubTab = parentTab:AddSubTab(text.SubMain)

    -- ESP Players Group
    local ESPGroup = SubTab:AddGroupbox(text.SecESP)
    ESPGroup:AddToggle({
        Text = text.ESP,
        Default = false,
        Callback = function(s) Visuals.Config.ESP_Enabled = s end
    })
    ESPGroup:AddToggle({
        Text = text.RoleColors,
        Default = true,
        Callback = function(s) Visuals.Config.RoleColors = s end
    })
    ESPGroup:AddToggle({
        Text = text.Chroma,
        Default = false,
        Callback = function(s) Visuals.Config.Chroma = s end
    })
    ESPGroup:AddToggle({
        Text = text.Outlines,
        Default = true,
        Callback = function(s) Visuals.Config.Outlines = s end
    })
    ESPGroup:AddToggle({
        Text = text.Health,
        Default = false,
        Callback = function(s) Visuals.Config.HealthBar = s end
    })
    ESPGroup:AddToggle({
        Text = text.Distance,
        Default = false,
        Callback = function(s) Visuals.Config.Distance = s end
    })
    ESPGroup:AddToggle({
        Text = text.Tracers,
        Default = false,
        Callback = function(s) Visuals.Config.Tracers = s end
    })
    ESPGroup:AddSlider({
        Text = text.Transp,
        Min = 0, Max = 1, Default = Visuals.Config.ESP_Transparency,
        Decimals = 2,
        Callback = function(v) Visuals.Config.ESP_Transparency = v end
    })
    ESPGroup:AddSlider({
        Text = text.TextSize,
        Min = 10, Max = 24, Default = Visuals.Config.ESP_TextSize,
        Suffix = " px",
        Callback = function(v) Visuals.Config.ESP_TextSize = v end
    })

    -- Items Group
    local ItemsGroup = SubTab:AddGroupbox(text.SecTrack)
    ItemsGroup:AddToggle({
        Text = text.GunESP,
        Default = false,
        Callback = function(s)
            Visuals.Config.GunESP = s
            if not s then removeGunESP() end
        end
    })
    ItemsGroup:AddToggle({
        Text = text.CoinESP,
        Default = false,
        Callback = function(s) end
    })

    -- HUD Group
    local HUDGroup = SubTab:AddGroupbox(text.SecHUD)
    HUDGroup:AddToggle({
        Text = text.NightMode,
        Default = false,
        Callback = function(s) Visuals.Config.NightMode = s end
    })
    HUDGroup:AddToggle({
        Text = text.Fullbright,
        Default = false,
        Callback = function(s) Visuals.Config.Fullbright = s end
    })
    HUDGroup:AddToggle({
        Text = text.Crosshair,
        Default = false,
        Callback = function(s) Visuals.Config.Crosshair = s end
    })
    HUDGroup:AddToggle({
        Text = text.AliveCount,
        Default = false,
        Callback = function(s) Visuals.Config.AliveCounter = s end
    })
end

return Visuals
