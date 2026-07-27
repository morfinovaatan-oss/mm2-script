-- [[ MM2 VISUALS MODULE - ULTIMATE BULLETPROOF EDITION V2 ]] --
local Visuals = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

Visuals.Config = {
    -- ESP & Игроки
    ESP_Enabled = false,
    RoleColors = true,
    Chroma = false,
    Outlines = true,
    Distance = false,
    HealthBar = false,
    Tracers = false,
    ESP_Transparency = 0.5,
    ESP_TextSize = 14,
    
    -- Предметы
    GunESP = false,
    CoinESP = false,
    
    -- HUD и Окружение
    NightMode = false,
    Fullbright = false,
    Crosshair = false,
    Watermark = true,
    AliveCounter = false,
    Radar = false
}

-- Создаем интерфейс для HUD
local HUDGui = Instance.new("ScreenGui")
HUDGui.Name = "PurpleFox_HUD"
HUDGui.ResetOnSpawn = false
pcall(function() HUDGui.Parent = CoreGui end)
if not HUDGui.Parent then HUDGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- 1. Watermark
local Watermark = Instance.new("TextLabel", HUDGui)
Watermark.Size = UDim2.new(0, 180, 0, 28)
Watermark.Position = UDim2.new(0, 10, 0, 10)
Watermark.BackgroundColor3 = Color3.fromRGB(15, 10, 20)
Watermark.BackgroundTransparency = 0.4
Watermark.TextColor3 = Color3.fromRGB(160, 32, 240)
Watermark.Font = Enum.Font.GothamBold
Watermark.TextSize = 13
Watermark.Text = " 🦊 PURPLE FOX | MM2 "
Watermark.Visible = false
Instance.new("UICorner", Watermark).CornerRadius = UDim.new(0, 4)

-- 2. Crosshair (Прицел)
local Crosshair = Instance.new("Frame", HUDGui)
Crosshair.Size = UDim2.new(0, 30, 0, 30)
Crosshair.Position = UDim2.new(0.5, -15, 0.5, -15)
Crosshair.BackgroundTransparency = 1
Crosshair.Visible = false

local CH_V = Instance.new("Frame", Crosshair)
CH_V.Size = UDim2.new(0, 2, 0, 12)
CH_V.Position = UDim2.new(0.5, -1, 0.5, -6)
CH_V.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
CH_V.BorderSizePixel = 0

local CH_H = Instance.new("Frame", Crosshair)
CH_H.Size = UDim2.new(0, 12, 0, 2)
CH_H.Position = UDim2.new(0.5, -6, 0.5, -1)
CH_H.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
CH_H.BorderSizePixel = 0

-- 3. Alive Counter (Счетчик живых)
local AliveFrame = Instance.new("TextLabel", HUDGui)
AliveFrame.Size = UDim2.new(0, 150, 0, 28)
AliveFrame.Position = UDim2.new(0.5, -75, 0, 10)
AliveFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
AliveFrame.BackgroundTransparency = 0.5
AliveFrame.TextColor3 = Color3.fromRGB(255, 255, 255)
AliveFrame.Font = Enum.Font.GothamBold
AliveFrame.TextSize = 14
AliveFrame.Visible = false
Instance.new("UICorner", AliveFrame).CornerRadius = UDim.new(0, 4)

-- Определение роли
local function GetRole(player)
    if not player or not player.Character then return "Innocent" end
    local backpack = player:FindFirstChild("Backpack")
    local char = player.Character

    if (backpack and backpack:FindFirstChild("Knife")) or char:FindFirstChild("Knife") then return "Murderer" end
    if (backpack and backpack:FindFirstChild("Gun")) or char:FindFirstChild("Gun") then return "Sheriff" end
    return "Innocent"
end

local function GetColor(role)
    if Visuals.Config.Chroma then return Color3.fromHSV((tick() % 5) / 5, 1, 1) end
    if role == "Murderer" then return Color3.fromRGB(255, 30, 30)
    elseif role == "Sheriff" then return Color3.fromRGB(30, 140, 255)
    else return Color3.fromRGB(30, 255, 30) end
end

