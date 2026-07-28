-- [[ MM2 AUTO‑FARM – End‑Round Automation + Stats Window + SkidFling + 5s Delay ]] --
local Autofarm = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Настройки
Autofarm.AutoEndRound = false
Autofarm.StatsWindow = false

-- Внутренние переменные
local totalCoinsGathered = 0
local StatsGui = nil
local FPSLabel, PingLabel, CoinsLabel = nil, nil, nil
local octree = nil
local coinContainer = nil
local touchedCoins = {}
local positionConnections = {}
local addConn, remConn = nil, nil
local farming = false
local roundStartTime = 0   -- время начала раунда (для 5-сек задержки)

-- ====================== СТАТИСТИКА ======================
local function createStatsWindow()
    if StatsGui then return end
    StatsGui = Instance.new("ScreenGui")
    StatsGui.Name = "PurpleFox_Stats"
    StatsGui.ResetOnSpawn = false
    pcall(function() StatsGui.Parent = CoreGui end)
    if not StatsGui.Parent then StatsGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local Frame = Instance.new("Frame", StatsGui)
    Frame.Size = UDim2.new(0, 200, 0, 100)
    Frame.Position = UDim2.new(0.8, 0, 0.8, 0)
    Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    Frame.BorderSizePixel = 0
    Frame.Active = true
    Frame.Draggable = true
    Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", Frame).Color = Color3.fromRGB(160, 32, 240)

    local Title = Instance.new("TextLabel", Frame)
    Title.Size = UDim2.new(1, 0, 0, 25)
    Title.BackgroundTransparency = 1
    Title.Text = "📊 Статистика"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 14

    FPSLabel = Instance.new("TextLabel", Frame)
    FPSLabel.Size = UDim2.new(1, -10, 0, 20)
    FPSLabel.Position = UDim2.new(0, 10, 0, 30)
    FPSLabel.BackgroundTransparency = 1
    FPSLabel.Text = "FPS: 0"
    FPSLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    FPSLabel.Font = Enum.Font.Gotham
    FPSLabel.TextSize = 12
    FPSLabel.TextXAlignment = Enum.TextXAlignment.Left

    PingLabel = Instance.new("TextLabel", Frame)
    PingLabel.Size = UDim2.new(1, -10, 0, 20)
    PingLabel.Position = UDim2.new(0, 10, 0, 50)
    PingLabel.BackgroundTransparency = 1
    PingLabel.Text = "Ping: 0 ms"
    PingLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    PingLabel.Font = Enum.Font.Gotham
    PingLabel.TextSize = 12
    PingLabel.TextXAlignment = Enum.TextXAlignment.Left

    CoinsLabel = Instance.new("TextLabel", Frame)
    CoinsLabel.Size = UDim2.new(1, -10, 0, 20)
    CoinsLabel.Position = UDim2.new(0, 10, 0, 70)
    CoinsLabel.BackgroundTransparency = 1
    CoinsLabel.Text = "Собрано монет: 0"
    CoinsLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    CoinsLabel.Font = Enum.Font.GothamBold
    CoinsLabel.TextSize = 12
    CoinsLabel.TextXAlignment = Enum.TextXAlignment.Left

    StatsGui.Enabled = Autofarm.StatsWindow

    RunService.RenderStepped:Connect(function(deltaTime)
        if not StatsGui.Enabled then return end
        local fps = math.floor(1 / deltaTime)
        local ping = 0
        pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        FPSLabel.Text = "FPS: " .. fps
        PingLabel.Text = "Ping: " .. ping .. " ms"
        CoinsLabel.Text = "Собрано монет: " .. totalCoinsGathered
    end)
end

-- ====================== ЗАВЕРШЕНИЕ РАУНДА ======================
local function getMap()
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v.Name == "Base" then return v.Parent end
    end
    return nil
end

local function getPlayerRole()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return "Dead" end
    local map = getMap()
    if map and not map:IsAncestorOf(char) then return "Dead" end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if char:FindFirstChild("Knife") or (backpack and backpack:FindFirstChild("Knife")) then return "Murderer" end
    if char:FindFirstChild("Gun") or (backpack and backpack:FindFirstChild("Gun")) then return "Sheriff" end
    return "Innocent"
end

local function FindMurderer()
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local hasKnife = p.Character:FindFirstChild("Knife") or (p:FindFirstChild("Backpack") and p.Backpack:FindFirstChild("Knife"))
            if hasKnife and p.Character:FindFirstChildOfClass("Humanoid").Health > 0 then return p end
        end
    end
    return nil
