-- [[ MM2 AUTO-FARM & END ROUND MODULE ]] --
local Autofarm = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")
local LocalPlayer = Players.LocalPlayer

-- Настройки
local RADIUS = 200
local WALKSPEED = 30
local TP_BACK_TO_START = true

Autofarm.Config = {
    Enabled = false,
    AutoEndRound = false,
    StatsWindow = false
}

-- Octree и контейнеры
local octree = nil
local coinContainer = nil
local touchedCoins = {}
local positionConnections = {}
local addConn, remConn = nil, nil
local farmThread = nil
local totalCoinsGathered = 0

-- UI Статистики
local StatsGui = nil
local FPSLabel, PingLabel, CoinsLabel = nil, nil, nil

-- ================== СТАТИСТИКА UI ==================
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
    Frame.Draggable = true -- Позволяет перетаскивать окно

    local UICorner = Instance.new("UICorner", Frame)
    UICorner.CornerRadius = UDim.new(0, 8)
    
    local UIStroke = Instance.new("UIStroke", Frame)
    UIStroke.Thickness = 2
    UIStroke.Color = Color3.fromRGB(160, 32, 240)

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

    StatsGui.Enabled = Autofarm.Config.StatsWindow

    -- Обновление FPS и Пинга
    RunService.RenderStepped:Connect(function(deltaTime)
        if not StatsGui.Enabled then return end
        local fps = math.floor(1 / deltaTime)
        local ping = 0
        pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        
        FPSLabel.Text = "FPS: " .. tostring(fps)
        PingLabel.Text = "Ping: " .. tostring(ping) .. " ms"
        CoinsLabel.Text = "Собрано монет: " .. tostring(totalCoinsGathered)
    end)
end

-- ================== ОПРЕДЕЛЕНИЕ РОЛЕЙ И ИГРОКОВ ==================
local function isRoundActive()
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v.Name == "Spawns" and v.Parent.Name ~= "Lobby" then
            return true
        end
    end
    return false
end

local function getPlayerRole()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then 
        return "Dead" 
    end
    local map = Workspace:FindFirstChild("Normal") or Workspace:FindFirstChild("Murder")
    -- Если игрок не на карте (в лобби), считаем его "Dead" в контексте раунда
    if map and not map:IsAncestorOf(LocalPlayer.Character) then
        return "Dead"
    end

    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    
    if char:FindFirstChild("Knife") or (backpack and backpack:FindFirstChild("Knife")) then return "Murderer" end
    if char:FindFirstChild("Gun") or (backpack and backpack:FindFirstChild("Gun")) then return "Sheriff" end
    return "Innocent"
end

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

local function SimulateClick()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    task.wait(0.02)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
end

-- ================== МЕТОДЫ УБИЙСТВА ==================
local function FlingPlayer(targetPlayer)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local targetRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    local root = char.HumanoidRootPart
    local bav = Instance.new("BodyAngularVelocity")
    bav.AngularVelocity = Vector3.new(0, 99999, 0)
    bav.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bav.P = math.huge
    bav.Parent = root

    local start = tick()
    while targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") and targetPlayer.Character.Humanoid.Health > 0 do
        if tick() - start > 5 then break end
        root.CFrame = targetRoot.CFrame * CFrame.new(math.random(-1,1), math.random(-1,1), math.random(-1,1))
        root.Velocity = Vector3.new(10000, 10000, 10000)
        task.wait()
    end
    if bav then bav:Destroy() end
    root.Velocity = Vector3.new(0,0,0)
end

