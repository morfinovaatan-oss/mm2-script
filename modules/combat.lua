-- [[ MM2 COMBAT MODULE – FIXED AUTO-PICKUP + CUSTOM KEYBINDS ]] --
local Combat = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

Combat.Config = {
    AimEnabled = false,
    AimMode = "Dynamic",   -- Static, Dynamic, Smooth, Hacker
    Prediction = 15,
    SmoothSpeed = 5,
    FOV = 120,
    FOVTransparency = 0.5,
    TriggerBot = false,
    AutoEquipGun = false,
    AutoShot = false,
    AutoPickGun = false,
    InfinitePickup = false,
    OneTapKnife = false,
    NoRecoil = false,
    AntiAim = false,
    FakeLag = false,

    -- Keybinds (customizable)
    ShootKey = Enum.KeyCode.C,   -- default C
    PickupKey = Enum.KeyCode.R,  -- default R
}

-- ================== FOV Circle ==================
local FOVGui = Instance.new("ScreenGui")
FOVGui.Name = "PurpleFox_FOV"
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
FOVStroke.Color = Color3.fromRGB(160, 32, 240)

-- ================== Helpers ==================
local function SimulateClick()
    pcall(function()
        local mouse = LocalPlayer:GetMouse()
        mouse1click()
    end)
end

local function IsThreat(player)
    if player == LocalPlayer then return false end
    local char = player.Character
    if not char then return false end
    local backpack = player:FindFirstChild("Backpack")
    local hasKnife = char:FindFirstChild("Knife") or (backpack and backpack:FindFirstChild("Knife"))
    local hasGun   = char:FindFirstChild("Gun")   or (backpack and backpack:FindFirstChild("Gun"))
    return hasKnife or hasGun
end

local function IsLocalSheriff()
    local char = LocalPlayer.Character
    if not char then return false end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    return (char:FindFirstChild("Gun") ~= nil) or (backpack and backpack:FindFirstChild("Gun") ~= nil)
end

