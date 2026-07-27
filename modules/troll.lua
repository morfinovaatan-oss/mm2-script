-- [[ MM2 TROLL MODULE – WORKING FLING (Teleport + Spin) ]] --
local Troll = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- ================== Помощники ==================

-- Получить позицию корневой части локального игрока (безопасно)
local function GetLocalRootPos()
    local char = LocalPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    return root and root.Position
end

-- Найти мёрдера (ближайшего с ножом)
local function FindMurderer()
    local myPos = GetLocalRootPos()
    if not myPos then return nil end

    local closest = nil
    local minDist = math.huge
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local hasKnife = player.Character:FindFirstChild("Knife")
                or (player:FindFirstChild("Backpack") and player.Backpack:FindFirstChild("Knife"))
            if hasKnife and player.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                local pos = player.Character.HumanoidRootPart.Position
                local dist = (pos - myPos).Magnitude
                if dist < minDist then
                    minDist = dist
                    closest = player
                end
            end
        end
    end
    return closest
end

-- Найти шерифа (любого с пистолетом)
local function FindSheriff()
    local myPos = GetLocalRootPos()
    if not myPos then return nil end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local hasGun = player.Character:FindFirstChild("Gun")
                or (player:FindFirstChild("Backpack") and player.Backpack:FindFirstChild("Gun"))
            if hasGun and player.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                return player  -- первого попавшегося
            end
        end
    end
    return nil
end

-- ================== Флинг (основная логика) ==================
local function FlingPlayer(targetPlayer)
    if not targetPlayer then return end
    local char = targetPlayer.Character
    if not char then return end
    local targetRoot = char:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    -- 1. Телепортируемся прямо в позицию цели
    myRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 1, 0)  -- чуть выше

    -- 2. Быстро вращаемся внутри цели, создавая толкающий эффект
    local duration = 0.3  -- секунд
    local startTime = tick()
    local connection
    connection = RunService.Stepped:Connect(function(_, deltaTime)
        if tick() - startTime > duration then
            connection:Disconnect()
            return
        end
        -- Проверяем, что оба живы
        if not myRoot or not myRoot.Parent or not targetRoot or not targetRoot.Parent then
            connection:Disconnect()
            return
        end
        -- Вращаем свою root‑часть на 15° за шаг (быстрое кручение)
        myRoot.CFrame = targetRoot.CFrame * CFrame.Angles(0, math.rad(15 * deltaTime * 60), 0)
            + Vector3.new(0, 0.5, 0)   -- остаёмся внутри цели
    end)
end

-- ================== Публичные методы ==================
function Troll.FlingSheriff()
    local sheriff = FindSheriff()
    if sheriff then
        FlingPlayer(sheriff)
    end
end

function Troll.FlingMurderer()
    local murderer = FindMurderer()
    if murderer then
        FlingPlayer(murderer)
    end
end

function Troll.FlingAll()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            FlingPlayer(player)
        end
    end
end

-- ================== Инициализация UI ==================
function Troll.Init(GlobalConfig, UI, Lang)
    local T = {
        RU = {
            TabName = "😂 Тролль",
            FlingSheriff = "Флинг шерифа",
            FlingMurderer = "Флинг мёрдера",
            FlingAll = "Флинг всех"
        },
        EN = {
            TabName = "😂 Troll",
            FlingSheriff = "Fling Sheriff",
            FlingMurderer = "Fling Murderer",
            FlingAll = "Fling All"
        }
    }
    local text = T[Lang] or T.RU

    local TrollTab = UI:CreateTab(text.TabName)
    TrollTab:AddButton(text.FlingSheriff, Troll.FlingSheriff)
    TrollTab:AddButton(text.FlingMurderer, Troll.FlingMurderer)
    TrollTab:AddButton(text.FlingAll, Troll.FlingAll)
end

return Troll
