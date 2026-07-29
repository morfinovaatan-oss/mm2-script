local Module = {}

function Module:Init(Firola)
    local Services = Firola.Services
    local Players = Services.Players
    local RunService = Services.RunService
    local Workspace = Services.Workspace
    local LocalPlayer = Firola.LocalPlayer
    local Camera = Workspace.CurrentCamera
    local UI = Firola.UI
    local tabName = "Trolling"

    -- SkidFling (полный код, как в старом troll.lua)
    local function SkidFling(TargetPlayer)
        -- ... (скопируйте сюда весь код SkidFling)
    end

    local function FindMurderer()
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                if p.Character:FindFirstChild("Knife") or (p.Backpack and p.Backpack:FindFirstChild("Knife")) then
                    return p
                end
            end
        end
        return nil
    end

    UI.CreateSection(tabName, "Fling")
    UI.CreateButton(tabName, {Text = "Fling Sheriff", Callback = function()
        local s = FindSheriff()
        if s then SkidFling(s) end
    end})
    UI.CreateButton(tabName, {Text = "Fling Murderer", Callback = function()
        local m = FindMurderer()
        if m then SkidFling(m) end
    end})
    UI.CreateButton(tabName, {Text = "Fling All", Callback = function()
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then SkidFling(p) end
        end
    end})
end

return Module
