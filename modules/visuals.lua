-- [[ MM2 VISUALS MODULE - WORKING EDITION ]] --
local Visuals = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

Visuals.Config = {
    ESP_Enabled = false,
    RoleColors = true,
    Distance = true,
    GunESP = false,
    NightMode = false,
    Crosshair = false,
    Watermark = true,
    ESP_Transparency = 0.5,
    ESP_TextSize = 14
}

-- Создаем интерфейс для HUD (Ватермарка и Прицел)
local HUDGui = Instance.new("ScreenGui")
HUDGui.Name = "PurpleFox_HUD"
HUDGui.ResetOnSpawn = false
pcall(function() HUDGui.Parent = CoreGui end)
if not HUDGui.Parent then HUDGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Watermark
local WatermarkLabel = Instance.new("TextLabel")
WatermarkLabel.Size = UDim2.new(0, 180, 0, 28)
WatermarkLabel.Position = UDim2.new(0, 10, 0, 10)
WatermarkLabel.BackgroundTransparency = 0.4
WatermarkLabel.BackgroundColor3 = Color3.fromRGB(15, 10, 20)
WatermarkLabel.TextColor3 = Color3.fromRGB(160, 32, 240)
WatermarkLabel.Font = Enum.Font.GothamBold
WatermarkLabel.TextSize = 13
WatermarkLabel.Text = " 🦊 PURPLE FOX | MM2 "
WatermarkLabel.TextXAlignment = Enum.TextXAlignment.Left
WatermarkLabel.Visible = false
WatermarkLabel.Parent = HUDGui
Instance.new("UICorner", WatermarkLabel).CornerRadius = UDim.new(0, 4)

-- Кастомный кроссхейр (Прицел в центре экрана)
local CrosshairFrame = Instance.new("Frame")
CrosshairFrame.Size = UDim2.new(0, 30, 0, 30)
CrosshairFrame.Position = UDim2.new(0.5, -15, 0.5, -15)
CrosshairFrame.BackgroundTransparency = 1
CrosshairFrame.Visible = false
CrosshairFrame.Parent = HUDGui

local CH_V = Instance.new("Frame", CrosshairFrame)
CH_V.Size = UDim2.new(0, 2, 0, 12)
CH_V.Position = UDim2.new(0.5, -1, 0.5, -6)
CH_V.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
CH_V.BorderSizePixel = 0

local CH_H = Instance.new("Frame", CrosshairFrame)
CH_H.Size = UDim2.new(0, 12, 0, 2)
CH_H.Position = UDim2.new(0.5, -6, 0.5, -1)
CH_H.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
CH_H.BorderSizePixel = 0

-- Определение роли игрока
local function GetRole(player)
    if not player or not player.Character then return "Innocent" end
    local backpack = player:FindFirstChild("Backpack")
    local char = player.Character

    if (backpack and backpack:FindFirstChild("Knife")) or char:FindFirstChild("Knife") then return "Murderer" end
    if (backpack and backpack:FindFirstChild("Gun")) or char:FindFirstChild("Gun") then return "Sheriff" end
    return "Innocent"
end

local function GetColor(role)
    if role == "Murderer" then return Color3.fromRGB(255, 30, 30) -- Красный (Убийца)
    elseif role == "Sheriff" then return Color3.fromRGB(30, 140, 255) -- Синий (Шериф)
    else return Color3.fromRGB(30, 255, 30) end -- Зеленый (Мирный)
end

