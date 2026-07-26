-- [[ MM2 COMBAT MODULE - FULL RELIABLE EDITION ]] --
local Combat = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

Combat.Config = {
    -- Аимбот
    AimEnabled = false,
    AimMode = "Dynamic", -- Static, Dynamic, Pro, Hacker, Smooth
    Prediction = 15,
    SmoothSpeed = 5,
    SilentAim = false,
    
    -- Дистанция и Наводка
    HackerDistance = 500,
    FOV = 120,
    FOVTransparency = 0.5,
    TriggerBot = false,
    
    -- Автоматизация
    AutoEquipGun = false,
    AutoShot = false,
    AutoPickGun = false,
    InfinitePickup = false,
    OneTapKnife = false,
    
    -- Прочее
    AntiAim = false,
    FakeLag = false,
    NoRecoil = false
}

-- Создаем кружок FOV на экране
local FOVGui = Instance.new("ScreenGui")
FOVGui.Name = "PurpleFox_FOV"
FOVGui.ResetOnSpawn = false
pcall(function() FOVGui.Parent = CoreGui end)
if not FOVGui.Parent then FOVGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local FOVFrame = Instance.new("Frame", FOVGui)
FOVFrame.Name = "FOVCircle"
FOVFrame.BackgroundTransparency = 1
FOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)
FOVFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
FOVFrame.Visible = false

local UICorner = Instance.new("UICorner", FOVFrame)
UICorner.CornerRadius = UDim.new(1, 0)

local UIStroke = Instance.new("UIStroke", FOVFrame)
UIStroke.Thickness = 1.5
UIStroke.Color = Color3.fromRGB(160, 32, 240)

-- Функция поиска ближайшей цели (Murderer или Sheriff)
local function GetTarget()
    local bestTarget = nil
    local shortestDist = Combat.Config.FOV

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            local head = char:FindFirstChild("Head")
            
            if hum and hum.Health > 0 and head then
                -- Проверка роли (если цель - Murderer или Sheriff)
                local backpack = player:FindFirstChild("Backpack")
                local isThreat = (backpack and (backpack:FindFirstChild("Knife") or backpack:FindFirstChild("Gun"))) or 
                                 char:FindFirstChild("Knife") or char:FindFirstChild("Gun")
                
                if isThreat or Combat.Config.AimMode == "Hacker" then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local mousePos = UserInputService:GetMouseLocation()
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        
                        if dist < shortestDist then
                            shortestDist = dist
                            bestTarget = head
                        end
                    end
                end
            end
        end
    end
    return bestTarget
end

