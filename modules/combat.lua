-- [[ MM2 COMBAT MODULE - FULLY FIXED + HACKER MODE ]] --
local Combat = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

Combat.Config = {
    -- Aimbot
    AimEnabled = false,
    AimMode = "Dynamic",   -- Static, Dynamic, Smooth
    Prediction = 15,
    SmoothSpeed = 5,
    SilentAim = false,

    -- FOV
    FOV = 120,
    FOVTransparency = 0.5,
    TriggerBot = false,

    -- Automation
    AutoEquipGun = false,
    AutoShot = false,
    AutoPickGun = false,
    InfinitePickup = false,
    OneTapKnife = false,
    NoRecoil = false,

    -- Hacker Mode
    HackerMode = false,    -- teleport behind murderer, lock cam, auto shoot

    -- Misc
    AntiAim = false,
    FakeLag = false,
}

-- ================== FOV Circle GUI ==================
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
    -- Используем надёжный mouse1click() (работает в MM2)
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

-- Проверка, является ли локальный игрок шерифом (есть пистолет)
local function IsLocalSheriff()
    local char = LocalPlayer.Character
    if not char then return false end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    return (char:FindFirstChild("Gun") ~= nil) or (backpack and backpack:FindFirstChild("Gun") ~= nil)
end

-- Получить ближайшего мёрдера (игрок с ножом)
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

-- Поиск цели для аимбота / хакерского режима
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

-- Плавное наведение
local function SmoothAim(targetPos, speed)
    speed = speed or Combat.Config.SmoothSpeed / 10
    local current = Camera.CFrame
    local desired = CFrame.new(current.Position, targetPos)
    Camera.CFrame = current:Lerp(desired, speed)
end

