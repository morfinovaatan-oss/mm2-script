-- [[ MM2 COMBAT MODULE – Silent Aim Camera Snap + Full Arsenal ]] --
local Combat = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local StarterGui = game:GetService("StarterGui")

Combat.Config = {
    -- Аимбот
    AimEnabled = false,
    AimMode = "Dynamic",        -- Static, Dynamic, Smooth, Hacker, Silent
    FOVCenter = "Mouse",        -- "Mouse" или "Camera"
    Prediction = 15,
    SmoothSpeed = 5,            -- 1-10, чем выше, тем резче поворот камеры
    FOV = 120,
    FOVTransparency = 0.5,
    TriggerBot = false,
    AutoShiftLock = true,       -- автоматически включать Shift Lock при захвате цели

    -- Настройки Hacker Mode
    HackerDistance = 15,

    -- Автоматизация
    AutoEquipGun = false,
    AutoShot = false,
    InstantGunPickup = false,
    OneTapKnife = false,
    NoRecoil = false,
    AntiAim = false,
    FakeLag = false,

    -- Бинды
    ShootKey = Enum.KeyCode.C,
    PickupKey = Enum.KeyCode.R,
    FindMurdererKey = Enum.KeyCode.Z,
    FindSheriffKey = Enum.KeyCode.X,
    AutoNotifyPickup = true,
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

-- ================== Состояния и кэш ==================
local bodyVelocity = nil
local hackerActive = false
local lastShotTime = 0
local SHOT_COOLDOWN = 0.5
local pickedUpThisRound = false
local shiftLockActive = false

-- ================== Helpers ==================
local function SimulateClick()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    task.wait(0.02)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
end

local function enableShiftLock()
    if shiftLockActive then return end
    if not Combat.Config.AutoShiftLock then return end
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
    if Combat.Config.FOVCenter == "Camera" then
        centerPoint = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    else
        centerPoint = UserInputService:GetMouseLocation()
    end

    local best = nil
    local bestDist = Combat.Config.FOV
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local head = p.Character:FindFirstChild("Head")
            if hum and hum.Health > 0 and head and IsThreat(p) then
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
    speed = speed or Combat.Config.SmoothSpeed / 10
    local current = Camera.CFrame
    local desired = CFrame.new(current.Position, targetPos)
    Camera.CFrame = current:Lerp(desired, speed)
end

-- ================== Поиск карты ==================
local function getMap()
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v.Name == "Spawns" and v.Parent.Name ~= "Lobby" then
            return v.Parent
        end
    end
    return nil
end

-- ================== Мгновенный подбор пистолета ==================
local function performInstantPickup(gunDrop)
    if not gunDrop then return end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local root = char.HumanoidRootPart
    local savedPos = root.CFrame

    root.CFrame = gunDrop:GetPivot() + Vector3.new(0, 1.5, 0)
    task.wait(0.02)
    firetouchinterest(root, gunDrop, 0)
    firetouchinterest(root, gunDrop, 1)
    task.wait(0.05)

    if char and char:FindFirstChild("HumanoidRootPart") then
        root.CFrame = savedPos
    end
    pickedUpThisRound = true
end

local function notifyGunDrop(gunDrop)
    if not Combat.Config.AutoNotifyPickup then return end
    local cb = Instance.new("BindableFunction")
    cb.OnInvoke = function(arg)
        if arg == "Get gun!" and gunDrop.Parent then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("Head") then
                gunDrop.CFrame = CFrame.new(char.Head.Position)
            end
        end
    end
    StarterGui:SetCore("SendNotification", {
        Title = "The sheriff has died!",
        Text = "Grab their gun?",
        Duration = 5,
        Button1 = "Dismiss",
        Button2 = "Get gun!",
        Callback = cb
    })
end

workspace.DescendantAdded:Connect(function(descendant)
    if descendant.Name == "GunDrop" then
        notifyGunDrop(descendant)
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    pickedUpThisRound = false
    if shiftLockActive then disableShiftLock() end
end)

-- ================== Управление BodyVelocity ==================
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

-- ================== Единый Heartbeat ==================
local heartbeatConnection
local function startHeartbeat()
    if heartbeatConnection then return end
    heartbeatConnection = RunService.Heartbeat:Connect(function()
        pcall(function()
            local char = LocalPlayer.Character
            if not char or char:FindFirstChildOfClass("Humanoid").Health <= 0 then
                if hackerActive then
                    hackerActive = false
                    disableAntiGravity()
                end
                FOVFrame.Visible = false
                if shiftLockActive then disableShiftLock() end
                return
            end

            -- Если Silent Aim, FOV круг всегда скрыт
            if Combat.Config.AimMode == "Silent" and Combat.Config.AimEnabled then
                FOVFrame.Visible = false
            else
                FOVFrame.Size = UDim2.new(0, Combat.Config.FOV * 2, 0, Combat.Config.FOV * 2)
                FOVStroke.Transparency = Combat.Config.FOVTransparency
                FOVFrame.Visible = Combat.Config.AimEnabled
            end

            local hasGun = IsLocalSheriff()

            -- ШАГ 1: Мгновенный подбор пистолета (если нужно)
            if Combat.Config.InstantGunPickup and not pickedUpThisRound and not hasGun then
                local map = getMap()
                local gunDrop = map and map:FindFirstChild("GunDrop")
                if gunDrop then
                    performInstantPickup(gunDrop)
                    return
                end
            end

            -- ШАГ 2: Аимбот и Hacker Mode
            if Combat.Config.AimEnabled then
                if Combat.Config.AimMode == "Hacker" and hasGun then
                    -- Hacker Mode (камера фиксируется жёстко, Shift Lock не нужен)
                    hackerActive = true
                    if shiftLockActive then disableShiftLock() end
                    local murderer = FindMurderer()
                    if murderer and murderer.Character then
                        local mRoot = murderer.Character:FindFirstChild("HumanoidRootPart")
                        local mHead = murderer.Character:FindFirstChild("Head") or mRoot
                        if mRoot and mHead then
                            enableAntiGravity()

                            local behindPos = mRoot.Position - (mRoot.CFrame.LookVector * Combat.Config.HackerDistance)
                            behindPos = behindPos + Vector3.new(0, 2.5, 0)
                            char:PivotTo(CFrame.new(behindPos, mRoot.Position))

                            local rootPart = char.HumanoidRootPart
                            if rootPart then
                                rootPart.Velocity = Vector3.new(0, 0, 0)
                                rootPart.RotVelocity = Vector3.new(0, 0, 0)
                            end

                            local targetPos = mHead.Position
                            if Combat.Config.Prediction > 0 then
                                targetPos += mRoot.Velocity * (Combat.Config.Prediction / 1000)
                            end
                            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)

                            local tool = char:FindFirstChildOfClass("Tool")
                            if not tool or tool.Name ~= "Gun" then
                                if Combat.Config.AutoEquipGun then
                                    local backpack = LocalPlayer:FindFirstChild("Backpack")
                                    local gun = backpack and backpack:FindFirstChild("Gun")
                                    if gun and char:FindFirstChildOfClass("Humanoid") then
                                        char:FindFirstChildOfClass("Humanoid"):EquipTool(gun)
                                    end
                                end
                            end

                            if Combat.Config.AutoShot and (tick() - lastShotTime >= SHOT_COOLDOWN) then
                                local currentTool = char:FindFirstChildOfClass("Tool")
                                if currentTool and (currentTool.Name == "Gun" or currentTool:FindFirstChild("Gun")) then
                                    SimulateClick()
                                    lastShotTime = tick()
                                end
                            end
                        end
                    else
                        hackerActive = false
                        disableAntiGravity()
                    end
                elseif Combat.Config.AimMode == "Silent" then
                    -- Silent Aim: никакого FOV, поворота камеры или Shift Lock
                    hackerActive = false
                    disableAntiGravity()
                    disableShiftLock()
                    -- AutoShot в этом режиме не работает (стрельба только по кнопке)
                else
                    -- Стандартные режимы (Static, Dynamic, Smooth) с поворотом камеры и Shift Lock
                    hackerActive = false
                    disableAntiGravity()
                    local target = GetAimTarget()
                    local targetPos = target and target.Position
                    if targetPos then
                        enableShiftLock()

                        if Combat.Config.Prediction > 0 then
                            local root = target.Parent and target.Parent:FindFirstChild("HumanoidRootPart")
                            if root then
                                targetPos += root.Velocity * (Combat.Config.Prediction / 1000)
                            end
                        end

                        if Combat.Config.AimMode == "Static" then
                            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)
                        elseif Combat.Config.AimMode == "Smooth" or Combat.Config.AimMode == "Dynamic" then
                            SmoothAim(targetPos)
                        end

                        if Combat.Config.AutoShot and (tick() - lastShotTime >= SHOT_COOLDOWN) then
                            local tool = char:FindFirstChildOfClass("Tool")
                            if tool and (tool.Name == "Gun" or tool:FindFirstChild("Gun")) then
                                SimulateClick()
                                lastShotTime = tick()
                            end
                        end
                    else
                        disableShiftLock()
                    end
                end
            else
                hackerActive = false
                disableAntiGravity()
                disableShiftLock()
            end

            -- Триггер-бот (отключается при Silent)
            if Combat.Config.TriggerBot and Combat.Config.AimMode ~= "Silent" and (tick() - lastShotTime >= SHOT_COOLDOWN) then
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
                        lastShotTime = tick()
                    end
                end
            end

            -- One Tap Knife
            if Combat.Config.OneTapKnife then
                local knife = char:FindFirstChild("Knife") or (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Knife"))
                if knife and knife:IsA("Tool") then knife.GripPos = Vector3.new(0, 0, 0) end
            end

            -- No Recoil
            if Combat.Config.NoRecoil then
                local tool = char:FindFirstChildOfClass("Tool")
                if tool and tool:FindFirstChild("Gun") then Camera.CFrame = Camera.CFrame end
            end

            -- Anti-Aim
            if Combat.Config.AntiAim then
                if char:FindFirstChild("Humanoid") then char.Humanoid.AutoRotate = false end
                local rootPart = char:FindFirstChild("HumanoidRootPart")
                if rootPart then rootPart.CFrame = rootPart.CFrame * CFrame.Angles(0, math.rad(15), 0) end
            else
                if char:FindFirstChild("Humanoid") then char.Humanoid.AutoRotate = true end
            end

            -- Fake Lag
            if Combat.Config.FakeLag then
                local rootPart = char:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    rootPart.Anchored = true
                    task.wait(0.05)
                    rootPart.Anchored = false
                end
            end
        end)
    end)
