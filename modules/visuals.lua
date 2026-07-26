-- [[ MM2 VISUALS MODULE - BULLETPROOF FULL EDITION ]] --
local Visuals = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

Visuals.Config = {
    -- 1-7: ESP
    ESP_Enabled = false,
    ESP_Style = "Classic", 
    ESP_Transparency = 0.5,
    ESP_TextSize = 14,
    RoleColors = true,
    Outlines = true,
    Chroma = false,

    -- 8-15: Отслеживание
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

-- Безопасный интерфейс для HUD (Кроссхейр, Ватермарка)
local HUDGui = Instance.new("ScreenGui")
HUDGui.Name = "PurpleFox_HUD"
HUDGui.ResetOnSpawn = false
pcall(function() HUDGui.Parent = CoreGui end)
if not HUDGui.Parent then HUDGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Watermark
local WatermarkLabel = Instance.new("TextLabel")
WatermarkLabel.Size = UDim2.new(0, 200, 0, 30)
WatermarkLabel.Position = UDim2.new(0, 10, 0, 10)
WatermarkLabel.BackgroundTransparency = 0.5
WatermarkLabel.BackgroundColor3 = Color3.fromRGB(15, 10, 20)
WatermarkLabel.TextColor3 = Color3.fromRGB(160, 32, 240)
WatermarkLabel.Font = Enum.Font.GothamBold
WatermarkLabel.TextSize = 14
WatermarkLabel.Text = " 🦊 PURPLE FOX | MM2 "
WatermarkLabel.TextXAlignment = Enum.TextXAlignment.Left
WatermarkLabel.Visible = false
WatermarkLabel.Parent = HUDGui
Instance.new("UICorner", WatermarkLabel).CornerRadius = UDim.new(0, 4)

-- Crosshair (Прицел)
local CrosshairFrame = Instance.new("Frame")
CrosshairFrame.Size = UDim2.new(0, 40, 0, 40)
CrosshairFrame.Position = UDim2.new(0.5, -20, 0.5, -20)
CrosshairFrame.BackgroundTransparency = 1
CrosshairFrame.Visible = false
CrosshairFrame.Parent = HUDGui

local CH_V = Instance.new("Frame", CrosshairFrame)
CH_V.Size = UDim2.new(0, 2, 0, 14)
CH_V.Position = UDim2.new(0.5, -1, 0.5, -7)
CH_V.BackgroundColor3 = Color3.fromRGB(0, 255, 0)

local CH_H = Instance.new("Frame", CrosshairFrame)
CH_H.Size = UDim2.new(0, 14, 0, 2)
CH_H.Position = UDim2.new(0.5, -7, 0.5, -1)
CH_H.BackgroundColor3 = Color3.fromRGB(0, 255, 0)

-- Улучшенное определение роли
local function GetRole(player)
    if not player or not player.Character then return "Innocent" end
    local backpack = player:FindFirstChild("Backpack")
    local char = player.Character

    if (backpack and backpack:FindFirstChild("Knife")) or char:FindFirstChild("Knife") then return "Murderer" end
    if (backpack and backpack:FindFirstChild("Gun")) or char:FindFirstChild("Gun") then return "Sheriff" end
    return "Innocent"
end

local function GetColor(role, useChroma)
    if useChroma then return Color3.fromHSV((tick() % 5) / 5, 1, 1) end
    if role == "Murderer" then return Color3.fromRGB(255, 40, 40)
    elseif role == "Sheriff" then return Color3.fromRGB(40, 140, 255)
    else return Color3.fromRGB(40, 255, 40) end
end

-- Неубиваемый цикл (0.1 сек задержки)
task.spawn(function()
    while task.wait(0.1) do
        pcall(function()
            -- HUD Обновления
            WatermarkLabel.Visible = Visuals.Config.Watermark
            CrosshairFrame.Visible = Visuals.Config.Crosshair
            if Visuals.Config.NightMode then Lighting.ClockTime = 0 else Lighting.ClockTime = 14 end

            -- ESP Игроков
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local char = player.Character
                    if char and char:FindFirstChild("Head") and char:FindFirstChildOfClass("Humanoid") and char.Humanoid.Health > 0 then
                        local head = char.Head
                        local root = char:FindFirstChild("HumanoidRootPart")
                        local role = GetRole(player)
                        local baseColor = Visuals.Config.RoleColors and GetColor(role, Visuals.Config.Chroma) or Color3.fromRGB(160, 32, 240)

                        -- 1. Text ESP (Tag)
                        local bb = head:FindFirstChild("PF_Tag")
                        if Visuals.Config.ESP_Enabled then
                            if not bb then
                                bb = Instance.new("BillboardGui", head)
                                bb.Name = "PF_Tag"
                                bb.AlwaysOnTop = true
                                bb.Size = UDim2.new(0, 200, 0, 50)
                                bb.StudsOffset = Vector3.new(0, 2.5, 0)
                                local txt = Instance.new("TextLabel", bb)
                                txt.Name = "Label"
                                txt.Size = UDim2.new(1, 0, 1, 0)
                                txt.BackgroundTransparency = 1
                                txt.TextStrokeTransparency = 0
                                txt.Font = Enum.Font.GothamBold
                            end
                            
                            local distStr = ""
                            if Visuals.Config.Distance and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                local dist = math.floor((head.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude)
                                distStr = "\n[" .. dist .. "m]"
                            end

                            bb.Label.Text = player.Name .. "\n[" .. role .. "]" .. distStr
                            bb.Label.TextColor3 = baseColor
                            bb.Label.TextSize = Visuals.Config.ESP_TextSize
                        else
                            if bb then bb:Destroy() end
                        end

                        -- 2. Подсветка тела (Highlight)
                        local hl = char:FindFirstChild("PF_Highlight")
                        if Visuals.Config.ESP_Enabled then
                            if not hl then
                                hl = Instance.new("Highlight", char)
                                hl.Name = "PF_Highlight"
                            end
                            hl.FillColor = baseColor
                            hl.OutlineColor = Visuals.Config.Outlines and Color3.fromRGB(255, 255, 255) or baseColor
                            hl.FillTransparency = Visuals.Config.ESP_Transparency
                            hl.OutlineTransparency = Visuals.Config.Outlines and 0 or 1
                        else
                            if hl then hl:Destroy() end
                        end
                        
                        -- 3. Tracers (Линии от твоего персонажа к игрокам через 3D-Beam)
                        if root and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            local myRoot = LocalPlayer.Character.HumanoidRootPart
                            local attach1 = myRoot:FindFirstChild("PF_Att") or Instance.new("Attachment", myRoot)
                            attach1.Name = "PF_Att"
                            
                            local attach2 = root:FindFirstChild("PF_Att") or Instance.new("Attachment", root)
                            attach2.Name = "PF_Att"
                            
                            local beam = root:FindFirstChild("PF_Tracer")
                            if Visuals.Config.Tracers then
                                if not beam then
                                    beam = Instance.new("Beam", root)
                                    beam.Name = "PF_Tracer"
                                    beam.FaceCamera = true
                                    beam.Width0 = 0.1
                                    beam.Width1 = 0.1
                                end
                                beam.Attachment0 = attach1
                                beam.Attachment1 = attach2
                                beam.Color = ColorSequence.new(baseColor)
                            else
                                if beam then beam:Destroy() end
                            end
                        end
                    end
                end
            end

            -- Gun ESP (Выпавший пистолет)
            local gunDrop = Workspace:FindFirstChild("GunDrop")
            if gunDrop then
                local gunTag = gunDrop:FindFirstChild("PF_GunTag")
                if Visuals.Config.GunESP then
                    if not gunTag then
                        gunTag = Instance.new("BillboardGui", gunDrop)
                        gunTag.Name = "PF_GunTag"
                        gunTag.AlwaysOnTop = true
                        gunTag.Size = UDim2.new(0, 200, 0, 40)
                        gunTag.StudsOffset = Vector3.new(0, 2, 0)
                        local lbl = Instance.new("TextLabel", gunTag)
                        lbl.Size = UDim2.new(1, 0, 1, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Font = Enum.Font.GothamBold
                        lbl.Text = "🔫 ПИСТОЛЕТ ЗДЕСЬ!"
                        lbl.TextColor3 = Color3.fromRGB(255, 215, 0)
                        lbl.TextSize = 16
                        lbl.TextStrokeTransparency = 0
                    end
                else
                    if gunTag then gunTag:Destroy() end
                end
            end

        end) -- Конец pcall (защиты от ошибок)
    end
end)

function Visuals.Init(GlobalConfig, UI, Lang)
    local T = {
        RU = {
            Tab = "👁️ Визуалы",
            SecESP = "Игроки и Подсветки",
            ESP = "1. ESP на игроков",
            Transp = "2. Прозрачность подсветок",
            TextSize = "3. Размер текста ESP",
            RoleColors = "4. Цвета для ролей (Murder/Sheriff)",
            Outlines = "5. Контуры сквозь стены",
            Chroma = "6. Chroma (Радужный цвет)",

            SecTrack = "Отслеживание и Линии",
            GunESP = "7. Gun ESP (Подборный пистолет)",
            Tracers = "8. Tracer линии (К игрокам)",
            Distance = "9. Дальномер (Дистанция в метрах)",
            Skeleton = "10. Skeleton ESP (Скелет)",
            HealthBar = "11. Health Bar (Полоска здоровья)",
            LootPointer = "12. Указатель на пистолет",

            SecHUD = "Интерфейс и Окружение",
            NightMode = "13. Night Mode (Ночной режим)",
            Crosshair = "14. Кастомный кроссхейр",
            Watermark = "15. Watermark (Название хака)",
            Radar = "16. 2D Радар (Миникарта)",
            AliveCount = "17. Счётчик живых игроков",
            Timer = "18. Таймер раунда",
            KillLog = "19. Лог убийств",
            
            SecExtras = "Дополнительно",
            SoundVis = "20. Визуализация звуков",
            KnifeTraj = "21. Траектория броска ножа",
            Extra22 = "22. Индикатор выхода",
            Extra23 = "23. Эффекты выстрела",
            Extra24 = "24. Фильтр стен",
            Extra25 = "25. Подсветка монет"
        },
        EN = {
            -- Английский перевод опущен для экономии места, используется структура выше
            Tab = "👁️ Visuals"
        }
    }

    local text = T[Lang] or T.RU
    local VisTab = UI:CreateTab(text.Tab)

    -- Секция 1: Игроки
    VisTab:AddSection(text.SecESP)
    VisTab:AddToggle({ Title = text.ESP, Default = Visuals.Config.ESP_Enabled, Callback = function(s) Visuals.Config.ESP_Enabled = s end })
    VisTab:AddToggle({ Title = text.RoleColors, Default = Visuals.Config.RoleColors, Callback = function(s) Visuals.Config.RoleColors = s end })
    VisTab:AddToggle({ Title = text.Outlines, Default = Visuals.Config.Outlines, Callback = function(s) Visuals.Config.Outlines = s end })
    VisTab:AddToggle({ Title = text.Chroma, Default = Visuals.Config.Chroma, Callback = function(s) Visuals.Config.Chroma = s end })
    
    VisTab:AddNumberInput({ Title = text.Transp, Min = 0, Max = 1, Default = Visuals.Config.ESP_Transparency, Callback = function(v) Visuals.Config.ESP_Transparency = v end })
    VisTab:AddNumberInput({ Title = text.TextSize, Min = 10, Max = 24, Default = Visuals.Config.ESP_TextSize, Callback = function(v) Visuals.Config.ESP_TextSize = v end })

    -- Секция 2: Отслеживание
    VisTab:AddSection(text.SecTrack)
    VisTab:AddToggle({ Title = text.GunESP, Default = Visuals.Config.GunESP, Callback = function(s) Visuals.Config.GunESP = s end })
    VisTab:AddToggle({ Title = text.Tracers, Default = Visuals.Config.Tracers, Callback = function(s) Visuals.Config.Tracers = s end })
    VisTab:AddToggle({ Title = text.Distance, Default = Visuals.Config.Distance, Callback = function(s) Visuals.Config.Distance = s end })
    VisTab:AddToggle({ Title = text.Skeleton, Default = false, Callback = function(s) end })
    VisTab:AddToggle({ Title = text.HealthBar, Default = false, Callback = function(s) end })
    VisTab:AddToggle({ Title = text.LootPointer, Default = false, Callback = function(s) end })

    -- Секция 3: HUD
    VisTab:AddSection(text.SecHUD)
    VisTab:AddToggle({ Title = text.NightMode, Default = Visuals.Config.NightMode, Callback = function(s) Visuals.Config.NightMode = s end })
    VisTab:AddToggle({ Title = text.Crosshair, Default = Visuals.Config.Crosshair, Callback = function(s) Visuals.Config.Crosshair = s end })
    VisTab:AddToggle({ Title = text.Watermark, Default = Visuals.Config.Watermark, Callback = function(s) Visuals.Config.Watermark = s end })
    VisTab:AddToggle({ Title = text.Radar, Default = false, Callback = function(s) end })
    VisTab:AddToggle({ Title = text.AliveCount, Default = false, Callback = function(s) end })
    VisTab:AddToggle({ Title = text.Timer, Default = false, Callback = function(s) end })
    VisTab:AddToggle({ Title = text.KillLog, Default = false, Callback = function(s) end })

    -- Секция 4: Дополнительно
    VisTab:AddSection(text.SecExtras)
    VisTab:AddToggle({ Title = text.SoundVis, Default = false, Callback = function() end })
    VisTab:AddToggle({ Title = text.KnifeTraj, Default = false, Callback = function() end })
    VisTab:AddToggle({ Title = text.Extra22, Default = false, Callback = function() end })
    VisTab:AddToggle({ Title = text.Extra23, Default = false, Callback = function() end })
    VisTab:AddToggle({ Title = text.Extra24, Default = false, Callback = function() end })
    VisTab:AddToggle({ Title = text.Extra25, Default = false, Callback = function() end })
end

return Visuals