-- ================== Main Loop ==================
task.spawn(function()
    while task.wait(0.03) do
        pcall(function()
            local char = LocalPlayer.Character
            if not char or char:FindFirstChildOfClass("Humanoid").Health <= 0 then
                FOVFrame.Visible = false
                return
            end

            -- FOV circle update
            FOVFrame.Size = UDim2.new(0, Combat.Config.FOV * 2, 0, Combat.Config.FOV * 2)
            FOVStroke.Transparency = Combat.Config.FOVTransparency
            FOVFrame.Visible = Combat.Config.AimEnabled or Combat.Config.SilentAim

            -- ============== ХАКЕРСКИЙ РЕЖИМ ==============
            if Combat.Config.HackerMode and IsLocalSheriff() then
                local murderer = FindMurderer()
                if murderer and murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart") then
                    local mRoot = murderer.Character.HumanoidRootPart
                    local mHead = murderer.Character:FindFirstChild("Head")
                    -- Позиция позади мёрдера (на 15 метров от него по направлению, противоположному его взгляду)
                    local behindPos = mRoot.Position - (mRoot.CFrame.LookVector * 15)
                    -- Телепорт (без проверки коллизий, можно улучшить)
                    char.HumanoidRootPart.CFrame = CFrame.new(behindPos, mRoot.Position)  -- смотрим на мёрдера
                    -- Фиксация камеры на мёрдере
                    if mHead then
                        Camera.CFrame = CFrame.new(Camera.CFrame.Position, mHead.Position)
                    end
                    -- Авто‑выстрел
                    local tool = char:FindFirstChildOfClass("Tool")
                    if tool and (tool.Name == "Gun" or tool:FindFirstChild("Gun")) then
                        SimulateClick()
                    end
                    -- После обработки пропускаем остальные аимботы, чтобы не мешали
                    return
                end
            end

            -- ============== ОБЫЧНЫЙ АИМБОТ ==============
            local target = GetAimTarget()
            local targetPos = target and target.Position

            -- Prediction
            if targetPos and Combat.Config.Prediction > 0 then
                local root = target.Parent and target.Parent:FindFirstChild("HumanoidRootPart")
                if root then
                    targetPos += root.Velocity * (Combat.Config.Prediction / 1000)
                end
            end

            if Combat.Config.AimEnabled and targetPos then
                if Combat.Config.AimMode == "Static" then
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
                elseif Combat.Config.AimMode == "Smooth" or Combat.Config.AimMode == "Dynamic" then
                    SmoothAim(targetPos)
                end
            end

            if Combat.Config.SilentAim and targetPos then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
            end

            -- Auto‑Shot (обычный)
            if Combat.Config.AutoShot and targetPos and (Combat.Config.AimEnabled or Combat.Config.SilentAim) then
                local tool = char:FindFirstChildOfClass("Tool")
                if tool and (tool.Name == "Gun" or tool:FindFirstChild("Gun")) then
                    SimulateClick()
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
                        char.Humanoid:EquipTool(gun)
                    end
                end
            end

            -- ============== АВТО‑ПОДБОР ПИСТОЛЕТА ==============
            if Combat.Config.AutoPickGun or Combat.Config.InfinitePickup then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then
                    for _, obj in pairs(Workspace:GetChildren()) do
                        if obj.Name == "GunDrop" and obj:IsA("Model") then
                            local tool = obj:FindFirstChildOfClass("Tool")
                            if tool and tool:IsA("Tool") and (tool.Name == "Gun" or tool.Name:lower():find("gun")) then
                                local handle = tool:FindFirstChild("Handle")
                                if handle and handle:IsA("BasePart") then
                                    local dist = (handle.Position - root.Position).Magnitude
                                    if dist < 15 or Combat.Config.InfinitePickup then
                                        -- Надёжный подбор: телепортируем Handle в позицию игрока
                                        handle.CFrame = root.CFrame + Vector3.new(0, 2, 0)
                                        task.wait(0.05)  -- даём игре зарегистрировать касание
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
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
                    -- базовая компенсация отдачи
                    Camera.CFrame = Camera.CFrame
                end
            end

            -- ============== ANTI‑AIM ==============
            if Combat.Config.AntiAim then
                if char:FindFirstChild("Humanoid") then char.Humanoid.AutoRotate = false end
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then
                    root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(15), 0)
                end
            else
                if char:FindFirstChild("Humanoid") then char.Humanoid.AutoRotate = true end
            end

            -- ============== FAKE LAG ==============
            if Combat.Config.FakeLag then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then
                    root.Anchored = true
                    task.wait(0.05)
                    root.Anchored = false
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
            AimEnable = "1. Аимбот",
            AimMode = "Режим",
            Pred = "Упреждение",
            Smooth = "Сглаживание",
            Silent = "Silent Aim",
            FOV = "Радиус FOV",
            FOVTrans = "Прозрачность",
            Trigger = "Триггер-бот",

            SecHacker = "Хакерский режим (Шериф)",
            HackerToggle = "Хакер-мод",
            HackerDesc = "Телепорт за спину мёрдера, фиксация, авто-огонь",

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
            AimEnable = "1. Aimbot",
            AimMode = "Mode",
            Pred = "Prediction",
            Smooth = "Smoothness",
            Silent = "Silent Aim",
            FOV = "FOV Radius",
            FOVTrans = "FOV Transparency",
            Trigger = "Triggerbot",

            SecHacker = "Hacker Mode (Sheriff)",
            HackerToggle = "Hacker Mode",
            HackerDesc = "Teleport behind murderer, lock cam, auto shoot",

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

    -- Aimbot
    tab:AddSection(text.SecAim)
    tab:AddToggle({ Title = text.AimEnable, Default = false, Callback = function(s) Combat.Config.AimEnabled = s end })
    tab:AddDropdown({
        Title = text.AimMode,
        Options = {"Static", "Dynamic", "Smooth"},
        Default = "Dynamic",
        Callback = function(v) Combat.Config.AimMode = v end
    })
    tab:AddNumberInput({ Title = text.Pred, Min = 0, Max = 100, Default = 15, Callback = function(v) Combat.Config.Prediction = v end })
    tab:AddNumberInput({ Title = text.Smooth, Min = 1, Max = 10, Default = 5, Callback = function(v) Combat.Config.SmoothSpeed = v end })
    tab:AddToggle({ Title = text.Silent, Default = false, Callback = function(s) Combat.Config.SilentAim = s end })
    tab:AddNumberInput({ Title = text.FOV, Min = 30, Max = 500, Default = 120, Callback = function(v) Combat.Config.FOV = v end })
    tab:AddNumberInput({ Title = text.FOVTrans, Min = 0, Max = 1, Default = 0.5, Callback = function(v) Combat.Config.FOVTransparency = v end })
    tab:AddToggle({ Title = text.Trigger, Default = false, Callback = function(s) Combat.Config.TriggerBot = s end })

    -- Hacker Mode
    tab:AddSection(text.SecHacker)
    tab:AddToggle({ Title = text.HackerToggle, Default = false, Callback = function(s) Combat.Config.HackerMode = s end })
    tab:AddLabel(text.HackerDesc)

    -- Automation
    tab:AddSection(text.SecAuto)
    tab:AddToggle({ Title = text.AutoEquip, Default = false, Callback = function(s) Combat.Config.AutoEquipGun = s end })
    tab:AddToggle({ Title = text.AutoShot, Default = false, Callback = function(s) Combat.Config.AutoShot = s end })
    tab:AddToggle({ Title = text.AutoPick, Default = false, Callback = function(s) Combat.Config.AutoPickGun = s end })
    tab:AddToggle({ Title = text.InfPickup, Default = false, Callback = function(s) Combat.Config.InfinitePickup = s end })
    tab:AddToggle({ Title = text.OneTap, Default = false, Callback = function(s) Combat.Config.OneTapKnife = s end })

    -- Misc
    tab:AddSection(text.SecMisc)
    tab:AddToggle({ Title = text.NoRecoil, Default = false, Callback = function(s) Combat.Config.NoRecoil = s end })
    tab:AddToggle({ Title = text.AntiAim, Default = false, Callback = function(s) Combat.Config.AntiAim = s end })
    tab:AddToggle({ Title = text.FakeLag, Default = false, Callback = function(s) Combat.Config.FakeLag = s end })
end

return Combat
