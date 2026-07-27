-- [[ MM2 SIMPLE AUTO-FARM – Octree, Reset & Avoid Murderer ]] --
local Autofarm = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local StarterGui = game:GetService("StarterGui")

-- Настройки
Autofarm.Config = {
    Enabled = false,
    Radius = 120,
    WalkSpeed = 20,
    ResetAfterFullBag = true,   -- умереть и возродиться после полного мешка
    AvoidMurderer = true,       -- избегать мёрдера
    AvoidDistance = 50,         -- дистанция срабатывания избегания
}

-- Внутренние переменные
local octree = nil
local touchedCoins = {}
local farming = false
local coinContainer = nil

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

local function isBagFull()
    local gui = LocalPlayer.PlayerGui:FindFirstChild("MainGUI")
    if not gui then return false end
    local coins = gui:FindFirstChild("Game") and gui.Game:FindFirstChild("CoinBags") 
        and gui.Game.CoinBags:FindFirstChild("Container") 
        and gui.Game.CoinBags.Container:FindFirstChild("SnowToken") 
        and gui.Game.CoinBags.Container.SnowToken:FindFirstChild("CurrencyFrame") 
        and gui.Game.CoinBags.Container.SnowToken.CurrencyFrame:FindFirstChild("Icon") 
        and gui.Game.CoinBags.Container.SnowToken.CurrencyFrame.Icon:FindFirstChild("Coins")
    if coins and coins:IsA("TextLabel") then
        local max = LocalPlayer:GetAttribute("Elite") and 50 or 40
        return tonumber(coins.Text) >= max
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
    -- Простой вариант: вернуться в зону спавна (первая точка SpawnLocation)
    local spawns = Workspace:FindFirstChild("Spawns", true)
    if spawns then
        local children = spawns:GetChildren()
        if #children > 0 then
            return children[math.random(#children)]:GetPivot()
        end
    end
    -- Запасной вариант: центр карты (примерные координаты MM2)
    return CFrame.new(-120, 135, 46)
end

-- ================== Управление монетами ==================
local function isCoinTouched(coin)
    return touchedCoins[coin] == true
end

local function markCoinAsTouched(coin)
    touchedCoins[coin] = true
    if octree then
        local node = octree:FindFirstNode(coin)
        if node then octree:RemoveNode(node) end
    end
end

local function populateOctree()
    if not octree or not coinContainer then return end
    octree:ClearAllNodes()
    for _, desc in ipairs(coinContainer:GetDescendants()) do
        if desc:IsA("TouchTransmitter") then
            local coin = desc.Parent
            if not isCoinTouched(coin) then
                octree:CreateNode(coin.Position, coin)
            end
        end
    end
end

local function moveToCoin(targetPos, duration)
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

-- ================== Основной цикл ==================
local function startFarming()
    if farming then return end
    if not loadOctree() then return end
    coinContainer = getCoinContainer()
    if not coinContainer then return end
    populateOctree()
    farming = true

    while farming and Autofarm.Config.Enabled do
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") or not char:FindFirstChildOfClass("Humanoid") or char:FindFirstChildOfClass("Humanoid").Health <= 0 then
            task.wait(1)
            continue
        end

        -- Избегание мёрдера
        if Autofarm.Config.AvoidMurderer then
            local murderer = findMurderer()
            if murderer and murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart") then
                local dist = (char.HumanoidRootPart.Position - murderer.Character.HumanoidRootPart.Position).Magnitude
                if dist < Autofarm.Config.AvoidDistance then
                    -- Телепортируемся в безопасное место
                    local safePos = getRandomSafePosition()
                    if safePos then
                        char:PivotTo(safePos)
                    end
                    task.wait(0.5)
                    continue
                end
            end
        end

        -- Проверка заполнения мешка
        if isBagFull() then
            if Autofarm.Config.ResetAfterFullBag then
                -- Умереть и возродиться
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.Health = 0
                    repeat task.wait(0.5) until LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") and LocalPlayer.Character:FindFirstChildOfClass("Humanoid").Health > 0
                    task.wait(1)
                end
            else
                -- Просто остановить фарм
                Autofarm.Config.Enabled = false
                break
            end
        end

        -- Поиск и сбор монеты
        if octree then
            local nearest = octree:GetNearest(char.HumanoidRootPart.Position, Autofarm.Config.Radius, 1)
            if nearest and #nearest > 0 then
                local coin = nearest[1].Object
                if not isCoinTouched(coin) then
                    local dist = (char.HumanoidRootPart.Position - coin.Position).Magnitude
                    local duration = dist / Autofarm.Config.WalkSpeed
                    moveToCoin(coin.Position, duration)
                    markCoinAsTouched(coin)
                    task.wait(0.2)
                end
            else
                task.wait(0.5)
            end
        else
            task.wait(0.5)
        end
    end
    farming = false
    if octree then octree:ClearAllNodes() end
end

local function stopFarming()
    farming = false
    Autofarm.Config.Enabled = false
    if octree then
        octree:ClearAllNodes()
    end
end

-- ================== Подключение UI ==================
function Autofarm.Init(GlobalConfig, UI, Lang)
    local T = {
        RU = {
            TabName = "💰 Автофарм",
            Enable = "Включить автофарм",
            Radius = "Радиус поиска",
            Speed = "Скорость движения",
            ResetAfter = "Ресет после полного мешка",
            Avoid = "Избегать мёрдера",
            AvoidDist = "Дистанция избегания",
        },
        EN = {
            TabName = "💰 AutoFarm",
            Enable = "Enable AutoFarm",
            Radius = "Search Radius",
            Speed = "Movement Speed",
            ResetAfter = "Reset after full bag",
            Avoid = "Avoid Murderer",
            AvoidDist = "Avoid Distance",
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
        Title = text.Radius,
        Min = 50,
        Max = 400,
        Default = Autofarm.Config.Radius,
        Callback = function(v) Autofarm.Config.Radius = v end
    })

    FarmTab:AddNumberInput({
        Title = text.Speed,
        Min = 10,
        Max = 40,
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