-- Главный защищенный цикл
task.spawn(function()
    while task.wait(0.2) do
        pcall(function()
            -- Обновление HUD элементов
            WatermarkLabel.Visible = Visuals.Config.Watermark
            CrosshairFrame.Visible = Visuals.Config.Crosshair
            
            if Visuals.Config.NightMode then
                Lighting.ClockTime = 0
            end

            -- Цикл по игрокам для ESP
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local char = player.Character
                    if char and char:FindFirstChild("Head") and char:FindFirstChildOfClass("Humanoid") and char.Humanoid.Health > 0 then
                        local head = char.Head
                        local role = GetRole(player)
                        local color = Visuals.Config.RoleColors and GetColor(role) or Color3.fromRGB(160, 32, 240)

                        -- 1. Текстовый лейбл над головой (Имя + Роль + Дистанция)
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
                                distStr = " (" .. dist .. "m)"
                            end

                            bb.Label.Text = player.Name .. " [" .. role .. "]" .. distStr
                            bb.Label.TextColor3 = color
                            bb.Label.TextSize = Visuals.Config.ESP_TextSize
                        else
                            if bb then bb:Destroy() end
                        end

                        -- 2. Подсветка персонажа (Highlight)
                        local hl = char:FindFirstChild("PF_Highlight")
                        if Visuals.Config.ESP_Enabled then
                            if not hl then
                                hl = Instance.new("Highlight", char)
                                hl.Name = "PF_Highlight"
                            end
                            hl.FillColor = color
                            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                            hl.FillTransparency = Visuals.Config.ESP_Transparency
                            hl.OutlineTransparency = 0
                        else
                            if hl then hl:Destroy() end
                        end
                    end
                end
            end

            -- 3. ESP на упавший пистолет
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

        end)
    end
end)

function Visuals.Init(GlobalConfig, UI, Lang)
    local T = {
        RU = {
            Tab = "👁️ Визуалы",
            SecESP = "Игроки и Подсветки",
            ESP = "ESP на игроков",
            RoleColors = "Цвета ролей (Murder/Sheriff)",
            Distance = "Показывать дистанцию в метрах",
            Transp = "Прозрачность подсветок",
            TextSize = "Размер текста ESP",

            SecTrack = "Предметы",
            GunESP = "ESP на упавший пистолет",

            SecHUD = "Интерфейс и Окружение",
            NightMode = "Ночной режим (Night Mode)",
            Crosshair = "Кастомный прицел (Crosshair)",
            Watermark = "Водяной знак (Watermark)"
        },
        EN = {
            Tab = "👁️ Visuals",
            SecESP = "Players & Highlights",
            ESP = "Player ESP",
            RoleColors = "Role Colors",
            Distance = "Show Distance",
            Transp = "ESP Transparency",
            TextSize = "ESP Text Size",

            SecTrack = "Items",
            GunESP = "Dropped Gun ESP",

            SecHUD = "HUD & Environment",
            NightMode = "Night Mode",
            Crosshair = "Custom Crosshair",
            Watermark = "Watermark"
        }
    }

    local text = T[Lang] or T.RU
    local VisTab = UI:CreateTab(text.Tab)

    -- Секция 1: Игроки
    VisTab:AddSection(text.SecESP)
    VisTab:AddToggle({ Title = text.ESP, Default = Visuals.Config.ESP_Enabled, Callback = function(s) Visuals.Config.ESP_Enabled = s end })
    VisTab:AddToggle({ Title = text.RoleColors, Default = Visuals.Config.RoleColors, Callback = function(s) Visuals.Config.RoleColors = s end })
    VisTab:AddToggle({ Title = text.Distance, Default = Visuals.Config.Distance, Callback = function(s) Visuals.Config.Distance = s end })

    VisTab:AddNumberInput({ Title = text.Transp, Min = 0, Max = 1, Default = Visuals.Config.ESP_Transparency, Callback = function(v) Visuals.Config.ESP_Transparency = v end })
    VisTab:AddNumberInput({ Title = text.TextSize, Min = 10, Max = 24, Default = Visuals.Config.ESP_TextSize, Callback = function(v) Visuals.Config.ESP_TextSize = v end })

    -- Секция 2: Предметы
    VisTab:AddSection(text.SecTrack)
    VisTab:AddToggle({ Title = text.GunESP, Default = Visuals.Config.GunESP, Callback = function(s) Visuals.Config.GunESP = s end })

    -- Секция 3: Окружение
    VisTab:AddSection(text.SecHUD)
    VisTab:AddToggle({ Title = text.NightMode, Default = Visuals.Config.NightMode, Callback = function(s) Visuals.Config.NightMode = s end })
    VisTab:AddToggle({ Title = text.Crosshair, Default = Visuals.Config.Crosshair, Callback = function(s) Visuals.Config.Crosshair = s end })
    VisTab:AddToggle({ Title = text.Watermark, Default = Visuals.Config.Watermark, Callback = function(s) Visuals.Config.Watermark = s end })
end

return Visuals
