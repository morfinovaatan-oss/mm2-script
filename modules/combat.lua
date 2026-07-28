-- [[ MM2 COMBAT MODULE – адаптированный под UILibrary ]] --
local Combat = {}

-- ... (весь предыдущий код до функции Init остаётся без изменений) ...

-- ================== UI Init (новый) ==================
function Combat.Init(GlobalConfig, parentTab, Lang)
    local T = {
        RU = {
            SubMain = "Основное",
            SecAim = "Аимбот",
            AimEnable = "Аимбот",
            AimMode = "Режим",
            FOVCenter = "Центр FOV",
            Pred = "Упреждение",
            Smooth = "Сглаживание",
            FOV = "Радиус FOV",
            FOVTrans = "Прозрачность FOV",
            HackerDist = "Дистанция Hacker",
            Trigger = "Триггер-бот",
            AutoShiftLock = "Авто-Shift Lock",

            SecKeys = "Горячие клавиши",
            ShootKey = "Выстрел",
            PickupKey = "Подобрать пистолет",
            FindMurdererKey = "Найти мёрдера",
            FindSheriffKey = "Найти шерифа",

            SecAuto = "Автоматизация",
            AutoEquip = "Авто-экипировка",
            AutoShot = "Авто-выстрел",
            InstantPickup = "Мгновенный подбор",
            AutoNotifyPickup = "Уведомление о пистолете",
            OneTap = "One Tap Knife",

            SecMisc = "Прочее",
            NoRecoil = "Без отдачи",
            AntiAim = "Anti-Aim",
            FakeLag = "Fake Lag"
        },
        EN = {
            SubMain = "Main",
            SecAim = "Aimbot",
            AimEnable = "Aimbot",
            AimMode = "Mode",
            FOVCenter = "FOV Center",
            Pred = "Prediction",
            Smooth = "Smoothness",
            FOV = "FOV Radius",
            FOVTrans = "FOV Transparency",
            HackerDist = "Hacker Distance",
            Trigger = "Triggerbot",
            AutoShiftLock = "Auto Shift Lock",

            SecKeys = "Keybinds",
            ShootKey = "Shoot",
            PickupKey = "Pickup Gun",
            FindMurdererKey = "Find Murderer",
            FindSheriffKey = "Find Sheriff",

            SecAuto = "Automation",
            AutoEquip = "Auto-Equip",
            AutoShot = "Auto-Shot",
            InstantPickup = "Instant Pickup",
            AutoNotifyPickup = "Notify gun drop",
            OneTap = "One Tap Knife",

            SecMisc = "Misc",
            NoRecoil = "No Recoil",
            AntiAim = "Anti-Aim",
            FakeLag = "Fake Lag"
        }
    }

    local text = T[Lang] or T.RU
    local SubTab = parentTab:AddSubTab(text.SubMain)

    -- Aimbot Group
    local AimGroup = SubTab:AddGroupbox(text.SecAim)
    AimGroup:AddToggle({
        Text = text.AimEnable,
        Default = false,
        Callback = function(s) Combat.Config.AimEnabled = s end
    })
    AimGroup:AddDropdown({
        Text = text.AimMode,
        Items = {"Static", "Dynamic", "Smooth", "Hacker", "Flick Shot"},
        Default = Combat.Config.AimMode == "Silent" and "Flick Shot" or Combat.Config.AimMode,
        Callback = function(v)
            if v == "Flick Shot" then
                Combat.Config.AimMode = "Silent"
            else
                Combat.Config.AimMode = v
            end
        end
    })
    AimGroup:AddDropdown({
        Text = text.FOVCenter,
        Items = {"Mouse", "Camera"},
        Default = Combat.Config.FOVCenter,
        Callback = function(v) Combat.Config.FOVCenter = v end
    })
    AimGroup:AddSlider({
        Text = text.Pred,
        Min = 0, Max = 100, Default = Combat.Config.Prediction,
        Suffix = "%",
        Callback = function(v) Combat.Config.Prediction = v end
    })
    AimGroup:AddSlider({
        Text = text.Smooth,
        Min = 1, Max = 10, Default = Combat.Config.SmoothSpeed,
        Callback = function(v) Combat.Config.SmoothSpeed = v end
    })
    AimGroup:AddSlider({
        Text = text.FOV,
        Min = 30, Max = 500, Default = Combat.Config.FOV,
        Callback = function(v) Combat.Config.FOV = v end
    })
    AimGroup:AddSlider({
        Text = text.FOVTrans,
        Min = 0, Max = 1, Default = Combat.Config.FOVTransparency,
        Suffix = "",
        Decimals = 2,
        Callback = function(v) Combat.Config.FOVTransparency = v end
    })
    AimGroup:AddSlider({
        Text = text.HackerDist,
        Min = 5, Max = 20, Default = Combat.Config.HackerDistance,
        Suffix = " m",
        Callback = function(v) Combat.Config.HackerDistance = v end
    })
    AimGroup:AddToggle({
        Text = text.Trigger,
        Default = false,
        Callback = function(s) Combat.Config.TriggerBot = s end
    })
    AimGroup:AddToggle({
        Text = text.AutoShiftLock,
        Default = Combat.Config.AutoShiftLock,
        Callback = function(s) Combat.Config.AutoShiftLock = s end
    })

    -- Keybinds Group
    local KeysGroup = SubTab:AddGroupbox(text.SecKeys)
    local function addKeybindRow(keyName, configKey)
        local label = KeysGroup:AddLabel(keyName .. " : " .. tostring(configKey):gsub("Enum.KeyCode.", ""))
        KeysGroup:AddButton({
            Text = keyName .. " (нажмите для смены)",
            Callback = function()
                local oldKey = configKey
                label:SetText(keyName .. " : ... (ожидание)")
                local conn
                conn = game:GetService("UserInputService").InputBegan:Connect(function(input, gp)
                    if gp then return end
                    conn:Disconnect()
                    Combat.Config[configKey] = input.KeyCode
                    label:SetText(keyName .. " : " .. tostring(input.KeyCode):gsub("Enum.KeyCode.", ""))
                end)
                task.wait(3)
                if Combat.Config[configKey] == oldKey then
                    label:SetText(keyName .. " : " .. tostring(oldKey):gsub("Enum.KeyCode.", ""))
                end
            end
        })
    end
    addKeybindRow(text.ShootKey, "ShootKey")
    addKeybindRow(text.PickupKey, "PickupKey")
    addKeybindRow(text.FindMurdererKey, "FindMurdererKey")
    addKeybindRow(text.FindSheriffKey, "FindSheriffKey")

    -- Automation Group
    local AutoGroup = SubTab:AddGroupbox(text.SecAuto)
    AutoGroup:AddToggle({
        Text = text.AutoEquip,
        Default = false,
        Callback = function(s) Combat.Config.AutoEquipGun = s end
    })
    AutoGroup:AddToggle({
        Text = text.AutoShot,
        Default = false,
        Callback = function(s) Combat.Config.AutoShot = s end
    })
    AutoGroup:AddToggle({
        Text = text.InstantPickup,
        Default = false,
        Callback = function(s) Combat.Config.InstantGunPickup = s end
    })
    AutoGroup:AddToggle({
        Text = text.AutoNotifyPickup,
        Default = true,
        Callback = function(s) Combat.Config.AutoNotifyPickup = s end
    })
    AutoGroup:AddToggle({
        Text = text.OneTap,
        Default = false,
        Callback = function(s) Combat.Config.OneTapKnife = s end
    })

    -- Misc Group
    local MiscGroup = SubTab:AddGroupbox(text.SecMisc)
    MiscGroup:AddToggle({
        Text = text.NoRecoil,
        Default = false,
        Callback = function(s) Combat.Config.NoRecoil = s end
    })
    MiscGroup:AddToggle({
        Text = text.AntiAim,
        Default = false,
        Callback = function(s) Combat.Config.AntiAim = s end
    })
    MiscGroup:AddToggle({
        Text = text.FakeLag,
        Default = false,
        Callback = function(s) Combat.Config.FakeLag = s end
    })
end

return Combat
