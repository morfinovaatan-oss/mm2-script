-- [[ MM2 ULTRA-FAST AUTO-FARM – No Pauses, Auto Start, Infinite Radius ]] --
local Autofarm = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local StarterGui = game:GetService("StarterGui")

-- Настройки
Autofarm.Config = {
    Enabled = false,
    WalkSpeed = 30,
    ResetAfterFullBag = true,
    AvoidMurderer = true,
    AvoidDistance = 50,
    FlyHeightOffset = -2.5,
    CollectionThreshold = 4.5,   -- расстояние, при котором монета считается собранной
    AutoStart = true,            -- автоматический старт при появлении монет и начале раунда
}

-- Внутренние переменные
local octree = nil
local touchedCoins = {}
local activeConnections = {}
local farming = false
local coinContainer = nil
local lastAvoidPosition = nil
local avoidReturnTime = 0
local avoidActive = false

-- ================== Загрузка Octree ==================
local function loadOctree()
    if octree then return true end
    local ok, result = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/Sleitnick/rbxts-octo-tree/main/src/init.lua")
    end)
    if not ok or not result then return false end
    local mod = loadstring(result)()
    if not mod then return false end
    octree = mod.new()
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
    return map and map:FindFirstChild("CoinContainer")
end

local function isRoundActive()
    -- Проверяем, что игрок в раунде (атрибут Alive или таймер на экране)
    if LocalPlayer:GetAttribute("Alive") then return true end
    local gui = LocalPlayer.PlayerGui:FindFirstChild("MainGUI")
    if gui and gui:FindFirstChild("Game") then
        if gui.Game:FindFirstChild("Timer") and gui.Game.Timer.Visible then
            return true
        end
        if gui.Game:FindFirstChild("EarnedXP") and gui.Game.EarnedXP.Visible then
            return true
        end
    end
    return false
end

local function isBagFull()
    local gui = LocalPlayer.PlayerGui:FindFirstChild("MainGUI")
    if not gui then return false end
    local coinsLabel = gui:FindFirstChild("Game") and gui.Game:FindFirstChild("CoinBags") 
        and gui.Game.CoinBags:FindFirstChild("Container") 
        and gui.Game.CoinBags.Container:FindFirstChild("SnowToken") 
        and gui.Game.CoinBags.Container.SnowToken:FindFirstChild("CurrencyFrame") 
        and gui.Game.CoinBags.Container.SnowToken.CurrencyFrame:FindFirstChild("Icon") 
        and gui.Game.CoinBags.Container.SnowToken.CurrencyFrame.Icon:FindFirstChild("Coins")
    if coinsLabel and coinsLabel:IsA("TextLabel") then
        local max = LocalPlayer:GetAttribute("Elite") and 50 or 40
        return tonumber(coinsLabel.Text) >= max
    end
    return false
end

local function findMurderer()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local hasKnife = p.Character:FindFirstChild("Knife") or (p:FindFirstChild("Backpack") and p.Backpack:FindFirstChild("Knife"))
            if hasKnife and p.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                return p
            end
        end
    end
    return nil
end