local function FindMurderer()
    local closest = nil
    local minDist = math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local hasKnife = p.Character:FindFirstChild("Knife") or (p:FindFirstChild("Backpack") and p.Backpack:FindFirstChild("Knife"))
            if hasKnife and p.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                local dist = (p.Character.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    closest = p
                end
            end
        end
    end
    return closest
end

local function GetAimTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local best = nil
    local bestDist = Combat.Config.FOV
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local head = p.Character:FindFirstChild("Head")
            if hum and hum.Health > 0 and head and IsThreat(p) then
                local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
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
    speed = speed or Combat.Config.SmoothSpeed / 10
    local current = Camera.CFrame
    local desired = CFrame.new(current.Position, targetPos)
    Camera.CFrame = current:Lerp(desired, speed)
end

-- ================== Ручной подбор пистолета ==================
local function PickupGun()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- Ищем все модели GunDrop (и вложенные) в Workspace
    for _, drop in pairs(Workspace:GetDescendants()) do
        if drop:IsA("Model") and drop.Name == "GunDrop" then
            local tool = drop:FindFirstChildOfClass("Tool")
            if tool and tool:IsA("Tool") and (tool.Name == "Gun" or tool.Name:lower():find("gun")) then
                local handle = tool:FindFirstChild("Handle")
                if handle and handle:IsA("BasePart") then
                    local dist = (handle.Position - root.Position).Magnitude
                    if dist < 25 or Combat.Config.InfinitePickup then
                        -- Телепортируем пистолет прямо к персонажу
                        handle.CFrame = root.CFrame + Vector3.new(0, 1.5, 0)
                        task.wait(0.02)
                        -- Явно симулируем подбор
                        firetouchinterest(root, handle, 0)
                        firetouchinterest(root, handle, 1)
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- ================== Main Loop ==================
task.spawn(function()
    -- Обработчик клавиш
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Combat.Config.ShootKey then
            SimulateClick()
        elseif input.KeyCode == Combat.Config.PickupKey then
            PickupGun()
        end
    end)

    while task.wait(0.03) do
        pcall(function()
            local char = LocalPlayer.Character
            if not char or char:FindFirstChildOfClass("Humanoid").Health <= 0 then
                FOVFrame.Visible = false
                return
            end

            -- FOV circle
            FOVFrame.Size = UDim2.new(0, Combat.Config.FOV * 2, 0, Combat.Config.FOV * 2)
            FOVStroke.Transparency = Combat.Config.FOVTransparency
            FOVFrame.Visible = Combat.Config.AimEnabled

            -- ============== АИМБОТ ==============
            if Combat.Config.AimEnabled then
                if Combat.Config.AimMode == "Hacker" and IsLocalSheriff() then
                    local murderer = FindMurderer()
                    if murderer and murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart") then
                        local mRoot = murderer.Character.HumanoidRootPart
                        local mHead = murderer.Character:FindFirstChild("Head")
                        local behindPos = mRoot.Position - (mRoot.CFrame.LookVector * 15)
                        char:FindFirstChild("HumanoidRootPart").CFrame = CFrame.new(behindPos, mRoot.Position)
                        if mHead then
                            Camera.CFrame = CFrame.new(Camera.CFrame.Position, mHead.Position)
                        end
                        local tool = char:FindFirstChildOfClass("Tool")
                        if tool and (tool.Name == "Gun" or tool:FindFirstChild("Gun")) then
                            SimulateClick()
                        end
                    end
                else
                    local target = GetAimTarget()
                    local targetPos = target and target.Position
                    if targetPos and Combat.Config.Prediction > 0 then
                        local root = target.Parent and target.Parent:FindFirstChild("HumanoidRootPart")
                        if root then
                            targetPos += root.Velocity * (Combat.Config.Prediction / 1000)
                        end
                    end
                    if targetPos then
                        if Combat.Config.AimMode == "Static" then
                            Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
                        elseif Combat.Config.AimMode == "Smooth" or Combat.Config.AimMode == "Dynamic" then
                            SmoothAim(targetPos)
                        end
                    end
                    if Combat.Config.AutoShot and targetPos then
                        local tool = char:FindFirstChildOfClass("Tool")
                        if tool and (tool.Name == "Gun" or tool:FindFirstChild("Gun")) then
                            SimulateClick()
                        end
                    end
                end
            end

            -- ============== ТРИГГЕР-БОТ ==============
            if Combat.Config.TriggerBot then
                local mousePos = UserInputService:GetMouseLocation()
                local ray = Camera:ViewportPointToRay(mousePos.X, mousePos.Y)
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Blacklist
                params.FilterDescendantsInstances = {char}
                local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
                if result and result.Instance then
                    local hitPlayer = Players:GetPlayerFromCharacter(result.Instance.Parent)
                    if hitPlayer and hitPlayer ~= LocalPlayer and IsThreat(hitPlayer) then
                        SimulateClick()
                    end
                end
            end

            -- ============== АВТО‑ЭКИПИРОВКА ==============
            if Combat.Config.AutoEquipGun then
                local currentTool = char:FindFirstChildOfClass("Tool")
                if not currentTool or currentTool.Name ~= "Gun" then
                    local backpack = LocalPlayer:FindFirstChild("Backpack")
                    local gun = backpack and backpack:FindFirstChild("Gun")
                    if gun then
                        char:FindFirstChildOfClass("Humanoid"):EquipTool(gun)
                    end
                end
            end

            -- ============== АВТО‑ПОДБОР ПИСТОЛЕТА ==============
            if Combat.Config.AutoPickGun then
                PickupGun()
            end

            -- ============== ONE TAP KNIFE ==============
            if Combat.Config.OneTapKnife then
                local knife = char:FindFirstChild("Knife") or (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Knife"))
                if knife and knife:IsA("Tool") then
                    knife.GripPos = Vector3.new(0, 0, 0)
                end
            end

            -- ============== NO RECOIL ==============
            if Combat.Config.NoRecoil then
                local tool = char:FindFirstChildOfClass("Tool")
                if tool and tool:FindFirstChild("Gun") then
                    Camera.CFrame = Camera.CFrame
                end
            end

            -- ============== ANTI‑AIM ==============
            if Combat.Config.AntiAim then
                if char:FindFirstChild("Humanoid") then char.Humanoid.AutoRotate = false end
                local rootPart = char:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    rootPart.CFrame = rootPart.CFrame * CFrame.Angles(0, math.rad(15), 0)
                end
            else
                if char:FindFirstChild("Humanoid") then char.Humanoid.AutoRotate = true end
            end

            -- ============== FAKE LAG ==============
            if Combat.Config.FakeLag then
                local rootPart = char:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    rootPart.Anchored = true
                    task.wait(0.05)
                    rootPart.Anchored = false
                end
            end
        end)
    end
end)

-- ================== UI Init ==================
function Combat.Init(GlobalConfig, UI, Lang)
    local T = {
        RU = {
            Tab = "⚔️ Комбат",
            SecAim = "Аимбот",
            AimEnable = "Аимбот",
            AimMode = "Режим",
            Pred = "Упреждение",
            Smooth = "Сглаживание",
            FOV = "Радиус FOV",
            FOVTrans = "Прозрачность FOV",
            Trigger = "Триггер-бот",

            SecKeys = "Горячие клавиши",
            ShootKey = "Выстрел",
            PickupKey = "Подобрать пистолет",
            CurrentKey = "Текущая:",

            SecAuto = "Автоматизация",
            AutoEquip = "Авто-экипировка",
            AutoShot = "Авто-выстрел",
            AutoPick = "Авто-подбор",
            InfPickup = "Беск. подбор",
            OneTap = "One Tap Knife",

            SecMisc = "Прочее",
            NoRecoil = "Без отдачи",
            AntiAim = "Anti-Aim",
            FakeLag = "Fake Lag"
        },
        EN = {
            Tab = "⚔️ Combat",
            SecAim = "Aimbot",
            AimEnable = "Aimbot",
            AimMode = "Mode",
            Pred = "Prediction",
            Smooth = "Smoothness",
            FOV = "FOV Radius",
            FOVTrans = "FOV Transparency",
            Trigger = "Triggerbot",

            SecKeys = "Keybinds",
            ShootKey = "Shoot",
            PickupKey = "Pickup Gun",
            CurrentKey = "Current:",

            SecAuto = "Automation",
            AutoEquip = "Auto-Equip",
            AutoShot = "Auto-Shot",
            AutoPick = "Auto-Pick",
            InfPickup = "Infinite Pickup",
            OneTap = "One Tap Knife",

            SecMisc = "Misc",
            NoRecoil = "No Recoil",
            AntiAim = "Anti-Aim",
            FakeLag = "Fake Lag"
        }
    }

    local text = T[Lang] or T.RU
    local tab = UI:CreateTab(text.Tab)

    -- Aimbot Section
    tab:AddSection(text.SecAim)
    tab:AddToggle({ Title = text.AimEnable, Default = false, Callback = function(s) Combat.Config.AimEnabled = s end })
    tab:AddDropdown({
        Title = text.AimMode,
        Options = {"Static", "Dynamic", "Smooth", "Hacker"},
        Default = Combat.Config.AimMode,
        Callback = function(v) Combat.Config.AimMode = v end
    })
    tab:AddNumberInput({ Title = text.Pred, Min = 0, Max = 100, Default = Combat.Config.Prediction, Callback = function(v) Combat.Config.Prediction = v end })
    tab:AddNumberInput({ Title = text.Smooth, Min = 1, Max = 10, Default = Combat.Config.SmoothSpeed, Callback = function(v) Combat.Config.SmoothSpeed = v end })
    tab:AddNumberInput({ Title = text.FOV, Min = 30, Max = 500, Default = Combat.Config.FOV, Callback = function(v) Combat.Config.FOV = v end })
    tab:AddNumberInput({ Title = text.FOVTrans, Min = 0, Max = 1, Default = Combat.Config.FOVTransparency, Callback = function(v) Combat.Config.FOVTransparency = v end })
    tab:AddToggle({ Title = text.Trigger, Default = false, Callback = function(s) Combat.Config.TriggerBot = s end })

    -- Keybinds Section (customizable)
    tab:AddSection(text.SecKeys)

    -- Шутер бинд
    local shootLabel = tab:AddLabel(text.ShootKey .. " : " .. tostring(Combat.Config.ShootKey):gsub("Enum.KeyCode.", ""))
    tab:AddButton(text.ShootKey .. " (нажмите для смены)", function()
        local oldKey = Combat.Config.ShootKey
        shootLabel.Text = text.ShootKey .. " : ... (ожидание)"
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            conn:Disconnect()
            Combat.Config.ShootKey = input.KeyCode
            shootLabel.Text = text.ShootKey .. " : " .. tostring(input.KeyCode):gsub("Enum.KeyCode.", "")
        end)
        task.wait(3)
        if Combat.Config.ShootKey == oldKey then
            shootLabel.Text = text.ShootKey .. " : " .. tostring(oldKey):gsub("Enum.KeyCode.", "")
        end
    end)

    -- Пикап бинд
    local pickupLabel = tab:AddLabel(text.PickupKey .. " : " .. tostring(Combat.Config.PickupKey):gsub("Enum.KeyCode.", ""))
    tab:AddButton(text.PickupKey .. " (нажмите для смены)", function()
        local oldKey = Combat.Config.PickupKey
        pickupLabel.Text = text.PickupKey .. " : ... (ожидание)"
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            conn:Disconnect()
            Combat.Config.PickupKey = input.KeyCode
            pickupLabel.Text = text.PickupKey .. " : " .. tostring(input.KeyCode):gsub("Enum.KeyCode.", "")
        end)
        task.wait(3)
        if Combat.Config.PickupKey == oldKey then
            pickupLabel.Text = text.PickupKey .. " : " .. tostring(oldKey):gsub("Enum.KeyCode.", "")
        end
    end)

    -- Automation Section
    tab:AddSection(text.SecAuto)
    tab:AddToggle({ Title = text.AutoEquip, Default = false, Callback = function(s) Combat.Config.AutoEquipGun = s end })
    tab:AddToggle({ Title = text.AutoShot, Default = false, Callback = function(s) Combat.Config.AutoShot = s end })
    tab:AddToggle({ Title = text.AutoPick, Default = false, Callback = function(s) Combat.Config.AutoPickGun = s end })
    tab:AddToggle({ Title = text.InfPickup, Default = false, Callback = function(s) Combat.Config.InfinitePickup = s end })
    tab:AddToggle({ Title = text.OneTap, Default = false, Callback = function(s) Combat.Config.OneTapKnife = s end })

    -- Misc Section
    tab:AddSection(text.SecMisc)
    tab:AddToggle({ Title = text.NoRecoil, Default = false, Callback = function(s) Combat.Config.NoRecoil = s end })
    tab:AddToggle({ Title = text.AntiAim, Default = false, Callback = function(s) Combat.Config.AntiAim = s end })
    tab:AddToggle({ Title = text.FakeLag, Default = false, Callback = function(s) Combat.Config.FakeLag = s end })
end

return Combat
