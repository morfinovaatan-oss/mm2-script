-- [[ MM2 AUTO‑FARM – Integrated FoxAutofarm Menu (Linoria-based) ]] --
local Autofarm = {}

function Autofarm.Init(GlobalConfig, UI, Lang)
    local T = {
        RU = { TabName = "💰 Автофарм", LaunchBtn = "Запустить автофарм" },
        EN = { TabName = "💰 AutoFarm", LaunchBtn = "Launch AutoFarm" }
    }
    local text = T[Lang] or T.RU
    local FarmTab = UI:CreateTab(text.TabName)

    FarmTab:AddButton(text.LaunchBtn, function()
        local success, err = pcall(function()
            -- ===== Встроенный код FoxAutofarm (бывший OminousVibes) =====
            local Players = game:GetService("Players")
            local RunService = game:GetService("RunService")
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local Workspace = game:GetService("Workspace")
            local CoreGui = game:GetService("CoreGui")

            local repo = "https://raw.githubusercontent.com/wally-rblx/LinoriaLib/main/"
            local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
            local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
            local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()

            local LocalPlayer = Players.LocalPlayer
            local BoundKeys = LocalPlayer.PlayerScripts.PlayerModule.CameraModule.MouseLockController.BoundKeys
            local FarmMethods = { "Coins only (Silent)", "Coins and EXP (Visible)", "Coins, EXP, and Kills (Blatant)" }

            local GunHighlight = Instance.new("Highlight")
            local GunHandleAdornment = Instance.new("SphereHandleAdornment")

            local murderer, sheriff, hero
            local roles = {}
            local visuals = {}

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
                        highlight.FillColor = Options[role .. "_Color"].Value
                    end
                end
            end

            local function onPlayerAdded(player)
                local highlight = Instance.new("Highlight")
                highlight.FillColor = Options.Unknown_Color.Value
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

            -- ===== Интерфейс =====
            Library:SetWatermark("FoxAutofarm")
            Library:Notify("Loading FoxAutofarm...")

            local Window = Library:CreateWindow("FoxAutofarm")

            -- Вкладка Legit
            local TabLegit = Window:AddTab("Legit")
            local RolesContainer = TabLegit:AddLeftTabbox("Roles")

            local Murd = RolesContainer:AddTab("Murderer")
            Murd:AddToggle("Reach", { Text = "Hitbox Extender", Default = false })
            Murd:AddSlider("Reach", { Text = "Hitbox Radius", Min = 5, Max = 20, Default = 10, Rounding = 0, Suffix = "studs" })
            Murd:AddSlider("ReachAngle", { Text = "Hitbox Angle", Min = 10, Max = 180, Default = 60, Rounding = 0, Suffix = "degrees" })
            Murd:AddToggle("StabAll", { Text = "Kill All (Swing your knife)", Default = false })

            local Sher = RolesContainer:AddTab("Sheriff")
            Sher:AddToggle("SilentAim", { Text = "Silent Aim", Default = false })
                :AddKeyPicker("SilentAim", { Text = "Silent Aim", Default = "G", Mode = "Toggle" })
            Sher:AddSlider("Prediction", { Text = "Prediction", Min = 0, Max = 100, Default = 10, Rounding = 0, Suffix = "%" })

            local Innocent = RolesContainer:AddTab("Innocent")
            Innocent:AddToggle("Callouts", { Text = "Callout Murderer", Default = false })
                :AddKeyPicker("Callouts", { Text = "Callouts", NoUI = true })
            Innocent:AddInput("CalloutMessage", { Text = "Callout Message", Default = "Murderer is ${murderer}, Sheriff is ${sheriff}" })
            Innocent:AddToggle("AutoGun", { Text = "Auto-Pickup Gun", Default = false })

            local OthersContainer = TabLegit:AddRightGroupbox("Others")
            OthersContainer:AddToggle("SpeedHack", { Text = "Speed Hack", Default = false })
                :AddKeyPicker("SpeedHack", { Text = "Speed", Default = "LeftShift", Mode = "Hold" })
            OthersContainer:AddSlider("Speed", { Text = "Speed", Min = 1, Max = 10, Default = 2, Rounding = 1, Suffix = "" })
            OthersContainer:AddToggle("LockBind", { Text = "Bind Shift-Lock", Default = false })
                :AddKeyPicker("LockBind", { Text = "Key", Default = "LeftControl", NoUI = true })

            local ProgressionContainer = TabLegit:AddLeftTabbox("Progression")
            local AutoFarmTab = ProgressionContainer:AddTab("Auto Farm")
            AutoFarmTab:AddToggle("AutoFarm", { Text = "Enabled", Default = false })
            AutoFarmTab:AddDropdown("FarmMethod", { Text = "Farm Algorithm", Default = FarmMethods[1], Values = FarmMethods })
            AutoFarmTab:AddToggle("FarmNotifications", { Text = "Status Notifications", Default = false })

            -- Вкладка Visuals
            local TabVisuals = Window:AddTab("Visuals")
            local VisualsContainer = TabVisuals:AddLeftTabbox("Visuals")
            local PlayerTab = VisualsContainer:AddTab("Player")
            PlayerTab:AddToggle("PlayerChams", { Text = "ESP", Default = true })
            local WorldTab = VisualsContainer:AddTab("World")
            WorldTab:AddToggle("GunChams", { Text = "Gun Chams", Default = false })
            local SettingsTab = VisualsContainer:AddTab("Settings")
            SettingsTab:AddLabel("Murderer Color"):AddColorPicker("Murderer_Color", { Default = Color3.new(1, 0, 0) })
            SettingsTab:AddLabel("Sheriff Color"):AddColorPicker("Sheriff_Color", { Default = Color3.new(0, 0, 1) })
            SettingsTab:AddLabel("Hero Color"):AddColorPicker("Hero_Color", { Default = Color3.new(1, 1, 0) })
            SettingsTab:AddLabel("Innocent Color"):AddColorPicker("Innocent_Color", { Default = Color3.new(1, 1, 1) })
            SettingsTab:AddLabel("Unknown Color"):AddColorPicker("Unknown_Color", { Default = Color3.new(0.5, 0.5, 0.5) })
            local WorldRenderContainer = TabVisuals:AddRightGroupbox("World Render")
            WorldRenderContainer:AddLabel("Work in progress")

            -- Вкладка Settings
            local TabSettings = Window:AddTab("Settings")
            ThemeManager:SetLibrary(Library)
            SaveManager:SetLibrary(Library)
            ThemeManager:SetFolder("FoxAutofarm")
            SaveManager:SetFolder("FoxAutofarm/MurderMystery2")
            SaveManager:IgnoreThemeSettings()
            SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
            SaveManager:BuildConfigSection(TabSettings)
            ThemeManager:ApplyToTab(TabSettings)

            local MenuGroup = TabSettings:AddLeftGroupbox("Menu")
            MenuGroup:AddButton("Unload", function() Library:Unload() end)
            MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "End", NoUI = true, Text = "Menu keybind" })
            MenuGroup:AddToggle("Keybinds", { Text = "Show Keybinds Menu", Default = true }):OnChanged(function()
                Library.KeybindFrame.Visible = Toggles.Keybinds.Value
            end)
            MenuGroup:AddToggle("Watermark", { Text = "Show Watermark", Default = true }):OnChanged(function()
                Library:SetWatermarkVisibility(Toggles.Watermark.Value)
            end)

            -- Обработчики событий
            Toggles.AutoFarm:OnChanged(function()
                while Toggles.AutoFarm.Value do
                    local character = LocalPlayer.Character
                    if isCharacterValid(character) then
                        local CoinContainer = Workspace:FindFirstChild("CoinContainer", true)
                        if CoinContainer and roles[LocalPlayer] ~= "Unknown" then
                            local coin = CoinContainer:FindFirstChild("Coin_Server")
                            if coin then
                                local root = character.HumanoidRootPart
                                repeat
                                    root.CFrame = CFrame.new(coin.Position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(180))
                                    RunService.Stepped:Wait()
                                    if not Toggles.AutoFarm.Value then break end
                                until not coin:IsDescendantOf(Workspace) or coin.Name ~= "Coin_Server"
                                task.wait(0.5)
                            end
                        else
                            task.wait(0.5)
                        end
                    end
                    task.wait()
                end
            end)

            Options.Callouts:OnClick(function()
                if Toggles.Callouts.Value then
                    local callout = Options.CalloutMessage.Value
                    local message = callout
                        :gsub("${murderer}", murderer and murderer.Name or "NaN")
                        :gsub("${sheriff}", sheriff and sheriff.Name or "NaN")
                    ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(message, "normalchat")
                end
            end)

            Library:Notify("FoxAutofarm Loaded")

            -- ===== Подключение событий и основной цикл =====
            Players.PlayerAdded:Connect(onPlayerAdded)
            Players.PlayerRemoving:Connect(onPlayerRemoving)

            local lastCFrame = false
            RunService.RenderStepped:Connect(function()
                local character = LocalPlayer.Character
                if isCharacterValid(character) then
                    if Toggles.Reach.Value then
                        local Knife = character:FindFirstChild("Knife")
                        if Knife and Knife:IsA("Tool") then
                            local HumanoidRootPart = character.HumanoidRootPart
                            for _, v in ipairs(Players:GetPlayers()) do
                                if v ~= LocalPlayer and isCharacterValid(v.Character) then
                                    local EnemyRoot = v.Character.HumanoidRootPart
                                    local EnemyPosition = EnemyRoot.Position
                                    local Distance = (EnemyPosition - HumanoidRootPart.Position).Magnitude
                                    local Angle = findAngleDelta(
                                        HumanoidRootPart.CFrame.LookVector.Unit,
                                        (EnemyPosition - HumanoidRootPart.Position).Unit
                                    )
                                    if Toggles.StabAll.Value or (Distance <= Options.Reach.Value and Angle <= Options.ReachAngle.Value) then
                                        firetouchinterest(EnemyRoot, Knife.Handle, 1)
                                        firetouchinterest(EnemyRoot, Knife.Handle, 0)
                                    end
                                end
                            end
                        end
                    end

                    if Toggles.AutoGun.Value and roles[LocalPlayer] == "Innocent" then
                        local gundrop = Workspace:FindFirstChild("GunDrop")
                        if gundrop and not lastCFrame then
                            lastCFrame = character.HumanoidRootPart.CFrame
                            task.spawn(pcall, function()
                                repeat
                                    character.HumanoidRootPart.CFrame = gundrop.CFrame
                                    RunService.Stepped:Wait()
                                until not gundrop:IsDescendantOf(Workspace) or not Toggles.AutoGun.Value
                                character.HumanoidRootPart.CFrame = lastCFrame
                                lastCFrame = false
                            end)
                        end
                    end

                    if Toggles.SpeedHack.Value then
                        local SpeedState = Options.SpeedHack:GetState()
                        character.Humanoid.WalkSpeed = SpeedState and (16 + Options.Speed.Value) or 16
                    end
                end

                BoundKeys.Value = Toggles.LockBind.Value and (Options.LockBind.Value or "LeftControl") or "LeftShift, RightShift"

                local gundrop = Workspace:FindFirstChild("GunDrop")
                GunHighlight.Adornee = gundrop
                GunHandleAdornment.Adornee = gundrop
                if gundrop then GunHandleAdornment.Size = gundrop.Size + Vector3.new(0.05, 0.05, 0.05) end

                for _, v in pairs(visuals) do v.Enabled = Toggles.PlayerChams.Value end
                GunHighlight.Enabled = Toggles.GunChams.Value
                GunHandleAdornment.Visible = Toggles.GunChams.Value
            end)

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

            local __namecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                local args = { ... }
                if not checkcaller() and typeof(self) == "Instance" then
                    if self.Name == "ShootGun" and method == "InvokeServer" then
                        if Toggles.SilentAim.Value and Options.SilentAim:GetState() and murderer then
                            local root = murderer.Character.PrimaryPart
                            local velocity = root.AssemblyLinearVelocity
                            local aimPosition = root.Position + velocity * Vector3.new(Options.Prediction.Value / 200, 0, Options.Prediction.Value / 200)
                            args[2] = aimPosition
                        end
                    end
                end
                return __namecall(self, unpack(args))
            end)

            GunHighlight.FillColor = Options.Hero_Color.Value
            GunHighlight.Adornee = Workspace:FindFirstChild("GunDrop")
            GunHighlight.OutlineTransparency = 1
            GunHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            GunHighlight.RobloxLocked = true

            GunHandleAdornment.Color3 = Options.Hero_Color.Value
            GunHandleAdornment.Transparency = 0.2
            GunHandleAdornment.Adornee = Workspace:FindFirstChild("GunDrop")
            GunHandleAdornment.AlwaysOnTop = true
            GunHandleAdornment.AdornCullingMode = Enum.AdornCullingMode.Never
            GunHandleAdornment.RobloxLocked = true

            pcall(function() if syn then syn.protect_gui(GunHighlight) end end)
            pcall(function() if syn then syn.protect_gui(GunHandleAdornment) end end)
            GunHighlight.Parent = CoreGui
            GunHandleAdornment.Parent = CoreGui

            for _, v in ipairs(Players:GetPlayers()) do
                if v ~= LocalPlayer then onPlayerAdded(v) end
            end

            local data = ReplicatedStorage.GetPlayerData:InvokeServer()
            for _, v in ipairs(Players:GetPlayers()) do
                local info = data[v.Name]
                if info then
                    local role = typeof(info) == "table" and info.Role or "Unknown"
                    pcall(updateRole, v, role)
                end
            end
        end)
        if not success then
            warn("FoxAutofarm launch error: " .. tostring(err))
        end
    end)
end

return Autofarm
