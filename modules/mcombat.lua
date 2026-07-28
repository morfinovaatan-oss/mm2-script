-- [[ MM2 MURDERER COMBAT MODULE – Aimbot + Auto Knife + Teleport ]] --
local MCombat = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local StarterGui = game:GetService("StarterGui")

MCombat.Config = {
    -- Аимбот
    AimEnabled = false,
    AimMode = "Dynamic",        -- Static, Dynamic, Smooth
    FOVCenter = "Mouse",        -- "Mouse" или "Camera"
    Prediction = 15,
    SmoothSpeed = 5,
    FOV = 120,
    FOVTransparency = 0.5,
    AutoShiftLock = true,       -- автоматически включать Shift Lock при захвате цели

    -- Телепорт к шерифу
    TeleportToSheriff = false,
    TeleportDistance = 5,       -- дистанция перед шерифом

    -- Авто‑атака ножом
    AutoKnife = false,
    KnifeDistance = 8,          -- дистанция для удара
    KnifeCooldown = 0.4,

    -- Бинды
    ShootKey = Enum.KeyCode.C,   -- для ножа будет использоваться этот же бинд (удар)
    FindSheriffKey = Enum.KeyCode.X,
}

-- FOV Circle GUI
local FOVGui = Instance.new("ScreenGui")
FOVGui.Name = "PurpleFox_FOV_M"
FOVGui.ResetOnSpawn = false
pcall(function() FOVGui.Parent = CoreGui end)
if not FOVGui.Parent then FOVGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local FOVFrame = Instance.new("Frame", FOVGui)
FOVFrame.BackgroundTransparency = 1
FOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)
FOVFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
FOVFrame.Visible = false
Instance.new("UICorner", FOVFrame).CornerRadius = UDim.new(1, 0)
local FOVStroke = Instance.new("UIStroke", FOVFrame)
FOVStroke.Thickness = 1.5
FOVStroke.Color = Color3.fromRGB(255, 50, 50)  -- красный для мёрдера

-- Состояния
local lastShotTime = 0
local shiftLockActive = false
local bodyVelocity = nil

-- Helpers
local function SimulateClick()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    task.wait(0.02)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
end

local function enableShiftLock()
    if shiftLockActive then return end
    if not MCombat.Config.AutoShiftLock then return end
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
    shiftLockActive = true
end

local function disableShiftLock()
    if not shiftLockActive then return end
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
    shiftLockActive = false
end

local function FindSheriff()
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local hasGun = p.Character:FindFirstChild("Gun") or (p:FindFirstChild("Backpack") and p.Backpack:FindFirstChild("Gun"))
            local hasRevolver = p.Character:FindFirstChild("Revolver") or (p:FindFirstChild("Backpack") and p.Backpack:FindFirstChild("Revolver"))
            if (hasGun or hasRevolver) and p.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                return p
            end
        end
    end
    return nil
end

local function GetAimTarget()
    local centerPoint
    if MCombat.Config.FOVCenter == "Camera" then
        centerPoint = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    else
        centerPoint = UserInputService:GetMouseLocation()
    end

    local best = nil
    local bestDist = MCombat.Config.FOV
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local head = p.Character:FindFirstChild("Head")
            -- Только шерифы
            local hasGun = p.Character:FindFirstChild("Gun") or (p:FindFirstChild("Backpack") and p.Backpack:FindFirstChild("Gun"))
            local hasRevolver = p.Character:FindFirstChild("Revolver") or (p:FindFirstChild("Backpack") and p.Backpack:FindFirstChild("Revolver"))
            if hum and hum.Health > 0 and head and (hasGun or hasRevolver) then
                local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - centerPoint).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        best = head
                    end
                end
            end
        end
    end
    return best
end

local function SmoothAim(targetPos, speed)
    speed = speed or MCombat.Config.SmoothSpeed / 10
    local current = Camera.CFrame
    local desired = CFrame.new(current.Position, targetPos)
    Camera.CFrame = current:Lerp(desired, speed)
end

local function enableAntiGravity()
    if bodyVelocity then return end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bodyVelocity.Parent = char.HumanoidRootPart
end

local function disableAntiGravity()
    if bodyVelocity then
        bodyVelocity:Destroy()
        bodyVelocity = nil
    end
end

