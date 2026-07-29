--[[
    Firola v1 - Trolling Module (Fling, Invisibility, Seizure)
--]]

local Module = {}

function Module:Init(Firola)
    local Services = Firola.Services
    local Players = Services.Players
    local RunService = Services.RunService
    local Workspace = Services.Workspace
    local UserInputService = Services.UserInputService
    local LocalPlayer = Firola.LocalPlayer
    local Camera = Workspace.CurrentCamera
    local UI = Firola.UI
    local tabName = "Trolling"

    -- ====================== КОНФИГУРАЦИЯ ======================
    local Config = {
        Invisibility = false,
        Seizure = false,
        SeizureIntensity = 10, -- сила тряски
    }

    -- Глобальные переменные для восстановления позиции (SkidFling)
    getgenv().OldPos = nil
    getgenv().FPDH = Workspace.FallenPartsDestroyHeight

    -- ====================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ======================
    local function GetLocalRootPos()
        local char = LocalPlayer.Character
        if not char then return nil end
        local root = char:FindFirstChild("HumanoidRootPart")
        return root and root.Position
    end

    local function FindMurderer()
        local myPos = GetLocalRootPos()
        if not myPos then return nil end
        local closest = nil
        local minDist = math.huge
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local hasKnife = player.Character:FindFirstChild("Knife")
                    or (player:FindFirstChild("Backpack") and player.Backpack:FindFirstChild("Knife"))
                if hasKnife and player.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                    local pos = player.Character.HumanoidRootPart.Position
                    local dist = (pos - myPos).Magnitude
                    if dist < minDist then
                        minDist = dist
                        closest = player
                    end
                end
            end
        end
        return closest
    end

    local function FindSheriff()
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local hasGun = player.Character:FindFirstChild("Gun")
                    or (player:FindFirstChild("Backpack") and player.Backpack:FindFirstChild("Gun"))
                if hasGun and player.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                    return player
                end
            end
        end
        return nil
    end

    -- ================== МОЩНЫЙ ФЛИНГ (SkidFling) ==================
    local function SkidFling(TargetPlayer)
        local Character = LocalPlayer.Character
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        local RootPart = Humanoid and Humanoid.RootPart
        local TCharacter = TargetPlayer.Character
        if not TCharacter then return end

        local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
        local TRootPart = THumanoid and THumanoid.RootPart
        local THead = TCharacter:FindFirstChild("Head")
        local Accessory = TCharacter:FindFirstChildOfClass("Accessory")
        local Handle = Accessory and Accessory:FindFirstChild("Handle")

        if not Character or not Humanoid or not RootPart then
            return
        end

        if RootPart.Velocity.Magnitude < 50 then
            getgenv().OldPos = RootPart.CFrame
        end

        if THumanoid and THumanoid.Sit then
            return
        end

        if THead then
            Camera.CameraSubject = THead
        elseif Handle then
            Camera.CameraSubject = Handle
        elseif THumanoid and TRootPart then
            Camera.CameraSubject = THumanoid
        end

        if not TCharacter:FindFirstChildWhichIsA("BasePart") then
            return
        end

        local FPos = function(BasePart, Pos, Ang)
            RootPart.CFrame = CFrame.new(BasePart.Position) * Pos * Ang
            Character:SetPrimaryPartCFrame(CFrame.new(BasePart.Position) * Pos * Ang)
            RootPart.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
            RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
        end

        local SFBasePart = function(BasePart)
            local TimeToWait = 2
            local Time = tick()
            local Angle = 0
            repeat
                if RootPart and THumanoid then
                    if BasePart.Velocity.Magnitude < 50 then
                        Angle = Angle + 100
                        FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle),0 ,0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle),0 ,0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle),0 ,0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0))
                        task.wait()
                    else
                        FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, -THumanoid.WalkSpeed), CFrame.Angles(0, 0, 0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                        task.wait()
                    end
                end
            until Time + TimeToWait < tick()
        end

        workspace.FallenPartsDestroyHeight = 0/0

        local BV = Instance.new("BodyVelocity")
        BV.Parent = RootPart
        BV.Velocity = Vector3.new(0, 0, 0)
        BV.MaxForce = Vector3.new(9e9, 9e9, 9e9)

        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

        if TRootPart then
            SFBasePart(TRootPart)
        elseif THead then
            SFBasePart(THead)
        elseif Handle then
            SFBasePart(Handle)
        end

        BV:Destroy()
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
        Camera.CameraSubject = Humanoid

        -- Восстановление позиции
        if getgenv().OldPos then
            repeat
                RootPart.CFrame = getgenv().OldPos * CFrame.new(0, .5, 0)
                Character:SetPrimaryPartCFrame(getgenv().OldPos * CFrame.new(0, .5, 0))
                Humanoid:ChangeState("GettingUp")
                for _, part in pairs(Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.Velocity, part.RotVelocity = Vector3.new(), Vector3.new()
                    end
                end
                task.wait()
            until (RootPart.Position - getgenv().OldPos.p).Magnitude < 25
            workspace.FallenPartsDestroyHeight = getgenv().FPDH
        end
    end

    -- ================== НЕВИДИМОСТЬ ==================
    local invisConnection
    local function setInvisibility(state)
        local char = LocalPlayer.Character
        if not char then return end
        if state then
            -- Делаем все части прозрачными
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") or part:IsA("Decal") then
                    part.Transparency = 1
                end
            end
            -- Отключаем RootJoint (чтобы персонаж не был виден в меню)
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.Name = "1" -- временно меняем имя, чтобы другие скрипты не нашли
            end
            -- Постоянно обновляем, т.к. игра может сбрасывать прозрачность
            invisConnection = RunService.Stepped:Connect(function()
                if LocalPlayer.Character then
                    for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                        if part:IsA("BasePart") or part:IsA("Decal") then
                            part.Transparency = 1
                        end
                    end
                end
            end)
        else
            -- Возвращаем обратно
            if invisConnection then
                invisConnection:Disconnect()
                invisConnection = nil
            end
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") or part:IsA("Decal") then
                        part.Transparency = 0
                    end
                end
                local humanoid = char:FindFirstChild("1")
                if humanoid then
                    humanoid.Name = "Humanoid"
                end
            end
        end
    end

    -- ================== SEIZURE MODE ==================
    local seizureConnection
    local function setSeizure(state)
        if state then
            seizureConnection = RunService.RenderStepped:Connect(function()
                local char = LocalPlayer.Character
                if not char or not char:FindFirstChild("HumanoidRootPart") then return end
                local root = char.HumanoidRootPart
                root.CFrame = root.CFrame * CFrame.Angles(
                    math.rad(math.random(-Config.SeizureIntensity, Config.SeizureIntensity)),
                    math.rad(math.random(-Config.SeizureIntensity, Config.SeizureIntensity)),
                    math.rad(math.random(-Config.SeizureIntensity, Config.SeizureIntensity))
                )
            end)
        else
            if seizureConnection then
                seizureConnection:Disconnect()
                seizureConnection = nil
            end
        end
    end

    -- Автоматическое восстановление при возрождении
    LocalPlayer.CharacterAdded:Connect(function(char)
        if Config.Invisibility then
            task.wait(0.5)
            setInvisibility(true)
        end
        if Config.Seizure then
            task.wait(0.5)
            setSeizure(true)
        end
    end)

    -- ================== ПУБЛИЧНЫЕ МЕТОДЫ ==================
    local function FlingSheriff()
        local sheriff = FindSheriff()
        if sheriff then
            SkidFling(sheriff)
        end
    end

    local function FlingMurderer()
        local murderer = FindMurderer()
        if murderer then
            SkidFling(murderer)
        end
    end

    local function FlingAll()
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                SkidFling(player)
            end
        end
    end

    -- ================== UI ==================
    UI.CreateSection(tabName, "Fling")
    UI.CreateButton(tabName, {Text = "Fling Sheriff", Callback = FlingSheriff})
    UI.CreateButton(tabName, {Text = "Fling Murderer", Callback = FlingMurderer})
    UI.CreateButton(tabName, {Text = "Fling All", Callback = FlingAll})

    UI.CreateSection(tabName, "Misc")
    UI.CreateToggle(tabName, {
        Text = "Invisibility",
        Default = false,
        Callback = function(state)
            Config.Invisibility = state
            setInvisibility(state)
        end
    })
    UI.CreateToggle(tabName, {
        Text = "Seizure Mode",
        Default = false,
        Callback = function(state)
            Config.Seizure = state
            setSeizure(state)
        end
    })
    UI.CreateSlider(tabName, {
        Text = "Seizure Intensity",
        Min = 1, Max = 50, Default = Config.SeizureIntensity,
        Callback = function(v) Config.SeizureIntensity = v end
    })
end

return Module
