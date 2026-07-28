-- [[ MM2 FOXAUTOFARM – Integrated Cheats & AutoFarm ]] --
local Autofarm = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local BoundKeys = LocalPlayer.PlayerScripts.PlayerModule.CameraModule.MouseLockController.BoundKeys

-- ====================== ГЛОБАЛЬНЫЕ НАСТРОЙКИ ======================
local Config = {
    AutoFarm = false,
    Reach = false,
    ReachRadius = 10,
    ReachAngle = 60,
    StabAll = false,
    SilentAim = false,
    SilentAimKey = Enum.KeyCode.G,
    Prediction = 10,
    AutoGun = false,
    SpeedHack = false,
    SpeedKey = Enum.KeyCode.LeftShift,
    SpeedValue = 2,
    LockBind = false,
    LockKey = Enum.KeyCode.LeftControl,
    PlayerChams = true,
    GunChams = false,
}

-- ====================== ПЕРЕМЕННЫЕ ======================
local murderer, sheriff, hero
local roles = {}
local visuals = {}
local GunHighlight = Instance.new("Highlight")
local GunHandleAdornment = Instance.new("SphereHandleAdornment")

-- ====================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ======================
local function findAngleDelta(a, b)
    return math.deg(math.acos(a:Dot(b)))
end

local function isCharacterValid(character)
    if character and character:IsA("Model") then
        local humanoid = character:FindFirstChildWhichIsA("Humanoid")
        if humanoid and humanoid.Health > 0 then
            local root = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
            if root then return true end
        end
    end
    return false
end

local function updateRole(player, role)
    if role ~= roles[player] then
        print(player.Name .. " is now " .. role)
    end
    roles[player] = role
    if role == "Murderer" then murderer = player
    elseif role == "Sheriff" then sheriff = player
    elseif role == "Hero" then hero = player
    end
    if player ~= LocalPlayer then
        local highlight = visuals[player]
        if highlight then
            highlight.FillColor = Color3.fromRGB(255, 0, 0)
        end
    end
end

local function onPlayerAdded(player)
    local highlight = Instance.new("Highlight")
    highlight.FillColor = Color3.fromRGB(128, 128, 128)
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.RobloxLocked = true
    pcall(function() if syn then syn.protect_gui(highlight) end end)
    visuals[player] = highlight
    highlight.Parent = CoreGui
    local function onCharacterAdded(character)
        highlight.Adornee = character
    end
    player.CharacterAdded:Connect(onCharacterAdded)
    local character = player.Character
    if character then onCharacterAdded(character) end
end

local function onPlayerRemoving(player)
    local highlight = visuals[player]
    if highlight then highlight:Destroy() end
    visuals[player] = nil
    roles[player] = nil
end

-- ====================== ИНИЦИАЛИЗАЦИЯ ПРИ ЗАГРУЗКЕ ======================
GunHighlight.FillColor = Color3.fromRGB(255, 255, 0)
GunHighlight.OutlineTransparency = 1
GunHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
GunHighlight.RobloxLocked = true

GunHandleAdornment.Color3 = Color3.fromRGB(255, 255, 0)
GunHandleAdornment.Transparency = 0.2
GunHandleAdornment.AlwaysOnTop = true
GunHandleAdornment.AdornCullingMode = Enum.AdornCullingMode.Never
GunHandleAdornment.RobloxLocked = true

pcall(function() if syn then syn.protect_gui(GunHighlight) end end)
pcall(function() if syn then syn.protect_gui(GunHandleAdornment) end end)
GunHighlight.Parent = CoreGui
GunHandleAdornment.Parent = CoreGui