-- Heartbeat
local heartbeatConnection
local function startHeartbeat()
    if heartbeatConnection then return end
    heartbeatConnection = RunService.Heartbeat:Connect(function()
        pcall(function()
            local char = LocalPlayer.Character
            if not char or char:FindFirstChildOfClass("Humanoid").Health <= 0 then
                FOVFrame.Visible = false
                disableShiftLock()
                disableAntiGravity()
                return
            end

            FOVFrame.Size = UDim2.new(0, MCombat.Config.FOV * 2, 0, MCombat.Config.FOV * 2)
            FOVStroke.Transparency = MCombat.Config.FOVTransparency
            FOVFrame.Visible = MCombat.Config.AimEnabled

            -- Телепорт к шерифу
            if MCombat.Config.TeleportToSheriff then
                local sheriff = FindSheriff()
                if sheriff and sheriff.Character and sheriff.Character:FindFirstChild("HumanoidRootPart") then
                    local sRoot = sheriff.Character.HumanoidRootPart
                    local targetPos = sRoot.Position + (sRoot.CFrame.LookVector * MCombat.Config.TeleportDistance)
                    targetPos = targetPos + Vector3.new(0, 2.5, 0)
                    char:PivotTo(CFrame.new(targetPos, sRoot.Position))
                    if char.HumanoidRootPart then
                        char.HumanoidRootPart.Velocity = Vector3.new(0, 0, 0)
                        char.HumanoidRootPart.RotVelocity = Vector3.new(0, 0, 0)
                    end
                    enableAntiGravity()
                else
                    disableAntiGravity()
                end
            else
                disableAntiGravity()
            end

            -- Аимбот
            if MCombat.Config.AimEnabled and not MCombat.Config.TeleportToSheriff then
                local target = GetAimTarget()
                local targetPos = target and target.Position
                if targetPos then
                    enableShiftLock()
                    if MCombat.Config.Prediction > 0 then
                        local root = target.Parent and target.Parent:FindFirstChild("HumanoidRootPart")
                        if root then
                            targetPos += root.Velocity * (MCombat.Config.Prediction / 1000)
                        end
                    end
                    if MCombat.Config.AimMode == "Static" then
                        Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)
                    elseif MCombat.Config.AimMode == "Smooth" or MCombat.Config.AimMode == "Dynamic" then
                        SmoothAim(targetPos)
                    end
                else
                    disableShiftLock()
                end
            elseif MCombat.Config.TeleportToSheriff then
                -- В режиме телепорта камера на шерифа
                local sheriff = FindSheriff()
                if sheriff and sheriff.Character and sheriff.Character:FindFirstChild("Head") then
                    Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, sheriff.Character.Head.Position)
                end
                disableShiftLock()
            else
                disableShiftLock()
            end

            -- Авто‑атака ножом
            if MCombat.Config.AutoKnife then
                local sheriff = FindSheriff()
                if sheriff and sheriff.Character and sheriff.Character:FindFirstChild("HumanoidRootPart") then
                    local sRoot = sheriff.Character.HumanoidRootPart
                    local myRoot = char:FindFirstChild("HumanoidRootPart")
                    if myRoot then
                        local dist = (myRoot.Position - sRoot.Position).Magnitude
                        if dist <= MCombat.Config.KnifeDistance and (tick() - lastShotTime >= MCombat.Config.KnifeCooldown) then
                            -- Экипируем нож, если не в руках
                            local tool = char:FindFirstChildOfClass("Tool")
                            if not tool or tool.Name ~= "Knife" then
                                local backpack = LocalPlayer:FindFirstChild("Backpack")
                                local knife = backpack and backpack:FindFirstChild("Knife")
                                if knife and char:FindFirstChildOfClass("Humanoid") then
                                    char:FindFirstChildOfClass("Humanoid"):EquipTool(knife)
                                end
                            end
                            SimulateClick()
                            lastShotTime = tick()
                        end
                    end
                end
            end
        end)
    end)
end

startHeartbeat()

-- Бинды
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == MCombat.Config.ShootKey then
        SimulateClick()
    elseif input.KeyCode == MCombat.Config.FindSheriffKey then
        local sheriff = FindSheriff()
        if sheriff then
            local userId = Players:GetUserIdFromNameAsync(sheriff.Name)
            StarterGui:SetCore("SendNotification", {
                Title = "Sheriff",
                Text = "Their name is " .. sheriff.Name .. "!",
                Icon = "https://web.roblox.com/Thumbs/Avatar.ashx?x=100&y=100&Format=Png&userid=" .. userId,
                Duration = 5,
                Button1 = "Dismiss",
            })
        else
            StarterGui:SetCore("SendNotification", {
                Title = "Sheriff",
                Text = "No sheriff could be found!",
                Duration = 5,
                Button1 = "Dismiss",
            })
        end
    end
end)

-- Очистка при возрождении
LocalPlayer.CharacterAdded:Connect(function()
    if shiftLockActive then disableShiftLock() end
    disableAntiGravity()
end)

