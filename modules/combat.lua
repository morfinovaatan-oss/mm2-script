-- [[ MM2 COMBAT MODULE - ENHANCED & RELIABLE (AutoPick fix) ]] --
local Combat = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

Combat.Config = {
    AimEnabled = false,
    AimMode = "Dynamic",
    Prediction = 15,
    SmoothSpeed = 5,
    SilentAim = false,
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
}

-- FOV circle GUI (без изменений)
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
local FOVCorner = Instance.new("UICorner", FOVFrame)
FOVCorner.CornerRadius = UDim.new(1, 0)
local FOVStroke = Instance.new("UIStroke", FOVFrame)
FOVStroke.Thickness = 1.5
FOVStroke.Color = Color3.fromRGB(160, 32, 240)

local function SimulateClick()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    task.wait(0.02)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
end

local function IsThreat(player)
    if player == LocalPlayer then return false end
    local char = player.Character
    if not char then return false end
    local backpack = player:FindFirstChild("Backpack")
    local hasKnife = (char:FindFirstChild("Knife") ~= nil) or (backpack and backpack:FindFirstChild("Knife"))
    local hasGun = (char:FindFirstChild("Gun") ~= nil) or (backpack and backpack:FindFirstChild("Gun"))
    return hasKnife or hasGun
end

local function GetTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local bestTarget = nil
    local closestDist = Combat.Config.FOV

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            local head = char:FindFirstChild("Head")
            if hum and hum.Health > 0 and head and IsThreat(player) then
                local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        bestTarget = head
                    end
                end
            end
        end
    end
    return bestTarget
end

local function SmoothAim(targetPos, speed)
    speed = speed or Combat.Config.SmoothSpeed / 10
    local currentCF = Camera.CFrame
    local desiredCF = CFrame.new(currentCF.Position, targetPos)
    Camera.CFrame = currentCF:Lerp(desiredCF, speed)
end

local function InstantAim(targetPos)
    Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
end

local function SilentAimSnap(targetPos)
    Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
end

