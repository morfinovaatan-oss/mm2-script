-- [[ MM2 COMBAT MODULE - ENHANCED & RELIABLE EDITION ]] --
local Combat = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

Combat.Config = {
    -- Aimbot
    AimEnabled = false,
    AimMode = "Dynamic",     -- Static, Dynamic, Smooth
    Prediction = 15,         -- percentage multiplier
    SmoothSpeed = 5,         -- 1-10 (higher = faster)
    SilentAim = false,       -- experimental

    -- Distance / FOV
    FOV = 120,
    FOVTransparency = 0.5,
    TriggerBot = false,

    -- Automation
    AutoEquipGun = false,
    AutoShot = false,
    AutoPickGun = false,
    InfinitePickup = false,
    OneTapKnife = false,
    NoRecoil = false,

    -- Misc
    AntiAim = false,
    FakeLag = false,
}

-- FOV circle GUI
local FOVGui = Instance.new("ScreenGui")
FOVGui.Name = "PurpleFox_FOV"
FOVGui.ResetOnSpawn = false
pcall(function() FOVGui.Parent = CoreGui end)
if not FOVGui.Parent then FOVGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local FOVFrame = Instance.new("Frame", FOVGui)
FOVFrame.BackgroundTransparency = 1
FOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)
FOVFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
FOVFrame.Visible = false
local FOVCorner = Instance.new("UICorner", FOVFrame)
FOVCorner.CornerRadius = UDim.new(1, 0)
local FOVStroke = Instance.new("UIStroke", FOVFrame)
FOVStroke.Thickness = 1.5
FOVStroke.Color = Color3.fromRGB(160, 32, 240)

-- Helper: simulate mouse click
local function SimulateClick()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    task.wait(0.02)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
end

-- Check if a player is a threat (Murderer or has weapon)
local function IsThreat(player)
    if player == LocalPlayer then return false end
    local char = player.Character
    if not char then return false end
    -- MM2 role detection: Murderer has a knife in hand or backpack, Sheriff has a gun
    local backpack = player:FindFirstChild("Backpack")
    local hasKnife = (char:FindFirstChild("Knife") ~= nil) or (backpack and backpack:FindFirstChild("Knife"))
    local hasGun = (char:FindFirstChild("Gun") ~= nil) or (backpack and backpack:FindFirstChild("Gun"))
    -- Murderer has knife, Sheriff has gun; both can be threats. Also account for Hero skin etc.
    return hasKnife or hasGun
end

-- Find best target within FOV (screen-space)
local function GetTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local bestTarget = nil
    local closestDist = Combat.Config.FOV  -- in pixels

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            local head = char:FindFirstChild("Head")
            if hum and hum.Health > 0 and head and IsThreat(player) then
                local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        bestTarget = head
                    end
                end
            end
        end
    end
    return bestTarget
end

-- Smooth aim towards a 3D position
local function SmoothAim(targetPos, speed)
    speed = speed or Combat.Config.SmoothSpeed / 10  -- normalize
    local currentCF = Camera.CFrame
    local desiredCF = CFrame.new(currentCF.Position, targetPos)
    Camera.CFrame = currentCF:Lerp(desiredCF, speed)
end

-- Instant aim (Static mode)
local function InstantAim(targetPos)
    Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
end

-- Silent Aim (experimental) - instantly rotates character's HumanoidRootPart? 
-- This is not a true silent aim; in MM2, weapons use RemoteEvents.
-- For demonstration we just snap camera without smoothing, still visually turning.
local function SilentAimSnap(targetPos)
    Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
end

