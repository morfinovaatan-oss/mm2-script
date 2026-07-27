-- [[ MM2 FULLY AUTOMATIC AFK FARMER – Octree + State Machine (No Post-Bag Actions) ]] --
local Autofarm = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")

-- ================== Config ==================
Autofarm.Config = {
    Enabled = false,
    Radius = 120,
    WalkSpeed = 20,
    TpBackToStart = true,
}

-- ================== Internal State Machine ==================
local State = {
    WaitingForRound = "WaitingForRound",
    Action = "Action",
    WaitingForRoundEnd = "WaitingForRoundEnd",
    RespawnState = "RespawnState"
}
local CurrentState = State.WaitingForRound
local lastPosition = nil
local roundInProgress = false
local isMurderer = false
local working = false
local bagIsFull = false

-- Octree and containers
local octree = nil
local coinContainer = nil
local touchedCoins = {}
local positionChangeConnections = {}
local AddedConn, RemovingConn = nil, nil

-- GUI references
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local mainGUI = playerGui:WaitForChild("MainGUI")
local roundTimer = Workspace:WaitForChild("RoundTimerPart").SurfaceGui.Timer

-- ================== Octree Loading ==================
local function loadOctree()
    if octree then return true end
    local success, result = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/Sleitnick/rbxts-octo-tree/main/src/init.lua")
    end)
    if not success or not result then return false end
    local octreeModule = loadstring(result)()
    if not octreeModule then return false end
    octree = octreeModule.new()
    return true
end

-- ================== Helpers ==================
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
    local coinsLabel = mainGUI:FindFirstChild("Game") 
        and mainGUI.Game:FindFirstChild("CoinBags") 
        and mainGUI.Game.CoinBags:FindFirstChild("Container") 
        and mainGUI.Game.CoinBags.Container:FindFirstChild("SnowToken") 
        and mainGUI.Game.CoinBags.Container.SnowToken:FindFirstChild("CurrencyFrame") 
        and mainGUI.Game.CoinBags.Container.SnowToken.CurrencyFrame:FindFirstChild("Icon") 
        and mainGUI.Game.CoinBags.Container.SnowToken.CurrencyFrame.Icon:FindFirstChild("Coins")
    if coinsLabel and coinsLabel:IsA("TextLabel") then
        local maxCoins = LocalPlayer:GetAttribute("Elite") and 50 or 40
        return tonumber(coinsLabel.Text) >= maxCoins
    end
    -- Fallback
    if octree and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local nearest = octree:GetNearest(LocalPlayer.Character.HumanoidRootPart.Position, 10000, 1)
        return #nearest == 0
    end
    return false
end

local function isCharacterAlive()
    return LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") and LocalPlayer.Character:FindFirstChildOfClass("Humanoid").Health > 0
end

local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function roundActive()
    return roundInProgress and getMap() ~= nil
end

-- ================== Coin Management ==================
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

local function setupTouchTracking(coin)
    local touchInterest = coin:FindFirstChildWhichIsA("TouchTransmitter")
    if not touchInterest then return end
    local conn
    conn = touchInterest.AncestryChanged:Connect(function(_, parent)
        if parent == nil then
            markCoinAsTouched(coin)
            if conn then conn:Disconnect() end
        end
    end)
    positionChangeConnections[coin] = conn
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
    if not coinContainer then return end
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

local function clearConnections()
    for _, conn in pairs(positionChangeConnections) do
        if conn and conn.Connected then conn:Disconnect() end
    end
    table.clear(positionChangeConnections)
    table.clear(touchedCoins)
    if AddedConn then AddedConn:Disconnect(); AddedConn = nil end
    if RemovingConn then RemovingConn:Disconnect(); RemovingConn = nil end
    if octree then
        octree:ClearAllNodes()
        -- Keep octree object, just clear nodes
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

-- ================== State Handlers ==================
local function changeState(newState)
    CurrentState = newState
end

local function waitingForRound()
    working = false
    repeat
        task.wait(0.5)
    until roundActive() and LocalPlayer:GetAttribute("Alive")
    changeState(State.Action)
end

local function waitingForRoundEnd()
    working = false
    if isCharacterAlive() and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid").Health = 0
    end
    repeat task.wait(0.5) until not roundActive()
    changeState(State.WaitingForRound)
end

local function respawnState()
    local char = getCharacter()
    task.wait(1)
    if lastPosition then
        char:PivotTo(lastPosition)
    end
    if not roundActive() then
        changeState(State.WaitingForRound)
        return
    end
    changeState(State.Action)
end

