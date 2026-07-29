-- [[ MM2 MOVEMENT MODULE – адаптированный под UILibrary ]] --
local Movement = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Переменные для полета
local FlyBodyVelocity = nil
local FlyBodyGyro = nil

Movement.Config = {
    WalkSpeed = 16,
    JumpPower = 50,
    InfiniteJump = false,
    Invisibility = false,
    AntiAFK = true,
    NoClip = false,
    NoPlayerCollision = false,
    Fly = false,
    FlySpeed = 50
}

local Connections = {}

-- Функция для управления физикой полета
local function ToggleFly(state)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local root = char.HumanoidRootPart
    local humanoid = char:FindFirstChildOfClass("Humanoid")

    if state then
        if not FlyBodyVelocity then
            FlyBodyVelocity = Instance.new("BodyVelocity")
            FlyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            FlyBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            FlyBodyVelocity.Parent = root
        end
        if not FlyBodyGyro then
            FlyBodyGyro = Instance.new("BodyGyro")
            FlyBodyGyro.P = 9e4
            FlyBodyGyro.maxTorque = Vector3.new(9e9, 9e9, 9e9)
            FlyBodyGyro.cframe = root.CFrame
            FlyBodyGyro.Parent = root
        end
        if humanoid then humanoid.PlatformStand = true end
    else
        if FlyBodyVelocity then FlyBodyVelocity:Destroy(); FlyBodyVelocity = nil end
        if FlyBodyGyro then FlyBodyGyro:Destroy(); FlyBodyGyro = nil end
        if humanoid then humanoid.PlatformStand = false end
    end
end

-- Восстановление флая при возрождении
Connections.CharAdded = LocalPlayer.CharacterAdded:Connect(function(char)
    if Movement.Config.Fly then
        task.wait(0.5)
        ToggleFly(true)
    end
end)

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
    if humanoid and not Movement.Config.Fly then
        humanoid.WalkSpeed = tonumber(Movement.Config.WalkSpeed) or 16
        humanoid.JumpPower = tonumber(Movement.Config.JumpPower) or 50
        humanoid.UseJumpPower = true
    end

    -- Ноу-клип
    if Movement.Config.NoClip then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then 
                part.CanCollide = false 
            end
        end
    end

    -- Отключение коллизии с игроками
    if Movement.Config.NoPlayerCollision then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                for _, part in pairs(player.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
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
    
    -- Логика полета
    if Movement.Config.Fly and FlyBodyVelocity and FlyBodyGyro then
        local moveDir = Vector3.new(0,0,0)
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0, 1, 0) end

        FlyBodyVelocity.Velocity = moveDir * (tonumber(Movement.Config.FlySpeed) or 50)
        FlyBodyGyro.CFrame = Camera.CFrame
    end
end)

-- ================== UI Init ==================
function Movement.Init(GlobalConfig, parentTab, Lang)
    local T = {
        RU = {
            SubMain = "Движение",
            SecSpeed = "Характеристики персонажа",
            Speed = "Скорость бега",
            Jump = "Высота прыжка",
            FlySpeed = "Скорость полета",
            SecAbilities = "Способности",
            InfJump = "Бесконечные прыжки",
            NoClip = "Ноу-клип (Проход сквозь стены)",
            NoPlayerCol = "Отключить коллизию с игроками",
            Fly = "Полет (Fly)",
            Invis = "Невидимость",
            AntiAFK = "Анти-АФК (Защита от вылета)"
        },
        EN = {
            SubMain = "Movement",
            SecSpeed = "Character Stats",
            Speed = "Walk Speed",
            Jump = "Jump Power",
            FlySpeed = "Fly Speed",
            SecAbilities = "Abilities",
            InfJump = "Infinite Jump",
            NoClip = "Noclip (Wallpass)",
            NoPlayerCol = "Disable Player Collision",
            Fly = "Fly",
            Invis = "Invisibility",
            AntiAFK = "Anti-AFK (Anti-Kick)"
        }
    }
    local text = T[Lang] or T.RU
    local SubTab = parentTab:AddSubTab(text.SubMain)

    -- Character Stats Group
    local StatsGroup = SubTab:AddGroupbox(text.SecSpeed)
    StatsGroup:AddSlider({
        Text = text.Speed,
        Min = 16, Max = 200, Default = Movement.Config.WalkSpeed,
        Suffix = " studs/s",
        Callback = function(v) Movement.Config.WalkSpeed = v end
    })
    StatsGroup:AddSlider({
        Text = text.Jump,
        Min = 50, Max = 350, Default = Movement.Config.JumpPower,
        Suffix = " power",
        Callback = function(v) Movement.Config.JumpPower = v end
    })
    StatsGroup:AddSlider({
        Text = text.FlySpeed,
        Min = 16, Max = 300, Default = Movement.Config.FlySpeed,
        Suffix = " studs/s",
        Callback = function(v) Movement.Config.FlySpeed = v end
    })

    -- Abilities Group
    local AbilitiesGroup = SubTab:AddGroupbox(text.SecAbilities)
    AbilitiesGroup:AddToggle({
        Text = text.Fly,
        Default = Movement.Config.Fly,
        Callback = function(state)
            Movement.Config.Fly = state
            ToggleFly(state)
        end
    })
    AbilitiesGroup:AddToggle({
        Text = text.InfJump,
        Default = Movement.Config.InfiniteJump,
        Callback = function(state) Movement.Config.InfiniteJump = state end
    })
    AbilitiesGroup:AddToggle({
        Text = text.NoClip,
        Default = Movement.Config.NoClip,
        Callback = function(state) Movement.Config.NoClip = state end
    })
    AbilitiesGroup:AddToggle({
        Text = text.NoPlayerCol,
        Default = Movement.Config.NoPlayerCollision,
        Callback = function(state) Movement.Config.NoPlayerCollision = state end
    })
    AbilitiesGroup:AddToggle({
        Text = text.Invis,
        Default = Movement.Config.Invisibility,
        Callback = function(state) Movement.Config.Invisibility = state end
    })
    AbilitiesGroup:AddToggle({
        Text = text.AntiAFK,
        Default = Movement.Config.AntiAFK,
        Callback = function(state) Movement.Config.AntiAFK = state end
    })
end

return Movement
