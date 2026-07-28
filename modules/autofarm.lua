-- [[ MM2 AUTO‑FARM – Reliable State Machine (Zynic core) ]] --
local Autofarm = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local StarterGui = game:GetService("StarterGui")

-- Настройки (фиксированные, как в оригинале)
local RADIUS = 200
local WALKSPEED = 30

-- Состояния конечного автомата
local State = {
    WaitingForRound = "WaitingForRound",
    Action = "Action",
    WaitingForRoundEnd = "WaitingForRoundEnd",
    RespawnState = "RespawnState",
    StandStillWait = "StandStillWait"
}

-- Внутренние переменные
local octree = nil
local rt = {}   -- эмуляция объекта rt из Zynic (частичная)
rt.octree = nil
rt.coinContainer = nil
rt.touchedCoins = {}
rt.positionChangeConnections = {}
rt.Added = nil
rt.Removing = nil
rt.RoundInProgress = false
rt.radius = RADIUS
rt.walkspeed = WALKSPEED

local CurrentState = State.WaitingForRound
local LastPosition = nil
local IsMurderer = false
local Working = false
local BagIsFull = false

-- Ссылки на GUI игры
local ROUND_TIMER = Workspace:WaitForChild("RoundTimerPart").SurfaceGui.Timer
local PLAYER_GUI = LocalPlayer:WaitForChild("PlayerGui")

-- Функция для отправки уведомлений (используем стандартный StarterGui, чтобы не зависеть от UI модуля)
local function Message(title, text, duration)
    duration = duration or 2
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration
        })
    end)
end

-- ====================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ======================
local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function waitForCharacter()
    repeat task.wait(0.02) until getCharacter() ~= nil
end

local function isRoundActive()
    if not PLAYER_GUI:FindFirstChild("MainGUI") then return false end
    local mainGui = PLAYER_GUI.MainGUI
    if mainGui.Game.Timer.Visible then return true end
    if mainGui.Game.EarnedXP.Visible then return true end
    return false
end

local function getMap()
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v.Name == "Spawns" and v.Parent.Name ~= "Lobby" then
            return v.Parent
        end
    end
    return nil
end

local function disconnect(conn)
    if conn and conn.Connected then
        conn:Disconnect()
    end
end

-- ====================== OCTREE И МОНЕТЫ ======================
local function loadOctree()
    if octree then return true end
    local ok, res = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/Sleitnick/rbxts-octo-tree/main/src/init.lua")
    end)
    if not ok or not res then return false end
    local mod = loadstring(res)()
    if not mod then return false end
    octree = mod.new()
    rt.octree = octree
    return true
end

local function isCoinTouched(coin)
    return rt.touchedCoins[coin] == true
end

local function markCoinAsTouched(coin)
    rt.touchedCoins[coin] = true
    if octree then
        local node = octree:FindFirstNode(coin)
        if node then octree:RemoveNode(node) end
    end
end

local function setupTouchTracking(coin)
    local touchInterest = coin:FindFirstChildWhichIsA("TouchTransmitter")
    if not touchInterest then return end
    local conn
    conn = touchInterest.AncestryChanged:Connect(function(_, parent)
        if parent == nil then
            markCoinAsTouched(coin)
            disconnect(conn)
        end
    end)
    rt.positionChangeConnections[coin] = conn
end

local function setupPositionTracking(coin)
    local lastY = coin.Position.Y
    local conn
    conn = coin:GetPropertyChangedSignal("Position"):Connect(function()
        if coin.Position.Y ~= lastY then
            markCoinAsTouched(coin)
            disconnect(conn)
            coin:Destroy()
        end
    end)
    rt.positionChangeConnections[coin] = conn
end