-- Подписка на роли
ReplicatedStorage.Fade.OnClientEvent:Connect(function(data)
    for _, v in ipairs(Players:GetPlayers()) do
        local info = data[v.Name]
        if info then
            local role = typeof(info) == "table" and info.Role or "Unknown"
            pcall(updateRole, v, role)
        end
    end
end)
ReplicatedStorage.UpdatePlayerData.OnClientEvent:Connect(function(data)
    for _, v in ipairs(Players:GetPlayers()) do
        local info = data[v.Name]
        if info then
            local role = typeof(info) == "table" and info.Role or "Unknown"
            pcall(updateRole, v, role)
        end
    end
end)
ReplicatedStorage.RoleSelect.OnClientEvent:Connect(function(role)
    updateRole(LocalPlayer, role or "Unknown")
end)
ReplicatedStorage.Remotes.Gameplay.RoundEndFade.OnClientEvent:Connect(function()
    for i, v in pairs(roles) do updateRole(i, "Unknown") end
    murderer, sheriff, hero = nil, nil, nil
end)

-- Игроки, которые уже в игре
for _, v in ipairs(Players:GetPlayers()) do
    if v ~= LocalPlayer then onPlayerAdded(v) end
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Хук для Silent Aim
local __namecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = { ... }
    if not checkcaller() and typeof(self) == "Instance" then
        if self.Name == "ShootGun" and method == "InvokeServer" then
            if Config.SilentAim and murderer then
                local char = murderer.Character
                if char and char.PrimaryPart then
                    local root = char.PrimaryPart
                    local velocity = root.AssemblyLinearVelocity
                    local aimPosition = root.Position
                        + velocity * Vector3.new(Config.Prediction / 200, 0, Config.Prediction / 200)
                    args[2] = aimPosition
                end
            end
        end
    end
    return __namecall(self, unpack(args))
end)

-- ====================== ОСНОВНОЙ ЦИКЛ ======================
task.spawn(function()
    while true do
        local character = LocalPlayer.Character
        if isCharacterValid(character) then
            -- AutoFarm
            if Config.AutoFarm then
                local CoinContainer = Workspace:FindFirstChild("CoinContainer", true)
                if CoinContainer and roles[LocalPlayer] ~= "Unknown" then
                    local coin = CoinContainer:FindFirstChild("Coin_Server")
                    if coin then
                        local root = character.HumanoidRootPart
                        root.CFrame = CFrame.new(coin.Position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(180))
                    end
                end
            end

            -- Reach / StabAll
            if Config.Reach or Config.StabAll then
                local knife = character:FindFirstChild("Knife")
                if knife and knife:IsA("Tool") then
                    local root = character.HumanoidRootPart
                    for _, v in ipairs(Players:GetPlayers()) do
                        if v ~= LocalPlayer and isCharacterValid(v.Character) then
                            local enemyRoot = v.Character.HumanoidRootPart
                            local enemyPos = enemyRoot.Position
                            local dist = (enemyPos - root.Position).Magnitude
                            local angle = findAngleDelta(
                                root.CFrame.LookVector.Unit,
                                (enemyPos - root.Position).Unit
                            )
                            if Config.StabAll or (dist <= Config.ReachRadius and angle <= Config.ReachAngle) then
                                firetouchinterest(enemyRoot, knife.Handle, 1)
                                firetouchinterest(enemyRoot, knife.Handle, 0)
                            end
                        end
                    end
                end
            end

            -- AutoGun
            if Config.AutoGun and roles[LocalPlayer] == "Innocent" then
                local gundrop = Workspace:FindFirstChild("GunDrop")
                if gundrop then
                    local root = character.HumanoidRootPart
                    local saved = root.CFrame
                    root.CFrame = gundrop.CFrame
                    task.wait(0.1)
                    root.CFrame = saved
                end
            end

            -- SpeedHack
            if Config.SpeedHack then
                local isKeyDown = UserInputService:IsKeyDown(Config.SpeedKey)
                character.Humanoid.WalkSpeed = isKeyDown and (16 + Config.SpeedValue) or 16
            else
                character.Humanoid.WalkSpeed = 16
            end
        end

        -- LockBind
        if Config.LockBind then
            BoundKeys.Value = Config.LockKey.Name or "LeftControl"
        else
            BoundKeys.Value = "LeftShift, RightShift"
        end

        -- Gun Chams / Player Chams
        local gundrop = Workspace:FindFirstChild("GunDrop")
        GunHighlight.Adornee = gundrop
        GunHandleAdornment.Adornee = gundrop
        if gundrop then
            GunHandleAdornment.Size = gundrop.Size + Vector3.new(0.05, 0.05, 0.05)
        end
        for _, v in pairs(visuals) do
            v.Enabled = Config.PlayerChams
        end
        GunHighlight.Enabled = Config.GunChams
        GunHandleAdornment.Visible = Config.GunChams

        task.wait(0.1)
    end
end)

