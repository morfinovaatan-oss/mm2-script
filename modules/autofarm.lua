-- [[ MM2 AUTOFARM – адаптированный под UILibrary ]] --
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
function Autofarm.Init(GlobalConfig, parentTab, Lang)
    local T = {
        RU = { SubMain = "Автофарм", Toggle = "Включить автофарм" },
        EN = { SubMain = "AutoFarm", Toggle = "Enable AutoFarm" }
    }
    local text = T[Lang] or T.RU
    local SubTab = parentTab:AddSubTab(text.SubMain)

    local FarmGroup = SubTab:AddGroupbox("Автофарм")
    FarmGroup:AddToggle({
        Text = text.Toggle,
        Default = false,
        Callback = function(state) Config.AutoFarm = state end
    })
end

return Autofarm