-- UI Init
function MCombat.Init(GlobalConfig, UI, Lang)
    local T = {
        RU = {
            Tab = "🔪 Убийца",
            SecAim = "Аимбот на шерифа",
            AimEnable = "Аимбот",
            AimMode = "Режим",
            FOVCenter = "Центр FOV",
            Pred = "Упреждение",
            Smooth = "Сглаживание",
            FOV = "Радиус FOV",
            FOVTrans = "Прозрачность FOV",
            AutoShiftLock = "Авто-Shift Lock",

            SecTeleport = "Телепорт к шерифу",
            TeleportEnable = "Телепортироваться",
            TeleportDist = "Дистанция перед шерифом",

            SecAuto = "Авто‑атака",
            AutoKnife = "Авто‑удар ножом",
            KnifeDist = "Дистанция удара",
            KnifeCooldown = "Кулдаун (сек)",

            SecKeys = "Клавиши",
            ShootKey = "Удар ножом",
            FindSheriffKey = "Найти шерифа",
        },
        EN = {
            Tab = "🔪 Murderer",
            SecAim = "Aimbot on Sheriff",
            AimEnable = "Aimbot",
            AimMode = "Mode",
            FOVCenter = "FOV Center",
            Pred = "Prediction",
            Smooth = "Smoothness",
            FOV = "FOV Radius",
            FOVTrans = "FOV Transparency",
            AutoShiftLock = "Auto Shift Lock",

            SecTeleport = "Teleport to Sheriff",
            TeleportEnable = "Teleport",
            TeleportDist = "Distance in front",

            SecAuto = "Auto Attack",
            AutoKnife = "Auto Knife",
            KnifeDist = "Knife Distance",
            KnifeCooldown = "Cooldown (s)",

            SecKeys = "Keybinds",
            ShootKey = "Knife Hit",
            FindSheriffKey = "Find Sheriff",
        }
    }

    local text = T[Lang] or T.RU
    local tab = UI:CreateTab(text.Tab)

    -- Aimbot Section
    tab:AddSection(text.SecAim)
    tab:AddToggle({ Title = text.AimEnable, Default = false, Callback = function(s) MCombat.Config.AimEnabled = s end })
    tab:AddDropdown({
        Title = text.AimMode,
        Options = {"Static", "Dynamic", "Smooth"},
        Default = MCombat.Config.AimMode,
        Callback = function(v) MCombat.Config.AimMode = v end
    })
    tab:AddDropdown({
        Title = text.FOVCenter,
        Options = {"Mouse", "Camera"},
        Default = MCombat.Config.FOVCenter,
        Callback = function(v) MCombat.Config.FOVCenter = v end
    })
    tab:AddNumberInput({ Title = text.Pred, Min = 0, Max = 100, Default = MCombat.Config.Prediction, Callback = function(v) MCombat.Config.Prediction = v end })
    tab:AddNumberInput({ Title = text.Smooth, Min = 1, Max = 10, Default = MCombat.Config.SmoothSpeed, Callback = function(v) MCombat.Config.SmoothSpeed = v end })
    tab:AddNumberInput({ Title = text.FOV, Min = 30, Max = 500, Default = MCombat.Config.FOV, Callback = function(v) MCombat.Config.FOV = v end })
    tab:AddNumberInput({ Title = text.FOVTrans, Min = 0, Max = 1, Default = MCombat.Config.FOVTransparency, Callback = function(v) MCombat.Config.FOVTransparency = v end })
    tab:AddToggle({ Title = text.AutoShiftLock, Default = MCombat.Config.AutoShiftLock, Callback = function(s) MCombat.Config.AutoShiftLock = s end })

    -- Teleport Section
    tab:AddSection(text.SecTeleport)
    tab:AddToggle({ Title = text.TeleportEnable, Default = false, Callback = function(s) MCombat.Config.TeleportToSheriff = s end })
    tab:AddNumberInput({ Title = text.TeleportDist, Min = 2, Max = 15, Default = MCombat.Config.TeleportDistance, Callback = function(v) MCombat.Config.TeleportDistance = v end })

    -- Auto Attack Section
    tab:AddSection(text.SecAuto)
    tab:AddToggle({ Title = text.AutoKnife, Default = false, Callback = function(s) MCombat.Config.AutoKnife = s end })
    tab:AddNumberInput({ Title = text.KnifeDist, Min = 3, Max = 12, Default = MCombat.Config.KnifeDistance, Callback = function(v) MCombat.Config.KnifeDistance = v end })
    tab:AddNumberInput({ Title = text.KnifeCooldown, Min = 0.1, Max = 1, Default = MCombat.Config.KnifeCooldown, Callback = function(v) MCombat.Config.KnifeCooldown = v end })

    -- Keybinds Section
    tab:AddSection(text.SecKeys)
    local function addBindLabelAndButton(keyName, configKeyString)
        local label = tab:AddLabel(keyName .. " : " .. tostring(MCombat.Config[configKeyString]):gsub("Enum.KeyCode.", ""))
        tab:AddButton(keyName .. " (нажмите для смены)", function()
            local oldKey = MCombat.Config[configKeyString]
            label.Text = keyName .. " : ... (ожидание)"
            local conn
            conn = UserInputService.InputBegan:Connect(function(input, gp)
                if gp then return end
                conn:Disconnect()
                MCombat.Config[configKeyString] = input.KeyCode
                label.Text = keyName .. " : " .. tostring(input.KeyCode):gsub("Enum.KeyCode.", "")
            end)
            task.wait(3)
            if MCombat.Config[configKeyString] == oldKey then
                label.Text = keyName .. " : " .. tostring(oldKey):gsub("Enum.KeyCode.", "")
            end
        end)
    end
    addBindLabelAndButton(text.ShootKey, "ShootKey")
    addBindLabelAndButton(text.FindSheriffKey, "FindSheriffKey")
end

return MCombat