-- Main combat loop
task.spawn(function()
    while task.wait(0.03) do
        pcall(function()
            if not LocalPlayer.Character or LocalPlayer.Character:FindFirstChildOfClass("Humanoid").Health <= 0 then
                FOVFrame.Visible = false
                return
            end

            -- Update FOV circle
            FOVFrame.Size = UDim2.new(0, Combat.Config.FOV * 2, 0, Combat.Config.FOV * 2)
            FOVStroke.Transparency = Combat.Config.FOVTransparency
            FOVFrame.Visible = Combat.Config.AimEnabled or Combat.Config.SilentAim

            local target = GetTarget()
            local targetPos = target and target.Position

            -- 1. Prediction
            if targetPos and Combat.Config.Prediction > 0 then
                local root = target.Parent and target.Parent:FindFirstChild("HumanoidRootPart")
                if root then
                    targetPos = targetPos + (root.Velocity * (Combat.Config.Prediction / 1000))
                end
            end

            -- 2. Aimbot
            if Combat.Config.AimEnabled and targetPos then
                if Combat.Config.AimMode == "Static" then
                    InstantAim(targetPos)
                elseif Combat.Config.AimMode == "Smooth" or Combat.Config.AimMode == "Dynamic" then
                    SmoothAim(targetPos, Combat.Config.SmoothSpeed / 10)
                end
            end

            -- 3. Silent Aim (if enabled, snaps camera instantly – not recommended for legit play)
            if Combat.Config.SilentAim and targetPos then
                SilentAimSnap(targetPos)  -- Overrides other aim modes, still rotates camera
            end

            -- 4. Auto‑Shot (fires if target within FOV and aim is active)
            if Combat.Config.AutoShot and targetPos and (Combat.Config.AimEnabled or Combat.Config.SilentAim) then
                local equippedTool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                if equippedTool and (equippedTool.Name == "Gun" or equippedTool:FindFirstChild("Gun")) then
                    SimulateClick()
                end
            end

            -- 5. TriggerBot (fires when mouse hovers over a threat)
            if Combat.Config.TriggerBot then
                local mouseTarget = UserInputService:GetMouseLocation()
                -- Simple approach: get part under mouse
                local ray = Camera:ViewportPointToRay(mouseTarget.X, mouseTarget.Y)
                local raycastParams = RaycastParams.new()
                raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
                local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)
                if result and result.Instance then
                    local hitPlayer = Players:GetPlayerFromCharacter(result.Instance.Parent)
                    if hitPlayer and hitPlayer ~= LocalPlayer and IsThreat(hitPlayer) then
                        SimulateClick()
                    end
                end
            end

            -- 6. Auto‑Equip Gun
            if Combat.Config.AutoEquipGun then
                local char = LocalPlayer.Character
                if char then
                    local currentTool = char:FindFirstChildOfClass("Tool")
                    if not currentTool or currentTool.Name ~= "Gun" then
                        local backpack = LocalPlayer:FindFirstChild("Backpack")
                        local gun = backpack and backpack:FindFirstChild("Gun")
                        if gun then
                            char.Humanoid:EquipTool(gun)
                        end
                    end
                end
            end

            -- 7. Auto‑Pick Gun (teleport pickups to player)
            if Combat.Config.AutoPickGun or Combat.Config.InfinitePickup then
                local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    for _, obj in pairs(Workspace:GetDescendants()) do
                        if obj:IsA("BasePart") and (obj.Name:lower():find("gun") or obj.Name:lower():find("gundrop")) then
                            local dist = (obj.Position - root.Position).Magnitude
                            if dist < 15 or Combat.Config.InfinitePickup then
                                obj.CFrame = root.CFrame + Vector3.new(0, 2, 0)  -- teleport to player
                                task.wait(0.05)
                            end
                        end
                    end
                end
            end

            -- 8. One Tap Knife (reduce knife grip distance for instant hit)
            if Combat.Config.OneTapKnife then
                local knife = LocalPlayer.Character and (LocalPlayer.Character:FindFirstChild("Knife") or
                    (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Knife")))
                if knife and knife:IsA("Tool") then
                    -- Adjust grip to zero offset
                    knife.GripPos = Vector3.new(0, 0, 0)
                end
            end

            -- 9. NoRecoil (counteract camera recoil when firing)
            if Combat.Config.NoRecoil then
                local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                if tool and tool:FindFirstChild("Gun") then
                    -- Simple method: lock camera to current orientation
                    Camera.CFrame = Camera.CFrame
                    -- A more robust method would involve hooking the gun's Recoil remote, but that's game-specific.
                end
            end

            -- 10. Anti‑Aim (spin character randomly)
            if Combat.Config.AntiAim then
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    char.Humanoid.AutoRotate = false
                    local root = char.HumanoidRootPart
                    root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(15), 0)  -- rotate 15° per tick
                end
            else
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                    LocalPlayer.Character.Humanoid.AutoRotate = true
                end
            end

            -- 11. FakeLag (stutter movement – experimental)
            if Combat.Config.FakeLag then
                -- This implementation is very basic; it freezes the character briefly.
                -- Real fake lag would require network manipulation.
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    char.HumanoidRootPart.Anchored = true
                    task.wait(0.05)
                    char.HumanoidRootPart.Anchored = false
                end
            end
        end)
    end
end)