-- ====================== ИНИЦИАЛИЗАЦИЯ UI ======================
function Autofarm.Init(GlobalConfig, UI, Lang)
    local T = {
        RU = {
            Tab = "🦊 FoxAutofarm",
            SecAutoFarm = "Автофарм",
            AutoFarm = "Автофарм",
            SecReach = "Расширитель хитбокса (Murderer)",
            Reach = "Включить",
            ReachRadius = "Радиус",
            ReachAngle = "Угол",
            StabAll = "Убить всех (взмах ножа)",
            SecSilentAim = "Silent Aim (Sheriff)",
            SilentAim = "Включить",
            SilentAimKey = "Клавиша",
            Prediction = "Упреждение",
            SecAutoGun = "Авто-подбор пистолета",
            AutoGun = "Авто-подбор",
            SecSpeed = "Speed Hack",
            SpeedHack = "Включить",
            SpeedKey = "Клавиша",
            SpeedValue = "Скорость",
            SecLockBind = "Lock Bind",
            LockBind = "Включить",
            LockKey = "Клавиша",
            SecVisuals = "Визуалы",
            PlayerChams = "ESP игроков",
            GunChams = "Подсветка пистолета",
        },
        EN = {
            Tab = "🦊 FoxAutofarm",
            SecAutoFarm = "Auto Farm",
            AutoFarm = "Auto Farm",
            SecReach = "Hitbox Extender (Murderer)",
            Reach = "Enable",
            ReachRadius = "Radius",
            ReachAngle = "Angle",
            StabAll = "Kill All (Swing knife)",
            SecSilentAim = "Silent Aim (Sheriff)",
            SilentAim = "Enable",
            SilentAimKey = "Key",
            Prediction = "Prediction",
            SecAutoGun = "Auto-Pickup Gun",
            AutoGun = "Auto-Pickup",
            SecSpeed = "Speed Hack",
            SpeedHack = "Enable",
            SpeedKey = "Key",
            SpeedValue = "Speed",
            SecLockBind = "Lock Bind",
            LockBind = "Enable",
            LockKey = "Key",
            SecVisuals = "Visuals",
            PlayerChams = "Player ESP",
            GunChams = "Gun Chams",
        }
    }
    local text = T[Lang] or T.RU
    local Tab = UI:CreateTab(text.Tab)

    Tab:AddSection(text.SecAutoFarm)
    Tab:AddToggle({ Title = text.AutoFarm, Default = false, Callback = function(s) Config.AutoFarm = s end })

    Tab:AddSection(text.SecReach)
    Tab:AddToggle({ Title = text.Reach, Default = false, Callback = function(s) Config.Reach = s end })
    Tab:AddNumberInput({ Title = text.ReachRadius, Min = 5, Max = 20, Default = 10, Callback = function(v) Config.ReachRadius = v end })
    Tab:AddNumberInput({ Title = text.ReachAngle, Min = 10, Max = 180, Default = 60, Callback = function(v) Config.ReachAngle = v end })
    Tab:AddToggle({ Title = text.StabAll, Default = false, Callback = function(s) Config.StabAll = s end })

    Tab:AddSection(text.SecSilentAim)
    Tab:AddToggle({ Title = text.SilentAim, Default = false, Callback = function(s) Config.SilentAim = s end })
    local silentKeyLabel = Tab:AddLabel(text.SilentAimKey .. " : " .. tostring(Config.SilentAimKey):gsub("Enum.KeyCode.", ""))
    Tab:AddButton(text.SilentAimKey .. " (нажмите для смены)", function()
        local oldKey = Config.SilentAimKey
        silentKeyLabel.Text = text.SilentAimKey .. " : ... (ожидание)"
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            conn:Disconnect()
            Config.SilentAimKey = input.KeyCode
            silentKeyLabel.Text = text.SilentAimKey .. " : " .. tostring(input.KeyCode):gsub("Enum.KeyCode.", "")
        end)
        task.wait(3)
        if Config.SilentAimKey == oldKey then
            silentKeyLabel.Text = text.SilentAimKey .. " : " .. tostring(oldKey):gsub("Enum.KeyCode.", "")
        end
    end)
    Tab:AddNumberInput({ Title = text.Prediction, Min = 0, Max = 100, Default = 10, Callback = function(v) Config.Prediction = v end })

    Tab:AddSection(text.SecAutoGun)
    Tab:AddToggle({ Title = text.AutoGun, Default = false, Callback = function(s) Config.AutoGun = s end })

    Tab:AddSection(text.SecSpeed)
    Tab:AddToggle({ Title = text.SpeedHack, Default = false, Callback = function(s) Config.SpeedHack = s end })
    local speedKeyLabel = Tab:AddLabel(text.SpeedKey .. " : " .. tostring(Config.SpeedKey):gsub("Enum.KeyCode.", ""))
    Tab:AddButton(text.SpeedKey .. " (нажмите для смены)", function()
        local oldKey = Config.SpeedKey
        speedKeyLabel.Text = text.SpeedKey .. " : ... (ожидание)"
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            conn:Disconnect()
            Config.SpeedKey = input.KeyCode
            speedKeyLabel.Text = text.SpeedKey .. " : " .. tostring(input.KeyCode):gsub("Enum.KeyCode.", "")
        end)
        task.wait(3)
        if Config.SpeedKey == oldKey then
            speedKeyLabel.Text = text.SpeedKey .. " : " .. tostring(oldKey):gsub("Enum.KeyCode.", "")
        end
    end)
    Tab:AddNumberInput({ Title = text.SpeedValue, Min = 1, Max = 10, Default = 2, Callback = function(v) Config.SpeedValue = v end })

    Tab:AddSection(text.SecLockBind)
    Tab:AddToggle({ Title = text.LockBind, Default = false, Callback = function(s) Config.LockBind = s end })
    local lockKeyLabel = Tab:AddLabel(text.LockKey .. " : " .. tostring(Config.LockKey):gsub("Enum.KeyCode.", ""))
    Tab:AddButton(text.LockKey .. " (нажмите для смены)", function()
        local oldKey = Config.LockKey
        lockKeyLabel.Text = text.LockKey .. " : ... (ожидание)"
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            conn:Disconnect()
            Config.LockKey = input.KeyCode
            lockKeyLabel.Text = text.LockKey .. " : " .. tostring(input.KeyCode):gsub("Enum.KeyCode.", "")
        end)
        task.wait(3)
        if Config.LockKey == oldKey then
            lockKeyLabel.Text = text.LockKey .. " : " .. tostring(oldKey):gsub("Enum.KeyCode.", "")
        end
    end)

    Tab:AddSection(text.SecVisuals)
    Tab:AddToggle({ Title = text.PlayerChams, Default = true, Callback = function(s) Config.PlayerChams = s end })
    Tab:AddToggle({ Title = text.GunChams, Default = false, Callback = function(s) Config.GunChams = s end })
end

return Autofarm
