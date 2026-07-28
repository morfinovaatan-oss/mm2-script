-- [[ MM2 SIMPLE AUTO-FARM – Reliable Octree + Fling on full bag + Speed/Height adjust ]] --
local Autofarm = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Настройки (изменяются через UI)
Autofarm.Config = {
    Enabled = false,
    FarmSpeed = 30,          -- скорость движения (10-60)
    FarmHeightOffset = 0,    -- смещение по высоте относительно монеты (-5..5)
}

-- Внутренние переменные
local octree = nil
local coinContainer = nil
local touchedCoins = {}
local positionConnections = {}
local addConn, remConn = nil, nil
local farming = false

-- ====================== ПОИСК КАРТЫ ======================
local function getMap()
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v.Name == "Base" then
            return v.Parent
        end
    end
    return nil
end

-- ====================== ФЛИНГ МЁРДЕРА ======================
local function FindMurderer()
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local hasKnife = p.Character:FindFirstChild("Knife") or (p:FindFirstChild("Backpack") and p.Backpack:FindFirstChild("Knife"))
            if hasKnife and p.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                return p
            end
        end
    end
    return nil
end

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

    if not Character or not Humanoid or not RootPart then return end

    if RootPart.Velocity.Magnitude < 50 then
        getgenv().OldPos = RootPart.CFrame
    end

    if THumanoid and THumanoid.Sit then return end

    if THead then
        Camera.CameraSubject = THead
    elseif Handle then
        Camera.CameraSubject = Handle
    elseif THumanoid and TRootPart then
        Camera.CameraSubject = THumanoid
    end

    if not TCharacter:FindFirstChildWhichIsA("BasePart") then return end

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

-- ====================== ЗАГРУЗКА OCTREE ======================
local function loadOctree()
    if octree then return true end
    local ok, res = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/Sleitnick/rbxts-octo-tree/main/src/init.lua")
    end)
    if not ok or not res then return false end
    local mod = loadstring(res)()
    if not mod then return false end
    octree = mod.new()
    return true
end

local function markCoinTouched(coin)
    touchedCoins[coin] = true
    if octree then
        local node = octree:FindFirstNode(coin)
        if node then octree:RemoveNode(node) end
    end
end

local function isCoinTouched(coin)
    return touchedCoins[coin] == true
end

-- ====================== ОСНОВНОЙ ЦИКЛ ФАРМА ======================
local function collectCoins()
    local map = getMap()
    if not map then return end
    coinContainer = map:FindFirstChild("CoinContainer")
    if not coinContainer then return end
    local waypoint = LocalPlayer.Character and LocalPlayer.Character:GetPivot()

    -- populate octree
    octree:ClearAllNodes()
    table.clear(touchedCoins)
    for _, desc in ipairs(coinContainer:GetDescendants()) do
        if desc:IsA("TouchTransmitter") then
            local coin = desc.Parent
            if not isCoinTouched(coin) then
                octree:CreateNode(coin.Position, coin)
            end
        end
    end

    local gui = LocalPlayer.PlayerGui:FindFirstChild("MainGUI")
    if not gui then return end

    while farming do
        local fullBagIcon = gui:FindFirstChild("Game") and gui.Game:FindFirstChild("CoinBags") 
            and gui.Game.CoinBags:FindFirstChild("Container") 
            and gui.Game.CoinBags.Container:FindFirstChild("SnowToken") 
            and gui.Game.CoinBags.Container.SnowToken:FindFirstChild("FullBagIcon")
        if fullBagIcon and fullBagIcon.Visible then
            -- Мешок полон: флинг мёрдера и остановка
            local murderer = FindMurderer()
            if murderer then
                SkidFling(murderer)
            end
            -- Возврат на старт, если нужно
            if waypoint then
                local char = LocalPlayer.Character
                if char then
                    char:PivotTo(waypoint)
                end
            end
            farming = false
            break
        end

        local char = LocalPlayer.Character
        if not char or not char.PrimaryPart then task.wait(0.5); continue end
        local root = char.PrimaryPart
        local nearest = octree:GetNearest(root.Position, 200, 1)
        if nearest and #nearest > 0 then
            local coin = nearest[1].Object
            if not isCoinTouched(coin) then
                local targetPos = coin.Position + Vector3.new(0, Autofarm.Config.FarmHeightOffset, 0)
                local dist = (root.Position - targetPos).Magnitude
                local duration = dist / Autofarm.Config.FarmSpeed
                -- Движение
                local startPos = root.Position
                local startTime = tick()
                while true do
                    local elapsed = tick() - startTime
                    local alpha = math.min(elapsed / duration, 1)
                    if not char or not char.PrimaryPart then break end
                    char:PivotTo(CFrame.new(startPos:Lerp(targetPos, alpha)))
                    if alpha >= 1 then
                        task.wait(0.2)
                        break
                    end
                    task.wait()
                end
                markCoinTouched(coin)
                task.wait(0.2)
            else
                task.wait(0.1)
            end
        else
            task.wait(1)
        end
    end

    -- Очистка
    if octree then octree:ClearAllNodes() end
end

local function farmLoop()
    while farming do
        if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChildOfClass("Humanoid") or LocalPlayer.Character:FindFirstChildOfClass("Humanoid").Health <= 0 then
            task.wait(1)
            continue
        end
        if not loadOctree() then
            task.wait(2)
            continue
        end
        collectCoins()
        task.wait(1) -- небольшая пауза перед следующей попыткой (если farming ещё true)
    end
end

local function startFarming()
    if farming then return end
    farming = true
    task.spawn(farmLoop)
end

local function stopFarming()
    farming = false
    if octree then octree:ClearAllNodes() end
end

-- ====================== UI ======================
function Autofarm.Init(GlobalConfig, UI, Lang)
    local T = {
        RU = {
            TabName = "💰 Автофарм",
            Enable = "Включить автофарм",
            Speed = "Скорость",
            Height = "Высота над монетой",
        },
        EN = {
            TabName = "💰 AutoFarm",
            Enable = "Enable AutoFarm",
            Speed = "Speed",
            Height = "Height offset",
        }
    }
    local text = T[Lang] or T.RU
    local FarmTab = UI:CreateTab(text.TabName)

    FarmTab:AddToggle({
        Title = text.Enable,
        Default = false,
        Callback = function(val)
            Autofarm.Config.Enabled = val
            if val then
                startFarming()
            else
                stopFarming()
            end
        end
    })

    FarmTab:AddNumberInput({
        Title = text.Speed,
        Min = 10,
        Max = 60,
        Default = Autofarm.Config.FarmSpeed,
        Callback = function(v) Autofarm.Config.FarmSpeed = v end
    })

    FarmTab:AddNumberInput({
        Title = text.Height,
        Min = -5,
        Max = 5,
        Default = Autofarm.Config.FarmHeightOffset,
        Callback = function(v) Autofarm.Config.FarmHeightOffset = v end
    })
end

return Autofarm