-- Initialization function to create UI elements (called by main loader)
function Combat.Init(GlobalConfig, UI, Lang)
    local T = {
        RU = {
            Tab = "⚔️ Комбат",
            SecAim = "Аимбот и Наводка",
            AimEnable = "1. Включить Аимбот",
            AimMode = "2. Режим Аимбота",
            Pred = "3. Упреждение (%)",
            Smooth = "4. Сглаживание (1‑10)",
            Silent = "5. Silent Aim (эксперим.)",
            FOV = "6. Радиус FOV",
            FOVTrans = "7. Прозрачность FOV",
            Trigger = "8. Триггер‑бот",

            SecAuto = "Автоматизация",
            AutoEquip = "9. Авто‑экипировка",
            AutoShot = "10. Авто‑выстрел",
            AutoPick = "11. Авто‑подбор пистолета",
            InfPickup = "12. Бесконечный подбор",
            OneTap = "13. One Tap Knife",

            SecMisc = "Дополнительно",
            NoRecoil = "14. Без отдачи",
            AntiAim = "15. Anti‑Aim",
            FakeLag = "16. Fake Lag"
        },
        EN = {
            Tab = "⚔️ Combat",
            SecAim = "Aimbot & Targeting",
            AimEnable = "1. Enable Aimbot",
            AimMode = "2. Aimbot Mode",
            Pred = "3. Prediction",
            Smooth = "4. Smooth Speed",
            Silent = "5. Silent Aim (exp.)",
            FOV = "6. FOV Radius",
            FOVTrans = "7. FOV Transparency",
            Trigger = "8. Triggerbot",

            SecAuto = "Automation",
            AutoEquip = "9. Auto‑Equip Gun",
            AutoShot = "10. Auto‑Shot",
            AutoPick = "11. Auto‑Pick Gun",
            InfPickup = "12. Infinite Pickup",
            OneTap = "13. One Tap Knife",

            SecMisc = "Misc",
            NoRecoil = "14. No Recoil",
            AntiAim = "15. Anti‑Aim",
            FakeLag = "16. Fake Lag"
        }
    }

    local text = T[Lang] or T.RU
    local CombatTab = UI:CreateTab(text.Tab)

    -- Section 1: Aimbot
    CombatTab:AddSection(text.SecAim)
    CombatTab:AddToggle({ Title = text.AimEnable, Default = false, Callback = function(s) Combat.Config.AimEnabled = s end })
    CombatTab:AddDropdown({
        Title = text.AimMode,
        Options = {"Static", "Dynamic", "Smooth"},
        Default = Combat.Config.AimMode,
        Callback = function(val) Combat.Config.AimMode = val end
    })
    CombatTab:AddNumberInput({ Title = text.Pred, Min = 0, Max = 100, Default = Combat.Config.Prediction, Callback = function(v) Combat.Config.Prediction = v end })
    CombatTab:AddNumberInput({ Title = text.Smooth, Min = 1, Max = 10, Default = Combat.Config.SmoothSpeed, Callback = function(v) Combat.Config.SmoothSpeed = v end })
    CombatTab:AddToggle({ Title = text.Silent, Default = false, Callback = function(s) Combat.Config.SilentAim = s end })
    CombatTab:AddNumberInput({ Title = text.FOV, Min = 30, Max = 400, Default = Combat.Config.FOV, Callback = function(v) Combat.Config.FOV = v end })
    CombatTab:AddNumberInput({ Title = text.FOVTrans, Min = 0, Max = 1, Default = Combat.Config.FOVTransparency, Callback = function(v) Combat.Config.FOVTransparency = v end })
    CombatTab:AddToggle({ Title = text.Trigger, Default = false, Callback = function(s) Combat.Config.TriggerBot = s end })

    -- Section 2: Automation
    CombatTab:AddSection(text.SecAuto)
    CombatTab:AddToggle({ Title = text.AutoEquip, Default = false, Callback = function(s) Combat.Config.AutoEquipGun = s end })
    CombatTab:AddToggle({ Title = text.AutoShot, Default = false, Callback = function(s) Combat.Config.AutoShot = s end })
    CombatTab:AddToggle({ Title = text.AutoPick, Default = false, Callback = function(s) Combat.Config.AutoPickGun = s end })
    CombatTab:AddToggle({ Title = text.InfPickup, Default = false, Callback = function(s) Combat.Config.InfinitePickup = s end })
    CombatTab:AddToggle({ Title = text.OneTap, Default = false, Callback = function(s) Combat.Config.OneTapKnife = s end })

    -- Section 3: Misc
    CombatTab:AddSection(text.SecMisc)
    CombatTab:AddToggle({ Title = text.NoRecoil, Default = false, Callback = function(s) Combat.Config.NoRecoil = s end })
    CombatTab:AddToggle({ Title = text.AntiAim, Default = false, Callback = function(s) Combat.Config.AntiAim = s end })
    CombatTab:AddToggle({ Title = text.FakeLag, Default = false, Callback = function(s) Combat.Config.FakeLag = s end })
end

return Combat