local function populateOctree()
    if not octree or not rt.coinContainer then return end
    octree:ClearAllNodes()
    table.clear(rt.touchedCoins)
    for _, desc in ipairs(rt.coinContainer:GetDescendants()) do
        if desc:IsA("TouchTransmitter") then
            local coin = desc.Parent
            if not isCoinTouched(coin) then
                octree:CreateNode(coin.Position, coin)
                setupTouchTracking(coin)
            end
            setupPositionTracking(coin)
        end
    end
    disconnect(rt.Added)
    disconnect(rt.Removing)
    rt.Added = rt.coinContainer.DescendantAdded:Connect(function(desc)
        if desc:IsA("TouchTransmitter") then
            local coin = desc.Parent
            if not isCoinTouched(coin) then
                octree:CreateNode(coin.Position, coin)
                setupTouchTracking(coin)
                setupPositionTracking(coin)
            end
        end
    end)
    rt.Removing = rt.coinContainer.DescendantRemoving:Connect(function(desc)
        if desc:IsA("TouchTransmitter") and desc.Parent.Name == "Coin_Server" then
            markCoinAsTouched(desc.Parent)
        end
    end)
end

local function moveToPositionSlowly(targetPos, duration)
    local char = getCharacter()
    if not char or not char.PrimaryPart then return end
    local startPos = char.PrimaryPart.Position
    local startTime = tick()

    -- Если ближайшая монета изменилась, обновляем цель
    if octree then
        local nearest = octree:GetNearest(startPos, rt.radius, 1)
        if nearest and #nearest > 0 then
            local coin = nearest[1].Object
            if not isCoinTouched(coin) then
                targetPos = coin.Position
            end
        end
    end

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

local function autoFarmCleanUp()
    if next(rt.positionChangeConnections) == nil then return end
    for _, conn in pairs(rt.positionChangeConnections) do
        disconnect(conn)
    end
    disconnect(rt.Added)
    disconnect(rt.Removing)
    table.clear(rt.touchedCoins)
    table.clear(rt.positionChangeConnections)
    if octree then octree:ClearAllNodes() end
end

-- ====================== ДЕЙСТВИЯ ПО СОСТОЯНИЯМ ======================
local function ChangeState(newState)
    CurrentState = newState
end

local function CheckMurderer()
    return IsMurderer
end

local function IsBagFull()
    local playerGui = PLAYER_GUI:WaitForChild("MainGUI")
    local coinText = playerGui.Game.CoinBags.Container.SnowToken.CurrencyFrame.Icon.Coins.Text
    local maxCoins = LocalPlayer:GetAttribute("Elite") and 50 or 40
    return tonumber(coinText) >= maxCoins
end

local function CollectCoins()
    Working = true
    rt.coinContainer = getMap():FindFirstChild("CoinContainer")
    if not rt.coinContainer then Working = false; return end
    populateOctree()

    while CurrentState == State.Action do
        if IsBagFull() then
            Message("AutoFarm", "Bag is full!", 2)
            BagIsFull = true
            break
        end

        if not getCharacter() then break end

        local char = getCharacter()
        if not char.PrimaryPart then break end
        local nearest = octree:GetNearest(char.PrimaryPart.Position, rt.radius, 1)
        if nearest and #nearest > 0 then
            local coin = nearest[1].Object
            if not isCoinTouched(coin) then
                local targetPos = coin.Position
                local dist = (char.PrimaryPart.Position - targetPos).Magnitude
                local duration = dist / rt.walkspeed
                moveToPositionSlowly(targetPos, duration)
                markCoinAsTouched(coin)
                task.wait(0.2)
            end
        else
            task.wait(1)
        end
    end
    autoFarmCleanUp()
end

local function WaitingForRound()
    Working = false
    repeat task.wait(0.5) until rt.RoundInProgress and isRoundActive()
    ChangeState(State.Action)
end

local function WaitForRoundEnd()
    Working = false
    if getCharacter() and getCharacter():FindFirstChildOfClass("Humanoid") then
        getCharacter():FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Dead)
    end
    repeat task.wait(1) until not rt.RoundInProgress
    ChangeState(State.WaitingForRound)
end

local function RespawnState()
    waitForCharacter()
    task.wait(1)
    if LastPosition then
        local char = getCharacter()
        if char then char:PivotTo(LastPosition) end
    end
    if not rt.RoundInProgress then
        ChangeState(State.WaitingForRound)
        return
    end
    ChangeState(State.Action)
