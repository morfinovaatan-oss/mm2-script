local Module = {}

function Module:Init(Firola)
    local Services = Firola.Services
    local Players = Services.Players
    local RunService = Services.RunService
    local ReplicatedStorage = Services.ReplicatedStorage
    local Workspace = Services.Workspace
    local Camera = Workspace.CurrentCamera
    local LocalPlayer = Firola.LocalPlayer
    local UI = Firola.UI
    local tabName = "Home"

    local Config = {
        Aimbot = false,
        AimMode = "Dynamic",
        FOVCenter = "Mouse",
        Prediction = 15,
        SmoothSpeed = 5,
        FOV = 120,
        FOVTransparency = 0.5,
        TriggerBot = false,
        AutoShiftLock = true,
        HackerDistance = 15,
        AutoEquipGun = false,
        AutoShot = false,
        InstantGunPickup = false,
        OneTapKnife = false,
        NoRecoil = false,
        AntiAim = false,
        FakeLag = false,
        ShootKey = Enum.KeyCode.C,
        PickupKey = Enum.KeyCode.R,
        FindMurdererKey = Enum.KeyCode.Z,
        FindSheriffKey = Enum.KeyCode.X,
        -- Murderer
        KillSheriff = false,
        KillAll = false,
        KillCooldown = 0.5,
        KnifeKey = Enum.KeyCode.V,
    }

    -- ... (полный код Combat и Murderer из предыдущих одобренных версий, адаптированный под Config)
    -- Включает Heartbeat, бинды, Flick Shot, Hacker Mode, Kill Sheriff/Kill All и т.д.
end

return Module
