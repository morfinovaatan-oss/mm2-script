
local Module = {}

function Module:Init(Firola)
    local Services = Firola.Services
    local RunService = Services.RunService
    local UserInputService = Services.UserInputService
    local Workspace = Services.Workspace
    local LocalPlayer = Firola.LocalPlayer
    local UI = Firola.UI
    local tabName = "me"

    local Config = {
        Noclip = false,
        WalkSpeed = 16,
        JumpPower = 50,
        ZeroGravity = false,
        Xray = false,
        InfiniteJump = false,
        Fly = false,
        FlySpeed = 50,
    }

    RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        hum.WalkSpeed = Config.WalkSpeed
        hum.JumpPower = Config.JumpPower
        hum.UseJumpPower = true

        if Config.Noclip then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)

    -- Zero Gravity
    local origGravity = Workspace.Gravity
    local function updateGravity()
        Workspace.Gravity = Config.ZeroGravity and 0 or origGravity
    end

    -- Infinite Jump
    UserInputService.JumpRequest:Connect(function()
        if not Config.InfiniteJump then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)

    -- Fly
    local FlyBV, FlyBG
    RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local root = char.HumanoidRootPart
        if Config.Fly then
            if not FlyBV then
                FlyBV = Instance.new("BodyVelocity")
                FlyBV.MaxForce = Vector3.new(1e6, 1e6, 1e6)
                FlyBV.Parent = root
                FlyBG = Instance.new("BodyGyro")
                FlyBG.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
                FlyBG.P = 1e4
                FlyBG.Parent = root
            end
            local cam = Workspace.CurrentCamera
            local dir = Vector3.new(0,0,0)
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0,1,0) end
            FlyBV.Velocity = dir * Config.FlySpeed
            FlyBG.CFrame = cam.CFrame
        else
            if FlyBV then FlyBV:Destroy(); FlyBV = nil end
            if FlyBG then FlyBG:Destroy(); FlyBG = nil end
        end
    end)

    -- UI
    UI.CreateSection(tabName, "Movement")
    UI.CreateSlider(tabName, {Text = "Walk Speed", Min = 16, Max = 200, Default = 16, Callback = function(v) Config.WalkSpeed = v end})
    UI.CreateSlider(tabName, {Text = "Jump Power", Min = 50, Max = 300, Default = 50, Callback = function(v) Config.JumpPower = v end})
    UI.CreateToggle(tabName, {Text = "Noclip", Default = false, Callback = function(s) Config.Noclip = s end})
    UI.CreateToggle(tabName, {Text = "Zero Gravity", Default = false, Callback = function(s) Config.ZeroGravity = s; updateGravity() end})
    UI.CreateToggle(tabName, {Text = "Infinite Jump", Default = false, Callback = function(s) Config.InfiniteJump = s end})
    UI.CreateToggle(tabName, {Text = "Fly", Default = false, Callback = function(s) Config.Fly = s end})
    UI.CreateSlider(tabName, {Text = "Fly Speed", Min = 20, Max = 200, Default = 50, Callback = function(v) Config.FlySpeed = v end})
end

return Module
