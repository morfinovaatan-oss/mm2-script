-- [[ MM2 VISUALS MODULE - BULLETPROOF VERSION ]] --
local Visuals = {}
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

Visuals.Config = {
    ESP = false,
    RoleColors = true
}

-- Улучшенное определение роли
local function GetRole(player)
    if not player or not player.Character then return "Innocent" end
    
    local backpack = player:FindFirstChild("Backpack")
    local char = player.Character

    -- Ищем нож
    if (backpack and backpack:FindFirstChild("Knife")) or char:FindFirstChild("Knife") then return "Murderer" end
    -- Ищем пистолет
    if (backpack and backpack:FindFirstChild("Gun")) or char:FindFirstChild("Gun") then return "Sheriff" end

    return "Innocent"
end

local function GetColor(role)
    if role == "Murderer" then return Color3.fromRGB(255, 20, 20) -- Красный
    elseif role == "Sheriff" then return Color3.fromRGB(20, 100, 255) -- Синий
    else return Color3.fromRGB(20, 255, 20) end -- Зеленый
end

-- Неубиваемый цикл, который работает на любых экзекуторах
task.spawn(function()
    while task.wait(0.2) do -- Обновляем 5 раз в секунду (не лагает)
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local char = player.Character
                if char and char:FindFirstChild("Head") and char:FindFirstChildOfClass("Humanoid") and char.Humanoid.Health > 0 then
                    local head = char.Head
                    
                    -- 1. ТЕКСТ НАД ГОЛОВОЙ (Name Tag)
                    local bb = head:FindFirstChild("PF_Tag")
                    if Visuals.Config.ESP then
                        if not bb then
                            bb = Instance.new("BillboardGui")
                            bb.Name = "PF_Tag"
                            bb.AlwaysOnTop = true
                            bb.Size = UDim2.new(0, 200, 0, 50)
                            bb.StudsOffset = Vector3.new(0, 2.5, 0)
                            
                            local txt = Instance.new("TextLabel")
                            txt.Name = "Label"
                            txt.Size = UDim2.new(1, 0, 1, 0)
                            txt.BackgroundTransparency = 1
                            txt.TextStrokeTransparency = 0 -- Обводка текста
                            txt.Font = Enum.Font.GothamBold
                            txt.TextSize = 14
                            txt.Parent = bb
                            
                            bb.Parent = head
                        end
                        
                        local role = GetRole(player)
                        local color = Visuals.Config.RoleColors and GetColor(role) or Color3.fromRGB(160, 32, 240)
                        
                        bb.Label.Text = player.Name .. "\n[" .. role .. "]"
                        bb.Label.TextColor3 = color
                    else
                        if bb then bb:Destroy() end
                    end

                    -- 2. ПОДСВЕТКА ТЕЛА (Highlight)
                    local hl = char:FindFirstChild("PF_Highlight")
                    if Visuals.Config.ESP then
                        if not hl then
                            hl = Instance.new("Highlight")
                            hl.Name = "PF_Highlight"
                            hl.FillTransparency = 0.5
                            hl.OutlineTransparency = 0
                            hl.Parent = char
                        end
                        local role = GetRole(player)
                        hl.FillColor = Visuals.Config.RoleColors and GetColor(role) or Color3.fromRGB(160, 32, 240)
                        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                    else
                        if hl then hl:Destroy() end
                    end
                end
            end
        end
    end
end)

function Visuals.Init(GlobalConfig, UI, Lang)
    local T = {
        RU = { Tab = "👁️ Визуалы", ESP = "ESP на игроков", Role = "Цвета ролей (Murder/Sheriff)" },
        EN = { Tab = "👁️ Visuals", ESP = "Player ESP", Role = "Role Colors (Murder/Sheriff)" }
    }
    local text = T[Lang] or T.RU
    local VisTab = UI:CreateTab(text.Tab)

    VisTab:AddSection(text.ESP)
    VisTab:AddToggle({
        Title = text.ESP,
        Default = Visuals.Config.ESP,
        Callback = function(state) Visuals.Config.ESP = state end
    })

    VisTab:AddToggle({
        Title = text.Role,
        Default = Visuals.Config.RoleColors,
        Callback = function(state) Visuals.Config.RoleColors = state end
    })
end

return Visuals
