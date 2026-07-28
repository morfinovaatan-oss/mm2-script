-- [[ MM2 MURDERER COMBAT MODULE – Fixed Kill Mechanics (no aimbot, no shiftlock) ]] --
local MCombat = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

MCombat.Config = {
    KillSheriff = false,
    KillAll = false,
    KillCooldown = 0.5,
    KnifeKey = Enum.KeyCode.C,
    FindSheriffKey = Enum.KeyCode.X,
}

local lastKillTime = 0
local killInProgress = false

-- Helpers
local function SimulateClick()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    task.wait(0.02)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
end

local function equipKnife()
    local char = LocalPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool or tool.Name ~= "Knife" then
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        local knife = backpack and backpack:FindFirstChild("Knife")
        if knife and char:FindFirstChildOfClass("Humanoid") then
            char:FindFirstChildOfClass("Humanoid"):EquipTool(knife)
        end
    end
end

local function FindSheriff()
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local hasGun = p.Character:FindFirstChild("Gun") or (p:FindFirstChild("Backpack") and p.Backpack:FindFirstChild("Gun"))
            local hasRevolver = p.Character:FindFirstChild("Revolver") or (p:FindFirstChild("Backpack") and p.Backpack:FindFirstChild("Revolver"))
            if (hasGun or hasRevolver) and p.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                return p
            end
        end
    end
    return nil
end

local function GetAlivePlayers()
    local alive = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            table.insert(alive, p)
        end
    end
    return alive
end

-- Убить одного игрока (телепорт прямо в него и серия ударов)
local function killPlayer(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local root = char.HumanoidRootPart
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    equipKnife()
    -- Телепорт прямо в позицию цели (без смещения вверх)
    root.CFrame = targetRoot.CFrame
    task.wait(0.05)

    local start = tick()
    while targetPlayer.Character and targetPlayer.Character:FindFirstChildOfClass("Humanoid") and targetPlayer.Character.Humanoid.Health > 0 do
        if tick() - start > 3 then break end
        SimulateClick()
        task.wait(0.1)
    end
end

-- Kill Sheriff один раз
local function killSheriffOnce()
    if killInProgress then return end
    killInProgress = true
    local sheriff = FindSheriff()
    if sheriff then
        killPlayer(sheriff)
    end
    killInProgress = false
end

-- Kill All: телепортируем всех живых к себе, затем убиваем
local function killAllOnce()
    if killInProgress then return end
    killInProgress = true
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        killInProgress = false
        return
    end
    local myRoot = char.HumanoidRootPart
    equipKnife()

    local alivePlayers = GetAlivePlayers()
    -- Сначала телепортируем всех ко мне
    for _, player in ipairs(alivePlayers) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            player.Character.HumanoidRootPart.CFrame = myRoot.CFrame + Vector3.new(math.random(-2,2), 0, math.random(-2,2))
        end
    end
    task.wait(0.1)

    -- Теперь быстро атакуем всех, кто рядом
    for _, player in ipairs(alivePlayers) do
        if not MCombat.Config.KillAll then break end
        killPlayer(player)
        task.wait(0.2)
    end
    MCombat.Config.KillAll = false
    killInProgress = false
end

-- Главный цикл проверки тогглов
task.spawn(function()
    while task.wait(0.3) do
        if MCombat.Config.KillSheriff and not killInProgress and (tick() - lastKillTime >= MCombat.Config.KillCooldown) then
            lastKillTime = tick()
            task.spawn(killSheriffOnce)
        end
        if MCombat.Config.KillAll and not killInProgress then
            task.spawn(killAllOnce)
        end
    end
end)

-- Бинды
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == MCombat.Config.KnifeKey then
        SimulateClick()
    elseif input.KeyCode == MCombat.Config.FindSheriffKey then
        local sheriff = FindSheriff()
        if sheriff then
            local userId = Players:GetUserIdFromNameAsync(sheriff.Name)
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Sheriff",
                Text = "Their name is " .. sheriff.Name .. "!",
                Icon = "https://web.roblox.com/Thumbs/Avatar.ashx?x=100&y=100&Format=Png&userid=" .. userId,
                Duration = 5,
                Button1 = "Dismiss",
            })
        else
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Sheriff",
                Text = "No sheriff could be found!",
                Duration = 5,
                Button1 = "Dismiss",
            })
        end
    end
end)

-- Сброс при возрождении
LocalPlayer.CharacterAdded:Connect(function()
    killInProgress = false
end)

-- UI Init
function MCombat.Init(GlobalConfig, UI, Lang)
    local T = {
        RU = {
            Tab = "🔪 Убийца",
            SecKill = "Убийства",
            KillSheriff = "Убить шерифа",
            KillAll = "Убить всех",
            KillCooldown = "Кулдаун (сек)",
            SecKeys = "Клавиши",
            KnifeKey = "Удар ножом",
            FindSheriffKey = "Найти шерифа",
        },
        EN = {
            Tab = "🔪 Murderer",
            SecKill = "Kills",
            KillSheriff = "Kill Sheriff",
            KillAll = "Kill All",
            KillCooldown = "Cooldown (s)",
            SecKeys = "Keybinds",
            KnifeKey = "Knife Hit",
            FindSheriffKey = "Find Sheriff",
        }
    }

    local text = T[Lang] or T.RU
    local tab = UI:CreateTab(text.Tab)

    tab:AddSection(text.SecKill)
    tab:AddToggle({ Title = text.KillSheriff, Default = false, Callback = function(s) MCombat.Config.KillSheriff = s end })
    tab:AddToggle({ Title = text.KillAll, Default = false, Callback = function(s) MCombat.Config.KillAll = s end })
    tab:AddNumberInput({ Title = text.KillCooldown, Min = 0.1, Max = 2, Default = MCombat.Config.KillCooldown, Callback = function(v) MCombat.Config.KillCooldown = v end })

    tab:AddSection(text.SecKeys)
    local function addBindLabelAndButton(keyName, configKeyString)
        local label = tab:AddLabel(keyName .. " : " .. tostring(MCombat.Config[configKeyString]):gsub("Enum.KeyCode.", ""))
        tab:AddButton(keyName .. " (нажмите для смены)", function()
            local oldKey = MCombat.Config[configKeyString]
            label.Text = keyName .. " : ... (ожидание)"
            local conn
            conn = UserInputService.InputBegan:Connect(function(input, gp)
                if gp then return end
                conn:Disconnect()
                MCombat.Config[configKeyString] = input.KeyCode
                label.Text = keyName .. " : " .. tostring(input.KeyCode):gsub("Enum.KeyCode.", "")
            end)
            task.wait(3)
            if MCombat.Config[configKeyString] == oldKey then
                label.Text = keyName .. " : " .. tostring(oldKey):gsub("Enum.KeyCode.", "")
            end
        end)
    end
    addBindLabelAndButton(text.KnifeKey, "KnifeKey")
    addBindLabelAndButton(text.FindSheriffKey, "FindSheriffKey")
end

return MCombat
