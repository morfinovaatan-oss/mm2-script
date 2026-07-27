-- [[ MM2 AUTOFARM MODULE – Enhanced with Octree & Smart Checks ]] --
local Autofarm = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")

-- Конфигурация (значения по умолчанию)
Autofarm.Config = {
    Enabled = false,
    Radius = 120,           -- радиус поиска монет
    WalkSpeed = 20,         -- скорость перемещения к монете (studs/s)
    TpBackToStart = true,   -- возвращаться на стартовую позицию после наполнения мешка
    Uninterrupted = false,  -- умереть перед фармом для безопасности
    AutoAction = true,      -- выполнять роль-действие при полном мешке
}

-- Внутренние переменные
local octree = nil
local touchedCoins = {}
local positionChangeConnections = {}
local farmingLoop = nil
local startPosition = nil
local coinContainer = nil
local AddedConn, RemovingConn = nil, nil
local characterConnection = nil

-- ================== Загрузка Octree ==================
local function loadOctree()
    if octree then return true end
    local success, result = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/Sleitnick/rbxts-octo-tree/main/src/init.lua")
    end)
    if not success or not result then
        warn("Не удалось загрузить Octree")
        return false
    end
    local octreeModule = loadstring(result)()
    if not octreeModule then return false end
    octree = octreeModule.new()
    return true
end

-- ================== Помощники ==================
local function getMap()
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v.Name == "Spawns" and v.Parent.Name ~= "Lobby" then
            return v.Parent
        end
    end
    return nil
end

local function getCoinContainer()
    local map = getMap()
    if map then
        return map:FindFirstChild("CoinContainer")
    end
    return nil
end

local function getRole()
    local char = LocalPlayer.Character
    if not char then return "Innocent" end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if char:FindFirstChild("Knife") or (backpack and backpack:FindFirstChild("Knife")) then
        return "Murderer"
    end
    if char:FindFirstChild("Gun") or char:FindFirstChild("Revolver") or (backpack and (backpack:FindFirstChild("Gun") or backpack:FindFirstChild("Revolver"))) then
        return "Sheriff"
    end
    return "Innocent"
end

local function findMurderer()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local hasKnife = player.Character:FindFirstChild("Knife") or (player:FindFirstChild("Backpack") and player.Backpack:FindFirstChild("Knife"))
            if hasKnife and player.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                return player
            end
        end
    end
    return nil
end

-- Простой флинг (телепорт + вращение)
local function flingPlayer(player)
    if not player or not player.Character then return end
    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot or not targetRoot then return end
    myRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 1.5, 0)
    task.wait(0.05)
    local start = tick()
    local conn
    conn = RunService.Stepped:Connect(function(_, dt)
        if tick() - start > 0.25 or not myRoot.Parent or not targetRoot.Parent then
            conn:Disconnect()
            return
        end
        myRoot.CFrame = targetRoot.CFrame * CFrame.Angles(0, math.rad(20), 0) + Vector3.new(0, 0.5, 0)
    end)
end

-- Действие шерифа: телепорт за спину мёрдера + выстрел
local function sheriffAction()
    local murderer = findMurderer()
    if not murderer then return end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local mRoot = murderer.Character.HumanoidRootPart
    local mHead = murderer.Character:FindFirstChild("Head")
    local behindPos = mRoot.Position - (mRoot.CFrame.LookVector * 15)
    root.CFrame = CFrame.new(behindPos, mRoot.Position)
    if mHead then
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, mHead.Position)
    end
    task.wait(0.1)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    task.wait(0.02)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
end

local function murdererAction()
    -- Заглушка
    if StarterGui then
        StarterGui:SetCore("SendNotification", {
            Title = "Автофарм",
            Text = "Действие для Murderer пока в разработке",
            Duration = 3
        })
    end
end

-- ================== Работа с Octree и монетами ==================
local function isCoinTouched(coin)
    return touchedCoins[coin] == true
end

local function markCoinAsTouched(coin)
    touchedCoins[coin] = true
    if octree then
        local node = octree:FindFirstNode(coin)
        if node then
            octree:RemoveNode(node)
        end
    end
end

local function setupTouchTracking(coin)
    local touchInterest = coin:FindFirstChildWhichIsA("TouchTransmitter")
    if touchInterest then
        local conn
        conn = touchInterest.AncestryChanged:Connect(function(_, parent)
            if parent == nil then
                markCoinAsTouched(coin)
                if conn then conn:Disconnect() end
            end
        end)
        positionChangeConnections[coin] = conn
    end