end

startHeartbeat()

-- ================== Бинды клавиш (Silent Aim с мгновенным поворотом камеры) ==================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Combat.Config.ShootKey then
        -- Если включён Silent Aim и аимбот активен, выполняем специальный выстрел
        if Combat.Config.AimEnabled and Combat.Config.AimMode == "Silent" then
            local murderer = FindMurderer()
            if not murderer or not murderer.Character then
                SimulateClick()
                return
            end

            local torso = murderer.Character:FindFirstChild("UpperTorso") or murderer.Character:FindFirstChild("HumanoidRootPart")
            if not torso then
                SimulateClick()
                return
            end

            local targetPos = torso.Position
            local root = murderer.Character:FindFirstChild("HumanoidRootPart")
            if root and Combat.Config.Prediction > 0 then
                targetPos = targetPos + root.Velocity * (Combat.Config.Prediction / 1000)
            end

            -- Авто-экипировка пистолета, если включена
            if Combat.Config.AutoEquipGun then
                local char = LocalPlayer.Character
                if char then
                    local tool = char:FindFirstChildOfClass("Tool")
                    if not tool or tool.Name ~= "Gun" then
                        local backpack = LocalPlayer:FindFirstChild("Backpack")
                        local gun = backpack and backpack:FindFirstChild("Gun")
                        if gun and char:FindFirstChildOfClass("Humanoid") then
                            char:FindFirstChildOfClass("Humanoid"):EquipTool(gun)
                        end
                    end
                end
            end

            -- Убедимся, что в руках пистолет
            local char = LocalPlayer.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if not tool or (tool.Name ~= "Gun" and not tool:FindFirstChild("Gun")) then
                SimulateClick()
                return
            end

            -- Сохраняем текущее положение камеры
            local originalCFrame = Camera.CFrame
            -- Мгновенно поворачиваем камеру на цель
            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)
            task.wait(0.01)  -- даём игре применить новый CFrame
            SimulateClick()   -- производим выстрел
            task.wait(0.01)
            -- Возвращаем камеру обратно
            Camera.CFrame = originalCFrame
        else
            -- Обычный выстрел
            SimulateClick()
        end
    elseif input.KeyCode == Combat.Config.PickupKey then
        local map = getMap()
        local gunDrop = map and map:FindFirstChild("GunDrop")
        if gunDrop then
            performInstantPickup(gunDrop)
        end
    elseif input.KeyCode == Combat.Config.FindSheriffKey then
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
    elseif input.KeyCode == Combat.Config.FindMurdererKey then
        local murderer = FindMurderer()
        if murderer then
            local userId = Players:GetUserIdFromNameAsync(murderer.Name)
            StarterGui:SetCore("SendNotification", {
                Title = "Murderer",
                Text = "Their name is " .. murderer.Name .. "!",
                Icon = "https://web.roblox.com/Thumbs/Avatar.ashx?x=100&y=100&Format=Png&userid=" .. userId,
                Duration = 5,
                Button1 = "Dismiss",
            })
        else
            StarterGui:SetCore("SendNotification", {
                Title = "Murderer",
                Text = "No murderer could be found!",
                Duration = 5,
                Button1 = "Dismiss",
            })
        end
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
            FOVCenter = "Центр FOV",
            Pred = "Упреждение",
            Smooth = "Сглаживание",
            FOV = "Радиус FOV",
            FOVTrans = "Прозрачность FOV",
            HackerDist = "Дистанция Hacker",
            Trigger = "Триггер-бот",
            AutoShiftLock = "Авто-Shift Lock",

            SecKeys = "Горячие клавиши",
            ShootKey = "Выстрел",
            PickupKey = "Подобрать пистолет",
            FindMurdererKey = "Найти мёрдера",
            FindSheriffKey = "Найти шерифа",

            SecAuto = "Автоматизация",
            AutoEquip = "Авто-экипировка",
            AutoShot = "Авто-выстрел",
            InstantPickup = "Мгновенный подбор",
            AutoNotifyPickup = "Уведомление о пистолете",
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
            FOVCenter = "FOV Center",
            Pred = "Prediction",
            Smooth = "Smoothness",
            FOV = "FOV Radius",
            FOVTrans = "FOV Transparency",
            HackerDist = "Hacker Distance",
            Trigger = "Triggerbot",
            AutoShiftLock = "Auto Shift Lock",

            SecKeys = "Keybinds",
            ShootKey = "Shoot",
            PickupKey = "Pickup Gun",
            FindMurdererKey = "Find Murderer",
            FindSheriffKey = "Find Sheriff",

            SecAuto = "Automation",
            AutoEquip = "Auto-Equip",
            AutoShot = "Auto-Shot",
            InstantPickup = "Instant Pickup",
            AutoNotifyPickup = "Notify gun drop",
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
        Options = {"Static", "Dynamic", "Smooth", "Hacker", "Silent"},
        Default = Combat.Config.AimMode,
        Callback = function(v) Combat.Config.AimMode = v end
    })
    tab:AddDropdown({
        Title = text.FOVCenter,
        Options = {"Mouse", "Camera"},
        Default = Combat.Config.FOVCenter,
        Callback = function(v) Combat.Config.FOVCenter = v end
    })
    tab:AddNumberInput({ Title = text.Pred, Min = 0, Max = 100, Default = Combat.Config.Prediction, Callback = function(v) Combat.Config.Prediction = v end })
    tab:AddNumberInput({ Title = text.Smooth, Min = 1, Max = 10, Default = Combat.Config.SmoothSpeed, Callback = function(v) Combat.Config.SmoothSpeed = v end })
    tab:AddNumberInput({ Title = text.FOV, Min = 30, Max = 500, Default = Combat.Config.FOV, Callback = function(v) Combat.Config.FOV = v end })
    tab:AddNumberInput({ Title = text.FOVTrans, Min = 0, Max = 1, Default = Combat.Config.FOVTransparency, Callback = function(v) Combat.Config.FOVTransparency = v end })
    tab:AddNumberInput({ Title = text.HackerDist, Min = 5, Max = 20, Default = Combat.Config.HackerDistance, Callback = function(v) Combat.Config.HackerDistance = v end })
    tab:AddToggle({ Title = text.Trigger, Default = false, Callback = function(s) Combat.Config.TriggerBot = s end })
    tab:AddToggle({ Title = text.AutoShiftLock, Default = Combat.Config.AutoShiftLock, Callback = function(s) Combat.Config.AutoShiftLock = s end })

    -- Keybinds Section
    tab:AddSection(text.SecKeys)

    local function addBindLabelAndButton(keyName, configKeyString)
        local label = tab:AddLabel(keyName .. " : " .. tostring(Combat.Config[configKeyString]):gsub("Enum.KeyCode.", ""))
        tab:AddButton(keyName .. " (нажмите для смены)", function()
            local oldKey = Combat.Config[configKeyString]
            label.Text = keyName .. " : ... (ожидание)"
            local conn
            conn = UserInputService.InputBegan:Connect(function(input, gp)
                if gp then return end
                conn:Disconnect()
                Combat.Config[configKeyString] = input.KeyCode
                label.Text = keyName .. " : " .. tostring(input.KeyCode):gsub("Enum.KeyCode.", "")
            end)
            task.wait(3)
            if Combat.Config[configKeyString] == oldKey then
                label.Text = keyName .. " : " .. tostring(oldKey):gsub("Enum.KeyCode.", "")
            end
        end)
    end

    addBindLabelAndButton(text.ShootKey, "ShootKey")
    addBindLabelAndButton(text.PickupKey, "PickupKey")
    addBindLabelAndButton(text.FindMurdererKey, "FindMurdererKey")
    addBindLabelAndButton(text.FindSheriffKey, "FindSheriffKey")

    -- Automation Section
    tab:AddSection(text.SecAuto)
    tab:AddToggle({ Title = text.AutoEquip, Default = false, Callback = function(s) Combat.Config.AutoEquipGun = s end })
    tab:AddToggle({ Title = text.AutoShot, Default = false, Callback = function(s) Combat.Config.AutoShot = s end })
    tab:AddToggle({ Title = text.InstantPickup, Default = false, Callback = function(s) Combat.Config.InstantGunPickup = s end })
    tab:AddToggle({ Title = text.AutoNotifyPickup, Default = true, Callback = function(s) Combat.Config.AutoNotifyPickup = s end })
    tab:AddToggle({ Title = text.OneTap, Default = false, Callback = function(s) Combat.Config.OneTapKnife = s end })

    -- Misc Section
    tab:AddSection(text.SecMisc)
    tab:AddToggle({ Title = text.NoRecoil, Default = false, Callback = function(s) Combat.Config.NoRecoil = s end })
    tab:AddToggle({ Title = text.AntiAim, Default = false, Callback = function(s) Combat.Config.AntiAim = s end })
    tab:AddToggle({ Title = text.FakeLag, Default = false, Callback = function(s) Combat.Config.FakeLag = s end })
end

return Combat
