--[[
    Firola v1 - Home Module (Combat + Murderer)
--]]

local Module = {}

function Module:Init(Firola)
    local Services = Firola.Services
    local Players = Services.Players
    local RunService = Services.RunService
    local ReplicatedStorage = Services.ReplicatedStorage
    local Workspace = Services.Workspace
    local UserInputService = Services.UserInputService
    local VirtualInputManager = Services.VirtualInputManager or game:GetService("VirtualInputManager") -- на случай, если нет в Services
    local CoreGui = Services.CoreGui
    local StarterGui = Services.StarterGui
    local LocalPlayer = Firola.LocalPlayer
    local Camera = Workspace.CurrentCamera
    local UI = Firola.UI
    local tabName = "Home"

    -- ====================== КОНФИГУРАЦИЯ ======================
    local Config = {
        -- Аимбот
        AimEnabled = false,
        AimMode = "Dynamic",        -- Static, Dynamic, Smooth, Hacker, Flick Shot
        FOVCenter = "Mouse",        -- "Mouse" или "Camera"
        Prediction = 15,
        SmoothSpeed = 5,
        FOV = 120,
        FOVTransparency = 0.5,
        TriggerBot = false,
        AutoShiftLock = true,
        HackerDistance = 15,
        AutoEquipGun = false,
        AutoShot = false,
        InstantGunPickup = false,
        OneTapKnife = false,
        NoRecoil = false,
        AntiAim = false,
        FakeLag = false,
        ShootKey = Enum.KeyCode.C,
        PickupKey = Enum.KeyCode.R,
        FindMurdererKey = Enum.KeyCode.Z,
        FindSheriffKey = Enum.KeyCode.X,
        AutoNotifyPickup = true,

        -- Murderer
        KillSheriff = false,
        KillAll = false,
        KillCooldown = 0.5,
        KnifeKey = Enum.KeyCode.V,  -- отдельная клавиша для удара ножом (убийца)
    }

    -- ====================== FOV КРУГ ======================
    local FOVGui = Instance.new("ScreenGui")
    FOVGui.Name = "Firola_FOV"
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
    FOVStroke.Color = Color3.fromRGB(0, 230, 200)  -- акцентный цвет Firola

    -- ====================== ВСПОМОГАТЕЛЬНЫЕ ПЕРЕМЕННЫЕ И ФУНКЦИИ ======================
    local bodyVelocity, hackerActive, lastShotTime, pickedUpThisRound, shiftLockActive = nil, false, 0, false, false
    local SHOT_COOLDOWN = 0.5
    local lastKillTime = 0
    local killInProgress = false

    -- Простой SimulateClick через VirtualInputManager
    local function SimulateClick()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
        task.wait(0.02)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
    end

    local function enableShiftLock()
        if shiftLockActive then return end
        if not Config.AutoShiftLock then return end
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
        if Config.FOVCenter == "Camera" then
            centerPoint = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        else
            centerPoint = UserInputService:GetMouseLocation()
        end

        local best = nil
        local bestDist = Config.FOV
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
        speed = speed or Config.SmoothSpeed / 10
        local current = Camera.CFrame
        local desired = CFrame.new(current.Position, targetPos)
        Camera.CFrame = current:Lerp(desired, speed)
    end

    local function getMap()
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v.Name == "Spawns" and v.Parent.Name ~= "Lobby" then return v.Parent end
        end
        return nil
    end

    -- Мгновенный подбор пистолета
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
        if char:FindFirstChild("HumanoidRootPart") then root.CFrame = savedPos end
        pickedUpThisRound = true
    end

    local function notifyGunDrop(gunDrop)
        if not Config.AutoNotifyPickup then return end
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

    Workspace.DescendantAdded:Connect(function(descendant)
        if descendant.Name == "GunDrop" then notifyGunDrop(descendant) end
    end)

    LocalPlayer.CharacterAdded:Connect(function()
        pickedUpThisRound = false
        if shiftLockActive then disableShiftLock() end
    end)

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
        if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity = nil end
    end

    -- ====================== MURDERER FUNCTIONS ======================
    local function equipKnife()
        local char = LocalPlayer.Character
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if not tool or tool.Name ~= "Knife" then
            local backpack = LocalPlayer:FindFirstChild("Backpack")
            local knife = backpack and backpack:FindFirstChild("Knife")
            if knife and char:FindFirstChildOfClass("Humanoid") then
                char:FindFirstChildOfClass("Humanoid"):EquipTool(knife)
            end
        end
    end

    local function disableCollision()
        local char = LocalPlayer.Character
        if not char then return end
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("MeshPart") then
                part.CanCollide = false
            end
        end
    end

    local function enableCollision()
        local char = LocalPlayer.Character
        if not char then return end
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("MeshPart") then
                part.CanCollide = true
            end
        end
    end

    local function summonPlayer(targetPlayer)
        if not targetPlayer or not targetPlayer.Character then return end
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local myRoot = char.HumanoidRootPart
        local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not targetRoot then return end
        targetRoot.CFrame = myRoot.CFrame + Vector3.new(math.random(-2,2), 0, math.random(-2,2))
    end

    local function killPlayer(targetPlayer)
        if not targetPlayer or not targetPlayer.Character then return end
        equipKnife()
        local start = tick()
        while targetPlayer.Character and targetPlayer.Character:FindFirstChildOfClass("Humanoid") and targetPlayer.Character.Humanoid.Health > 0 do
            if tick() - start > 3 then break end
            SimulateClick()
            task.wait(0.1)
        end
    end

    local function killSheriffOnce()
        if killInProgress then return end
        killInProgress = true
        disableCollision()
        local sheriff = FindSheriff()
        if sheriff then
            summonPlayer(sheriff)
            task.wait(0.1)
            killPlayer(sheriff)
        end
        enableCollision()
        killInProgress = false
    end

    local function killAllOnce()
        if killInProgress then return end
        killInProgress = true
        disableCollision()
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            enableCollision()
            killInProgress = false
            return
        end
        equipKnife()

        for _ = 1, 100 do
            if not Config.KillAll then break end
            local allPlayers = {}
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    table.insert(allPlayers, p)
                end
            end
            for _, player in ipairs(allPlayers) do
                summonPlayer(player)
            end
            for _, player in ipairs(allPlayers) do
                if player.Character and player.Character:FindFirstChildOfClass("Humanoid") and player.Character.Humanoid.Health > 0 then
                    SimulateClick()
                end
            end
            task.wait(0.05)
        end

        local alivePlayers = {}
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChildOfClass("Humanoid") and p.Character.Humanoid.Health > 0 then
                table.insert(alivePlayers, p)
            end
        end
        for _, player in ipairs(alivePlayers) do
            if not Config.KillAll then break end
            if player.Character and player.Character:FindFirstChildOfClass("Humanoid") and player.Character.Humanoid.Health > 0 then
                killPlayer(player)
            end
            task.wait(0.1)
        end

        enableCollision()
        Config.KillAll = false
        killInProgress = false
    end

    task.spawn(function()
        while task.wait(0.3) do
            if Config.KillSheriff and not killInProgress and (tick() - lastKillTime >= Config.KillCooldown) then
                lastKillTime = tick()
                task.spawn(killSheriffOnce)
            end
            if Config.KillAll and not killInProgress then
                task.spawn(killAllOnce)
            end
        end
    end)

    LocalPlayer.CharacterAdded:Connect(function()
        killInProgress = false
        enableCollision()
    end)

    -- ====================== ГЛАВНЫЙ ЦИКЛ HEARTBEAT ======================
    local heartbeatConnection
    local function startHeartbeat()
        if heartbeatConnection then return end
        heartbeatConnection = RunService.Heartbeat:Connect(function()
            pcall(function()
                local char = LocalPlayer.Character
                if not char or char:FindFirstChildOfClass("Humanoid").Health <= 0 then
                    if hackerActive then hackerActive = false; disableAntiGravity() end
                    FOVFrame.Visible = false
                    if shiftLockActive then disableShiftLock() end
                    return
                end

                -- Flick Shot скрывает круг
                if Config.AimMode == "Flick Shot" and Config.AimEnabled then
                    FOVFrame.Visible = false
                else
                    FOVFrame.Size = UDim2.new(0, Config.FOV * 2, 0, Config.FOV * 2)
                    FOVStroke.Transparency = Config.FOVTransparency
                    FOVFrame.Visible = Config.AimEnabled
                end

                local hasGun = IsLocalSheriff()

                -- Подбор пистолета
                if Config.InstantGunPickup and not pickedUpThisRound and not hasGun then
                    local map = getMap()
                    local gunDrop = map and map:FindFirstChild("GunDrop")
                    if gunDrop then performInstantPickup(gunDrop); return end
                end

                -- Аимбот
                if Config.AimEnabled then
                    if Config.AimMode == "Hacker" and hasGun then
                        hackerActive = true
                        if shiftLockActive then disableShiftLock() end
                        local murderer = FindMurderer()
                        if murderer and murderer.Character then
                            local mRoot = murderer.Character:FindFirstChild("HumanoidRootPart")
                            local mHead = murderer.Character:FindFirstChild("Head") or mRoot
                            if mRoot and mHead then
                                enableAntiGravity()
                                local behindPos = mRoot.Position - (mRoot.CFrame.LookVector * Config.HackerDistance) + Vector3.new(0, 2.5, 0)
                                char:PivotTo(CFrame.new(behindPos, mRoot.Position))
                                local rootPart = char.HumanoidRootPart
                                if rootPart then rootPart.Velocity = Vector3.new(0,0,0); rootPart.RotVelocity = Vector3.new(0,0,0) end
                                local targetPos = mHead.Position
                                if Config.Prediction > 0 then targetPos += mRoot.Velocity * (Config.Prediction / 1000) end
                                Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)

                                local tool = char:FindFirstChildOfClass("Tool")
                                if not tool or tool.Name ~= "Gun" then
                                    if Config.AutoEquipGun then
                                        local backpack = LocalPlayer:FindFirstChild("Backpack")
                                        local gun = backpack and backpack:FindFirstChild("Gun")
                                        if gun and char:FindFirstChildOfClass("Humanoid") then char:FindFirstChildOfClass("Humanoid"):EquipTool(gun) end
                                    end
                                end

                                if Config.AutoShot and (tick() - lastShotTime >= SHOT_COOLDOWN) then
                                    local currentTool = char:FindFirstChildOfClass("Tool")
                                    if currentTool and (currentTool.Name == "Gun" or currentTool:FindFirstChild("Gun")) then
                                        SimulateClick()
                                        lastShotTime = tick()
                                    end
                                end
                            end
                        else
                            hackerActive = false; disableAntiGravity()
                        end
                    elseif Config.AimMode ~= "Flick Shot" then
                        hackerActive = false; disableAntiGravity()
                        local target = GetAimTarget()
                        local targetPos = target and target.Position
                        if targetPos then
                            enableShiftLock()
                            if Config.Prediction > 0 then
                                local root = target.Parent and target.Parent:FindFirstChild("HumanoidRootPart")
                                if root then targetPos += root.Velocity * (Config.Prediction / 1000) end
                            end
                            if Config.AimMode == "Static" then Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)
                            elseif Config.AimMode == "Smooth" or Config.AimMode == "Dynamic" then SmoothAim(targetPos) end

                            if Config.AutoShot and (tick() - lastShotTime >= SHOT_COOLDOWN) then
                                local tool = char:FindFirstChildOfClass("Tool")
                                if tool and (tool.Name == "Gun" or tool:FindFirstChild("Gun")) then SimulateClick(); lastShotTime = tick() end
                            end
                        else
                            disableShiftLock()
                        end
                    end
                else
                    hackerActive = false; disableAntiGravity(); disableShiftLock()
                end

                -- Триггер-бот
                if Config.TriggerBot and Config.AimMode ~= "Flick Shot" and (tick() - lastShotTime >= SHOT_COOLDOWN) then
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
                if Config.OneTapKnife then
                    local knife = char:FindFirstChild("Knife") or (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Knife"))
                    if knife and knife:IsA("Tool") then knife.GripPos = Vector3.new(0,0,0) end
                end

                -- No Recoil
                if Config.NoRecoil then
                    local tool = char:FindFirstChildOfClass("Tool")
                    if tool and tool:FindFirstChild("Gun") then Camera.CFrame = Camera.CFrame end
                end

                -- Anti-Aim
                if Config.AntiAim then
                    if char:FindFirstChild("Humanoid") then char.Humanoid.AutoRotate = false end
                    local rootPart = char:FindFirstChild("HumanoidRootPart")
                    if rootPart then rootPart.CFrame = rootPart.CFrame * CFrame.Angles(0, math.rad(15), 0) end
                else
                    if char:FindFirstChild("Humanoid") then char.Humanoid.AutoRotate = true end
                end

                -- Fake Lag
                if Config.FakeLag then
                    local rootPart = char:FindFirstChild("HumanoidRootPart")
                    if rootPart then rootPart.Anchored = true; task.wait(0.05); rootPart.Anchored = false end
                end
            end)
        end)
    end
    startHeartbeat()

    -- ====================== БИНДЫ КЛАВИШ ======================
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end

        if input.KeyCode == Config.ShootKey then
            if Config.AimEnabled and Config.AimMode == "Flick Shot" then
                local murderer = FindMurderer()
                if not murderer or not murderer.Character then SimulateClick(); return end
                local torso = murderer.Character:FindFirstChild("UpperTorso") or murderer.Character:FindFirstChild("HumanoidRootPart")
                if not torso then SimulateClick(); return end
                local targetPos = torso.Position
                local root = murderer.Character:FindFirstChild("HumanoidRootPart")
                if root and Config.Prediction > 0 then targetPos += root.Velocity * (Config.Prediction / 1000) end
                if Config.AutoEquipGun then
                    local char = LocalPlayer.Character
                    if char then
                        local tool = char:FindFirstChildOfClass("Tool")
                        if not tool or tool.Name ~= "Gun" then
                            local backpack = LocalPlayer:FindFirstChild("Backpack")
                            local gun = backpack and backpack:FindFirstChild("Gun")
                            if gun and char:FindFirstChildOfClass("Humanoid") then char:FindFirstChildOfClass("Humanoid"):EquipTool(gun) end
                        end
                    end
                end
                local char = LocalPlayer.Character
                local tool = char and char:FindFirstChildOfClass("Tool")
                if not tool or (tool.Name ~= "Gun" and not tool:FindFirstChild("Gun")) then SimulateClick(); return end
                local originalCFrame = Camera.CFrame
                Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)
                task.wait(0.01)
                SimulateClick()
                task.wait(0.01)
                Camera.CFrame = originalCFrame
            else
                SimulateClick()
            end
        elseif input.KeyCode == Config.KnifeKey then
            -- Удар ножом (Murderer)
            SimulateClick()
        elseif input.KeyCode == Config.PickupKey then
            local map = getMap()
            local gunDrop = map and map:FindFirstChild("GunDrop")
            if gunDrop then performInstantPickup(gunDrop) end
        elseif input.KeyCode == Config.FindSheriffKey then
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
        elseif input.KeyCode == Config.FindMurdererKey then
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

    -- ====================== UI ======================
    UI.CreateSection(tabName, "Aimbot")
    UI.CreateToggle(tabName, {Text = "Aimbot", Default = false, Callback = function(s) Config.AimEnabled = s end})
    UI.CreateDropdown(tabName, {Text = "Aim Mode", Items = {"Static", "Dynamic", "Smooth", "Hacker", "Flick Shot"}, Default = Config.AimMode, Callback = function(v) Config.AimMode = v end})
    UI.CreateDropdown(tabName, {Text = "FOV Center", Items = {"Mouse", "Camera"}, Default = Config.FOVCenter, Callback = function(v) Config.FOVCenter = v end})
    UI.CreateSlider(tabName, {Text = "Prediction", Min = 0, Max = 100, Default = Config.Prediction, Suffix = "%", Callback = function(v) Config.Prediction = v end})
    UI.CreateSlider(tabName, {Text = "Smoothness", Min = 1, Max = 10, Default = Config.SmoothSpeed, Callback = function(v) Config.SmoothSpeed = v end})
    UI.CreateSlider(tabName, {Text = "FOV Radius", Min = 30, Max = 500, Default = Config.FOV, Callback = function(v) Config.FOV = v end})
    UI.CreateSlider(tabName, {Text = "FOV Transparency", Min = 0, Max = 1, Default = Config.FOVTransparency, Decimals = 2, Callback = function(v) Config.FOVTransparency = v end})
    UI.CreateToggle(tabName, {Text = "Trigger Bot", Default = false, Callback = function(s) Config.TriggerBot = s end})
    UI.CreateToggle(tabName, {Text = "Auto Shift Lock", Default = Config.AutoShiftLock, Callback = function(s) Config.AutoShiftLock = s end})

    UI.CreateSection(tabName, "Keybinds")
    -- Можно добавить бинды вручную через кнопки, но пока опустим для краткости (используются значения по умолчанию)

    UI.CreateSection(tabName, "Automation")
    UI.CreateToggle(tabName, {Text = "Auto Equip Gun", Default = false, Callback = function(s) Config.AutoEquipGun = s end})
    UI.CreateToggle(tabName, {Text = "Auto Shoot", Default = false, Callback = function(s) Config.AutoShot = s end})
    UI.CreateToggle(tabName, {Text = "Instant Gun Pickup", Default = false, Callback = function(s) Config.InstantGunPickup = s end})
    UI.CreateToggle(tabName, {Text = "Notify Gun Drop", Default = true, Callback = function(s) Config.AutoNotifyPickup = s end})
    UI.CreateToggle(tabName, {Text = "One Tap Knife", Default = false, Callback = function(s) Config.OneTapKnife = s end})
    UI.CreateToggle(tabName, {Text = "No Recoil", Default = false, Callback = function(s) Config.NoRecoil = s end})
    UI.CreateToggle(tabName, {Text = "Anti Aim", Default = false, Callback = function(s) Config.AntiAim = s end})
    UI.CreateToggle(tabName, {Text = "Fake Lag", Default = false, Callback = function(s) Config.FakeLag = s end})

    UI.CreateSection(tabName, "Murderer")
    UI.CreateToggle(tabName, {Text = "Kill Sheriff", Default = false, Callback = function(s) Config.KillSheriff = s end})
    UI.CreateToggle(tabName, {Text = "Kill All", Default = false, Callback = function(s) Config.KillAll = s end})
    UI.CreateSlider(tabName, {Text = "Kill Cooldown", Min = 0.1, Max = 2, Default = Config.KillCooldown, Decimals = 1, Suffix = "s", Callback = function(v) Config.KillCooldown = v end})
end

return Module