local function actionState()
    lastPosition = LocalPlayer.Character and LocalPlayer.Character:GetPivot()
    coinContainer = getCoinContainer()
    if not coinContainer then
        -- Map not ready, go back to waiting
        changeState(State.WaitingForRound)
        return
    end
    populateOctree()
    working = true
    while working and roundActive() do
        if isBagFull() then
            bagIsFull = true
            break
        end
        if not isCharacterAlive() then
            break
        end
        if octree then
            local nearest = octree:GetNearest(LocalPlayer.Character.PrimaryPart.Position, Autofarm.Config.Radius, 1)
            if nearest and #nearest > 0 then
                local coin = nearest[1].Object
                if not isCoinTouched(coin) then
                    local dist = (LocalPlayer.Character.PrimaryPart.Position - coin.Position).Magnitude
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
    clearConnections()
    if bagIsFull or not roundActive() then
        if isMurderer then
            -- Murderer just stops
            bagIsFull = false
            working = false
            if Autofarm.Config.TpBackToStart and lastPosition then
                local char = getCharacter()
                char:PivotTo(lastPosition)
            end
            changeState(State.WaitingForRoundEnd)
        else
            -- Innocent/Sheriff: die, wait for next round
            bagIsFull = false
            working = false
            if Autofarm.Config.TpBackToStart and lastPosition then
                local char = getCharacter()
                char:PivotTo(lastPosition)
            end
            changeState(State.WaitingForRoundEnd)
        end
    else
        -- Died during farming
        changeState(State.RespawnState)
    end
end

-- ================== Event Listeners ==================
-- Detect role
LocalPlayer.DescendantAdded:Connect(function(desc)
    if desc:IsA("Tool") and desc.Name == "Knife" then
        isMurderer = true
    end
end)
LocalPlayer.Backpack.ChildAdded:Connect(function(child)
    if child.Name == "Knife" then isMurderer = true end
end)

-- Round start/end detection
local lastTimerText = roundTimer.Text
roundTimer:GetPropertyChangedSignal("Text"):Connect(function()
    roundInProgress = true
    if CurrentState == State.WaitingForRound then
        -- round started while waiting, change immediately
        changeState(State.Action)
    end
end)

playerGui.ChildAdded:Connect(function(child)
    if child:IsA("Sound") then
        roundInProgress = false
        if CurrentState == State.Action or CurrentState == State.RespawnState then
            working = false
            changeState(State.WaitingForRound)
        end
    end
end)

-- Death handling
LocalPlayer.CharacterRemoving:Connect(function()
    if not working then return end
    clearConnections()
    if not roundActive() then
        changeState(State.WaitingForRound)
    else
        lastPosition = lastPosition or (LocalPlayer.Character and LocalPlayer.Character:GetPivot())
        changeState(State.RespawnState)
    end
end)

-- Start state machine
task.spawn(function()
    while true do
        if not Autofarm.Config.Enabled then
            task.wait(1)
            continue
        end
        if CurrentState == State.WaitingForRound then
            waitingForRound()
        elseif CurrentState == State.Action then
            actionState()
        elseif CurrentState == State.WaitingForRoundEnd then
            waitingForRoundEnd()
        elseif CurrentState == State.RespawnState then
            respawnState()
        end
        task.wait(0.1)
    end
end)

-- ================== UI Init ==================
function Autofarm.Init(GlobalConfig, UI, Lang)
    local T = {
        RU = {
            TabName = "💰 Автофарм",
            Enable = "Включить автофарм",
            Radius = "Радиус поиска",
            Speed = "Скорость движения",
            TpBack = "Возврат на старт",
            SetStart = "Запомнить позицию",
        },
        EN = {
            TabName = "💰 AutoFarm",
            Enable = "Enable AutoFarm",
            Radius = "Search Radius",
            Speed = "Movement Speed",
            TpBack = "Return to start",
            SetStart = "Set current position",
        }
    }
    local text = T[Lang] or T.RU

    local FarmTab = UI:CreateTab(text.TabName)

    FarmTab:AddToggle({
        Title = text.Enable,
        Default = false,
        Callback = function(val)
            Autofarm.Config.Enabled = val
            if not val then
                working = false
                clearConnections()
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
        Title = text.TpBack,
        Default = Autofarm.Config.TpBackToStart,
        Callback = function(v) Autofarm.Config.TpBackToStart = v end
    })

    FarmTab:AddButton(text.SetStart, function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            lastPosition = char:GetPivot()
            if UI.Notification then
                UI:Notification("AutoFarm", "Позиция сохранена!", 2)
            end
        end
    end)
end

return Autofarm
