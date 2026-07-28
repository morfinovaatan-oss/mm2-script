-- [[ MM2 FOXAUTOFARM – Minimal Tab (will appear for sure) ]] --
local Autofarm = {}

function Autofarm.Init(GlobalConfig, UI, Lang)
    local T = {
        RU = { Tab = "🦊 FoxAutofarm" },
        EN = { Tab = "🦊 FoxAutofarm" }
    }
    local text = T[Lang] or T.RU
    local Tab = UI:CreateTab(text.Tab)
    Tab:AddSection("Тест")
    Tab:AddLabel("Вкладка успешно создана")
end

return Autofarm