local function SheriffHackerKill(murderer)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local mRoot = murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart")
    if not mRoot then return end

    -- Экипировка пистолета
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool or tool.Name ~= "Gun" then
        local gun = LocalPlayer.Backpack:FindFirstChild("Gun")
        if gun then char:FindFirstChildOfClass("Humanoid"):EquipTool(gun) end
    end

    -- Телепорт и выстрел
    char:PivotTo(mRoot.CFrame * CFrame.new(0, 2, 5))
    task.wait(0.1)
    Workspace.CurrentCamera.CFrame = CFrame.lookAt(Workspace.CurrentCamera.CFrame.Position, mRoot.Position)
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
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            if p.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                local tRoot = p.Character.HumanoidRootPart
                char:PivotTo(tRoot.CFrame * CFrame.new(0, 0, 2))
                task.wait(0.1)
                SimulateClick()
                task.wait(0.1)
            end
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
        if m then FlingPlayer(m) end
    end
end

-- ================== ЛОГИКА АВТОФАРМА ==================
local function getMap()
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v.Name == "Base" then return v.Parent end
    end
    return nil
end

local function loadOctree()
    if octree then return true end
    local ok, res = pcall(function() return game:HttpGet("https://raw.githubusercontent.com/Sleitnick/rbxts-octo-tree/main/src/init.lua") end)
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

local function isCoinTouched(coin) return touchedCoins[coin] == true end

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

    while Autofarm.Config.Enabled do
        local fullBagIcon = gui:FindFirstChild("Game") and gui.Game:FindFirstChild("CoinBags") 
            and gui.Game.CoinBags:FindFirstChild("Container") 
            and gui.Game.CoinBags.Container:FindFirstChild("SnowToken") 
            and gui.Game.CoinBags.Container.SnowToken:FindFirstChild("FullBagIcon")
            
        -- Проверка завершения сбора
        if fullBagIcon and fullBagIcon.Visible then
            Autofarm.Config.Enabled = false
            
            -- Вызов окончания раунда если включено
            if Autofarm.Config.AutoEndRound then
                ExecuteEndRound()
            end
            break
        end

        local char = LocalPlayer.Character
        if not char or not char.PrimaryPart then task.wait(0.5); continue end
        local root = char.PrimaryPart
        local nearest = octree:GetNearest(root.Position, RADIUS, 1)
        if nearest and #nearest > 0 then
            local coin = nearest[1].Object
            if not isCoinTouched(coin) then
                local targetPos = coin.Position
                local dist = (root.Position - targetPos).Magnitude
                local duration = dist / WALKSPEED
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

    if TP_BACK_TO_START and waypoint then
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
    while Autofarm.Config.Enabled do
        if not isRoundActive() then
            task.wait(1)
            continue
        end
        if not loadOctree() then
            task.wait(2)
            continue
        end
        collectCoins()
        task.wait(1)
    end
end

local function startFarming()
    if Autofarm.Config.Enabled then return end
    Autofarm.Config.Enabled = true
    farmThread = task.spawn(farmLoop)
end

local function stopFarming()
    Autofarm.Config.Enabled = false
    if farmThread then farmThread = nil end
    if addConn then addConn:Disconnect(); addConn = nil end
    if remConn then remConn:Disconnect(); remConn = nil end
    for _, conn in pairs(positionConnections) do
        if conn and conn.Connected then conn:Disconnect() end
    end
    table.clear(positionConnections)
    if octree then octree:ClearAllNodes() end
end

-- Постоянная проверка для лобби (если мёртв/зашёл в игру)
RunService.Heartbeat:Connect(function()
    if Autofarm.Config.AutoEndRound and isRoundActive() and getPlayerRole() == "Dead" then
        -- Выполняем авто-флинг раз в секунду (чтобы не спамить)
        task.spawn(function()
            ExecuteEndRound()
            task.wait(1)
        end)
    end
end)

-- ================== UI INIT ==================
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
            Autofarm.Config.AutoEndRound = val
        end
    })

    FarmTab:AddToggle({
        Title = text.StatsTog,
        Default = false,
        Callback = function(val)
            Autofarm.Config.StatsWindow = val
            if StatsGui then
                StatsGui.Enabled = val
            end
        end
    })
end

return Autofarm
