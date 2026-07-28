-- [[ MM2 AUTOFARM – Simple coin teleport (from OminousVibes) ]] --
local Autofarm = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Конфигурация
local Config = {
    AutoFarm = false,
}

-- Основной цикл автофарма
task.spawn(function()
    while true do
        if Config.AutoFarm then
            local character = LocalPlayer.Character
            if character and character:FindFirstChild("HumanoidRootPart") then
                local CoinContainer = Workspace:FindFirstChild("CoinContainer", true)
                if CoinContainer then
                    local coin = CoinContainer:FindFirstChild("Coin_Server")
                    if coin then
                        local root = character.HumanoidRootPart
                        root.CFrame = CFrame.new(coin.Position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(180))
                    end
                end
            end
        end
        task.wait(0.5)
    end
end)

-- Инициализация UI
function Autofarm.Init(GlobalConfig, UI, Lang)
    local T = {
        RU = { Tab = "💰 Автофарм", Toggle = "Включить автофарм" },
        EN = { Tab = "💰 AutoFarm", Toggle = "Enable AutoFarm" }
    }
    local text = T[Lang] or T.RU
    local Tab = UI:CreateTab(text.Tab)
    Tab:AddToggle({
        Title = text.Toggle,
        Default = false,
        Callback = function(state) Config.AutoFarm = state end
    })
end

return Autofarm
