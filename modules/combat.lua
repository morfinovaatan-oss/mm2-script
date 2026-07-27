-- [[ MM2 COMBAT MODULE – Fixed & Optimized ]] --
local Combat = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

Combat.Config = {
    -- Аимбот
    AimEnabled = false,
    AimMode = "Dynamic",   -- Static, Dynamic, Smooth, Hacker
    Prediction = 15,
    SmoothSpeed = 5,
    FOV = 120,
    FOVTransparency = 0.5,
    TriggerBot = false,

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

-- ================== Helpers ==================
local function SimulateClick()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    task.wait(0.02)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
end

local function GetBasePart(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function IsThreat(player)
    if player == LocalPlayer then return false end
    local char = player.Character
    if not char then return false end
    local backpack = player:FindFirstChildOfClass("Backpack") or player:FindFirstChild("Backpack")
    local hasKnife = char:FindFirstChild("Knife") or (backpack and backpack:FindFirstChild("Knife"))
    local hasGun   = char:FindFirstChild("Gun")   or (backpack and backpack:FindFirstChild("Gun"))
    return (hasKnife ~= nil) or (hasGun ~= nil)
end

local function IsLocalSheriff()
    local char = LocalPlayer.Character
    if not char then return false end
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
    return (char:FindFirstChild("Gun") ~= nil) or (backpack and backpack:FindFirstChild("Gun") ~= nil)
end

local function FindMurderer()
    local closest = nil
    local minDist = math.huge
    local localChar = LocalPlayer.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local backpack = p:FindFirstChildOfClass("Backpack") or p:FindFirstChild("Backpack")
            local hasKnife = p.Character:FindFirstChild("Knife") or (backpack and backpack:FindFirstChild("Knife"))
            
            if hasKnife and hum and hum.Health > 0 and root and localRoot then
                local dist = (root.Position - localRoot.Position).Magnitude
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
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local backpack = p:FindFirstChildOfClass("Backpack") or p:FindFirstChild("Backpack")
            local hasGun = p.Character:FindFirstChild("Gun") or (backpack and backpack:FindFirstChild("Gun"))
            local hasRevolver = p.Character:FindFirstChild("Revolver") or (backpack and backpack:FindFirstChild("Revolver"))
            
            if (hasGun or hasRevolver) and hum and hum.Health > 0 then
                return p
            end
        end
    end
    return nil
end

local function GetAimTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local best = nil
    local bestDist = Combat.Config.FOV

    for _, p in ipairs(Players:GetPlayers()) do
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
    speed = (speed or Combat.Config.SmoothSpeed) / 10
    local current = Camera.CFrame
    local desired = CFrame.lookAt(current.Position, targetPos)
    Camera.CFrame = current:Lerp(desired, math.clamp(speed, 0.01, 1))
end

-- ================== Поиск карты ==================
local function getMap()
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v.Name == "Spawns" and v.Parent and v.Parent.Name ~= "Lobby" then
            return v.Parent
        end
    end
    return nil
end

-- ================== Мгновенный подбор пистолета ==================
local function HandleGunDrop(child)
    if child.Name ~= "GunDrop" then return end

    if Combat.Config.AutoNotifyPickup then
        local cb = Instance.new("BindableFunction")
        cb.OnInvoke = function(arg)
            if arg == "Get gun!" and child.Parent then
                local char = LocalPlayer.Character
                local part = GetBasePart(child)
                if char and char:FindFirstChild("Head") and part then
                    part.CFrame = CFrame.new(char.Head.Position)
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

    if Combat.Config.InstantGunPickup then
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local root = char.HumanoidRootPart
        local savedPos = root.CFrame
        local targetPart = GetBasePart(child)

        if targetPart then
            root.CFrame = targetPart.CFrame + Vector3.new(0, 1.5, 0)
            task.wait(0.05)

            if firetouchinterest then
                firetouchinterest(root, targetPart, 0)
                firetouchinterest(root, targetPart, 1)
            end

            task.wait(0.1)
            if char and char:FindFirstChild("HumanoidRootPart") then
                root.CFrame = savedPos
            end
        end
    end
end

Workspace.DescendantAdded:Connect(function(descendant)
    if descendant.Name == "GunDrop" then
        HandleGunDrop(descendant)
    end
end)

-- ================== Поиск RemoteEvent для выстрела ==================
local shootRemote = nil
local function getShootRemote()
    if shootRemote and shootRemote.Parent then return shootRemote end
    
    local names = {"ShootGun", "Shoot", "FireGun", "GunEvent", "ShootEvent"}
    for _, name in ipairs(names) do
        local remote = ReplicatedStorage:FindFirstChild(name, true)
        if remote and remote:IsA("RemoteEvent") then
            shootRemote = remote
            return remote
        end
    end
    
    if LocalPlayer.Character then
        local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if tool then
            local remote = tool:FindFirstChildOfClass("RemoteEvent")
            if remote then
                shootRemote = remote
                return shootRemote
            end
        end
    end
    return nil
end

-- ================== Hacker TP Kill Logic ==================
local tpKillCooldown = false

local function ExecuteHackerShot()
    if tpKillCooldown then return end
    
    local char = LocalPlayer.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local murderer = FindMurderer()
    
    if myRoot and murderer and murderer.Character then
        local mRoot = murderer.Character:FindFirstChild("HumanoidRootPart")
        local mHead = murderer.Character:FindFirstChild("Head") or mRoot
        
        if mRoot and mHead then
            tpKillCooldown = true
            
            -- Авто-экипировка пистолета перед телепортом
            if Combat.Config.AutoEquipGun then
                local currentTool = char:FindFirstChildOfClass("Tool")
                if not currentTool or (currentTool.Name ~= "Gun" and not currentTool:FindFirstChild("Gun")) then
                    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
                    local gun = backpack and (backpack:FindFirstChild("Gun") or backpack:FindFirstChildOfClass("Tool"))
                    if gun and hum then
                        hum:EquipTool(gun)
                    end
                end
            end
            
            local savedPos = myRoot.CFrame
            
            -- 1. Телепортируемся за спину мардеру
            myRoot.CFrame = mRoot.CFrame * CFrame.new(0, 0, 3.5)
            
            -- 2. Ожидание такта физики для регистрации позиции сервером
            RunService.Heartbeat:Wait()
            
            -- 3. Выстрел по точным координатам
            local targetPos = mHead.Position
            if Combat.Config.Prediction > 0 then
                targetPos = targetPos + (mRoot.AssemblyLinearVelocity * (Combat.Config.Prediction / 1000))
            end
            
            local remote = getShootRemote()
            if remote then
                remote:FireServer(targetPos, myRoot.Position)
            else
                SimulateClick()
            end
            
            -- 4. Возврат на исходную позицию
            myRoot.CFrame = savedPos
            
            task.delay(1, function()
                tpKillCooldown = false
            end)
        end
    end
end

-- ================== Input Connections ==================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Combat.Config.ShootKey then
        if Combat.Config.AimMode == "Hacker" and IsLocalSheriff() then
            ExecuteHackerShot()
        else
            SimulateClick()
        end
    elseif input.KeyCode == Combat.Config.PickupKey then
        local map = getMap()
        local gunDrop = map and map:FindFirstChild("GunDrop")
        if gunDrop then
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local targetPart = GetBasePart(gunDrop)
            if root and targetPart then
                local savedPos = root.CFrame
                root.CFrame = targetPart.CFrame + Vector3.new(0, 1.5, 0)
                task.wait(0.05)
                if firetouchinterest then
                    firetouchinterest(root, targetPart, 0)
                    firetouchinterest(root, targetPart, 1)
                end
                task.wait(0.1)
                if char:FindFirstChild("HumanoidRootPart") then
                    root.CFrame = savedPos
                end
            end
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

-- ================== Main Render Loop ==================
RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum or hum.Health <= 0 then
        FOVFrame.Visible = false
        return
    end

    -- Обновление FOV GUI
    FOVFrame.Size = UDim2.new(0, Combat.Config.FOV * 2, 0, Combat.Config.FOV * 2)
    FOVStroke.Transparency = Combat.Config.FOVTransparency
    FOVFrame.Visible = Combat.Config.AimEnabled

    if Camera.CameraType == Enum.CameraType.Scriptable and Combat.Config.AimMode ~= "Static" and Combat.Config.AimMode ~= "Hacker" then
        Camera.CameraType = Enum.CameraType.Custom
    end

    -- ================= АИМБОТ =================
    if Combat.Config.AimEnabled then
        if Combat.Config.AimMode == "Hacker" and IsLocalSheriff() then
            -- Автоматический TP Kill через автовыстрел, если включен AutoShot
            if Combat.Config.AutoShot then
                ExecuteHackerShot()
            else
                -- Просто доворачиваем камеру/подготавливаем позицию, если автовыстрел выключен
                local murderer = FindMurderer()
                if murderer and murderer.Character then
                    local mHead = murderer.Character:FindFirstChild("Head") or murderer.Character:FindFirstChild("HumanoidRootPart")
                    if mHead then
                        local targetPos = mHead.Position
                        local mRoot = murderer.Character:FindFirstChild("HumanoidRootPart")
                        if Combat.Config.Prediction > 0 and mRoot then
                            targetPos = targetPos + (mRoot.AssemblyLinearVelocity * (Combat.Config.Prediction / 1000))
                        end
                        Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)
                    end
                end
            end
        else
            local target = GetAimTarget()
            local targetPos = target and target.Position
            if targetPos and Combat.Config.Prediction > 0 then
                local root = target.Parent and target.Parent:FindFirstChild("HumanoidRootPart")
                if root then
                    targetPos = targetPos + (root.AssemblyLinearVelocity * (Combat.Config.Prediction / 1000))
                end
            end

            if targetPos then
                if Combat.Config.AimMode == "Static" then
                    Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)
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

    -- Триггер-бот
    if Combat.Config.TriggerBot then
        local mousePos = UserInputService:GetMouseLocation()
        local ray = Camera:ViewportPointToRay(mousePos.X, mousePos.Y)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {char}
        local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
        if result and result.Instance then
            local hitPlayer = Players:GetPlayerFromCharacter(result.Instance.Parent) or Players:GetPlayerFromCharacter(result.Instance.Parent.Parent)
            if hitPlayer and hitPlayer ~= LocalPlayer and IsThreat(hitPlayer) then
                SimulateClick()
            end
        end
    end

    -- Авто-экипировка (для остальных режимов)
    if Combat.Config.AutoEquipGun and Combat.Config.AimMode ~= "Hacker" then
        local currentTool = char:FindFirstChildOfClass("Tool")
        if not currentTool or currentTool.Name ~= "Gun" then
            local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
            local gun = backpack and backpack:FindFirstChild("Gun")
            if gun and hum then
                hum:EquipTool(gun)
            end
        end
    end

    -- One Tap Knife
    if Combat.Config.OneTapKnife then
        local knife = char:FindFirstChild("Knife") or (LocalPlayer:FindFirstChild("Backpack") and LocalPlayer.Backpack:FindFirstChild("Knife"))
        if knife and knife:IsA("Tool") then
            knife.GripPos = Vector3.new(0, 0, 0)
        end
    end

    -- Anti-Aim
    if Combat.Config.AntiAim then
        if hum then hum.AutoRotate = false end
        local rootPart = char:FindFirstChild("HumanoidRootPart")
        if rootPart then
            rootPart.CFrame = rootPart.CFrame * CFrame.Angles(0, math.rad(15), 0)
        end
    else
        if hum then hum.AutoRotate = true end
    end

    -- Fake Lag
    if Combat.Config.FakeLag then
        local rootPart = char:FindFirstChild("HumanoidRootPart")
        if rootPart then
            rootPart.Anchored = true
            task.delay(0.03, function()
                if rootPart then rootPart.Anchored = false end
            end)
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
            Pred = "Упреждение",
            Smooth = "Сглаживание",
            FOV = "Радиус FOV",
            FOVTrans = "Прозрачность FOV",
            Trigger = "Триггер-бот",

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
            Pred = "Prediction",
            Smooth = "Smoothness",
            FOV = "FOV Radius",
            FOVTrans = "FOV Transparency",
            Trigger = "Triggerbot",

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
        Options = {"Static", "Dynamic", "Smooth", "Hacker"},
        Default = Combat.Config.AimMode,
        Callback = function(v) Combat.Config.AimMode = v end
    })
    tab:AddNumberInput({ Title = text.Pred, Min = 0, Max = 100, Default = Combat.Config.Prediction, Callback = function(v) Combat.Config.Prediction = v end })
    tab:AddNumberInput({ Title = text.Smooth, Min = 1, Max = 10, Default = Combat.Config.SmoothSpeed, Callback = function(v) Combat.Config.SmoothSpeed = v end })
    tab:AddNumberInput({ Title = text.FOV, Min = 30, Max = 500, Default = Combat.Config.FOV, Callback = function(v) Combat.Config.FOV = v end })
    tab:AddNumberInput({ Title = text.FOVTrans, Min = 0, Max = 1, Default = Combat.Config.FOVTransparency, Callback = function(v) Combat.Config.FOVTransparency = v end })
    tab:AddToggle({ Title = text.Trigger, Default = false, Callback = function(s) Combat.Config.TriggerBot = s end })

    -- Keybinds Section
    tab:AddSection(text.SecKeys)

    local function addBindLabelAndButton(keyName, configKeyRef)
        local currentKey = Combat.Config[configKeyRef]
        local keyString = tostring(currentKey):gsub("Enum.KeyCode.", "")
        local label = tab:AddLabel(keyName .. " : " .. keyString)

        tab:AddButton(keyName .. " (нажмите для смены)", function()
            local oldKey = Combat.Config[configKeyRef]
            label.Text = keyName .. " : ... (ожидание)"
            local conn
            conn = UserInputService.InputBegan:Connect(function(input, gp)
                if gp or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
                conn:Disconnect()
                Combat.Config[configKeyRef] = input.KeyCode
                label.Text = keyName .. " : " .. tostring(input.KeyCode):gsub("Enum.KeyCode.", "")
            end)
            
            task.delay(3, function()
                if Combat.Config[configKeyRef] == oldKey and conn.Connected then
                    conn:Disconnect()
                    label.Text = keyName .. " : " .. tostring(oldKey):gsub("Enum.KeyCode.", "")
                end
            end)
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
