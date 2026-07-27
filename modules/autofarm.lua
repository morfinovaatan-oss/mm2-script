-- [[ MM2 AUTOFARM MODULE – Coin farming + role actions ]] --
local Autofarm = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

Autofarm.Config = {
    Enabled = false,
    CoinName = "Coin_Server",   -- имя объекта монеты
    CoinsForFull = 10,          -- запасной лимит (если не найдены монеты)
    AutoAction = true,          -- выполнять роль-действие при полном мешке
}

-- ================== Вспомогательные функции ==================
local function GetRole()
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

local function FindMurderer()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local hasKnife = player.Character:FindFirstChild("Knife") or (player:FindFirstChild("Backpack") and player.Backpack:FindFirstChild("Knife"))
            if hasKnife and player.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                return player
            end
        end
    end
    return nil
end

-- Простой флинг через телепорт + вращение (рабочий вариант)
local function FlingPlayer(player)
    if not player or not player.Character then return end
    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot or not targetRoot then return end

    -- Телепорт прямо в цель
    myRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 1.5, 0)
    task.wait(0.05)

    -- Быстрое вращение
    local start = tick()
    local connection
    connection = RunService.Stepped:Connect(function(_, dt)
        if tick() - start > 0.25 then
            connection:Disconnect()
            return
        end
        if myRoot.Parent and targetRoot.Parent then
            myRoot.CFrame = targetRoot.CFrame * CFrame.Angles(0, math.rad(20), 0) + Vector3.new(0, 0.5, 0)
        else
            connection:Disconnect()
        end
    end)
end

-- Действие для шерифа: телепорт за спину мёрдера + выстрел
local function SheriffAction()
    local murderer = FindMurderer()
    if not murderer then return end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local mRoot = murderer.Character.HumanoidRootPart
    local mHead = murderer.Character:FindFirstChild("Head")

    -- Позиция за спиной мёрдера (15 метров)
    local behindPos = mRoot.Position - (mRoot.CFrame.LookVector * 15)
    root.CFrame = CFrame.new(behindPos, mRoot.Position)

    -- Направить камеру на голову
    if mHead then
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, mHead.Position)
    end

    task.wait(0.1)

    -- Выстрелить
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    task.wait(0.02)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
end

-- ================== Основной цикл фарма ==================
local coinCount = 0
local startPosition = nil
local farmingLoop = nil

local function getNearestCoin()
    local nearest, minDist = nil, math.huge
    local origin = startPosition or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position)
    if not origin then return nil end

    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name == Autofarm.Config.CoinName then
            local dist = (obj.Position - origin).Magnitude
            if dist < minDist then
                minDist = dist
                nearest = obj
            end
        end
    end
    return nearest
end

local function startFarming()
    if farmingLoop then return end

    -- Сохраняем стартовую позицию, если ещё не задана
    if not startPosition then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            startPosition = char.HumanoidRootPart.CFrame
        end
    end

    coinCount = 0

    farmingLoop = task.spawn(function()
        while Autofarm.Config.Enabled do
            local char = LocalPlayer.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then
                task.wait(1)
                continue
            end

            local root = char.HumanoidRootPart
            local coin = getNearestCoin()

            if coin then
                -- Телепортируемся к монете
                root.CFrame = CFrame.new(coin.Position + Vector3.new(0, 3, 0))
                task.wait(0.3)

                -- Возвращаемся на стартовую позицию
                if startPosition then
                    root.CFrame = startPosition
                end
                coinCount = coinCount + 1
                task.wait(1)  -- задержка между подборами
            else
                -- Нет монет – мешок полон (или лимит достигнут)
                if Autofarm.Config.AutoAction and coinCount > 0 then
                    local role = GetRole()
                    if role == "Innocent" then
                        local murderer = FindMurderer()
                        if murderer then
                            FlingPlayer(murderer)
                        end
                    elseif role == "Sheriff" then
                        SheriffAction()
                    elseif role == "Murderer" then
                        -- Заглушка: в разработке
                        if Synapse then -- или другой способ уведомления
                            game:GetService("StarterGui"):SetCore("SendNotification", {
                                Title = "Автофарм",
                                Text = "Действие для Murderer пока в разработке",
                                Duration = 3
                            })
                        end
                    end
                    coinCount = 0
                    task.wait(2)  -- пауза после действия
                else
                    task.wait(2)
                end
            end
        end
    end)
end

local function stopFarming()
    if farmingLoop then
        farmingLoop:Disconnect()
        farmingLoop = nil
    end
end

-- ================== Инициализация UI ==================
function Autofarm.Init(GlobalConfig, UI, Lang)
    local T = {
        RU = {
            TabName = "💰 Автофарм",
            Enable = "Включить автофарм",
            CoinName = "Название монеты",
            CoinsForFull = "Лимит монет",
            SetStart = "Запомнить позицию",
            StartAction = "Действие при полном мешке",
        },
        EN = {
            TabName = "💰 AutoFarm",
            Enable = "Enable AutoFarm",
            CoinName = "Coin object name",
            CoinsForFull = "Coin limit",
            SetStart = "Set current position",
            StartAction = "Action on full bag",
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
        Title = text.CoinName .. " (текст не меняем, извини – это заглушка)",
        Min = 1,
        Max = 999,
        Default = Autofarm.Config.CoinsForFull,
        Callback = function(v) Autofarm.Config.CoinsForFull = v end
    })

    FarmTab:AddButton(text.SetStart, function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            startPosition = char.HumanoidRootPart.CFrame
            if UI and UI.Notification then
                UI:Notification("AutoFarm", "Позиция сохранена!", 2)
            end
        end
    end)

    FarmTab:AddToggle({
        Title = text.StartAction,
        Default = true,
        Callback = function(v) Autofarm.Config.AutoAction = v end
    })

    -- Очистка при выключении
    FarmTab:AddButton("Сбросить позицию", function()
        startPosition = nil
    end)
end

return Autofarm