local function getRandomSafePosition()
    local spawns = Workspace:FindFirstChild("Spawns", true)
    if spawns then
        local children = spawns:GetChildren()
        if #children > 0 then
            return children[math.random(#children)]:GetPivot()
        end
    end
    return CFrame.new(-120, 135, 46)
end

-- ================== Управление Octree ==================
local function clearOctreeConnections()
    for _, conn in pairs(activeConnections) do
        if conn and conn.Connected then conn:Disconnect() end
    end
    table.clear(activeConnections)
end

local function setupCoinTracking(coin)
    if touchedCoins[coin] then return end
    local touchInterest = coin:FindFirstChildWhichIsA("TouchTransmitter")
    if touchInterest then
        local conn
        conn = touchInterest.AncestryChanged:Connect(function(_, parent)
            if parent == nil then
                touchedCoins[coin] = true
                if octree then
                    local node = octree:FindFirstNode(coin)
                    if node then octree:RemoveNode(node) end
                end
                if conn then conn:Disconnect() end
            end
        end)
        activeConnections[conn] = true
    end
end

local function addCoinToOctree(coin)
    if not octree or touchedCoins[coin] then return end
    local existing = octree:FindFirstNode(coin)
    if not existing then
        octree:CreateNode(coin.Position, coin)
        setupCoinTracking(coin)
    end
end

local function removeCoinFromOctree(coin)
    if not octree then return end
    local node = octree:FindFirstNode(coin)
    if node then
        octree:RemoveNode(node)
    end
    touchedCoins[coin] = true
end

local function populateOctree()
    if not octree or not coinContainer then return end
    octree:ClearAllNodes()
    table.clear(touchedCoins)
    for _, desc in ipairs(coinContainer:GetDescendants()) do
        if desc:IsA("TouchTransmitter") then
            local coin = desc.Parent
            addCoinToOctree(coin)
        end
    end

    clearOctreeConnections()
    local addConn = coinContainer.DescendantAdded:Connect(function(desc)
        if desc:IsA("TouchTransmitter") then
            addCoinToOctree(desc.Parent)
        end
    end)
    local removeConn = coinContainer.DescendantRemoving:Connect(function(desc)
        if desc:IsA("TouchTransmitter") then
            removeCoinFromOctree(desc.Parent)
        end
    end)
    activeConnections[addConn] = true
    activeConnections[removeConn] = true
end

-- ================== Движение без остановок ==================
local function getNextCoinPosition()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
    local root = char.HumanoidRootPart
    if not octree then return nil end

    local nearest = octree:GetNearest(root.Position, 5000, 1)
    if nearest and #nearest > 0 then
        local coin = nearest[1].Object
        if not touchedCoins[coin] then
            local targetPos = coin.Position + Vector3.new(0, Autofarm.Config.FlyHeightOffset, 0)
            local dist = (root.Position - targetPos).Magnitude
            return targetPos, coin, dist
        end
    end
    return nil, nil, nil
end

local function avoidMurderer()
    if not Autofarm.Config.AvoidMurderer then return false end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return false end
    local root = char.HumanoidRootPart
    local murderer = findMurderer()
    if murderer and murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart") then
        local dist = (root.Position - murderer.Character.HumanoidRootPart.Position).Magnitude
        if dist < Autofarm.Config.AvoidDistance then
            lastAvoidPosition = root.CFrame
            local safePos = getRandomSafePosition()
            if safePos then
                char:PivotTo(safePos)
            end
            avoidReturnTime = tick() + 4
            avoidActive = true
            return true
        end
    end
    -- Возврат через 4 секунды
    if avoidActive and tick() >= avoidReturnTime then
        if lastAvoidPosition and char and char:FindFirstChild("HumanoidRootPart") then
            char:PivotTo(lastAvoidPosition)
        end
        avoidActive = false
    end
    return false
end

local function resetCharacter()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChildOfClass("Humanoid") then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    hum.Health = 0
    repeat task.wait(0.5) until LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") and LocalPlayer.Character:FindFirstChildOfClass("Humanoid").Health > 0
    task.wait(1)
end

-- ================== Главный цикл ==================
local function farmLoop()
    while farming do
        -- Если не в раунде, ждём
        if not isRoundActive() then
            task.wait(0.5)
            continue
        end

        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            task.wait(0.5)
            continue
        end
        local root = char.HumanoidRootPart

        -- Проверка полного мешка
        if isBagFull() then
            if Autofarm.Config.ResetAfterFullBag then
                resetCharacter()
                -- После воскрешения Octree обновится, но farming остаётся true, продолжаем
            else
                Autofarm.Config.Enabled = false
                farming = false
                break
            end
        end

        -- Избегание мёрдера (может телепортировать и активировать таймер)
        avoidMurderer()

        -- Если активно избегание, стоим на месте до истечения таймера
        if avoidActive and tick() < avoidReturnTime then
            task.wait(0.1)
            continue
        elseif avoidActive then
            -- возврат уже произошёл в avoidMurderer, сбрасываем
            avoidActive = false
        end

        -- Получаем ближайшую монету
        local targetPos, coin, dist = getNextCoinPosition()
        if not targetPos or not coin then
            task.wait(0.2)
            continue
        end

        -- Движение к монете
        local moveDir = (targetPos - root.Position).Unit
        local moveStep = Autofarm.Config.WalkSpeed * 0.05
        local newPos = root.Position + moveDir * moveStep
        local lookAt = CFrame.new(newPos, newPos + moveDir)
        char:PivotTo(lookAt)

        -- Если достаточно близко, помечаем монету собранной и переходим к следующей
        if dist <= Autofarm.Config.CollectionThreshold then
            touchedCoins[coin] = true
            if octree then
                local node = octree:FindFirstNode(coin)
                if node then octree:RemoveNode(node) end
            end
        end

        task.wait(0.05)
    end

    -- Остановка: очистка ресурсов
    clearOctreeConnections()
    if octree then octree:ClearAllNodes() end
end

local function startFarming()
    if farming then return end
    if not loadOctree() then return end
    coinContainer = getCoinContainer()
    if not coinContainer then return end
    populateOctree()
    farming = true
    task.spawn(farmLoop)
end

local function stopFarming()
    farming = false
    Autofarm.Config.Enabled = false
    clearOctreeConnections()
    if octree then octree:ClearAllNodes() end
end

-- ================== Автостарт ==================
-- Если включён AutoStart, при включении тоггла начинаем мониторинг условий
-- и автоматически запускаем фарм, когда появляется возможность.
local autoStartConnection = nil
local function setupAutoStart()
    if autoStartConnection then autoStartConnection:Disconnect() end
    if not Autofarm.Config.AutoStart or not Autofarm.Config.Enabled then return end

    autoStartConnection = RunService.Heartbeat:Connect(function()
        if farming then return end
        if not Autofarm.Config.Enabled then return end
        if not isRoundActive() then return end
        if not getCoinContainer() then return end
        -- Проверим, есть ли монеты
        if getNextCoinPosition() then
            startFarming()
        end
    end)
end

-- ================== UI ==================
function Autofarm.Init(GlobalConfig, UI, Lang)
    local T = {
        RU = {
            TabName = "💰 Автофарм",
            Enable = "Включить автофарм",
            AutoStart = "Автостарт",
            Speed = "Скорость",
            ResetAfter = "Ресет после полного мешка",
            Avoid = "Избегать мёрдера",
            AvoidDist = "Дистанция избегания",
        },
        EN = {
            TabName = "💰 AutoFarm",
            Enable = "Enable AutoFarm",
            AutoStart = "Auto Start",
            Speed = "Speed",
            ResetAfter = "Reset after full bag",
            Avoid = "Avoid Murderer",
            AvoidDist = "Avoid Distance",
        }
    }
    local text = T[Lang] or T.RU
    local FarmTab = UI:CreateTab(text.TabName)

    local enableToggle = FarmTab:AddToggle({
        Title = text.Enable,
        Default = false,
        Callback = function(val)
            Autofarm.Config.Enabled = val
            if val then
                -- Если включён AutoStart, запустим мониторинг, иначе начнём сразу (если возможно)
                if Autofarm.Config.AutoStart then
                    setupAutoStart()
                else
                    if isRoundActive() and getCoinContainer() then
                        startFarming()
                    end
                end
            else
                stopFarming()
                if autoStartConnection then
                    autoStartConnection:Disconnect()
                    autoStartConnection = nil
                end
            end
        end
    })

    FarmTab:AddToggle({
        Title = text.AutoStart,
        Default = Autofarm.Config.AutoStart,
        Callback = function(val)
            Autofarm.Config.AutoStart = val
            if val and Autofarm.Config.Enabled then
                setupAutoStart()
            elseif not val and autoStartConnection then
                autoStartConnection:Disconnect()
                autoStartConnection = nil
            end
        end
    })

    FarmTab:AddNumberInput({
        Title = text.Speed,
        Min = 10,
        Max = 60,
        Default = Autofarm.Config.WalkSpeed,
        Callback = function(v) Autofarm.Config.WalkSpeed = v end
    })

    FarmTab:AddToggle({
        Title = text.ResetAfter,
        Default = Autofarm.Config.ResetAfterFullBag,
        Callback = function(v) Autofarm.Config.ResetAfterFullBag = v end
    })

    FarmTab:AddToggle({
        Title = text.Avoid,
        Default = Autofarm.Config.AvoidMurderer,
        Callback = function(v) Autofarm.Config.AvoidMurderer = v end
    })

    FarmTab:AddNumberInput({
        Title = text.AvoidDist,
        Min = 20,
        Max = 100,
        Default = Autofarm.Config.AvoidDistance,
        Callback = function(v) Autofarm.Config.AvoidDistance = v end
    })
end

return Autofarm