end

local function SimulateClick()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    task.wait(0.02)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
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

local function SheriffHackerKill(murderer)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local mRoot = murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart")
    if not mRoot then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool or tool.Name ~= "Gun" then
        local gun = LocalPlayer.Backpack:FindFirstChild("Gun")
        if gun then char:FindFirstChildOfClass("Humanoid"):EquipTool(gun) end
    end
    char:PivotTo(mRoot.CFrame * CFrame.new(0, 2, 5))
    task.wait(0.1)
    Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, mRoot.Position)
    task.wait(0.05)
    SimulateClick()
end

local function MurdererKillAll()
    local char = LocalPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool or tool.Name ~= "Knife" then
        local knife = LocalPlayer.Backpack:FindFirstChild("Knife")
        if knife then char:FindFirstChildOfClass("Humanoid"):EquipTool(knife) end
    end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            local tRoot = p.Character.HumanoidRootPart
            char:PivotTo(tRoot.CFrame * CFrame.new(0, 0, 2))
            task.wait(0.1)
            SimulateClick()
            task.wait(0.1)
        end
    end
end

local function ExecuteEndRound()
    local role = getPlayerRole()
    if role == "Murderer" then
        MurdererKillAll()
    elseif role == "Sheriff" then
        local m = FindMurderer()
        if m then SheriffHackerKill(m) end
    elseif role == "Innocent" or role == "Dead" then
        local m = FindMurderer()
        if m then SkidFling(m) end   -- <-- теперь используется мощный флинг
    end
end

-- ====================== АВТОФАРМ (Octree) ======================
local function isRoundActive()
    if not LocalPlayer.Character then return false end
    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v.Name == "Spawns" and v.Parent.Name ~= "Lobby" then return true end
    end
    return false
end

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
    if not touchedCoins[coin] then
        totalCoinsGathered = totalCoinsGathered + 1
    end
    touchedCoins[coin] = true
    if octree then
        local node = octree:FindFirstNode(coin)
        if node then octree:RemoveNode(node) end
    end
end

local function isCoinTouched(coin)
    return touchedCoins[coin] == true
end

local function setupTouchTracking(coin)
    local ti = coin:FindFirstChildWhichIsA("TouchTransmitter")
    if not ti then return end
    local conn
    conn = ti.AncestryChanged:Connect(function(_, parent)
        if parent == nil then
            markCoinTouched(coin)
            if conn then conn:Disconnect() end
        end
    end)
    positionConnections[coin] = conn
end

local function setupPositionTracking(coin, lastY)
    local conn
    conn = coin:GetPropertyChangedSignal("Position"):Connect(function()
        if coin.Position.Y ~= lastY then
            markCoinTouched(coin)
            if conn then conn:Disconnect() end
            coin:Destroy()
        end
    end)
    positionConnections[coin] = conn
end

local function populateOctree()
    if not octree or not coinContainer then return end
    octree:ClearAllNodes()
    table.clear(touchedCoins)
    for _, desc in ipairs(coinContainer:GetDescendants()) do
        if desc:IsA("TouchTransmitter") then
            local coin = desc.Parent
            if not isCoinTouched(coin) then
                octree:CreateNode(coin.Position, coin)
                setupTouchTracking(coin)
            end
            setupPositionTracking(coin, coin.Position.Y)
        end
    end
    if addConn then addConn:Disconnect() end
    if remConn then remConn:Disconnect() end
    addConn = coinContainer.DescendantAdded:Connect(function(desc)
        if desc:IsA("TouchTransmitter") then
            local coin = desc.Parent
            if not isCoinTouched(coin) then
                octree:CreateNode(coin.Position, coin)
                setupTouchTracking(coin)
                setupPositionTracking(coin, coin.Position.Y)
            end
        end
    end)
    remConn = coinContainer.DescendantRemoving:Connect(function(desc)
        if desc:IsA("TouchTransmitter") and desc.Parent.Name == "Coin_Server" then
            markCoinTouched(desc.Parent)
        end
    end)
end

local function moveToPositionSlowly(targetPos, duration)
    local char = LocalPlayer.Character
    if not char or not char.PrimaryPart then return end
    local startPos = char.PrimaryPart.Position
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
end

