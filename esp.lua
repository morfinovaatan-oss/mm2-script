--[[
    Firola v1 - ESP Module (Player ESP + Gun ESP + HUD)
--]]

local Module = {}

function Module:Init(Firola)
    local Services = Firola.Services
    local Players = Services.Players
    local Workspace = Services.Workspace
    local Lighting = Services.Lighting
    local CoreGui = Services.CoreGui
    local RunService = Services.RunService
    local LocalPlayer = Firola.LocalPlayer
    local UI = Firola.UI
    local tabName = "ESP"

    -- ====================== КОНФИГУРАЦИЯ ======================
    local Config = {
        ESP_Enabled = false,
        RoleColors = true,
        Chroma = false,
        Outlines = true,
        Distance = false,
        HealthBar = false,
        Tracers = false,
        ESP_Transparency = 0.5,
        ESP_TextSize = 14,
        GunESP = false,
        CoinESP = false,
        NightMode = false,
        Fullbright = false,
        Crosshair = false,
        AliveCounter = false,
    }

    -- Внутренние переменные для GunESP
    local currentGunHighlight = nil
    local currentGunBillboard = nil

    -- ====================== HUD ======================
    local HUDGui = Instance.new("ScreenGui")
    HUDGui.Name = "Firola_HUD"
    HUDGui.ResetOnSpawn = false
    pcall(function() HUDGui.Parent = CoreGui end)
    if not HUDGui.Parent then HUDGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    -- Crosshair
    local Crosshair = Instance.new("Frame", HUDGui)
    Crosshair.Size = UDim2.new(0, 30, 0, 30)
    Crosshair.Position = UDim2.new(0.5, -15, 0.5, -15)
    Crosshair.BackgroundTransparency = 1
    Crosshair.Visible = false
    local CH_V = Instance.new("Frame", Crosshair)
    CH_V.Size = UDim2.new(0, 2, 0, 12)
    CH_V.Position = UDim2.new(0.5, -1, 0.5, -6)
    CH_V.BackgroundColor3 = Color3.fromRGB(0, 230, 200)
    CH_V.BorderSizePixel = 0
    local CH_H = Instance.new("Frame", Crosshair)
    CH_H.Size = UDim2.new(0, 12, 0, 2)
    CH_H.Position = UDim2.new(0.5, -6, 0.5, -1)
    CH_H.BackgroundColor3 = Color3.fromRGB(0, 230, 200)
    CH_H.BorderSizePixel = 0

    -- Alive Counter
    local AliveFrame = Instance.new("TextLabel", HUDGui)
    AliveFrame.Size = UDim2.new(0, 200, 0, 28)
    AliveFrame.Position = UDim2.new(0.5, -100, 0, 10)
    AliveFrame.BackgroundColor3 = Color3.fromRGB(34, 34, 34)
    AliveFrame.BackgroundTransparency = 0.3
    AliveFrame.TextColor3 = Color3.fromRGB(220, 220, 220)
    AliveFrame.Font = Enum.Font.GothamBold
    AliveFrame.TextSize = 14
    AliveFrame.Visible = false
    Instance.new("UICorner", AliveFrame).CornerRadius = UDim.new(0, 4)
    Instance.new("UIStroke", AliveFrame).Color = Color3.fromRGB(0, 230, 200)

    -- ====================== РОЛИ ======================
    local function GetRole(player)
        if not player or not player.Character then return "Innocent" end
        local backpack = player:FindFirstChild("Backpack")
        local char = player.Character
        if (backpack and backpack:FindFirstChild("Knife")) or char:FindFirstChild("Knife") then return "Murderer" end
        if (backpack and backpack:FindFirstChild("Gun")) or char:FindFirstChild("Gun") then return "Sheriff" end
        return "Innocent"
    end

    local function GetColor(role)
        if Config.Chroma then return Color3.fromHSV((tick() % 5) / 5, 1, 1) end
        if role == "Murderer" then return Color3.fromRGB(255, 30, 30)
        elseif role == "Sheriff" then return Color3.fromRGB(30, 140, 255)
        else return Color3.fromRGB(30, 255, 30) end
    end

    -- ====================== ПОИСК КАРТЫ ======================
    local function getMap()
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v.Name == "Spawns" and v.Parent.Name ~= "Lobby" then
                return v.Parent
            end
        end
        return nil
    end

    -- ====================== GUN ESP ======================
    local function removeGunESP()
        if currentGunHighlight then 
            pcall(function() currentGunHighlight:Destroy() end)
            currentGunHighlight = nil 
        end
        if currentGunBillboard then 
            pcall(function() currentGunBillboard:Destroy() end)
            currentGunBillboard = nil 
        end
    end

    local function applyGunESP(gunDrop)
        removeGunESP()
        if not gunDrop then return end

        local handle = gunDrop:IsA("BasePart") and gunDrop
            or gunDrop:FindFirstChild("Handle")
            or gunDrop:FindFirstChildWhichIsA("BasePart", true)

        if not handle then return end

        -- 1. Highlight (видно сквозь стены)
        local hl = Instance.new("Highlight")
        hl.Name = "Firola_GunHighlight"
        hl.FillColor = Color3.fromRGB(255, 215, 0)
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.25
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee = gunDrop
        
        pcall(function() hl.Parent = CoreGui end)
        if not hl.Parent then hl.Parent = gunDrop end
        currentGunHighlight = hl

        -- 2. BillboardGui с надписью
        local bb = Instance.new("BillboardGui")
        bb.Name = "Firola_GunText"
        bb.Adornee = handle
        bb.Size = UDim2.new(0, 150, 0, 40)
        bb.StudsOffset = Vector3.new(0, 2.5, 0)
        bb.AlwaysOnTop = true

        local label = Instance.new("TextLabel", bb)
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = "🔫 GUN HERE"
        label.TextColor3 = Color3.fromRGB(255, 215, 0)
        label.Font = Enum.Font.GothamBlack
        label.TextSize = 18
        label.TextStrokeTransparency = 0
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

        pcall(function() bb.Parent = CoreGui end)
        if not bb.Parent then bb.Parent = handle end
        currentGunBillboard = bb
    end

    -- ====================== ГЛАВНЫЙ ЦИКЛ ======================
    task.spawn(function()
        while task.wait(0.1) do
            pcall(function()
                -- HUD
                Crosshair.Visible = Config.Crosshair
                AliveFrame.Visible = Config.AliveCounter

                if Config.NightMode then
                    Lighting.ClockTime = 0
                elseif Config.Fullbright then
                    Lighting.ClockTime = 12
                    Lighting.Ambient = Color3.new(1, 1, 1)
                end

                local aliveCount = 0

                -- ESP игроков
                for _, player in pairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        local char = player.Character
                        if char and char:FindFirstChild("Head") and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChildOfClass("Humanoid") and char.Humanoid.Health > 0 then
                            aliveCount = aliveCount + 1
                            local head = char.Head
                            local root = char.HumanoidRootPart
                            local hum = char.Humanoid
                            local role = GetRole(player)
                            local color = Config.RoleColors and GetColor(role) or Color3.fromRGB(0, 230, 200)

                            -- 1. BillboardGui с именем и ролью
                            local bb = head:FindFirstChild("Firola_Tag")
                            if Config.ESP_Enabled then
                                if not bb then
                                    bb = Instance.new("BillboardGui", head)
                                    bb.Name = "Firola_Tag"
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
                                if Config.Distance and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                    local dist = math.floor((head.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude)
                                    distStr = "\n[" .. dist .. "m]"
                                end

                                bb.Label.Text = player.Name .. "\n[" .. role .. "]" .. distStr
                                bb.Label.TextColor3 = color
                                bb.Label.TextSize = Config.ESP_TextSize
                                
                                bb.HP_BG.Visible = Config.HealthBar
                                if Config.HealthBar then
                                    local hpPercent = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                                    bb.HP_BG.HP_Bar.Size = UDim2.new(hpPercent, 0, 1, 0)
                                    bb.HP_BG.HP_Bar.BackgroundColor3 = Color3.fromRGB(255 - (hpPercent * 255), hpPercent * 255, 0)
                                end
                            else
                                if bb then bb:Destroy() end
                            end

                            -- 2. Highlight персонажа
                            local hl = char:FindFirstChild("Firola_Highlight")
                            if Config.ESP_Enabled then
                                if not hl then
                                    hl = Instance.new("Highlight", char)
                                    hl.Name = "Firola_Highlight"
                                end
                                hl.FillColor = color
                                hl.OutlineColor = Config.Outlines and Color3.fromRGB(255, 255, 255) or color
                                hl.FillTransparency = Config.ESP_Transparency
                                hl.OutlineTransparency = Config.Outlines and 0 or 1
                            else
                                if hl then hl:Destroy() end
                            end

                            -- 3. Tracers
                            local myChar = LocalPlayer.Character
                            if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                                local myRoot = myChar.HumanoidRootPart
                                local att1 = myRoot:FindFirstChild("Firola_Att") or Instance.new("Attachment", myRoot)
                                att1.Name = "Firola_Att"
                                local att2 = root:FindFirstChild("Firola_Att") or Instance.new("Attachment", root)
                                att2.Name = "Firola_Att"

                                local beam = root:FindFirstChild("Firola_Tracer")
                                if Config.Tracers then
                                    if not beam then
                                        beam = Instance.new("Beam", root)
                                        beam.Name = "Firola_Tracer"
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

                if Config.AliveCounter then
                    AliveFrame.Text = "🔪 Alive: " .. aliveCount
                end

                -- === ДИНАМИЧЕСКИЙ GUN ESP ===
                if Config.GunESP then
                    local map = getMap()
                    local gunDrop = (map and map:FindFirstChild("GunDrop", true)) or Workspace:FindFirstChild("GunDrop", true)

                    if gunDrop then
                        if not currentGunHighlight or not currentGunHighlight.Parent or currentGunHighlight.Adornee ~= gunDrop then
                            applyGunESP(gunDrop)
                        end
                    else
                        if currentGunHighlight then
                            removeGunESP()
                        end
                    end
                else
                    if currentGunHighlight then
                        removeGunESP()
                    end
                end
            end)
        end
    end)

    -- ====================== UI ======================
    UI.CreateSection(tabName, "Players & ESP")
    UI.CreateToggle(tabName, {Text = "Enable ESP", Default = false, Callback = function(s) Config.ESP_Enabled = s end})
    UI.CreateToggle(tabName, {Text = "Role Colors", Default = true, Callback = function(s) Config.RoleColors = s end})
    UI.CreateToggle(tabName, {Text = "Rainbow (Chroma)", Default = false, Callback = function(s) Config.Chroma = s end})
    UI.CreateToggle(tabName, {Text = "Outlines", Default = true, Callback = function(s) Config.Outlines = s end})
    UI.CreateToggle(tabName, {Text = "Health Bar", Default = false, Callback = function(s) Config.HealthBar = s end})
    UI.CreateToggle(tabName, {Text = "Distance", Default = false, Callback = function(s) Config.Distance = s end})
    UI.CreateToggle(tabName, {Text = "Tracers", Default = false, Callback = function(s) Config.Tracers = s end})
    UI.CreateSlider(tabName, {Text = "Fill Transparency", Min = 0, Max = 1, Default = Config.ESP_Transparency, Decimals = 2, Callback = function(v) Config.ESP_Transparency = v end})
    UI.CreateSlider(tabName, {Text = "Text Size", Min = 10, Max = 24, Default = Config.ESP_TextSize, Suffix = " px", Callback = function(v) Config.ESP_TextSize = v end})

    UI.CreateSection(tabName, "Loot & Items")
    UI.CreateToggle(tabName, {Text = "Gun Drop ESP", Default = false, Callback = function(s) Config.GunESP = s; if not s then removeGunESP() end end})
    UI.CreateToggle(tabName, {Text = "Coin ESP", Default = false, Callback = function(s) Config.CoinESP = s end})

    UI.CreateSection(tabName, "HUD")
    UI.CreateToggle(tabName, {Text = "Night Mode", Default = false, Callback = function(s) Config.NightMode = s end})
    UI.CreateToggle(tabName, {Text = "Fullbright", Default = false, Callback = function(s) Config.Fullbright = s end})
    UI.CreateToggle(tabName, {Text = "Crosshair", Default = false, Callback = function(s) Config.Crosshair = s end})
    UI.CreateToggle(tabName, {Text = "Alive Counter", Default = false, Callback = function(s) Config.AliveCounter = s end})
end

return Module
