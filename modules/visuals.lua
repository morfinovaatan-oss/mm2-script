-- [[ MM2 VISUALS MODULE - RELIABLE RENDER ]] --
local Visuals = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

Visuals.Config = {
    ESP_Enabled = false,
    RoleColors = true,
    GunESP = false,
    Tracers = false,
    Crosshair = false,
    NightMode = false,
    Watermark = true,
    ESP_Transparency = 0.5,
    ESP_TextSize = 14
}

-- Папка в CoreGui для хранения подсветок и надписей
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "PurpleFox_ESP"
pcall(function() ESPFolder.Parent = CoreGui end)
if not ESPFolder.Parent then ESPFolder.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Функция определения роли в MM2
local function GetPlayerRole(player)
    if not player or not player.Character then return "Innocent" end
    
    -- Проверка инвентаря и рук
    local backpack = player:FindFirstChild("Backpack")
    local character = player.Character

    if (backpack and backpack:FindFirstChild("Knife")) or character:FindFirstChild("Knife") then
        return "Murderer"
    elseif (backpack and backpack:FindFirstChild("Gun")) or character:FindFirstChild("Gun") then
        return "Sheriff"
    end

    -- Дополнительная проверка на случай специфической структуры MM2
    for _, item in pairs(character:GetChildren()) do
        if item:IsA("Tool") then
            if item.Name:lower():find("knife") or item.Name:lower():find("blade") then return "Murderer" end
            if item.Name:lower():find("gun") or item.Name:lower():find("revolver") then return "Sheriff" end
        end
    end

    return "Innocent"
end

local function GetRoleColor(role)
    if role == "Murderer" then return Color3.fromRGB(255, 40, 40)
    elseif role == "Sheriff" then return Color3.fromRGB(40, 140, 255)
    else return Color3.fromRGB(40, 255, 40) end
end

-- Отрисовка каждый кадр
RunService.RenderStepped:Connect(function()
    -- 1. ESP и Текстовые метки над игроками
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local tag = ESPFolder:FindFirstChild("Tag_" .. player.Name)
            local hl = ESPFolder:FindFirstChild("HL_" .. player.Name)

            if Visuals.Config.ESP_Enabled and player.Character and player.Character:FindFirstChild("Head") and player.Character:FindFirstChildOfClass("Humanoid") and player.Character.Humanoid.Health > 0 then
                local head = player.Character.Head
                local role = GetPlayerRole(player)
                local color = Visuals.Config.RoleColors and GetRoleColor(role) or Color3.fromRGB(160, 32, 240)

                -- 1A. Текстовый Tag (Имя + Роль + Дистанция)
                if not tag then
                    tag = Instance.new("BillboardGui")
                    tag.Name = "Tag_" .. player.Name
                    tag.AlwaysOnTop = true
                    tag.Size = UDim2.new(0, 200, 0, 50)
                    tag.StudsOffset = Vector3.new(0, 3, 0)

                    local lbl = Instance.new("TextLabel")
                    lbl.Name = "Label"
                    lbl.Size = UDim2.new(1, 0, 1, 0)
                    lbl.BackgroundTransparency = 1
                    lbl.Font = Enum.Font.GothamBold
                    lbl.TextStrokeTransparency = 0
                    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                    lbl.Parent = tag
                    tag.Parent = ESPFolder
                end

                tag.Adornee = head
                tag.Enabled = true
                
                local dist = math.floor((head.Position - Camera.CFrame.Position).Magnitude)
                local label = tag:FindFirstChild("Label")
                if label then
                    label.Text = string.format("%s\n[%s] (%dm)", player.Name, role, dist)
                    label.TextColor3 = color
                    label.TextSize = Visuals.Config.ESP_TextSize
                end

                -- 1B. Подсветка персонажа (Highlight)
                if not hl then
                    hl = Instance.new("Highlight")
                    hl.Name = "HL_" .. player.Name
                    hl.Parent = ESPFolder
                end

                hl.Adornee = player.Character
                hl.FillColor = color
                hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                hl.FillTransparency = Visuals.Config.ESP_Transparency
                hl.Enabled = true
            else
                if tag then tag.Enabled = false end
                if hl then hl.Enabled = false end
            end
        end
    end

    -- 2. ESP на выпавший пистолет (Gun ESP)
    local gunDrop = Workspace:FindFirstChild("GunDrop")
    local gunTag = ESPFolder:FindFirstChild("Tag_GunDrop")
    if Visuals.Config.GunESP and gunDrop then
        if not gunTag then
            gunTag = Instance.new("BillboardGui")
            gunTag.Name = "Tag_GunDrop"
            gunTag.AlwaysOnTop = true
            gunTag.Size = UDim2.new(0, 200, 0, 40)
            gunTag.StudsOffset = Vector3.new(0, 2, 0)

            local lbl = Instance.new("TextLabel")
            lbl.Name = "Label"
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamBold
            lbl.Text = "🔫 ПИСТОЛЕТ!"
            lbl.TextColor3 = Color3.fromRGB(255, 215, 0)
            lbl.TextSize = 16
            lbl.TextStrokeTransparency = 0
            lbl.Parent = gunTag
            gunTag.Parent = ESPFolder
        end
        gunTag.Adornee = gunDrop
        gunTag.Enabled = true
    else
        if gunTag then gunTag.Enabled = false end
    end

    -- 3. Ночной режим
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
            RoleColors = "2. Цвета для ролей (Murder/Sheriff)",
            Transp = "3. Прозрачность подсветок",
            TextSize = "4. Размер текста над головой",

            SecTrack = "Отслеживание предметов",
            GunESP = "8. Gun ESP (Подборный пистолет)",

            SecHUD = "Интерфейс и Окружение",
            NightMode = "16. Night Mode (Ночной режим)"
        },
        EN = {
            Tab = "👁️ Visuals",
            SecESP = "Players & Highlights",
            ESP = "1. Player ESP (Toggle)",
            RoleColors = "2. Role Colors (Murder/Sheriff)",
            Transp = "3. ESP Transparency",
            TextSize = "4. ESP Text Size",

            SecTrack = "Item Tracking",
            GunESP = "8. Dropped Gun ESP",

            SecHUD = "Environment",
            NightMode = "16. Night Mode"
        }
    }

    local text = T[Lang] or T.RU
    local VisTab = UI:CreateTab(text.Tab)

    -- Секция 1: Игроки
    VisTab:AddSection(text.SecESP)
    VisTab:AddToggle({ Title = text.ESP, Default = Visuals.Config.ESP_Enabled, Callback = function(s) Visuals.Config.ESP_Enabled = s end })
    VisTab:AddToggle({ Title = text.RoleColors, Default = Visuals.Config.RoleColors, Callback = function(s) Visuals.Config.RoleColors = s end })
    
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

    -- Секция 2: Предметы
    VisTab:AddSection(text.SecTrack)
    VisTab:AddToggle({ Title = text.GunESP, Default = Visuals.Config.GunESP, Callback = function(s) Visuals.Config.GunESP = s end })

    -- Секция 3: Окружение
    VisTab:AddSection(text.SecHUD)
    VisTab:AddToggle({ Title = text.NightMode, Default = Visuals.Config.NightMode, Callback = function(s) Visuals.Config.NightMode = s end })
end

return Visuals
