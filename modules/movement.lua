-- [[ MM2 MOVEMENT MODULE - PURPLE FOX HUB ]] --

local Movement = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

-- Базовый конфиг по умолчанию
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

-- Бесконечные прыжки
Connections.InfJump = UserInputService.JumpRequest:Connect(function()
    if Movement.Config.InfiniteJump and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- Anti-AFK
Connections.AntiAFK = LocalPlayer.Idled:Connect(function()
    if Movement.Config.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- Цикл физики (С защитой от nil!)
Connections.MainLoop = RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")

    if humanoid then
        humanoid.WalkSpeed = tonumber(Movement.Config.WalkSpeed) or 16
        humanoid.JumpPower = tonumber(Movement.Config.JumpPower) or 50
        humanoid.UseJumpPower = true
    end

    -- NoClip
    if Movement.Config.NoClip then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end

    -- Невидимость
    if Movement.Config.Invisibility and root then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("Decal") then
                part.Transparency = 1
            end
        end
    end

    -- Anti-Fling
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

function Movement.Init(GlobalConfig, UI)
    -- Безопасное обновление настроек
    if type(GlobalConfig) == "table" then
        for k, v in pairs(GlobalConfig) do
            Movement.Config[k] = v
        end
    end

    local MoveTab = UI:GetTab("🏃 Движение")

    -- 1. Слайдер скорости (С гарантированными значениями)
    MoveTab:AddSlider({
        Title = "Кастомная скорость бега",
        Min = 16,
        Max = 150,
        Default = tonumber(Movement.Config.WalkSpeed) or 16,
        Callback = function(val)
            Movement.Config.WalkSpeed = val
        end
    })

    -- 2. Слайдер прыжка
    MoveTab:AddSlider({
        Title = "Кастомная высота прыжка",
        Min = 50,
        Max = 300,
        Default = tonumber(Movement.Config.JumpPower) or 50,
        Callback = function(val)
            Movement.Config.JumpPower = val
        end
    })

    -- 3. Бесконечные прыжки
    MoveTab:AddToggle({
        Title = "Бесконечные прыжки",
        Default = Movement.Config.InfiniteJump or false,
        Callback = function(state)
            Movement.Config.InfiniteJump = state
        end
    })

    -- 4. NoClip
    MoveTab:AddToggle({
        Title = "Ноу-клип (NoClip)",
        Default = Movement.Config.NoClip or false,
        Callback = function(state)
            Movement.Config.NoClip = state
        end
    })

    -- 5. Невидимость
    MoveTab:AddToggle({
        Title = "Невидимость для всех игроков",
        Default = Movement.Config.Invisibility or false,
        Callback = function(state)
            Movement.Config.Invisibility = state
        end
    })

    -- 6. Анти-Флинг
    MoveTab:AddToggle({
        Title = "Анти-Флинг (Защита)",
        Default = Movement.Config.AntiFling or false,
        Callback = function(state)
            Movement.Config.AntiFling = state
        end
    })

    -- 7. Анти-АФК
    MoveTab:AddToggle({
        Title = "Анти-АФК (Защита от кика)",
        Default = Movement.Config.AntiAFK or true,
        Callback = function(state)
            Movement.Config.AntiAFK = state
        end
    })
end

return Movement