-- Основной цикл
task.spawn(function()
    while task.wait(0.03) do
        pcall(function()
            if not LocalPlayer.Character or LocalPlayer.Character:FindFirstChildOfClass("Humanoid").Health <= 0 then
                FOVFrame.Visible = false
                return
            end

            FOVFrame.Size = UDim2.new(0, Combat.Config.FOV * 2, 0, Combat.Config.FOV * 2)
            FOVStroke.Transparency = Combat.Config.FOVTransparency
            FOVFrame.Visible = Combat.Config.AimEnabled or Combat.Config.SilentAim

            local target = GetTarget()
            local targetPos = target and target.Position

            if targetPos and Combat.Config.Prediction > 0 then
                local root = target.Parent and target.Parent:FindFirstChild("HumanoidRootPart")
                if root then
                    targetPos = targetPos + (root.Velocity * (Combat.Config.Prediction / 1000))
                end
            end

            if Combat.Config.AimEnabled and targetPos then
                if Combat.Config.AimMode == "Static" then
                    InstantAim(targetPos)
                elseif Combat.Config.AimMode == "Smooth" or Combat.Config.AimMode == "Dynamic" then
                    SmoothAim(targetPos, Combat.Config.SmoothSpeed / 10)
                end
            end

            if Combat.Config.SilentAim and targetPos then
                SilentAimSnap(targetPos)
            end

            if Combat.Config.AutoShot and targetPos and (Combat.Config.AimEnabled or Combat.Config.SilentAim) then
                local equippedTool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                if equippedTool and (equippedTool.Name == "Gun" or equippedTool:FindFirstChild("Gun")) then
                    SimulateClick()
                end
            end

            -- Триггер-бот через Raycast
            if Combat.Config.TriggerBot then
                local mousePos = UserInputService:GetMouseLocation()
                local ray = Camera:ViewportPointToRay(mousePos.X, mousePos.Y)
                local raycastParams = RaycastParams.new()
                raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
                local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)
                if result and result.Instance then
                    local hitPlayer = Players:GetPlayerFromCharacter(result.Instance.Parent)
                    if hitPlayer and hitPlayer ~= LocalPlayer and IsThreat(hitPlayer) then
                        SimulateClick()
                    end
                end
            end

            -- Авто-экипировка
            if Combat.Config.AutoEquipGun then
                local char = LocalPlayer.Character
                if char then
                    local currentTool = char:FindFirstChildOfClass("Tool")
                    if not currentTool or currentTool.Name ~= "Gun" then
                        local backpack = LocalPlayer:FindFirstChild("Backpack")
                        local gun = backpack and backpack:FindFirstChild("Gun")
                        if gun then
                            char.Humanoid:EquipTool(gun)
                        end
                    end
                end
            end

            -- ===== ИСПРАВЛЕННЫЙ АВТО‑ПОДБОР =====
            if Combat.Config.AutoPickGun or Combat.Config.InfinitePickup then
                local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    -- Ищем только выпавшие пистолеты (модель GunDrop)
                    for _, drop in pairs(Workspace:GetChildren()) do
                        if drop.Name == "GunDrop" and drop:IsA("Model") then
                            local tool = drop:FindFirstChildOfClass("Tool")
                            if tool and tool:IsA("Tool") and (tool.Name == "Gun" or tool.Name:lower():find("gun")) then
                                local handle = tool:FindFirstChild("Handle")
                                if handle and handle:IsA("BasePart") then
                                    local dist = (handle.Position - root.Position).Magnitude
                                    if dist < 15 or Combat.Config.InfinitePickup then
                                        -- Безопасный подбор через касание
                                        firetouchinterest(root, handle, 0)
                                        firetouchinterest(root, handle, 1)
                                        break  -- подбираем один за цикл
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- One Tap Knife
            if Combat.Config.OneTapKnife then
                local knife = LocalPlayer.Character and (LocalPlayer.Character:FindFirstChild("Knife") or
                    (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Knife")))
                if knife and knife:IsA("Tool") then
                    knife.GripPos = Vector3.new(0, 0, 0)
                end
            end

            -- NoRecoil
            if Combat.Config.NoRecoil then
                local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                if tool and tool:FindFirstChild("Gun") then
                    -- Базовая блокировка отдачи
                    Camera.CFrame = Camera.CFrame
                end
            end

            -- Anti-Aim
            if Combat.Config.AntiAim then
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    char.Humanoid.AutoRotate = false
                    local root = char.HumanoidRootPart
                    root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(15), 0)
                end
            else
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                    LocalPlayer.Character.Humanoid.AutoRotate = true
                end
            end

            -- FakeLag
            if Combat.Config.FakeLag then
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    char.HumanoidRootPart.Anchored = true
                    task.wait(0.05)
                    char.HumanoidRootPart.Anchored = false
                end
            end
        end)
    end
end)