-- Функция поиска выпавшего пистолета во всем Workspace
-- Функция поиска ВЫПАВШЕГО пистолета (только на земле, не в руках)
local function FindGunDrop()
    -- Стандартный способ: модель GunDrop в Workspace
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj.Name == "GunDrop" then
            -- Дополнительно убедимся, что это не оружие в руках (нет Humanoid у родителя)
            local parent = obj.Parent
            if parent and parent:FindFirstChildOfClass("Humanoid") then
                continue -- это персонаж, пропускаем
            end
            return obj
        end
    end

    -- Запасной вариант: Tool с именем "Gun", лежащий прямо в Workspace (не в Character)
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Tool") and (obj.Name == "Gun" or obj.Name:lower():find("gun")) then
            -- Проверяем, что у него нет родителя с Humanoid
            local parent = obj.Parent
            if parent and parent:FindFirstChildOfClass("Humanoid") then
                continue
            end
            return obj
        end
    end

    -- Если не нашли, поищем глубже (на случай, если дроп лежит в папке)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name == "GunDrop" then
            local parent = obj.Parent
            if parent and parent:FindFirstChildOfClass("Humanoid") then
                continue
            end
            return obj
        elseif obj:IsA("Tool") and (obj.Name == "Gun" or obj.Name:lower():find("gun")) then
            local parent = obj.Parent
            if parent and parent:FindFirstChildOfClass("Humanoid") then
                continue
            end
            return obj
        end
    end

    return nil
end

