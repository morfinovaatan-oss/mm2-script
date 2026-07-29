
--[[
    Firola v1 - UI Module (Nazuro/Neverlose Style with Tabs)
--]]

local Module = {}
local TweenService, CoreGui, UserInputService, Players, LocalPlayer
local ACCENT = Color3.fromRGB(0, 230, 200)
local BG = Color3.fromRGB(24, 24, 24)
local CARD = Color3.fromRGB(34, 34, 34)
local TEXT = Color3.fromRGB(220, 220, 220)

local function createTween(obj, props, time)
    local tween = TweenService:Create(obj, TweenInfo.new(time or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    tween:Play()
    return tween
end

function Module:Init(Firola)
    TweenService = Firola.Services.TweenService
    CoreGui = Firola.Services.CoreGui
    UserInputService = Firola.Services.UserInputService
    Players = Firola.Services.Players
    LocalPlayer = Firola.LocalPlayer

    local SG = Instance.new("ScreenGui")
    SG.Name = "Firola_UI"
    SG.ResetOnSpawn = false
    SG.IgnoreGuiInset = true
    pcall(function() SG.Parent = CoreGui end)
    if not SG.Parent then SG.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local Main = Instance.new("Frame", SG)
    Main.Size = UDim2.new(0, 680, 0, 440)
    Main.Position = UDim2.new(0.5, -340, 0.5, -220)
    Main.BackgroundColor3 = BG
    Main.BackgroundTransparency = 0.05
    Main.Active = true
    Main.Draggable = true
    Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", Main).Color = ACCENT

    -- Sidebar
    local Sidebar = Instance.new("Frame", Main)
    Sidebar.Size = UDim2.new(0, 180, 1, 0)
    Sidebar.BackgroundColor3 = CARD
    Sidebar.BorderSizePixel = 0
    Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", Sidebar).Color = ACCENT

    local Logo = Instance.new("TextLabel", Sidebar)
    Logo.Size = UDim2.new(1, -20, 0, 40)
    Logo.Position = UDim2.new(0, 10, 0, 15)
    Logo.BackgroundTransparency = 1
    Logo.Text = "Firola"
    Logo.TextColor3 = ACCENT
    Logo.Font = Enum.Font.GothamBold
    Logo.TextSize = 24
    Logo.TextXAlignment = Enum.TextXAlignment.Left

    local Version = Instance.new("TextLabel", Sidebar)
    Version.Size = UDim2.new(1, -20, 0, 20)
    Version.Position = UDim2.new(0, 10, 0, 50)
    Version.BackgroundTransparency = 1
    Version.Text = "v1  |  murder mystery"
    Version.TextColor3 = Color3.fromRGB(150, 150, 150)
    Version.Font = Enum.Font.GothamMedium
    Version.TextSize = 11
    Version.TextXAlignment = Enum.TextXAlignment.Left

    -- Вкладки
    local tabs = {"Home", "Farming", "Trolling", "me", "ESP", "Teleport", "Chat", "Update Logs", "Settings"}
    local pages = {}
    local tabButtons = {}

    local Content = Instance.new("Frame", Main)
    Content.Size = UDim2.new(1, -180, 1, 0)
    Content.Position = UDim2.new(0, 180, 0, 0)
    Content.BackgroundColor3 = BG
    Content.BorderSizePixel = 0

    local Header = Instance.new("Frame", Content)
    Header.Size = UDim2.new(1, 0, 0, 40)
    Header.BackgroundColor3 = CARD
    Header.BorderSizePixel = 0

    local HeaderTitle = Instance.new("TextLabel", Header)
    HeaderTitle.Size = UDim2.new(1, -60, 1, 0)
    HeaderTitle.Position = UDim2.new(0, 15, 0, 0)
    HeaderTitle.BackgroundTransparency = 1
    HeaderTitle.Text = "Home"
    HeaderTitle.TextColor3 = ACCENT
    HeaderTitle.Font = Enum.Font.GothamBold
    HeaderTitle.TextSize = 18
    HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left

    local CloseBtn = Instance.new("TextButton", Header)
    CloseBtn.Size = UDim2.new(0, 30, 0, 30)
    CloseBtn.Position = UDim2.new(1, -35, 0, 5)
    CloseBtn.BackgroundTransparency = 1
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 16
    CloseBtn.MouseButton1Click:Connect(function()
        SG:Destroy()
    end)

    -- Кнопки вкладок
    local tabY = 120
    for i, name in ipairs(tabs) do
        local btn = Instance.new("TextButton", Sidebar)
        btn.Size = UDim2.new(1, -20, 0, 32)
        btn.Position = UDim2.new(0, 10, 0, tabY + (i-1)*36)
        btn.BackgroundColor3 = i == 1 and ACCENT or CARD
        btn.Text = "  " .. name
        btn.TextColor3 = i == 1 and Color3.new(0,0,0) or TEXT
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 14
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.AutoButtonColor = false
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        tabButtons[name] = btn

        -- Страница
        local page = Instance.new("ScrollingFrame", Content)
        page.Size = UDim2.new(1, 0, 1, -40)
        page.Position = UDim2.new(0, 0, 0, 40)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 4
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.Visible = (i == 1)
        local layout = Instance.new("UIListLayout", page)
        layout.Padding = UDim.new(0, 8)
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
        end)
        Instance.new("UIPadding", page).PaddingTop = UDim.new(0, 10)
        pages[name] = {page = page, layout = layout}

        btn.MouseButton1Click:Connect(function()
            for _, b in pairs(tabButtons) do
                createTween(b, {BackgroundColor3 = CARD, TextColor3 = TEXT}, 0.2)
            end
            createTween(btn, {BackgroundColor3 = ACCENT, TextColor3 = Color3.new(0,0,0)}, 0.2)
            HeaderTitle.Text = name
            for _, p in pairs(pages) do
                p.page.Visible = false
            end
            page.Visible = true
        end)
    end

    -- Профиль внизу
    local Profile = Instance.new("Frame", Sidebar)
    Profile.Size = UDim2.new(1, -20, 0, 50)
    Profile.Position = UDim2.new(0, 10, 1, -60)
    Profile.BackgroundColor3 = BG
    Profile.BorderSizePixel = 0
    Instance.new("UICorner", Profile).CornerRadius = UDim.new(0, 6)
    local Avatar = Instance.new("ImageLabel", Profile)
    Avatar.Size = UDim2.new(0, 36, 0, 36)
    Avatar.Position = UDim2.new(0, 7, 0, 7)
    Avatar.BackgroundTransparency = 1
    Avatar.Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
    Instance.new("UICorner", Avatar).CornerRadius = UDim.new(1, 0)
    local NameLabel = Instance.new("TextLabel", Profile)
    NameLabel.Size = UDim2.new(1, -55, 0, 20)
    NameLabel.Position = UDim2.new(0, 50, 0, 5)
    NameLabel.BackgroundTransparency = 1
    NameLabel.Text = LocalPlayer.Name
    NameLabel.TextColor3 = TEXT
    NameLabel.Font = Enum.Font.GothamMedium
    NameLabel.TextSize = 12
    NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    local DiscordLabel = Instance.new("TextLabel", Profile)
    DiscordLabel.Size = UDim2.new(1, -55, 0, 16)
    DiscordLabel.Position = UDim2.new(0, 50, 0, 25)
    DiscordLabel.BackgroundTransparency = 1
    DiscordLabel.Text = "discord.gg/firola"
    DiscordLabel.TextColor3 = Color3.fromRGB(150,150,150)
    DiscordLabel.Font = Enum.Font.GothamMedium
    DiscordLabel.TextSize = 10
    DiscordLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- Методы для других модулей
    Firola.UI = {
        AddToTab = function(tabName, element)
            local tab = pages[tabName]
            if tab then
                element.Parent = tab.page
                tab.layout:ApplyLayout()
            end
        end,
        CreateSection = function(tabName, title)
            local tab = pages[tabName]
            if not tab then return end
            local sec = Instance.new("TextLabel")
            sec.Size = UDim2.new(1, -20, 0, 24)
            sec.BackgroundTransparency = 1
            sec.Text = title
            sec.TextColor3 = ACCENT
            sec.Font = Enum.Font.GothamBold
            sec.TextSize = 14
            sec.TextXAlignment = Enum.TextXAlignment.Left
            sec.Parent = tab.page
            return sec
        end,
        CreateToggle = function(tabName, props)
            local tab = pages[tabName]
            if not tab then return end
            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(1, -20, 0, 32)
            frame.BackgroundTransparency = 1
            frame.Parent = tab.page

            local label = Instance.new("TextLabel", frame)
            label.Size = UDim2.new(1, -50, 1, 0)
            label.BackgroundTransparency = 1
            label.Text = props.Text or "Toggle"
            label.TextColor3 = TEXT
            label.Font = Enum.Font.GothamMedium
            label.TextSize = 13
            label.TextXAlignment = Enum.TextXAlignment.Left

            local btn = Instance.new("TextButton", frame)
            btn.Size = UDim2.new(0, 40, 0, 20)
            btn.Position = UDim2.new(1, -42, 0.5, -10)
            btn.BackgroundColor3 = props.Default and ACCENT or Color3.fromRGB(60,60,60)
            btn.Text = ""
            btn.AutoButtonColor = false
            Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

            local circle = Instance.new("Frame", btn)
            circle.Size = UDim2.new(0, 16, 0, 16)
            circle.Position = props.Default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
            circle.BackgroundColor3 = Color3.fromRGB(255,255,255)
            Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

            local state = props.Default or false
            btn.MouseButton1Click:Connect(function()
                state = not state
                createTween(btn, {BackgroundColor3 = state and ACCENT or Color3.fromRGB(60,60,60)}, 0.2)
                createTween(circle, {Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}, 0.2)
                if props.Callback then props.Callback(state) end
                Firola.State.Toggles[props.Text] = state
            end)
            return frame
        end,
        CreateSlider = function(tabName, props)
            local tab = pages[tabName]
            if not tab then return end
            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(1, -20, 0, 32)
            frame.BackgroundTransparency = 1
            frame.Parent = tab.page

            local label = Instance.new("TextLabel", frame)
            label.Size = UDim2.new(1, -70, 1, 0)
            label.BackgroundTransparency = 1
            label.Text = props.Text or "Slider"
            label.TextColor3 = TEXT
            label.Font = Enum.Font.GothamMedium
            label.TextSize = 13
            label.TextXAlignment = Enum.TextXAlignment.Left

            local box = Instance.new("TextBox", frame)
            box.Size = UDim2.new(0, 60, 0, 20)
            box.Position = UDim2.new(1, -62, 0.5, -10)
            box.BackgroundColor3 = Color3.fromRGB(60,60,60)
            box.Text = tostring(props.Default or 0)
            box.TextColor3 = TEXT
            box.Font = Enum.Font.GothamMedium
            box.TextSize = 12
            Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)

            box.FocusLost:Connect(function()
                local val = tonumber(box.Text)
                if val then
                    val = math.clamp(val, props.Min or 0, props.Max or 100)
                    box.Text = tostring(val)
                    if props.Callback then props.Callback(val) end
                    Firola.State.Values[props.Text] = val
                end
            end)
            return frame
        end,
        CreateButton = function(tabName, props)
            local tab = pages[tabName]
            if not tab then return end
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -20, 0, 32)
            btn.BackgroundColor3 = ACCENT
            btn.Text = props.Text or "Button"
            btn.TextColor3 = Color3.new(0,0,0)
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 13
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            btn.Parent = tab.page
            btn.MouseButton1Click:Connect(function()
                if props.Callback then props.Callback() end
            end)
            return btn
        end,
    }
end

return Module
