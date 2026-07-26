-- [[ MM2 MOVEMENT MODULE ]] --
local Movement = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

Movement.Config = {
    WalkSpeed = 16,
    JumpPower = 50,
    InfiniteJump = false,
    Invisibility = false,
    AntiAFK = true,
    NoClip = false
}

local Connections = {}

-- Бесконечный прыжок
Connections.InfJump = UserInputService.JumpRequest:Connect(function()
    if Movement.Config.InfiniteJump and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- Анти-АФК
Connections.AntiAFK = LocalPlayer.Idled:Connect(function()
    if Movement.Config.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- Основной цикл (Физика персонажа)
Connections.MainLoop = RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")

    -- Скорость и прыжок
    if humanoid then
        humanoid.WalkSpeed = tonumber(Movement.Config.WalkSpeed) or 16
        humanoid.JumpPower = tonumber(Movement.Config.JumpPower) or 50
        humanoid.UseJumpPower = true
    end

    -- Ноу-клип (Проход сквозь стены)
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
end)

function Movement.Init(GlobalConfig, UI, Lang)
    -- Переводы текста
    local T = {
        RU = {
            Tab = "🏃 Движение",
            SecSpeed = "Характеристики персонажа",
            Speed = "Скорость бега",
            Jump = "Высота прыжка",
            SecAbilities = "Способности",
            InfJump = "Бесконечные прыжки",
            NoClip = "Ноу-клип (Проход сквозь стены)",
            Invis = "Невидимость",
            AntiAFK = "Анти-АФК (Защита от вылета)"
        },
        EN = {
            Tab = "🏃 Movement",
            SecSpeed = "Character Stats",
            Speed = "Walk Speed",
            Jump = "Jump Power",
            SecAbilities = "Abilities",
            InfJump = "Infinite Jump",
            NoClip = "Noclip (Wallpass)",
            Invis = "Invisibility",
            AntiAFK = "Anti-AFK (Anti-Kick)"
        }
    }
    
    local text = T[Lang] or T.RU
    local MoveTab = UI:CreateTab(text.Tab)

    -- Секция 1: Скорость и Прыжок
    MoveTab:AddSection(text.SecSpeed)

    MoveTab:AddNumberInput({
        Title = text.Speed,
        Min = 16,
        Max = 200,
        Default = Movement.Config.WalkSpeed,
        Callback = function(val) Movement.Config.WalkSpeed = val end
    })

    MoveTab:AddNumberInput({
        Title = text.Jump,
        Min = 50,
        Max = 350,
        Default = Movement.Config.JumpPower,
        Callback = function(val) Movement.Config.JumpPower = val end
    })

    -- Секция 2: Способности
    MoveTab:AddSection(text.SecAbilities)

    MoveTab:AddToggle({
        Title = text.InfJump,
        Default = Movement.Config.InfiniteJump,
        Callback = function(state) Movement.Config.InfiniteJump = state end
    })

    MoveTab:AddToggle({
        Title = text.NoClip,
        Default = Movement.Config.NoClip,
        Callback = function(state) Movement.Config.NoClip = state end
    })

    MoveTab:AddToggle({
        Title = text.Invis,
        Default = Movement.Config.Invisibility,
        Callback = function(state) Movement.Config.Invisibility = state end
    })

    MoveTab:AddToggle({
        Title = text.AntiAFK,
        Default = Movement.Config.AntiAFK,
        Callback = function(state) Movement.Config.AntiAFK = state end
    })
end

return Movement
