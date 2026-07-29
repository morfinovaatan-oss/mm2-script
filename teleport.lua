local Module = {}

function Module:Init(Firola)
    local HttpService = Firola.Services.HttpService
    local UI = Firola.UI
    local tabName = "Settings"

    local function saveSettings()
        local data = {
            Toggles = Firola.State.Toggles,
            Values = Firola.State.Values,
            Binds = Firola.State.Binds,
        }
        local json = HttpService:JSONEncode(data)
        writefile("Firola/config.json", json)
    end

    local function loadSettings()
        local success, content = pcall(function() return readfile("Firola/config.json") end)
        if success and content then
            local data = HttpService:JSONDecode(content)
            Firola.State.Toggles = data.Toggles or {}
            Firola.State.Values = data.Values or {}
            Firola.State.Binds = data.Binds or {}
        end
    end

    loadSettings()

    UI.CreateButton(tabName, {Text = "Save Settings", Callback = saveSettings})
    UI.CreateButton(tabName, {Text = "Load Settings", Callback = loadSettings})
end

return Module