end

local function setupPositionTracking(coin)
    local lastY = coin.Position.Y
    local conn
    conn = coin:GetPropertyChangedSignal("Position"):Connect(function()
        if coin.Position.Y ~= lastY then
            markCoinAsTouched(coin)
            if conn then conn:Disconnect() end
            coin:Destroy()
        end
    end)
    positionChangeConnections[coin] = conn
end

local function populateOctree()
    if not octree then return end
    octree:ClearAllNodes()
    for _, desc in ipairs(coinContainer:GetDescendants()) do
        if desc:IsA("TouchTransmitter") then
            local coin = desc.Parent
            if not isCoinTouched(coin) then
                octree:CreateNode(coin.Position, coin)
                setupTouchTracking(coin)
            end
            setupPositionTracking(coin)
        end
    end
    -- Слушаем добавление новых монет
    AddedConn = coinContainer.DescendantAdded:Connect(function(desc)
        if desc:IsA("TouchTransmitter") then
            local coin = desc.Parent
            if not isCoinTouched(coin) then
                octree:CreateNode(coin.Position, coin)
                setupTouchTracking(coin)
                setupPositionTracking(coin)
            end
        end
    end)
    RemovingConn = coinContainer.DescendantRemoving:Connect(function(desc)
        if desc:IsA("TouchTransmitter") and desc.Parent.Name == "Coin_Server" then
            markCoinAsTouched(desc.Parent)
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
        char:PivotTo(CFrame.new(startPos:Lerp(targetPos, alpha)))
        if alpha >= 1 then
            task.wait(0.2)
            break
        end
        task.wait()
    end
end

local function checkFullBag()
    local gui = LocalPlayer.PlayerGui:FindFirstChild("MainGUI")
    if not gui then return false end
    local coinsLabel = gui:FindFirstChild("Game") and gui.Game:FindFirstChild("CoinBags") 
        and gui.Game.CoinBags:FindFirstChild("Container") 
        and gui.Game.CoinBags.Container:FindFirstChild("SnowToken") 
        and gui.Game.CoinBags.Container.SnowToken:FindFirstChild("CurrencyFrame") 
        and gui.Game.CoinBags.Container.SnowToken.CurrencyFrame:FindFirstChild("Icon") 
        and gui.Game.CoinBags.Container.SnowToken.CurrencyFrame.Icon:FindFirstChild("Coins")
    if coinsLabel and coinsLabel:IsA("TextLabel") then
        local maxCoins = 40
        if LocalPlayer:GetAttribute("Elite") then maxCoins = 50 end
        return coinsLabel.Text == tostring(maxCoins)
    end
    -- Fallback: если GUI не найден, считаем что мешок полон, когда нет монет
    if octree then
        local nearest = octree:GetNearest(LocalPlayer.Character and LocalPlayer.Character.PrimaryPart and LocalPlayer.Character.PrimaryPart.Position or Vector3.zero, 10000, 1)
        return #nearest == 0
    end
    return false
end

-- ================== Основной цикл фарма ==================
local function collectCoins()
    local char = LocalPlayer.Character
    if not char or not char.PrimaryPart then return end

    -- Сохраняем стартовую позицию, если ещё нет
    if not startPosition then
        startPosition = char:GetPivot()
    end

    while Autofarm.Config.Enabled do
        if checkFullBag() then
            if Autofarm.Config.AutoAction then
                local role = getRole()
                if role == "Innocent" then
                    flingPlayer(findMurderer())
                elseif role == "Sheriff" then
                    sheriffAction()
                elseif role == "Murderer" then
                    murdererAction()
                end
            end
            if Autofarm.Config.TpBackToStart and startPosition then
                char:PivotTo(startPosition)
            end
            -- Очистка и выход из цикла (запускаем заново при следующем включении)
            Autofarm.Config.Enabled = false
            farmingLoop = nil
            return
        end

        if not octree then break end

        local nearest = octree:GetNearest(char.PrimaryPart.Position, Autofarm.Config.Radius, 1)
        if nearest and #nearest > 0 then
            local node = nearest[1]
            local coin = node.Object
            if not isCoinTouched(coin) then
                local dist = (char.PrimaryPart.Position - coin.Position).Magnitude
                local duration = dist / Autofarm.Config.WalkSpeed
                moveToPositionSlowly(coin.Position, duration)
                -- Ждём, пока сработает касание
                markCoinAsTouched(coin)
                task.wait(0.2)
            end
        else
            task.wait(0.5)
        end
    end
end

local function startFarming()
    if farmingLoop then return end
    if not loadOctree() then return end

    coinContainer = getCoinContainer()
    if not coinContainer then
        warn("CoinContainer не найден")
        return
    end

    -- При Uninterrupted: убиваем себя, ждём возрождения, телепортируемся к мёрдеру
    if Autofarm.Config.Uninterrupted then
        local char = LocalPlayer.Character
        if char and char:FindFirstChildOfClass("Humanoid") then
            char:FindFirstChildOfClass("Humanoid").Health = 0
            repeat task.wait() until LocalPlayer.CharacterAdded:Wait()
            task.wait(1)
            local murderer = findMurderer()
            if murderer then
                LocalPlayer.Character:PivotTo(murderer.Character:GetPivot())
            end
        end
    end

    populateOctree()
    farmingLoop = task.spawn(collectCoins)
end

local function stopFarming()
    Autofarm.Config.Enabled = false
    if farmingLoop then
        farmingLoop = nil
    end
    -- Отключаем все соединения
    for _, conn in pairs(positionChangeConnections) do
        if conn.Connected then conn:Disconnect() end
    end
    table.clear(positionChangeConnections)
    table.clear(touchedCoins)
    if AddedConn then AddedConn:Disconnect(); AddedConn = nil end
    if RemovingConn then RemovingConn:Disconnect(); RemovingConn = nil end
    if octree then
        octree:ClearAllNodes()
        octree = nil
    end
    -- Возвращаемся на стартовую позицию, если нужно
    if Autofarm.Config.TpBackToStart and startPosition then
        local char = LocalPlayer.Character
        if char then
            char:PivotTo(startPosition)
        end
    end
end

-- Сброс при смерти персонажа
characterConnection = LocalPlayer.CharacterRemoving:Connect(function()
    if Autofarm.Config.Enabled then
        stopFarming()
    end
end)

-- ================== Инициализация UI ==================
function Autofarm.Init(GlobalConfig, UI, Lang)
    local T = {
        RU = {
            TabName = "💰 Автофарм",
            Enable = "Включить автофарм",
            Radius = "Радиус поиска",
            Speed = "Скорость движения",
            TpBack = "Возврат на старт",
            Uninterrupted = "Uninterrupted режим",
            AutoAction = "Действие при полном мешке",
            SetStart = "Запомнить позицию",
        },
        EN = {
            TabName = "💰 AutoFarm",
            Enable = "Enable AutoFarm",
            Radius = "Search Radius",
            Speed = "Movement Speed",
            TpBack = "Return to start",
            Uninterrupted = "Uninterrupted mode",
            AutoAction = "Action on full bag",
            SetStart = "Set current position",
        }
    }
    local text = T[Lang] or T.RU

    local FarmTab = UI:CreateTab(text.TabName)

    -- Включение/выключение
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

    -- Радиус поиска
    FarmTab:AddNumberInput({
        Title = text.Radius,
        Min = 50,
        Max = 400,
        Default = Autofarm.Config.Radius,
        Callback = function(v)
            Autofarm.Config.Radius = v
        end
    })

    -- Скорость движения
    FarmTab:AddNumberInput({
        Title = text.Speed,
        Min = 10,
        Max = 40,
        Default = Autofarm.Config.WalkSpeed,
        Callback = function(v)
            Autofarm.Config.WalkSpeed = v
        end
    })

    -- Возврат на старт
    FarmTab:AddToggle({
        Title = text.TpBack,
        Default = Autofarm.Config.TpBackToStart,
        Callback = function(v)
            Autofarm.Config.TpBackToStart = v
        end
    })

    -- Uninterrupted
    FarmTab:AddToggle({
        Title = text.Uninterrupted,
        Default = Autofarm.Config.Uninterrupted,
        Callback = function(v)
            Autofarm.Config.Uninterrupted = v
        end
    })

    -- Автодействие при полном мешке
    FarmTab:AddToggle({
        Title = text.AutoAction,
        Default = Autofarm.Config.AutoAction,
        Callback = function(v)
            Autofarm.Config.AutoAction = v
        end
    })

    -- Кнопка запомнить текущую позицию
    FarmTab:AddButton(text.SetStart, function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            startPosition = char:GetPivot()
            if UI and UI.Notification then
                UI:Notification("AutoFarm", "Позиция сохранена!", 2)
            end
        end
    end)
end

return Autofarm
