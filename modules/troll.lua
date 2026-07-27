-- [[ MM2 TROLL MODULE – Fling & Fun ]] --
local Troll = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer

-- ================== Helpers ==================

-- Найти любого игрока с ножом (мёрдера)
local function FindMurderer()
    local closest = nil
    local minDist = math.huge
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local hasKnife = player.Character:FindFirstChild("Knife")
                or (player:FindFirstChild("Backpack") and player.Backpack:FindFirstChild("Knife"))
            if hasKnife and player.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                local dist = (player.Character.HumanoidRootPart.Position - LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position or Vector3.zero).Magnitude
                if dist < minDist then
                    minDist = dist
                    closest = player
                end
            end
        end
    end
    return closest
end

-- Найти шерифа (игрок с пистолетом)
local function FindSheriff()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local hasGun = player.Character:FindFirstChild("Gun")
                or (player:FindFirstChild("Backpack") and player.Backpack:FindFirstChild("Gun"))
            if hasGun and player.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                return player
            end
        end
    end
    return nil
end

-- Универсальная функция флинга (подкидывает персонаж)
local function FlingPlayer(player)
    if not player or not player.Character then return end
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- Прикладываем мощный вертикальный импульс
    local bodyVel = Instance.new("BodyVelocity")
    bodyVel.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bodyVel.Velocity = Vector3.new(math.random(-2000, 2000), 10000, math.random(-2000, 2000))
    bodyVel.P = 1e5
    bodyVel.Parent = root
    Debris:AddItem(bodyVel, 0.15)   -- удалится через 0.15 сек, игрок уже в полёте
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
