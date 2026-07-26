-- [[ MM2 MOVEMENT MODULE - PURPLE FOX HUB ]] --

local Movement = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- 1. ЛОКАЛЬНЫЙ КОНФИГ МОДУЛЯ
-- ==========================================
Movement.Config = {
    WalkSpeed = 16,
    JumpPower = 50,
    InfiniteJump = false,
    Invisibility = false,
    AntiFling = false,
    AntiAFK = true,
    NoClip = false
}

local Connections = {}

-- ==========================================
-- 2. ОСНОВНЫЕ СИСТЕМЫ И ЦИКЛЫ
-- ==========================================

-- ⚡ Бесконечные прыжки (Infinite Jump)
Connections.InfJump = UserInputService.JumpRequest:Connect(function()
    if Movement.Config.InfiniteJump and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- 🛡️ Anti-AFK (Защита от кика)
Connections.AntiAFK = LocalPlayer.Idled:Connect(function()
    if Movement.Config.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- 🔄 Главный цикл физики (WalkSpeed, JumpPower, NoClip, AntiFling, Invisibility)
Connections.MainLoop = RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")

    -- Скорость бега и высота прыжка
    if humanoid then
        humanoid.WalkSpeed = Movement.Config.WalkSpeed
        humanoid.JumpPower = Movement.Config.JumpPower
        humanoid.UseJumpPower = true
    end

    -- 🚪 NoClip (Хождение сквозь стены)
    if Movement.Config.NoClip then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end

    -- 👻 Невидимость (Invisibility)
    if Movement.Config.Invisibility and root then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("Decal") then
                part.Transparency = 1
            end
        end
    end

    -- 🛡️ Anti-Fling (Защита от стороннего флинга)
    if Movement.Config.AntiFling then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                for _, part in pairs(player.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                        part.Velocity = Vector3.new(0, 0, 0)
                        part.RotVelocity = Vector3.new(0, 0, 0)
                    end
                end
            end
        end
    end
end)

-- ==========================================
-- 3. ПОДКЛЮЧЕНИЕ К ИНТЕРФЕЙСУ (UI REGISTRY)
-- ==========================================
function Movement.Init(GlobalConfig, UI)
    -- Синхронизация с глобальным конфигом, если он передан
    if GlobalConfig then
        Movement.Config = GlobalConfig
    end

    -- Создаем или запрашиваем вкладку "🏃 Движение" в фиолетовом меню
    local MoveTab = UI:GetTab("🏃 Движение")

    -- 1. Слайдер скорости (16 - 150)
    MoveTab:AddSlider({
        Title = "Кастомная скорость бега",
        Min = 16,
        Max = 150,
        Default = Movement.Config.WalkSpeed,
        Callback = function(val)
            Movement.Config.WalkSpeed = val
        end
    })

    -- 2. Слайдер высоты прыжка (50 - 300)
    MoveTab:AddSlider({
        Title = "Кастомная высота прыжка",
        Min = 50,
        Max = 300,
        Default = Movement.Config.JumpPower,
        Callback = function(val)
            Movement.Config.JumpPower = val
        end
    })

    -- 3. Бесконечные прыжки
    MoveTab:AddToggle({
        Title = "Бесконечные прыжки",
        Default = Movement.Config.InfiniteJump,
        Callback = function(state)
            Movement.Config.InfiniteJump = state
        end
    })

    -- 4. NoClip
    MoveTab:AddToggle({
        Title = "Ноу-клип (NoClip)",
        Default = Movement.Config.NoClip,
        Callback = function(state)
            Movement.Config.NoClip = state
        end
    })

    -- 5. Невидимость
    MoveTab:AddToggle({
        Title = "Невидимость для всех игроков",
        Default = Movement.Config.Invisibility,
        Callback = function(state)
            Movement.Config.Invisibility = state
        end
    })

    -- 6. Анти-Флинг
    MoveTab:AddToggle({
        Title = "Анти-Флинг (Защита)",
        Default = Movement.Config.AntiFling,
        Callback = function(state)
            Movement.Config.AntiFling = state
        end
    })

    -- 7. Анти-АФК
    MoveTab:AddToggle({
        Title = "Анти-АФК (Защита от кика)",
        Default = Movement.Config.AntiAFK,
        Callback = function(state)
            Movement.Config.AntiAFK = state
        end
    })
end

return Movement