function Combat.Init(GlobalConfig, UI, Lang)
    local T = {
        RU = {
            Tab = "⚔️ Комбат",
            SecAim = "Аимбот и Наводка",
            AimEnable = "1. Включить Аимбот",
            AimMode = "2. Режим Аимбота",
            Pred = "3. Упреждение (%)",
            Smooth = "4. Сглаживание (1‑10)",
            Silent = "5. Silent Aim (эксперим.)",
            FOV = "6. Радиус FOV",
            FOVTrans = "7. Прозрачность FOV",
            Trigger = "8. Триггер‑бот",
            SecAuto = "Автоматизация",
            AutoEquip = "9. Авто‑экипировка",
            AutoShot = "10. Авто‑выстрел",
            AutoPick = "11. Авто‑подбор пистолета",
            InfPickup = "12. Бесконечный подбор",
            OneTap = "13. One Tap Knife",
            SecMisc = "Дополнительно",
            NoRecoil = "14. Без отдачи",
            AntiAim = "15. Anti‑Aim",
            FakeLag = "16. Fake Lag"
        },
        EN = {
            Tab = "⚔️ Combat",
            SecAim = "Aimbot & Targeting",
            AimEnable = "1. Enable Aimbot",
            AimMode = "2. Aimbot Mode",
            Pred = "3. Prediction",
            Smooth = "4. Smooth Speed",
            Silent = "5. Silent Aim (exp.)",
            FOV = "6. FOV Radius",
            FOVTrans = "7. FOV Transparency",
            Trigger = "8. Triggerbot",
            SecAuto = "Automation",
            AutoEquip = "9. Auto‑Equip Gun",
            AutoShot = "10. Auto‑Shot",
            AutoPick = "11. Auto‑Pick Gun",
            InfPickup = "12. Infinite Pickup",
            OneTap = "13. One Tap Knife",
            SecMisc = "Misc",
            NoRecoil = "14. No Recoil",
            AntiAim = "15. Anti‑Aim",
            FakeLag = "16. Fake Lag"
        }
    }

    local text = T[Lang] or T.RU
    local CombatTab = UI:CreateTab(text.Tab)

    CombatTab:AddSection(text.SecAim)
    CombatTab:AddToggle({ Title = text.AimEnable, Default = false, Callback = function(s) Combat.Config.AimEnabled = s end })
    CombatTab:AddDropdown({
        Title = text.AimMode,
        Options = {"Static", "Dynamic", "Smooth"},
        Default = Combat.Config.AimMode,
        Callback = function(val) Combat.Config.AimMode = val end
    })
    CombatTab:AddNumberInput({ Title = text.Pred, Min = 0, Max = 100, Default = Combat.Config.Prediction, Callback = function(v) Combat.Config.Prediction = v end })
    CombatTab:AddNumberInput({ Title = text.Smooth, Min = 1, Max = 10, Default = Combat.Config.SmoothSpeed, Callback = function(v) Combat.Config.SmoothSpeed = v end })
    CombatTab:AddToggle({ Title = text.Silent, Default = false, Callback = function(s) Combat.Config.SilentAim = s end })
    CombatTab:AddNumberInput({ Title = text.FOV, Min = 30, Max = 400, Default = Combat.Config.FOV, Callback = function(v) Combat.Config.FOV = v end })
    CombatTab:AddNumberInput({ Title = text.FOVTrans, Min = 0, Max = 1, Default = Combat.Config.FOVTransparency, Callback = function(v) Combat.Config.FOVTransparency = v end })
    CombatTab:AddToggle({ Title = text.Trigger, Default = false, Callback = function(s) Combat.Config.TriggerBot = s end })

    CombatTab:AddSection(text.SecAuto)
    CombatTab:AddToggle({ Title = text.AutoEquip, Default = false, Callback = function(s) Combat.Config.AutoEquipGun = s end })
    CombatTab:AddToggle({ Title = text.AutoShot, Default = false, Callback = function(s) Combat.Config.AutoShot = s end })
    CombatTab:AddToggle({ Title = text.AutoPick, Default = false, Callback = function(s) Combat.Config.AutoPickGun = s end })
    CombatTab:AddToggle({ Title = text.InfPickup, Default = false, Callback = function(s) Combat.Config.InfinitePickup = s end })
    CombatTab:AddToggle({ Title = text.OneTap, Default = false, Callback = function(s) Combat.Config.OneTapKnife = s end })

    CombatTab:AddSection(text.SecMisc)
    CombatTab:AddToggle({ Title = text.NoRecoil, Default = false, Callback = function(s) Combat.Config.NoRecoil = s end })
    CombatTab:AddToggle({ Title = text.AntiAim, Default = false, Callback = function(s) Combat.Config.AntiAim = s end })
    CombatTab:AddToggle({ Title = text.FakeLag, Default = false, Callback = function(s) Combat.Config.FakeLag = s end })
end

return Combat