local function collectCoins()
    local map = getMap()
    if not map then return end
    coinContainer = map:FindFirstChild("CoinContainer")
    if not coinContainer then return end
    local waypoint = LocalPlayer.Character and LocalPlayer.Character:GetPivot()
    populateOctree()
    local gui = LocalPlayer.PlayerGui:FindFirstChild("MainGUI")
    if not gui then return end

    while farming do
        local fullBagIcon = gui:FindFirstChild("Game") and gui.Game:FindFirstChild("CoinBags") 
            and gui.Game.CoinBags:FindFirstChild("Container") 
            and gui.Game.CoinBags.Container:FindFirstChild("SnowToken") 
            and gui.Game.CoinBags.Container.SnowToken:FindFirstChild("FullBagIcon")
        if fullBagIcon and fullBagIcon.Visible then
            while isRoundActive() and farming do
                if Autofarm.AutoEndRound then
                    ExecuteEndRound()
                end
                task.wait(1)
            end
            break
        end
        local char = LocalPlayer.Character
        if not char or not char.PrimaryPart then task.wait(0.5); continue end
        local root = char.PrimaryPart
        local nearest = octree:GetNearest(root.Position, 200, 1)
        if nearest and #nearest > 0 then
            local coin = nearest[1].Object
            if not isCoinTouched(coin) then
                local targetPos = coin.Position
                local dist = (root.Position - targetPos).Magnitude
                local duration = dist / 30
                moveToPositionSlowly(targetPos, duration)
                markCoinTouched(coin)
                task.wait(0.2)
            else
                task.wait(0.1)
            end
        else
            task.wait(1)
        end
    end

    if waypoint then
        local char = LocalPlayer.Character
        if char then char:PivotTo(waypoint) end
    end
    if addConn then addConn:Disconnect(); addConn = nil end
    if remConn then remConn:Disconnect(); remConn = nil end
    for _, conn in pairs(positionConnections) do
        if conn and conn.Connected then conn:Disconnect() end
    end
    table.clear(positionConnections)
    if octree then octree:ClearAllNodes() end
end

local function farmLoop()
    while farming do
        if not isRoundActive() then
            roundStartTime = 0   -- сбрасываем таймер
            task.wait(1)
            continue
        end

        -- Если раунд только начался, запоминаем время
        if roundStartTime == 0 then
            roundStartTime = tick()
        end

        -- Ждём 5 секунд после начала раунда, прежде чем действовать
        if tick() - roundStartTime < 5 then
            task.wait(1)
            continue
        end

        -- Если мы мертвы и включено авто‑завершение, просто убиваем мёрдера
        if Autofarm.AutoEndRound and getPlayerRole() == "Dead" then
            ExecuteEndRound()
            task.wait(1)
            continue
        end

        -- Иначе фармим монеты
        if not loadOctree() then
            task.wait(2)
            continue
        end
        collectCoins()
        task.wait(1)
    end
end

local function startFarming()
    if farming then return end
    farming = true
    task.spawn(farmLoop)
end

local function stopFarming()
    farming = false
    if addConn then addConn:Disconnect(); addConn = nil end
    if remConn then remConn:Disconnect(); remConn = nil end
    for _, conn in pairs(positionConnections) do
        if conn and conn.Connected then conn:Disconnect() end
    end
    table.clear(positionConnections)
    if octree then octree:ClearAllNodes() end
end

-- ====================== UI ======================
function Autofarm.Init(GlobalConfig, UI, Lang)
    createStatsWindow()
    local T = {
        RU = { 
            TabName = "💰 Автофарм", 
            Enable = "Включить автофарм",
            AutoEnd = "Авто-завершение раунда",
            StatsTog = "Окно статистики"
        },
        EN = { 
            TabName = "💰 AutoFarm", 
            Enable = "Enable AutoFarm",
            AutoEnd = "Auto-End Round",
            StatsTog = "Statistics Window"
        }
    }
    local text = T[Lang] or T.RU
    local FarmTab = UI:CreateTab(text.TabName)

    FarmTab:AddToggle({
        Title = text.Enable,
        Default = false,
        Callback = function(val)
            if val then startFarming() else stopFarming() end
        end
    })

    FarmTab:AddToggle({
        Title = text.AutoEnd,
        Default = false,
        Callback = function(val)
            Autofarm.AutoEndRound = val
        end
    })

    FarmTab:AddToggle({
        Title = text.StatsTog,
        Default = false,
        Callback = function(val)
            Autofarm.StatsWindow = val
            if StatsGui then StatsGui.Enabled = val end
        end
    })
end

return Autofarm