end

local function StandStillWait()
    Message("AutoFarm", "Waiting for murderer to respawn", 2)
    ChangeState("Nothing")
    waitForCharacter()
    task.wait(2)
    ChangeState(State.WaitingForRound)
end

local function ActionState()
    LastPosition = nil
    if CheckMurderer() then
        Message("AutoFarm", "You are the Murderer! Collecting coins...", 2)
        CollectCoins()
    else
        CollectCoins()
    end

    if BagIsFull or not rt.RoundInProgress then
        if CheckMurderer() then
            BagIsFull = false
            Working = false
            rt.RoundInProgress = false
            if getCharacter() and getCharacter():FindFirstChildOfClass("Humanoid") then
                getCharacter():FindFirstChildOfClass("Humanoid").Health = 0
            end
        else
            BagIsFull = false
            Working = false
            if getCharacter() and getCharacter():FindFirstChildOfClass("Humanoid") then
                getCharacter():FindFirstChildOfClass("Humanoid").Health = 0
            end
            ChangeState(State.WaitingForRoundEnd)
        end
    end
end

-- ====================== ГЛАВНЫЙ ЦИКЛ ======================
local function mainLoop()
    while true do
        if CurrentState == State.WaitingForRound then
            WaitingForRound()
        elseif CurrentState == State.Action then
            ActionState()
        elseif CurrentState == State.WaitingForRoundEnd then
            WaitForRoundEnd()
        elseif CurrentState == State.RespawnState then
            RespawnState()
        elseif CurrentState == State.StandStillWait then
            StandStillWait()
        end
        task.wait(0.5)
    end
end

-- ====================== ПОДКЛЮЧЕНИЕ СОБЫТИЙ ======================
LocalPlayer.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("Tool") and descendant.Name == "Knife" then
        IsMurderer = true
    end
end)

ROUND_TIMER:GetPropertyChangedSignal("Text"):Connect(function()
    rt.RoundInProgress = true
end)

PLAYER_GUI.ChildAdded:Connect(function(child)
    if child:IsA("Sound") then
        rt.RoundInProgress = false
        Working = false
        ChangeState(State.WaitingForRound)
    end
end)

LocalPlayer.CharacterRemoving:Connect(function()
    autoFarmCleanUp()
    if CheckMurderer() then
        IsMurderer = false
        LastPosition = nil
        Working = false
        rt.RoundInProgress = false
        ChangeState(State.StandStillWait)
        return
    end
    if not rt.RoundInProgress then
        IsMurderer = false
        LastPosition = nil
        Working = false
        ChangeState(State.WaitingForRound)
        return
    end
    task.wait(2)
    if ROUND_TIMER.Text == ROUND_TIMER.Text then  -- если текст не изменился, раунд ещё идёт
        if Working then
            Working = false
            IsMurderer = false
            LastPosition = nil
            ChangeState(State.RespawnState)
        end
    else
        LastPosition = nil
        IsMurderer = false
        rt.RoundInProgress = false
        Working = false
        ChangeState(State.WaitingForRound)
    end
end)

-- Определяем, мёрдер ли мы, при старте
IsMurderer = LocalPlayer.Backpack:FindFirstChild("Knife") and true or false

-- Запускаем главный цикл один раз, он будет работать постоянно, пока модуль загружен
task.spawn(mainLoop)

-- ====================== ИНИЦИАЛИЗАЦИЯ UI ======================
function Autofarm.Init(GlobalConfig, UI, Lang)
    loadOctree()  -- загружаем Octree заранее, чтобы не тормозить при старте фарма
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
            -- При включении/выключении ничего дополнительно не делаем, 
            -- потому что главный цикл уже запущен и сам реагирует на состояния.
            -- Но можно добавить принудительный сброс, если нужно.
            if not val then
                -- выключение: останавливаем текущие действия
                Working = false
                BagIsFull = false
                autoFarmCleanUp()
                ChangeState(State.WaitingForRound)
            end
        end
    })
end

return Autofarm