-- Основной боевой цикл
task.spawn(function()
    while task.wait(0.03) do
        pcall(function()
            -- Обновление FOV круга
            FOVFrame.Visible = Combat.Config.AimEnabled or Combat.Config.SilentAim
            FOVFrame.Size = UDim2.new(0, Combat.Config.FOV * 2, 0, Combat.Config.FOV * 2)
            UIStroke.Transparency = Combat.Config.FOVTransparency

            -- 1. Аимбот и Silent Aim
            if Combat.Config.AimEnabled or Combat.Config.SilentAim then
                local target = GetTarget()
                if target then
                    local targetPos = target.Position
                    
                    -- Упреждение (Prediction)
                    if Combat.Config.Prediction > 0 and target.Parent and target.Parent:FindFirstChild("HumanoidRootPart") then
                        local root = target.Parent.HumanoidRootPart
                        targetPos = targetPos + (root.Velocity * (Combat.Config.Prediction / 1000))
                    end

                    if Combat.Config.AimEnabled and not Combat.Config.SilentAim then
                        if Combat.Config.AimMode == "Static" then
                            Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
                        elseif Combat.Config.AimMode == "Smooth" or Combat.Config.AimMode == "Dynamic" then
                            Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, targetPos), Combat.Config.SmoothSpeed / 10)
                        end
                    end
                end
            end

            -- 2. Авто-экипировка пистолета (если есть в инвентаре)
            if Combat.Config.AutoEquipGun and LocalPlayer.Character then
                local backpack = LocalPlayer:FindFirstChild("Backpack")
                local gun = backpack and backpack:FindFirstChild("Gun")
                if gun then
                    LocalPlayer.Character.Humanoid:EquipTool(gun)
                end
            end

            -- 3. Авто-подбор упавшего пистолета
            if Combat.Config.AutoPickGun then
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj.Name:lower():find("gundrop") or obj.Name:lower():find("gun") then
                        if obj:IsA("BasePart") and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            local myRoot = LocalPlayer.Character.HumanoidRootPart
                            local dist = (obj.Position - myRoot.Position).Magnitude
                            
                            if dist < 15 or Combat.Config.InfinitePickup then
                                firetouchinterest(myRoot, obj, 0)
                                firetouchinterest(myRoot, obj, 1)
                            end
                        end
                    end
                end
            end

            -- 4. Триггер-бот (Автовыстрел при наведении)
            if Combat.Config.TriggerBot then
                local mouse = LocalPlayer:GetMouse()
                local target = mouse.Target
                if target and target.Parent then
                    local p = Players:GetPlayerFromCharacter(target.Parent)
                    if p and p ~= LocalPlayer then
                        mouse1click()
                    end
                end
            end

            -- 5. One Tap Ножом (Мгновенный удар)
            if Combat.Config.OneTapKnife and LocalPlayer.Character then
                local knife = LocalPlayer.Character:FindFirstChild("Knife") or (LocalPlayer:FindFirstChild("Backpack") and LocalPlayer.Backpack:FindFirstChild("Knife"))
                if knife then
                    knife.GripPos = Vector3.new(0, 0, 0) -- Сокращаем дистанцию урона ножа до максимума
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
            Pred = "3. Упреждение / Предсказание (%)",
            Smooth = "4. Скорость сглаживания (Smooth)",
            Silent = "5. Silent Aim (Без поворота камеры)",
            FOV = "6. Радиус FOV круга",
            FOVTrans = "7. Прозрачность FOV",
            Trigger = "8. Триггер-бот (Автовыстрел)",

            SecAuto = "Автоматизация и Лут",
            AutoEquip = "9. Авто-экипировка пистолета",
            AutoShot = "10. Авто-выстрел по цели",
            AutoPick = "11. Авто-подбор пистолета",
            InfPickup = "12. Бесконечная дистанция подбора",
            OneTap = "13. One Tap Knife (Быстрый нож)",

            SecMisc = "Дополнительно",
            AntiAim = "14. Anti-Aim (Уклонение)",
            FakeLag = "15. Fake Lag (Симуляция лагов)",
            NoRecoil = "16. Безоткатный выстрел"
        },
        EN = {
            Tab = "⚔️ Combat",
            SecAim = "Aimbot",
            AimEnable = "1. Enable Aimbot",
            AimMode = "2. Aimbot Mode",
            Pred = "3. Prediction",
            Smooth = "4. Smooth Speed",
            Silent = "5. Silent Aim",
            FOV = "6. FOV Radius",
            FOVTrans = "7. FOV Transparency",
            Trigger = "8. Triggerbot",

            SecAuto = "Automation",
            AutoEquip = "9. Auto-Equip Gun",
            AutoShot = "10. Auto-Shot",
            AutoPick = "11. Auto-Pick Gun",
            InfPickup = "12. Infinite Pickup Range",
            OneTap = "13. One Tap Knife",

            SecMisc = "Misc",
            AntiAim = "14. Anti-Aim",
            FakeLag = "15. Fake Lag",
            NoRecoil = "16. No Recoil"
        }
    }

    local text = T[Lang] or T.RU
    local CombatTab = UI:CreateTab(text.Tab)

    -- Секция 1: Аимбот
    CombatTab:AddSection(text.SecAim)
    CombatTab:AddToggle({ Title = text.AimEnable, Default = Combat.Config.AimEnabled, Callback = function(s) Combat.Config.AimEnabled = s end })
    
    CombatTab:AddDropdown({
        Title = text.AimMode,
        Options = {"Static", "Dynamic", "Pro", "Hacker", "Smooth"},
        Default = Combat.Config.AimMode,
        Callback = function(val) Combat.Config.AimMode = val end
    })

    CombatTab:AddNumberInput({ Title = text.Pred, Min = 0, Max = 100, Default = Combat.Config.Prediction, Callback = function(v) Combat.Config.Prediction = v end })
    CombatTab:AddNumberInput({ Title = text.Smooth, Min = 1, Max = 10, Default = Combat.Config.SmoothSpeed, Callback = function(v) Combat.Config.SmoothSpeed = v end })
    CombatTab:AddToggle({ Title = text.Silent, Default = Combat.Config.SilentAim, Callback = function(s) Combat.Config.SilentAim = s end })
    
    CombatTab:AddNumberInput({ Title = text.FOV, Min = 30, Max = 400, Default = Combat.Config.FOV, Callback = function(v) Combat.Config.FOV = v end })
    CombatTab:AddNumberInput({ Title = text.FOVTrans, Min = 0, Max = 1, Default = Combat.Config.FOVTransparency, Callback = function(v) Combat.Config.FOVTransparency = v end })
    CombatTab:AddToggle({ Title = text.Trigger, Default = Combat.Config.TriggerBot, Callback = function(s) Combat.Config.TriggerBot = s end })

    -- Секция 2: Автоматизация
    CombatTab:AddSection(text.SecAuto)
    CombatTab:AddToggle({ Title = text.AutoEquip, Default = Combat.Config.AutoEquipGun, Callback = function(s) Combat.Config.AutoEquipGun = s end })
    CombatTab:AddToggle({ Title = text.AutoShot, Default = Combat.Config.AutoShot, Callback = function(s) Combat.Config.AutoShot = s end })
    CombatTab:AddToggle({ Title = text.AutoPick, Default = Combat.Config.AutoPickGun, Callback = function(s) Combat.Config.AutoPickGun = s end })
    CombatTab:AddToggle({ Title = text.InfPickup, Default = Combat.Config.InfinitePickup, Callback = function(s) Combat.Config.InfinitePlayer = s end })
    CombatTab:AddToggle({Title = text.OneTap, Default = Combat.Config.OneTapKnife, Callback = function(s) Combat.Config.OneTapKnife = s end })

    -- Секция 3: Дополнительно
    CombatTab:AddSection(text.SecMisc)
    CombatTab:AddToggle({ Title = text.AntiAim, Default = Combat.Config.AntiAim, Callback = function(s) Combat.Config.AntiAim = s end })
    CombatTab:AddToggle({ Title = text.FakeLag, Default = Combat.Config.FakeLag, Callback = function(s) Combat.Config.FakeLag = s end })
    CombatTab:AddToggle({ Title = text.NoRecoil, Default = Combat.Config.NoRecoil, Callback = function(s) Combat.Config.NoRecoil = s end })
end

return Combat
