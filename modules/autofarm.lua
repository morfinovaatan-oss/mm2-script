-- [[ MM2 SIMPLE AUTO-FARM – Based on Zynic's working core ]] --
local Autofarm = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Минимальные настройки (фиксированные, не меняются через UI)
local RADIUS = 200
local WALKSPEED = 30
local TP_BACK_TO_START = true

-- Octree и контейнеры
local octree = nil
local coinContainer = nil
local touchedCoins = {}
local positionConnections = {}
local addConn, remConn = nil, nil
local farming = false
local farmThread = nil

-- Проверка, что раунд идёт (есть карта и игрок жив)
local function isRoundActive()
    if not LocalPlayer.Character then return false end
    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v.Name == "Spawns" and v.Parent.Name ~= "Lobby" then
            return true
        end
    end
    return false
end

-- Поиск карты (как у Zynic)
local function getMap()
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v.Name == "Base" then
            return v.Parent
        end
    end
    return nil
end

-- Загрузка Octree
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

-- Управление метками монет
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

-- Отслеживание касаний и позиций (как у Zynic)
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

-- Заполнение Octree
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
    -- Убираем старые соединения, если есть
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

-- Плавное движение к точке (как у Zynic)
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

-- Основная логика сбора монет
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
        -- Проверка полного мешка (как у Zynic – через FullBagIcon.Visible)
        local fullBagIcon = gui:FindFirstChild("Game") and gui.Game:FindFirstChild("CoinBags") 
            and gui.Game.CoinBags:FindFirstChild("Container") 
            and gui.Game.CoinBags.Container:FindFirstChild("SnowToken") 
            and gui.Game.CoinBags.Container.SnowToken:FindFirstChild("FullBagIcon")
        if fullBagIcon and fullBagIcon.Visible then
            farming = false
            break
        end

        -- Поиск ближайшей монеты
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

    -- Возврат на стартовую позицию
    if TP_BACK_TO_START and waypoint then
        local char = LocalPlayer.Character
        if char then
            char:PivotTo(waypoint)
        end
    end

    -- Очистка
    if addConn then addConn:Disconnect(); addConn = nil end
    if remConn then remConn:Disconnect(); remConn = nil end
    for _, conn in pairs(positionConnections) do
        if conn and conn.Connected then conn:Disconnect() end
    end
    table.clear(positionConnections)
    if octree then octree:ClearAllNodes() end
end

-- Цикл ожидания раунда и запуска сбора
local function farmLoop()
    while farming do
        if not isRoundActive() then
            task.wait(1)
            continue
        end
        -- Загружаем Octree при необходимости
        if not loadOctree() then
            task.wait(2)
            continue
        end
        collectCoins()
        -- После выхода из collectCoins (полный мешок или farming = false) ждём перед новой попыткой
        task.wait(1)
    end
end

-- Старт / Стоп
local function startFarming()
    if farming then return end
    farming = true
    farmThread = task.spawn(farmLoop)
end

local function stopFarming()
    farming = false
    if farmThread then
        farmThread = nil
    end
    if addConn then addConn:Disconnect(); addConn = nil end
    if remConn then remConn:Disconnect(); remConn = nil end
    for _, conn in pairs(positionConnections) do
        if conn and conn.Connected then conn:Disconnect() end
    end
    table.clear(positionConnections)
    if octree then octree:ClearAllNodes() end
end

-- UI инициализация
function Autofarm.Init(GlobalConfig, UI, Lang)
    local T = {
        RU = { TabName = "💰 Автофарм", Enable = "Включить автофарм" },
        EN = { TabName = "💰 AutoFarm", Enable = "Enable AutoFarm" }
    }
    local text = T[Lang] or T.RU
    local FarmTab = UI:CreateTab(text.TabName)

    FarmTab:AddToggle({
        Title = text.Enable,
        Default = false,
        Callback = function(val)
            if val then
                startFarming()
            else
                stopFarming()
            end
        end
    })
end

return Autofarm
