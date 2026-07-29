local Module = {}

function Module:Init(Firola)
    local Services = Firola.Services
    local Workspace = Services.Workspace
    local RunService = Services.RunService
    local LocalPlayer = Firola.LocalPlayer
    local UI = Firola.UI
    local tabName = "Farming"

    local Config = {
        AutoFarm = false,
    }

    task.spawn(function()
        while task.wait(0.3) do
            if not Config.AutoFarm then continue end
            local char = LocalPlayer.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then continue end
            local container = Workspace:FindFirstChild("CoinContainer", true)
            if container then
                local coin = container:FindFirstChild("Coin_Server")
                if coin then
                    char.HumanoidRootPart.CFrame = CFrame.new(coin.Position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(180))
                end
            end
        end
    end)

    UI.CreateSection(tabName, "Auto Farm")
    UI.CreateToggle(tabName, {Text = "Auto Farm Coins", Default = false, Callback = function(s) Config.AutoFarm = s end})
end

return Module