-- Главный защищенный цикл
task.spawn(function()
    while task.wait(0.1) do
        pcall(function()
            -- Обновление HUD
            Watermark.Visible = Visuals.Config.Watermark
            Crosshair.Visible = Visuals.Config.Crosshair
            AliveFrame.Visible = Visuals.Config.AliveCounter
            
            if Visuals.Config.NightMode then Lighting.ClockTime = 0
            elseif Visuals.Config.Fullbright then Lighting.ClockTime = 12; Lighting.Ambient = Color3.new(1, 1, 1) end

            local aliveCount = 0

            -- Цикл игроков
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local char = player.Character
                    if char and char:FindFirstChild("Head") and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChildOfClass("Humanoid") and char.Humanoid.Health > 0 then
                        aliveCount = aliveCount + 1
                        local head = char.Head
                        local root = char.HumanoidRootPart
                        local hum = char.Humanoid
                        local role = GetRole(player)
                        local color = Visuals.Config.RoleColors and GetColor(role) or Color3.fromRGB(160, 32, 240)

                        -- 1. ESP TAG & Health Bar
                        local bb = head:FindFirstChild("PF_Tag")
                        if Visuals.Config.ESP_Enabled then
                            if not bb then
                                bb = Instance.new("BillboardGui", head)
                                bb.Name = "PF_Tag"
                                bb.AlwaysOnTop = true
                                bb.Size = UDim2.new(0, 200, 0, 60)
                                bb.StudsOffset = Vector3.new(0, 2.5, 0)
                                
                                local txt = Instance.new("TextLabel", bb)
                                txt.Name = "Label"
                                txt.Size = UDim2.new(1, 0, 0.6, 0)
                                txt.BackgroundTransparency = 1
                                txt.TextStrokeTransparency = 0
                                txt.Font = Enum.Font.GothamBold
                                
                                local hpBG = Instance.new("Frame", bb)
                                hpBG.Name = "HP_BG"
                                hpBG.Size = UDim2.new(0.5, 0, 0.15, 0)
                                hpBG.Position = UDim2.new(0.25, 0, 0.7, 0)
                                hpBG.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                                hpBG.BorderSizePixel = 0
                                
                                local hpBar = Instance.new("Frame", hpBG)
                                hpBar.Name = "HP_Bar"
                                hpBar.Size = UDim2.new(1, 0, 1, 0)
                                hpBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
                                hpBar.BorderSizePixel = 0
                            end
                            
                            local distStr = ""
                            if Visuals.Config.Distance and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                local dist = math.floor((head.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude)
                                distStr = "\n[" .. dist .. "m]"
                            end

                            bb.Label.Text = player.Name .. "\n[" .. role .. "]" .. distStr
                            bb.Label.TextColor3 = color
                            bb.Label.TextSize = Visuals.Config.ESP_TextSize
                            
                            bb.HP_BG.Visible = Visuals.Config.HealthBar
                            if Visuals.Config.HealthBar then
                                local hpPercent = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                                bb.HP_BG.HP_Bar.Size = UDim2.new(hpPercent, 0, 1, 0)
                                bb.HP_BG.HP_Bar.BackgroundColor3 = Color3.fromRGB(255 - (hpPercent * 255), hpPercent * 255, 0)
                            end
                        else
                            if bb then bb:Destroy() end
                        end

                        -- 2. Highlight (Подсветка)
                        local hl = char:FindFirstChild("PF_Highlight")
                        if Visuals.Config.ESP_Enabled then
                            if not hl then
                                hl = Instance.new("Highlight", char)
                                hl.Name = "PF_Highlight"
                            end
                            hl.FillColor = color
                            hl.OutlineColor = Visuals.Config.Outlines and Color3.fromRGB(255, 255, 255) or color
                            hl.FillTransparency = Visuals.Config.ESP_Transparency
                            hl.OutlineTransparency = Visuals.Config.Outlines and 0 or 1
                        else
                            if hl then hl:Destroy() end
                        end

                        -- 3. Tracers (Линии от игрока)
                        local myChar = LocalPlayer.Character
                        if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                            local myRoot = myChar.HumanoidRootPart
                            local att1 = myRoot:FindFirstChild("PF_Att") or Instance.new("Attachment", myRoot)
                            att1.Name = "PF_Att"
                            local att2 = root:FindFirstChild("PF_Att") or Instance.new("Attachment", root)
                            att2.Name = "PF_Att"

                            local beam = root:FindFirstChild("PF_Tracer")
                            if Visuals.Config.Tracers then
                                if not beam then
                                    beam = Instance.new("Beam", root)
                                    beam.Name = "PF_Tracer"
                                    beam.FaceCamera = true
                                    beam.Width0 = 0.05
                                    beam.Width1 = 0.05
                                end
                                beam.Attachment0 = att1
                                beam.Attachment1 = att2
                                beam.Color = ColorSequence.new(color)
                            else
                                if beam then beam:Destroy() end
                            end
                        end
                    end
                end
            end
            
            if Visuals.Config.AliveCounter then AliveFrame.Text = "🔪 Живых игроков: " .. aliveCount end

            -- Gun ESP (Улучшенный поиск)
           -- Функция поиска ВЫПАВШЕГО пистолета (игнорирует оружие в руках игроков)
          local function FindGunDrop()
    -- 1. Быстрый поиск по прямым детям Workspace (стандартный случай)
          for _, child in ipairs(Workspace:GetChildren()) do
          if child:IsA("Model") and child.Name == "GunDrop" then
            -- Убедимся, что объект не принадлежит какому-либо игроку
          if not child:IsDescendantOf(Players) then
                return child
            end
          elseif child:IsA("Tool") and (child.Name == "Gun" or child.Name:lower():find("gun")) then
            if not child:IsDescendantOf(Players) then
                return child
            end
        end
    end

    -- 2. Если не нашли, ищем глубже во всех потомках Workspace (исключая Players)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name == "GunDrop" then
            if not obj:IsDescendantOf(Players) then
                return obj
            end
        elseif obj:IsA("Tool") and (obj.Name == "Gun" or obj.Name:lower():find("gun")) then
            if not obj:IsDescendantOf(Players) then
                return obj
            end
        end
    end

    return nil
end

function Visuals.Init(GlobalConfig, UI, Lang)
    local T = {
        RU = {
            Tab = "👁️ Визуалы",
            SecESP = "Игроки и ESP",
            ESP = "1. Включить ESP",
            RoleColors = "2. Цвета ролей (Murder/Sheriff)",
            Chroma = "3. Радужный ESP (Chroma)",
            Outlines = "4. Контуры (Outlines)",
            Health = "5. Полоска здоровья (Health Bar)",
            Distance = "6. Дистанция (Метры)",
            Tracers = "7. Линии к игрокам (Tracers)",
            Transp = "8. Прозрачность заливки",
            TextSize = "9. Размер текста",

            SecTrack = "Лут и Предметы",
            GunESP = "10. ESP на пистолет (GunDrop)",
            CoinESP = "11. Подсветка монет (В разработке)",

            SecHUD = "Интерфейс (HUD)",
            NightMode = "12. Ночной режим",
            Fullbright = "13. Максимальная яркость",
            Crosshair = "14. Прицел в центре экрана",
            Watermark = "15. Водяной знак хака",
            AliveCount = "16. Счетчик живых игроков"
        },
        EN = {
            Tab = "👁️ Visuals",
            SecESP = "Players & ESP",
            ESP = "1. Enable ESP",
            RoleColors = "2. Role Colors",
            Chroma = "3. Rainbow ESP (Chroma)",
            Outlines = "4. Outlines",
            Health = "5. Health Bar",
            Distance = "6. Distance",
            Tracers = "7. Tracers",
            Transp = "8. Fill Transparency",
            TextSize = "9. Text Size",

            SecTrack = "Items",
            GunESP = "10. Gun Drop ESP",
            CoinESP = "11. Coin ESP (WIP)",

            SecHUD = "HUD",
            NightMode = "12. Night Mode",
            Fullbright = "13. Fullbright",
            Crosshair = "14. Crosshair",
            Watermark = "15. Watermark",
            AliveCount = "16. Alive Counter"
        }
    }

    local text = T[Lang] or T.RU
    local VisTab = UI:CreateTab(text.Tab)

    VisTab:AddSection(text.SecESP)
    VisTab:AddToggle({ Title = text.ESP, Default = Visuals.Config.ESP_Enabled, Callback = function(s) Visuals.Config.ESP_Enabled = s end })
    VisTab:AddToggle({ Title = text.RoleColors, Default = Visuals.Config.RoleColors, Callback = function(s) Visuals.Config.RoleColors = s end })
    VisTab:AddToggle({ Title = text.Chroma, Default = Visuals.Config.Chroma, Callback = function(s) Visuals.Config.Chroma = s end })
    VisTab:AddToggle({ Title = text.Outlines, Default = Visuals.Config.Outlines, Callback = function(s) Visuals.Config.Outlines = s end })
    VisTab:AddToggle({ Title = text.Health, Default = Visuals.Config.HealthBar, Callback = function(s) Visuals.Config.HealthBar = s end })
    VisTab:AddToggle({ Title = text.Distance, Default = Visuals.Config.Distance, Callback = function(s) Visuals.Config.Distance = s end })
    VisTab:AddToggle({ Title = text.Tracers, Default = Visuals.Config.Tracers, Callback = function(s) Visuals.Config.Tracers = s end })
    
    VisTab:AddNumberInput({ Title = text.Transp, Min = 0, Max = 1, Default = Visuals.Config.ESP_Transparency, Callback = function(v) Visuals.Config.ESP_Transparency = v end })
    VisTab:AddNumberInput({ Title = text.TextSize, Min = 10, Max = 24, Default = Visuals.Config.ESP_TextSize, Callback = function(v) Visuals.Config.ESP_TextSize = v end })

    VisTab:AddSection(text.SecTrack)
    VisTab:AddToggle({ Title = text.GunESP, Default = Visuals.Config.GunESP, Callback = function(s) Visuals.Config.GunESP = s end })
    VisTab:AddToggle({ Title = text.CoinESP, Default = false, Callback = function(s) end })

    VisTab:AddSection(text.SecHUD)
    VisTab:AddToggle({ Title = text.NightMode, Default = Visuals.Config.NightName or Visuals.Config.NightMode, Callback = function(s) Visuals.Config.NightMode = s end })
    VisTab:AddToggle({ Title = text.Fullbright, Default = Visuals.Config.Fullbright, Callback = function(s) Visuals.Config.Fullbright = s end })
    VisTab:AddToggle({ Title = text.Crosshair, Default = Visuals.Config.Crosshair, Callback = function(s) Visuals.Config.Crosshair = s end })
    VisTab:AddToggle({ Title = text.Watermark, Default = Visuals.Config.Watermark, Callback = function(s) Visuals.Config.Watermark = s end })
    VisTab:AddToggle({ Title = text.AliveCount, Default = Visuals.Config.AliveCounter, Callback = function(s) Visuals.Config.AliveCounter = s end })
end

return Visuals
