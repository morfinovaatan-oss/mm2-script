-- [[ MM2 MURDERER COMBAT MODULE – адаптированный под UILibrary ]] --
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

-- Отключить коллизию на всех частях персонажа
local function disableCollision()
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") or part:IsA("MeshPart") then
            part.CanCollide = false
        end
    end
end

-- Включить коллизию обратно
local function enableCollision()
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") or part:IsA("MeshPart") then
            part.CanCollide = true
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

local function GetAllPlayers()
    local all = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(all, p)
        end
    end
    return all
end

-- Телепортировать игрока к нашей позиции
local function summonPlayer(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local myRoot = char.HumanoidRootPart
    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end
    targetRoot.CFrame = myRoot.CFrame + Vector3.new(math.random(-2,2), 0, math.random(-2,2))
end

-- Убить одного игрока (серия ударов)
local function killPlayer(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    equipKnife()
    local start = tick()
    while targetPlayer.Character and targetPlayer.Character:FindFirstChildOfClass("Humanoid") and targetPlayer.Character.Humanoid.Health > 0 do
        if tick() - start > 3 then break end
        SimulateClick()
        task.wait(0.1)
    end
end

-- Убить шерифа (призвать + отключить коллизию + убить)
local function killSheriffOnce()
    if killInProgress then return end
    killInProgress = true
    disableCollision()
    local sheriff = FindSheriff()
    if sheriff then
        summonPlayer(sheriff)
        task.wait(0.1)
        killPlayer(sheriff)
    end
    enableCollision()
    killInProgress = false
end

-- Убить всех (100 раз призвать всех + одновременно убивать)
local function killAllOnce()
    if killInProgress then return end
    killInProgress = true
    disableCollision()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        enableCollision()
        killInProgress = false
        return
    end
    equipKnife()

    for _ = 1, 100 do
        if not MCombat.Config.KillAll then break end
        local allPlayers = GetAllPlayers()
        -- Призываем всех
        for _, player in ipairs(allPlayers) do
            summonPlayer(player)
        end
        -- Бьём всех, кто рядом
        for _, player in ipairs(allPlayers) do
            if player.Character and player.Character:FindFirstChildOfClass("Humanoid") and player.Character.Humanoid.Health > 0 then
                SimulateClick()
            end
        end
        task.wait(0.05)
    end

    -- Добиваем оставшихся
    local alivePlayers = GetAllPlayers()
    for _, player in ipairs(alivePlayers) do
        if not MCombat.Config.KillAll then break end
        if player.Character and player.Character:FindFirstChildOfClass("Humanoid") and player.Character.Humanoid.Health > 0 then
            killPlayer(player)
        end
        task.wait(0.1)
    end

    enableCollision()
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
    enableCollision()
end)

-- ================== UI Init ==================
function MCombat.Init(GlobalConfig, parentTab, Lang)
    local T = {
        RU = {
            SubMain = "Убийства",
            SecKill = "Убийства",
            KillSheriff = "Убить шерифа",
            KillAll = "Убить всех",
            KillCooldown = "Кулдаун (сек)",
            SecKeys = "Клавиши",
            KnifeKey = "Удар ножом",
            FindSheriffKey = "Найти шерифа",
        },
        EN = {
            SubMain = "Kills",
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
    local SubTab = parentTab:AddSubTab(text.SubMain)

    -- Kills Group
    local KillGroup = SubTab:AddGroupbox(text.SecKill)
    KillGroup:AddToggle({
        Text = text.KillSheriff,
        Default = false,
        Callback = function(s) MCombat.Config.KillSheriff = s end
    })
    KillGroup:AddToggle({
        Text = text.KillAll,
        Default = false,
        Callback = function(s) MCombat.Config.KillAll = s end
    })
    KillGroup:AddSlider({
        Text = text.KillCooldown,
        Min = 0.1, Max = 2, Default = MCombat.Config.KillCooldown,
        Suffix = " s", Decimals = 1,
        Callback = function(v) MCombat.Config.KillCooldown = v end
    })

    -- Keybinds Group
    local KeysGroup = SubTab:AddGroupbox(text.SecKeys)
    local function addKeybindRow(keyName, configKey)
        local label = KeysGroup:AddLabel(MCombat.Config[configKey] and (keyName .. " : " .. tostring(MCombat.Config[configKey]):gsub("Enum.KeyCode.", "")) or (keyName .. " : None"))
        KeysGroup:AddButton({
            Text = keyName .. " (нажмите для смены)",
            Callback = function()
                local oldKey = MCombat.Config[configKey]
                label:SetText(keyName .. " : ... (ожидание)")
                local conn
                conn = UserInputService.InputBegan:Connect(function(input, gp)
                    if gp then return end
                    conn:Disconnect()
                    MCombat.Config[configKey] = input.KeyCode
                    label:SetText(keyName .. " : " .. tostring(input.KeyCode):gsub("Enum.KeyCode.", ""))
                end)
                task.wait(3)
                if MCombat.Config[configKey] == oldKey then
                    label:SetText(keyName .. " : " .. tostring(oldKey):gsub("Enum.KeyCode.", ""))
                end
            end
        })
    end
    addKeybindRow(text.KnifeKey, "KnifeKey")
    addKeybindRow(text.FindSheriffKey, "FindSheriffKey")
end

return MCombat
