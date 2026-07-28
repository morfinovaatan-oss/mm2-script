-- [[ MM2 AUTO‑FARM – Button to launch Zynic's menu as FoxAutofarm ]] --
local Autofarm = {}

function Autofarm.Init(GlobalConfig, UI, Lang)
    local T = {
        RU = { TabName = "💰 Автофарм", LaunchBtn = "Запустить автофарм" },
        EN = { TabName = "💰 AutoFarm", LaunchBtn = "Launch AutoFarm" }
    }
    local text = T[Lang] or T.RU
    local FarmTab = UI:CreateTab(text.TabName)

    -- Кнопка, открывающая окно FoxAutofarm
    FarmTab:AddButton(text.LaunchBtn, function()
        -- Загружаем необходимые библиотеки и запускаем интерфейс
        local success, err = pcall(function()
            -- Octree
            local Octree = loadstring(game:HttpGet("https://raw.githubusercontent.com/Sleitnick/rbxts-octo-tree/main/src/init.lua", true))()
            -- XSX UI Library
            local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Zyn-ic/MM2-AutoFarm/refs/heads/main/UI-Library/XSX.lua", true))()
            -- Iris (для WaypointManager)
            local Iris = loadstring(game:HttpGet("https://raw.githubusercontent.com/x0581/Iris-Exploit-Bundle/2.0.4/bundle.lua"))().Init(game.CoreGui)

            -- Устанавливаем заголовок
            library.title = "FoxAutofarm"

            local rt = {} -- Removable table
rt.__index = rt
rt.octree = Octree.new()

rt.Players = game:GetService("Players")
rt.RunService = game:GetService("RunService")
rt.CoreGui = game:GetService("CoreGui")
rt.TeleportService = game:GetService("TeleportService")
rt.HttpService = game:GetService("HttpService")
rt.Camera = game:GetService("Workspace").CurrentCamera

rt.IWPM = false :: boolean-- Iris WayPointManager

rt.player = rt.Players.LocalPlayer :: Player
rt.sheriff = nil :: Player 
rt.Murderer = nil :: Player 
rt.PreviousMurderer = nil :: Player
rt.Viewing = false :: boolean
rt.RoleTracker1 = nil :: RBXScriptConnection 
rt.RoleTracker2 = nil :: RBXScriptConnection 
rt.WeaponTracker1 = nil :: RBXScriptConnection 
rt.WeaponTracker2 = nil :: RBXScriptConnection
rt.Joined = nil :: RBXScriptConnection 
rt.Left = nil :: RBXScriptConnection 
rt.viewChanged = nil :: RBXScriptConnection 
rt.viewDiedFunc = nil :: RBXScriptConnection 
rt.Map = nil :: Model 

rt.flingActive = false :: boolean
rt.refresh = nil :: (boolean?) -> ()

rt.HitboxSize = nil :: number

rt.espON = false :: boolean
rt.playerESP = {}


rt.AutoFarmOn = false
rt.coinContainer = nil
rt.Material = Enum.Material.Ice :: EnumItem
rt.TpBackToStart = true :: boolean
rt.Uninterrupted = false :: boolean
rt.radius = 200 :: number -- Radius to search for coins
rt.walkspeed = 35 :: number -- speed at which you will go to a coin measured in walkspeed
rt.touchedCoins = {} -- Table to track touched coins
rt.positionChangeConnections = setmetatable({}, { __mode = "v" }) -- Weak table for connections
rt.Added = nil :: RBXScriptConnection
rt.Removing = nil :: RBXScriptConnection
rt.start = nil :: thread

rt.UserDied = nil :: RBXScriptConnection

rt.Settings = {}
rt.waypoint = nil :: CFrame
rt.Settings.WayPoints = {}


---------------------------------------LOCAL FUNCTIONS-------------------------------------------
-------------------------------------------------------------------------------------------------

-- Function to set a palyer Collision Status
-- local function setCharacterCollision (character: Model, state:boolean)
--     for _, part in pairs(character:GetDescendants()) do
--         if part:IsA("BasePart") or part:IsA("MeshPart") then
--             part.CanCollide = state
--         end
--     end
-- end

-- Function to teleport to a player
local function TeleportToPlayer(targetPlayer)
    if rt:Character() and rt:Character():FindFirstChild("HumanoidRootPart") and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        rt:Character():PivotTo(targetPlayer.Character:GetPivot())
    end
end

-- Function to disconnect ESP for a player
local function RemovePlayerESP(player)
    if rt.playerESP[player] then
        rt.playerESP[player].button.Parent:Destroy()
        rt.Disconnect(rt.playerESP[player].connection1)
        rt.Disconnect(rt.playerESP[player].connection2)
        rt.Disconnect(rt.playerESP[player].connection3)
        rt.playerESP[player] = nil
    end
end

-- Function to create the UI for a player's ESP
local function CreatePlayerESP(player)
    if rt.espON == false then return end
    if rt.playerESP[player] then return end -- Prevent duplicate ESPs

    -- Create ScreenGui for the ESP
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CorePosition_" .. player.Name
    screenGui.Parent = game:GetService("CoreGui")

    -- Create a button for the ESP
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 25, 0, 25) -- Size of the button
    button.Text = "👤"
    button.BackgroundColor3 = Color3.fromRGB(94, 94, 94) -- Default grey color
    button.TextSize = 14
    button.Visible = false
    button.Parent = screenGui
    Instance.new("UICorner").Parent = button -- Rounded corners

    -- Track the button and connection
    rt.playerESP[player] = { button = button, connection1 = nil, connection2 = nil, connection3 = nil }

	local lastClick = 0
	local holdingStartTime = 0
	local holding = false

	button.MouseButton1Down:Connect(function()
		holdingStartTime = tick()
		holding = true

		-- Start a task to check if the button is held for 1.5 seconds
		task.spawn(function()
			while holding do
				if tick() - holdingStartTime >= 0.3 then
					TeleportToPlayer(player) -- Teleport after 1.5 seconds
					holding = false -- Stop the loop
					break
				end
				task.wait()
			end
		end)
	end)

	button.MouseButton1Up:Connect(function()
		holding = false -- Stop checking when the button is released

		local now = tick()

		-- Handle button double-click for removing ESP
		if now - lastClick < 0.5 then
			RemovePlayerESP(player)
		end

		lastClick = now -- Update last click time
	end)


    -- Update button's position and properties each frame
    rt.playerESP[player].connection1 = rt.RunService.RenderStepped:Connect(function()
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local character = player.Character
            local rootPart = character.HumanoidRootPart
            local screenPoint = rt.Camera:WorldToScreenPoint(rootPart.Position)

            -- Check if the player is on screen
            if screenPoint.Z > 0 then
                button.Position = UDim2.new(0, screenPoint.X - button.Size.X.Offset / 2, 0, screenPoint.Y - button.Size.Y.Offset / 2)
                button.Visible = true

                -- Update button text and color based on role
                if rt.Murderer ~= nil and player.Name == rt.Murderer.Name then
                    button.Text = "🔪"
                    button.BackgroundColor3 = Color3.fromRGB(184, 88, 88) -- Red
                elseif rt.sheriff ~= nil and player.Name == rt.sheriff.Name then
                    button.Text = "🔫"
                    button.BackgroundColor3 = Color3.fromRGB(99, 99, 168) -- Blue
                else
                    button.Text = "👤"
                    button.BackgroundColor3 = Color3.fromRGB(94, 94, 94) -- Grey
                end
            else
                button.Visible = false
            end
        else
            -- Update button to "dead" state
            button.Text = "💀"
            button.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- Black
            button.Visible = true
        end
    end)

    -- Update ESP when the player dies or respawns
    rt.playerESP[player].connection2 = player.CharacterRemoving:Connect(function()
        button.Text = "💀"
        button.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- Black
    end)

    rt.playerESP[player].connection3 = player.CharacterAdded:Connect(function()
		task.wait()
        button.Text = "👤"
        button.BackgroundColor3 = Color3.fromRGB(94, 94, 94) -- Grey
        -- Refresh roles dynamically
        if rt.Murderer ~= nil and player.Name == rt.Murderer.Name then
            button.Text = "🔪"
            button.BackgroundColor3 = Color3.fromRGB(184, 88, 88) -- Red
        elseif rt.sheriff ~= nil and player.Name == rt.sheriff.Name then
            button.Text = "🔫"
            button.BackgroundColor3 = Color3.fromRGB(99, 99, 168) -- Blue
        end
    end)

end

-- Function to refresh ESP roles dynamically
local function RefreshRoles(newMurderer, newSheriff)
    local murdererName = newMurderer or ""
    local sheriffName = newSheriff or ""

    -- Refresh all existing ESP buttons
    for player, espData in pairs(rt.playerESP) do
        local button = espData.button
        if  player.Name == murdererName then
            button.Text = "🔪"
            button.BackgroundColor3 = Color3.fromRGB(184, 88, 88) -- Red
        elseif player.Name == sheriffName then
            button.Text = "🔫"
            button.BackgroundColor3 = Color3.fromRGB(99, 99, 168) -- Blue
        else
            button.Text = "👤"
            button.BackgroundColor3 = Color3.fromRGB(94, 94, 94) -- Grey
        end
    end
end

local function createHitboxForPlayers(players, sizeArg, Trans:number ?)
    for _, v in pairs(players) do
        if v.Name == rt.player.Name then continue end
        if v.Character and v.Character:FindFirstChild('HumanoidRootPart') then
            local Size = Vector3.new(sizeArg, sizeArg, sizeArg)
            local Root = v.Character:FindFirstChild('HumanoidRootPart')
            if Root:IsA("BasePart") then
                if not sizeArg or sizeArg == 1 then
                    Root.Size = Vector3.new(2, 2, 1)
                    Root.Transparency = Trans or 0.3
                    Root.CanCollide = false;
                else
                    --reset hitbox
                    if sizeArg == 0 then Root.Size = rt:Character().PrimaryPart.Size; Root.Transparency = Trans or 1; Root.CanCollide = true; continue end
                    
                    -- set hitbox
                    Root.Size = Size
                    Root.Transparency = Trans or  0.3
                    Root.CanCollide = false;
                end
            end
        end
    end
end

---------------------------------------ATUOFARM SECTION--------------------------------------
local collectCoins
local function AutoFarmCleanUp()
    -- Check if the table is empty
    if next(rt.positionChangeConnections) == nil then
        rt.AutoFarmOn = false
        print("No items in positionChangeConnections")
        return true
    end

    rt.AutoFarmOn = false
    coroutine.yield(rt.start)
    coroutine.close(rt.start)
    if coroutine.status(rt.start) == "suspended" then
        coroutine.yield(rt.start)
        coroutine.close(rt.start)
    end
    
    -- Disconnect all connections
    for _, connection in pairs(rt.positionChangeConnections) do
        rt.Disconnect(connection)
    end
    rt.Disconnect(rt.Added)
    rt.Disconnect(rt.Removing)

    -- Notify and clean up
    Notif:Notify("Removing cached instances for AutoFarm", 1.5, "success")
    table.clear(rt.touchedCoins)
    table.clear(rt.positionChangeConnections)
    
    task.wait(1)
    rt.start = coroutine.create(collectCoins)
    return true
end


-- Function to check if a coin has been touched
local function isCoinTouched(coin)
    return rt.touchedCoins[coin]
end

-- Function to mark a coin as touched
local function markCoinAsTouched(coin)
    if not rt then return end
    rt.touchedCoins[coin] = true
    local node = rt.octree:FindFirstNode(coin)
    if node then
        rt.octree:RemoveNode(node)
    end
end

-- Function to track touch interactions
local function setupTouchTracking(coin)
    
    local touchInterest = coin:FindFirstChildWhichIsA("TouchTransmitter")
    if touchInterest then
        local connection
        connection = touchInterest.AncestryChanged:Connect(function(_, parent)
            if not rt then connection:Disconnect() return end
            if parent == nil then
                -- TouchInterest removed; mark the coin as touched
                markCoinAsTouched(coin)
                rt.Disconnect(connection)
            end
        end)
        rt.positionChangeConnections[coin] = connection
    end
end

local function setupPositionTracking(coin: MeshPart, LastPositonY: number)
    local connection
    connection = coin:GetPropertyChangedSignal("Position"):Connect(function()
        -- Check if the Y position has changed
        local currentY = coin.Position.Y
        if LastPositonY and LastPositonY ~= currentY then

            -- Remove the coin from the octree as it has been moved
            markCoinAsTouched(coin)

            rt.Disconnect(connection)
            coin:Destroy()
            return
        end
    end)
    rt.positionChangeConnections[coin] = connection
end

-- Function to populate the Octree with coins
local function populateOctree()
    rt.octree:ClearAllNodes() -- Clear previous nodes

    for _, descendant in pairs(rt.coinContainer:GetDescendants()) do
        if descendant:IsA("TouchTransmitter") then --and descendant.Material == rt.Material then
            local parentCoin = descendant.Parent
            if not isCoinTouched(parentCoin) then
                rt.octree:CreateNode(parentCoin.Position, parentCoin)
                setupTouchTracking(parentCoin)
            end
            setupPositionTracking(parentCoin, parentCoin.Position.Y)
        end
    end

    rt.Added = rt.coinContainer.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("TouchTransmitter") then --and descendant.Material == rt.Material then
            local parentCoin = descendant.Parent
            if not isCoinTouched(parentCoin) then
                rt.octree:CreateNode(parentCoin.Position, parentCoin)
                setupTouchTracking(parentCoin)
                setupPositionTracking(parentCoin, parentCoin.Position.Y)
            end
        end
    end)

    rt.Removing = rt.coinContainer.DescendantRemoving:Connect(function(descendant)
        if descendant:IsA("TouchTransmitter") and descendant.Parent.Name == "Coin_Server" then
            local parentCoin = descendant.Parent
            if isCoinTouched(parentCoin) then
                markCoinAsTouched(parentCoin)
            end
        end
    end)
end

local function moveToPositionSlowly(targetPosition: Vector3, duration: number)
    rt.humanoidRootPart = rt:Character().PrimaryPart
    local startPosition = rt.humanoidRootPart.Position
    local startTime = tick()
    
    while true do
        local elapsedTime = tick() - startTime
        local alpha = math.min(elapsedTime / duration, 1)
        rt:Character():PivotTo(CFrame.new(startPosition:Lerp(targetPosition, alpha)))

        if alpha >= 1 then
            task.wait(0.2)
            break
        end

        task.wait() -- Small delay to make the movement smoother
    end
end

-- Function to collect coins
collectCoins = function ()
    -- Ensure CoinContainer exists
    rt.coinContainer = rt:Map():FindFirstChild("CoinContainer")
    rt.waypoint = rt:Character():GetPivot()
    local check = rt:MainGUI():WaitForChild("Game").CoinBags.Container.SnowToken.CurrencyFrame.Icon.Coins
    local price = "40"
    if rt:IsElite() then price = "50" end

    -- Populate Octree
    populateOctree()
    
    while rt.AutoFarmOn do
        if check.Text == price then
            Notif:Notify("Full Bag", 2, "success")
            break
        end

        -- Find nearest coin
        local nearestNode = rt.octree:GetNearest(rt:Character().PrimaryPart.Position, rt.radius, 1)[1]

        if nearestNode then
            local closestCoin = nearestNode.Object
            if not isCoinTouched(closestCoin) then
                local closestCoinPosition = closestCoin.Position
                local distance = (rt:Character().PrimaryPart.Position - closestCoinPosition).Magnitude
                local duration = distance / rt.walkspeed -- Default walk speed is 26 studs/sec

                -- Move to the coin
                moveToPositionSlowly(closestCoinPosition, duration)

                -- Mark coin as touched and clean up
                markCoinAsTouched(closestCoin)
                task.wait(0.2) -- Ensure touch is registered
            end
        else
            task.wait(1) -- No coins; retry after delay
        end
    end

    if rt.TpBackToStart then
        rt:Character():PivotTo(rt.waypoint)
    end
    AutoFarmCleanUp()
end

local function ToggleAutoFarm(value : boolean)
    if not value then
        return AutoFarmCleanUp()
    end

    if not rt:CheckIfGameInProgress() then Notif:Notify("Map must be loaded to use Autofarm", 2, "error") return false  end
    if not rt:CheckIfPlayerWasInARound() then Notif:Notify("You need to be in a round or have played a round to use the autofarm", 5, "error") return false end
    if not rt.Murderer then Notif:Notify("No Murderer found to satisfy: Round in Progress", 4, "information") return false  end
    local isAlive = rt:CheckIfPlayerIsInARound()
    local OldState = rt.Uninterrupted
    local IsMurderer = rt.player.Name == rt.Murderer.Name

    --if the player is the murderer and has on rt.Uninterrupted
    if rt.Uninterrupted and IsMurderer then rt.Uninterrupted = false; IsMurderer = not IsMurderer end

    if rt.Uninterrupted then
        rt:Character():FindFirstChildWhichIsA("Humanoid"):ChangeState(Enum.HumanoidStateType.Dead)
        repeat task.wait() until rt.player.CharacterAdded:Wait()  --rt.player:HasAppearanceLoaded()
        task.wait(1)
        TeleportToPlayer(rt.Murderer)
        --start autofarm
        Notif:Notify("Uninterrupted made it all the way", 4, "alert")
        rt.AutoFarmOn = true
        coroutine.resume(rt.start)
    else
        if rt.Uninterrupted ~= OldState then rt.Uninterrupted = OldState end

        if IsMurderer then
            if not isAlive then Notif:Notify("Died before you could start? sad ngl ", 4, "alert") return false end 
            --start autofarm
            Notif:Notify("Collect sum coins Murderer!", 4, "alert")
            rt.AutoFarmOn = true
            coroutine.resume(rt.start)
        else
            --start autofarm
            if not isAlive then TeleportToPlayer(rt.Murderer) end
            Notif:Notify("Normal made it all the way", 4, "alert")
            rt.AutoFarmOn = true
            coroutine.resume(rt.start)
        end
    end

    return true
end

--------------------------------FUNCTIONS SECTION OF THE CODE-----------------------------------
------------------------------------------------------------------------------------------------

function rt:MainGUI () : (ScreenGui)
    return rt.player.PlayerGui.MainGUI or rt.player.PlayerGui:WaitForChild("MainGUI")
end

function rt:Character () : (Model)
    return self.player.Character or self.player.CharacterAdded:Wait()
end

function rt.Disconnect (connection:RBXScriptConnection)
    if connection and connection.Connected then
        connection:Disconnect()
    end
end

function rt.FindPlayer(val : string) : (Player)
    local match
    for _, v : Player in pairs(rt.Players:GetChildren()) do
        if string.match(v.Name:lower(), val:lower()) or string.match(v.DisplayName:lower(), val:lower()) then
            match = v
        end
    end

    return match
end

function rt:Map () : (Model | nil)
    for _, v in workspace:GetDescendants() do
        if v.Name == "Spawns" and v.Parent.Name ~= "Lobby"  then
            return v.Parent
        end
    end
    return nil
end

function rt:CheckForConnection () : (boolean) -- if someone reload the script while script this will help us know
    if self.player:GetAttribute("Connection") then
        return true
    end
    
    return false
end

function rt:IsElite() : (boolean)
    if self.player:GetAttribute("Elite") then
        return true
    end

    return false
end

function rt:CheckIfGameInProgress () : (boolean)
    if rt:Map() then return true end
    return false
end

function rt:CheckIfPlayerIsInARound () : (boolean)
    --check if player is in a round
    --check by going to the players gui -> MainGui -> Game -> Timer.Visible
    if not self:MainGUI() then return false end

    if self:MainGUI().Game.Timer.Visible then
        return true
    end

    --check by going to the players gui -> MainGui -> Game -> EarnedXP.Visible
    if self:MainGUI().Game.EarnedXP.Visible then
        return true
    end

    return false
end

function rt:CheckIfPlayerWasInARound () : (boolean)
    --check if player was in a round
    --check by going to the players -> localplayer -> GetAttributes() -> "Alive"
    if self.player:GetAttribute("Alive") then
        return true
    end

    return false
end

function rt:GetAlivePlayers (): (table | nil)
    --get all players that are alive
    local aliveplrs = setmetatable({}, {__mode = "v"})
    local OldPos = self:Character():GetPivot()
    local pos = CFrame.new(-121.995956, 134.462997, 46.4180717)
    
    if not rt:CheckIfGameInProgress() then return nil end

    local isAlive = rt:CheckIfPlayerIsInARound()

    if not isAlive then self:Character():PivotTo(pos) end

    for _, v in pairs(rt.Players:GetPlayers()) do
        local distance = (self:Character().PrimaryPart.Position - v.Character.PrimaryPart.Position).Magnitude
        if isAlive then
            if distance <= 500 then
                table.insert(aliveplrs, v)
            end
        else
            if distance > 500 then
                table.insert(aliveplrs, v)
            end
        end
    end

    if not isAlive then self:Character():PivotTo(OldPos) end
    
    return aliveplrs
end

function rt:GetRoles() : {sheriff: Player | nil, Murderer : Player | nil}
    if rt.sheriff ~= nil or rt.Murderer ~= nil then return {sheriff = rt.sheriff, Murderer = rt.Murderer} end

    local checkBackPacks = function()
        for _, v in pairs(rt.Players:GetPlayers()) do
            if v.Backpack:FindFirstChild("Gun") then
                rt.sheriff = v
            elseif v.Backpack:FindFirstChild("Knife") then
                rt.Murderer = v
            end
        end
    end

    local checkCharacters = function()
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("Tool") then
                if v.Name == "Gun" then
                    rt.sheriff = rt.Players:GetPlayerFromCharacter(v.Parent)
                elseif v.Name == "Knife" then
                    rt.Murderer = rt.Players:GetPlayerFromCharacter(v.Parent)
                end
            end
        end
    end

    coroutine.wrap(checkBackPacks)
    coroutine.wrap(checkCharacters)

    task.wait(0.5)

    return {sheriff = rt.sheriff, Murderer = rt.Murderer}
end

function rt:SpeedUp () : (boolean)
    --speed up the player no more than 28
    if self:Character():FindFirstChildWhichIsA("Humanoid").WalkSpeed == 28 then return false end
    self:Character():FindFirstChildWhichIsA("Humanoid").WalkSpeed += 4

    return true
end

function rt:ResetSpeed () : (boolean)
    if self:Character():FindFirstChildWhichIsA("Humanoid").WalkSpeed == 16 then return false end
    self:Character():FindFirstChildWhichIsA("Humanoid").WalkSpeed = 16
    
    return true
end

function rt:ViewMurderer () : (boolean | string)
    
    if not self.Murderer then self.Viewing = true return false end
    if self.Viewing then return Notif:Notify("alr in view", 1, "error") end
    self.Viewing = true

    self.Camera.CameraSubject = self.Murderer and self.Murderer.Character:FindFirstChildWhichIsA("Humanoid") or self:Character():FindFirstChildWhichIsA("Humanoid")
    
    self.viewChanged = workspace.CurrentCamera:GetPropertyChangedSignal("CameraSubject"):Connect(function()
        if not self.Murderer then return rt:UnViewMurderer() end
        self.Murderer.CharacterAdded:Wait()
        self.Camera.CameraSubject = self.Murderer and self.Murderer.Character:FindFirstChildWhichIsA("Humanoid") or self:Character():FindFirstChildWhichIsA("Humanoid")
    end)

    self.viewDiedFunc = self.player.CharacterAdded:Connect(function()
        rt:UnViewMurderer()
    end)

    return true
end

function rt:UnViewMurderer () : (boolean | string)
    
    if not self.Murderer then self.Viewing = false; self.Camera.CameraSubject = self:Character():FindFirstChildWhichIsA("Humanoid")  return false end
    if not self.Viewing then return  Notif:Notify("alr removed view", 1, "error") end
    self.Viewing = false

    local camera = game.Workspace.CurrentCamera
    rt.Disconnect(rt.viewChanged)
    rt.Disconnect(rt.viewDiedFunc)
    self.Camera.CameraSubject = self:Character():FindFirstChildWhichIsA("Humanoid")
    return true
end

function rt:GetGun ()
    if not (rt:CheckIfGameInProgress()) then return Notif:Notify("No game in progress", 1, "error") end

    local Gun = rt:Map():FindFirstChild("GunDrop") :: BasePart | MeshPart -- getinstances()["GunDrop"]
    if not Gun then return Notif:Notify("No Gun found", 1, "error") end

    if rt.Settings.Safe_Gun_Grab then
        local distance = (rt:Character().PrimaryPart.Position - Gun.Position).Magnitude
        if distance > 500 then
            distance = nil
            return Notif:Notify("Gun is too far away [Safe Gun Grab]", 1, "error")
        end
    end

    rt:Character():PivotTo(Gun:GetPivot())
    task.wait(0.2) -- wait for the character to pick up the gun

    if not rt.player.Backpack:FindFirstChild("Gun") then
        return Notif:Notify("Failed to get the gun. Sorry Sheriff you had your chance 😔.", 2, "alert")
    end

    Notif:Notify("Successfully picked up the gun", 1, "success")
    Gun = nil
end

function rt.LoadRoleInfo (roles, MurdFolder : {}, SherFolder : {})
    -- Load in Murderer info
    if roles.Murderer then
        
        MurdFolder.MurdName:Text("Murderer Username: " .. roles.Murderer.Name)
        MurdFolder.MurdKnife:Text("Murderer Knife: " .. (roles.Murderer:GetAttribute("EquippedKnife") or ""))
        MurdFolder.MurdKnifeEffect:Text("Murderer Knife Effect: " .. (roles.Murderer:GetAttribute("EquippedEffect") or ""))
        MurdFolder.MurdPerk:Text("Murderer Perk: " .. (roles.Murderer:GetAttribute("EquippedPerk") or ""))
        MurdFolder.Murdlvl:Text("Murderer Lvl: " .. (roles.Murderer:GetAttribute("Level") or ""))
        MurdFolder.MurdPres:Text("Murderer Prestige: " .. (roles.Murderer:GetAttribute("Prestige") or ""))
        MurdFolder.MurdXP:Text("Murderer XP: " .. (roles.Murderer:GetAttribute("XP") or ""))
    else
        MurdFolder.MurdName:Text("Murderer Username: N/A")
        MurdFolder.MurdKnife:Text("Murderer Knife: N/A")
        MurdFolder.MurdKnifeEffect:Text("Murderer Knife Effect: N/A")
        MurdFolder.MurdPerk:Text("Murderer Perk: N/A")
        MurdFolder.Murdlvl:Text("Murderer Lvl: N/A")
        MurdFolder.MurdPres:Text("Murderer Prestige: N/A")
        MurdFolder.MurdXP:Text("Murderer XP: N/A")
    end

    -- Load in Sheriff info
    if roles.sheriff then
        SherFolder.SherName:Text("Sheriff Username: " .. roles.sheriff.Name)
        SherFolder.SherGun:Text("Sheriff Gun: " .. (roles.sheriff:GetAttribute("EquippedGun") or ""))
        SherFolder.Sherlvl:Text("Sheriff Lvl: " .. (roles.sheriff:GetAttribute("Level") or "N/A") or "")
        SherFolder.SherPres:Text("Sheriff Prestige: " .. (roles.sheriff:GetAttribute("Prestige") or ""))
        SherFolder.SherXP:Text("Sheriff XP: " .. (roles.sheriff:GetAttribute("XP") or ""))
    else
        SherFolder.SherName:Text("Sheriff Username: N/A")
        SherFolder.SherGun:Text("Sheriff Gun: N/A")
        SherFolder.Sherlvl:Text("Sheriff Lvl: N/A")
        SherFolder.SherPres:Text("Sheriff Prestige: N/A")
        SherFolder.SherXP:Text("Sheriff XP: N/A")
    end
end

--Checks places where Role Weapons are so it can update who has them
function rt:UpdateRoles()
    -- Reset roles
    local oldSheriff = rt.sheriff
    local oldMurderer = rt.Murderer
    rt.sheriff = nil
    rt.Murderer = nil

    -- Check players' backpacks for tools
    for _, player in ipairs(rt.Players:GetPlayers()) do
        if player:FindFirstChild("Backpack") then
            local backpack = player.Backpack
            if backpack:FindFirstChild("Gun") then
                rt.sheriff = player
            elseif backpack:FindFirstChild("Knife") then
                rt.Murderer = player
            end
        end
    end

    -- Check workspace for tools attached to characters
    for _, descendant in ipairs(workspace:GetDescendants()) do
        if descendant:IsA("Tool") then
            if descendant.Name == "Gun" then
                local owner = rt.Players:GetPlayerFromCharacter(descendant.Parent)
                rt.sheriff = owner or rt.sheriff
            elseif descendant.Name == "Knife" then
                local owner = rt.Players:GetPlayerFromCharacter(descendant.Parent)
                rt.Murderer = owner or rt.Murderer
            end
        elseif descendant.Name == "GunDrop" then
            rt.sheriff = nil -- Gun dropped, sheriff is unknown
        end
    end

    -- Refresh UI or ESP if roles have changed
    if oldSheriff ~= rt.sheriff or oldMurderer ~= rt.Murderer then
        rt.refresh("Roles Updated")
        if rt.espON then RefreshRoles(rt.sheriff, rt.Murderer) end
    end
end

--This function is a bunch of connectings to triggers
function rt:MonitorTools()
    -- Listen for tools being added or removed in players
    rt.RoleTracker1 = rt.Players.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("Tool") then
            if descendant.Name == "Gun" or descendant.Name == "Knife" then
                rt:UpdateRoles()
            end
        end
    end)

    rt.RoleTracker2 = rt.Players.DescendantRemoving:Connect(function(descendant)
        if descendant:IsA("Tool") then
            if descendant.Name == "Gun" or descendant.Name == "Knife" then
                rt:UpdateRoles()
            end
        end
    end)

    -- Listen for tools being added or removed in workspace
    rt.WeaponTracker1 = workspace.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("Tool") or descendant.Name == "GunDrop" then
            rt:UpdateRoles()
        end

        if descendant:IsA("Model") then
            if string.match(descendant.Name, "Glitch") and descendant.Parent.Name ~= "Lobby" then
                descendant:Destroy()
            end
    
            if string.match(descendant.Name, "Invis") and descendant.Parent.Name ~= "Lobby" then
                descendant:Destroy()
            end
    
            if string.match(descendant.Name, "Invis") and descendant.Parent.Name ~= "Lobby" then
                descendant:Destroy()
            end
        end
    end)

    rt.WeaponTracker2 = workspace.DescendantRemoving:Connect(function(descendant)
        if descendant:IsA("Tool") or descendant.Name == "GunDrop" then
            rt:UpdateRoles()
        end
    end)
end

------------------------------------INFINITE YEILD SCRIPTS-----------------------------------------------
----------------------------------------------------------------------------------------------------------

local function Fling (targetPlayer)
    if rt.flingActive then
        rt.flingActive = false
        return
    end

    rt.flingActive = true

    local character = rt:Character()
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = humanoid and humanoid.RootPart
    local tCharacter = targetPlayer.Character
    local tHumanoid = tCharacter and tCharacter:FindFirstChildOfClass("Humanoid")
    local tRootPart = tHumanoid and tHumanoid.RootPart
    local tHead = tCharacter and tCharacter:FindFirstChild("Head")
    local accessory = tCharacter and tCharacter:FindFirstChildOfClass("Accessory")
    local handle = accessory and accessory:FindFirstChild("Handle")

    if character and humanoid and rootPart then
        if rootPart.Velocity.Magnitude < 50 then
            getgenv().OldPos = rootPart:GetPivot()
        end
        if tHumanoid and tHumanoid.Sit then
            Notif:Notify("Target is sitting", 5, "error")
            return
        end
        if tHead then
            workspace.CurrentCamera.CameraSubject = tHead
        elseif handle then
            workspace.CurrentCamera.CameraSubject = handle
        else
            workspace.CurrentCamera.CameraSubject = tHumanoid
        end
        if not tCharacter:FindFirstChildWhichIsA("BasePart") then
            return
        end

        local function FPos(basePart, pos, ang)
            rootPart.CFrame = CFrame.new(basePart.Position) * pos * ang
            character:PivotTo(CFrame.new(basePart.Position) * pos * ang)
            rootPart.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
            rootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
        end

        local function SFBasePart(basePart)
            local timeToWait = 2
            local time = tick()
            local angle = 0

            repeat
                if rootPart and tHumanoid then
                    if basePart.Velocity.Magnitude < 50 then
                        angle = angle + 100

                        FPos(basePart, CFrame.new(0, 1.5, 0) + tHumanoid.MoveDirection * basePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
                        task.wait()

                        FPos(basePart, CFrame.new(0, -1.5, 0) + tHumanoid.MoveDirection * basePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
                        task.wait()

                        FPos(basePart, CFrame.new(2.25, 1.5, -2.25) + tHumanoid.MoveDirection * basePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
                        task.wait()

                        FPos(basePart, CFrame.new(-2.25, -1.5, 2.25) + tHumanoid.MoveDirection * basePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
                        task.wait()

                        FPos(basePart, CFrame.new(0, 1.5, 0) + tHumanoid.MoveDirection, CFrame.Angles(math.rad(angle), 0, 0))
                        task.wait()

                        FPos(basePart, CFrame.new(0, -1.5, 0) + tHumanoid.MoveDirection, CFrame.Angles(math.rad(angle), 0, 0))
                        task.wait()
                    else
                        FPos(basePart, CFrame.new(0, 1.5, tHumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()

                        FPos(basePart, CFrame.new(0, -1.5, -tHumanoid.WalkSpeed), CFrame.Angles(0, 0, 0))
                        task.wait()

                        FPos(basePart, CFrame.new(0, 1.5, tHumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()

                        FPos(basePart, CFrame.new(0, 1.5, tRootPart.Velocity.Magnitude / 1.25), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()

                        FPos(basePart, CFrame.new(0, -1.5, -tRootPart.Velocity.Magnitude / 1.25), CFrame.Angles(0, 0, 0))
                        task.wait()

                        FPos(basePart, CFrame.new(0, 1.5, tRootPart.Velocity.Magnitude / 1.25), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()

                        FPos(basePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()

                        FPos(basePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                        task.wait()

                        FPos(basePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(-90), 0, 0))
                        task.wait()

                        FPos(basePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                        task.wait()
                    end
                else
                    break
                end
            until basePart.Velocity.Magnitude > 500 or basePart.Parent ~= targetPlayer.Character or targetPlayer.Parent ~= rt.Players or not targetPlayer.Character == tCharacter or tHumanoid.Sit or humanoid.Health <= 0 or tick() > time + timeToWait
        end

        workspace.FallenPartsDestroyHeight = 0 / 0

        local bv = Instance.new("BodyVelocity")
        bv.Name = "EpixVel"
        bv.Parent = rootPart
        bv.Velocity = Vector3.new(9e8, 9e8, 9e8)
        bv.MaxForce = Vector3.new(1 / 0, 1 / 0, 1 / 0)

        humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

        if tRootPart and tHead then
            if (tRootPart.CFrame.p - tHead.CFrame.p).Magnitude > 5 then
                SFBasePart(tHead)
            else
                SFBasePart(tRootPart)
            end
        elseif tRootPart and not tHead then
            SFBasePart(tRootPart)
        elseif not tRootPart and tHead then
            SFBasePart(tHead)
        elseif not tRootPart and not tHead and accessory and handle then
            SFBasePart(handle)
        else
            Notif:Notify("Target is missing everything", 5, "error")
            return
        end

        bv:Destroy()
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
        workspace.CurrentCamera.CameraSubject = humanoid

        repeat
            rootPart.CFrame = getgenv().OldPos * CFrame.new(0, .5, 0)
            character:PivotTo(getgenv().OldPos * CFrame.new(0, .5, 0))
            humanoid:ChangeState("GettingUp")
            for _, x in ipairs(character:GetChildren()) do
                if x:IsA("BasePart") then
                    x.Velocity, x.RotVelocity = Vector3.new(), Vector3.new()
                end
            end
            task.wait()
        until (rootPart.Position - getgenv().OldPos.p).Magnitude < 25
        workspace.FallenPartsDestroyHeight = workspace.FallenPartsDestroyHeight
        getgenv().OldPos = nil
    else
        Notif:Notify("Random error", 5, "error")
    end
end

local function ServerHop()
    local PlaceId = game.PlaceId
    local JobId = game.JobId

    local servers = {}
    local req = request({Url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true", PlaceId)})
    local body = rt.HttpService:JSONDecode(req.Body)

    if body and body.data then
        for i, v in next, body.data do
            if type(v) == "table" and tonumber(v.playing) and tonumber(v.maxPlayers) and v.playing < v.maxPlayers and v.id ~= JobId then
                table.insert(servers, 1, v.id)
            end
        end
    end

    if #servers > 0 then
        rt.TeleportService:TeleportToPlaceInstance(PlaceId, servers[math.random(1, #servers)], rt.player)
    else
        return Notif:Notify("Couldnt find a server", 1, "error")
    end
end

local function RejoinServer()
    local PlaceId = game.PlaceId
    local JobId = game.JobId

    if #rt.Players:GetPlayers() <= 1 then
		rt.player:Kick("\nRejoining...")
		task.wait()
		rt.TeleportService:Teleport(PlaceId, rt.player)
	else
		rt.TeleportService:TeleportToPlaceInstance(PlaceId, JobId, rt.player)
	end
end
-----------------------------------------IRIS SCRIPTS-----------------------------------------------------
----------------------------------------------------------------------------------------------------------

local function WayPointManager ()

    local function helpMarker(helpText: string)
        Iris.PushConfig({ TextColor = Iris._config.TextDisabledColor })
        local text = Iris.Text({ "(?)" })
        Iris.PopConfig()

        Iris.PushConfig({ ContentWidth = UDim.new(0, 350) })
        if text.hovered() then
            Iris.Tooltip({ helpText })
        end
        Iris.PopConfig()
    end

    local function WaypointWindow()
        Iris.Window({ "Waypoint Manager", [Iris.Args.Window.NoClose] = true })

            -- Dropdown (tree) for waypoints
            Iris.SameLine()
                helpMarker("Double click to Teleport")
                Iris.Tree({ "Waypoints" })
                local waypointList = Iris.State({})
                local sharedwaypoint = Iris.State(1)
                local selectedWaypoint = Iris.State(0)
                local inputtext = Iris.State("")
                local waypointName = Iris.State("waypoint")

                for i, waypoint in ipairs(waypointList:get()) do
                    local item = Iris.Selectable({ waypoint, i }, { index = sharedwaypoint })

                    if item.doubleClicked() then
                        print("Waypoint double-clicked:", waypoint)
                        -- Handle double-click logic
                        for _, rtwaypoint in ipairs(rt.Settings.WayPoints) do
                            if rtwaypoint.name == waypoint then
                                rt:Character():PivotTo(rtwaypoint.waypoint)
                                break
                            end
                        end
                    end

                    if item.selected() then
                        selectedWaypoint:set(i)
                    end
                end
                Iris.End() -- End Tree
            Iris.End()
            -- Separator
            Iris.Separator()

            -- Text Input and Help Marker
            Iris.SameLine()

            helpMarker("Not required but Recommended")
            Iris.InputText({ "", "way point name" }, { text = inputtext })
            
            Iris.End()

            -- Add Waypoint Button
            if Iris.Button({ "Add Waypoint" }).clicked() then
                local newWaypoint
                local name = inputtext:get() ~= "" and inputtext:get() or waypointName:get() .. #waypointList:get() + 1
                if inputtext:get() == "" then
                    table.insert(waypointList:get(), name)
                    sharedwaypoint:set(#waypointList:get())

                    newWaypoint = { name = name, waypoint = rt:Character():GetPivot() }
                    table.insert(rt.Settings.WayPoints, newWaypoint)
                    inputtext:set("")
                    return Iris.End()
                end

                table.insert(waypointList:get(), name)
                sharedwaypoint:set(#waypointList:get())

                newWaypoint = { name = name, waypoint = rt:Character():GetPivot() }
                table.insert(rt.Settings.WayPoints, newWaypoint)
                inputtext:set("")
            end

            -- Remove Selected Waypoint Button
            if Iris.Button({ "Remove Selected" }).clicked() then
                local selectedIndex = selectedWaypoint:get()
                if selectedIndex ~= 0 then
                    local selectedName = waypointList:get()[selectedIndex]

                    -- Remove from waypointList
                    local waypoints = waypointList:get()
                    table.remove(waypoints, selectedIndex)
                    waypointList:set(waypoints)

                    -- Reset selection
                    selectedWaypoint:set(0)

                    -- Remove from rt.Settings.WayPoints
                    for i, waypoint in ipairs(rt.Settings.WayPoints) do
                        if waypoint.name == selectedName then
                            table.remove(rt.Settings.WayPoints, i)
                            break
                        end
                    end
                end
            end

        Iris.End() -- End Window
    end


    Iris:Connect(WaypointWindow)

end 
--------------------------------CONNECTIONS SECTION OF THE CODE---------------------------------
------------------------------------------------------------------------------------------------

if (rt:CheckForConnection()) then  
    Notif:Notify("Cleaning Connections...", 1, "success")
    rt.Disconnect(rt.RoleTracker1)
    rt.Disconnect(rt.RoleTracker2)
    rt:Disconnect(rt.viewChanged)
    rt.Disconnect(rt.viewDiedFunc)
    rt.Disconnect(rt.WeaponTracker1)
    rt.Disconnect(rt.WeaponTracker2)
    rt.Disconnect(rt.Joined)
    rt.Disconnect(rt.Left)
    rt.Disconnect(rt.UserDied)

    for _, v in pairs(rt.playerESP) do
        rt.Disconnect(v.connection1)
        rt.Disconnect(v.connection2)
        rt.Disconnect(v.connection3)
    end

    Notif:Notify("Cleaning Memory...", 1, "success")
    rt.player:SetAttribute("Connection", nil)

    -- if Esp is on while removing UI then we remove all ESP
    if rt.espON then for _, v in (rt.Players:GetChildren()) do RemovePlayerESP(v) end end

    rt = nil

    Notif:Notify("Removing Instances...", 1, "success")

    task.wait(0.5) -- add in before the scheduler

    game:GetService("CoreGui"):FindFirstChild("watermark"):Destroy()
    game:GetService("CoreGui"):FindFirstChild("Notifications"):Destroy()
    game:GetService("CoreGui"):FindFirstChild("screen"):Destroy()
end

-- Add ESP for players who join later
rt.Joined = rt.Players.PlayerAdded:Connect(function(player)
    if rt.espON then CreatePlayerESP(player) end
end)

rt.Left = rt.Players.PlayerRemoving:Connect(function(player)
    if rt.espON then RemovePlayerESP(player) end
end)

rt.UserDied = rt.player.CharacterRemoving:Connect(function(character)
    if coroutine.status(rt.start) == 'running' then
        AutoFarmCleanUp()
    end
end)

rt.player:SetAttribute("Connection", true)
rt.start = coroutine.create(collectCoins)

--------------------------------UI SECTION OF THE CODE------------------------------------------
------------------------------------------------------------------------------------------------


library.title = "FoxAutofarm"
if library.rank ~= "developer" then library:Introduction(); task.wait(1) end


local Init = library:Init()
local Tab1 = Init:NewTab("Home 🏠")
local Tab2 = Init:NewTab("Auto Farm ♻️")
local Tab3 = Init:NewTab("Actions 🔨")
local Tab4 = Init:NewTab("Misc ⚙️")
local Tab5 = Init:NewTab("Credits 🎉")

------------------------------------HOME TAB--------------------------------------------------
----------------------------------------------------------------------------------------------
Tab1:NewSection("KeyBind Section")

Tab1:NewKeybind("Hide Gui", Enum.KeyCode.RightAlt, function(key)
    Init:UpdateKeybind(key)
end)
Tab1:NewLabel("", "center")

-------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------
Tab1:NewSection("Movement Section")

Tab1:NewButton("Reset WalkSpeed", function()
    local result = rt:ResetSpeed() -- reset speed
    if result == false then Notif:Notify("WalkSpeed is already at default:", 1.5, "error") return end -- error handling

    Notif:Notify("Reseted WalkSpeed to 16 ", 1, "success")
    result = nil
end)

Tab1:NewButton("Increase WalkSpeed", function()
    local result = rt:SpeedUp() -- reset speed
    if result == false then Notif:Notify("WalkSpeed is at max", 1.5, "error") return end -- error handling

    Notif:Notify("Increased WalkSpeed to: ".. rt:Character():FindFirstChildWhichIsA("Humanoid").WalkSpeed, 1, "success")
    result = nil
end)
Tab1:NewLabel("this will up your walkspeed by 4 [28 is max]", "center")
Tab1:NewLabel("", "center")

-------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------
Tab1:NewSection("Destory Section")

local DestoryGui = Tab1:NewButton("Destroy gui", function()
    --Add A function into the UI LIB to handle this and disconnect all connections within the UI
    --Use schduler to handle the destruction of the UI

    Notif:Notify("Cleaning Connections...", 1, "success")
    AutoFarmCleanUp()
    rt.Disconnect(rt.Added)
    rt.Disconnect(rt.Removing)
    rt.Disconnect(rt.RoleTracker1)
    rt.Disconnect(rt.RoleTracker2)
    rt:Disconnect(rt.viewChanged)
    rt.Disconnect(rt.viewDiedFunc)
    rt.Disconnect(rt.WeaponTracker1)
    rt.Disconnect(rt.WeaponTracker2)
    rt.Disconnect(rt.Joined)
    rt.Disconnect(rt.Left)
    rt.Disconnect(rt.UserDied)

    for _, v in pairs(rt.playerESP) do
        rt.Disconnect(v.connection1)
        rt.Disconnect(v.connection2)
        rt.Disconnect(v.connection3)
    end

    Notif:Notify("Cleaning Memory...", 1, "success")
    rt.player:SetAttribute("Connection", nil)

    -- if Esp is on while removing UI then we remove all ESP
    if rt.espON then for _, v in (rt.Players:GetChildren()) do RemovePlayerESP(v) end end

    rt = nil

    Notif:Notify("Removing Instances...", 1, "success")

    task.wait(0.5) -- add in before the scheduler

    game:GetService("CoreGui"):FindFirstChild("watermark"):Destroy()
    game:GetService("CoreGui"):FindFirstChild("Notifications"):Destroy()
    game:GetService("CoreGui"):FindFirstChild("screen"):Destroy()
end)
Tab1:NewLabel("remove UI HUB and its CONNECTIONS", "center")

------------------------------------AUTO FARM TAB--------------------------------------------------
---------------------------------------------------------------------------------------------------

Tab2:NewSection("Zynic's Auto Farm Settings")

Tab2:NewToggle("Uninterrupted Mode", rt.Uninterrupted, function(value)
    local vers = value and "on" or "off"
    rt.Uninterrupted = value
    Notif:Notify("Uninterrupted Mode: " .. vers, 1, "success")
end)
Tab2:NewLabel("this will kill you before you start autofarm", "center")
Tab2:NewLabel("", "center")

Tab2:NewToggle("Set Return Point", rt.TpBackToStart, function(value)
    local vers = value and "on" or "off"
    rt.TpBackToStart = value
    Notif:Notify("Return point: " .. vers, 1, "success")
end)
Tab2:NewLabel("this will return u to the point where u started the autofarm", "center")
Tab2:NewLabel("", "center")

Tab2:NewSlider("Radius", "", true, "/", {min = 50, max = rt.radius, default = 120}, function(value)
    rt.radius = value
end)
Tab2:NewLabel("this will be how far in studs you can search for the closet token", "center")
Tab2:NewLabel("", "center")
rt.radius = 120

Tab2:NewSlider("Tween Speed", "", true, "/", {min = 16, max = rt.walkspeed, default = 20}, function(value)
    rt.walkspeed = value
end)
Tab2:NewLabel("speed at which you will move to a token", "center")
Tab2:NewLabel("", "center")
rt.walkspeed = 20

-------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------
Tab2:NewSection("Auto Farm Section")

local AutoFarm 
local AutoFarmValueChanged = false 
AutoFarm = Tab2:NewToggle("Zynic AutoFarm", false, function(value)
    local vers = value and "on" or "off"

    if AutoFarmValueChanged then AutoFarmValueChanged = not AutoFarmValueChanged return end
    if not ToggleAutoFarm(value) then AutoFarmValueChanged = true; AutoFarm:Set(false) end

    
    Notif:Notify("Zynic AutoFarm is now " .. vers, 1, "success")
end)
Tab2:NewLabel("this is the built in autofarm maybe by Zynic [Recommended]", "center")
Tab2:NewLabel("", "center")


------------------------------------ACTIONS TAB--------------------------------------------------
---------------------------------------------------------------------------------------------------

Tab3:NewSection("Roles Section")
Tab3:NewLabel("Murderer Info", "center")
local MurdName = Tab3:NewLabel("Murderer Username:", "left")
local MurdKnife = Tab3:NewLabel("Murderer Knife:", "left")
local MurdKnifeEffect = Tab3:NewLabel("Murderer Knife Effect:", "left")
local MurdPerk = Tab3:NewLabel("Murderer Perk:", "left")
local Murdlvl = Tab3:NewLabel("Murderer Lvl:", "left")
local MurdPres = Tab3:NewLabel("Murderer Prestige:", "left")
local MurdXP = Tab3:NewLabel("Murderer XP:", "left")

Tab3:NewLabel("Sheriff Info", "center")
local SherName = Tab3:NewLabel("Sheriff Username:", "left")
local SherGun = Tab3:NewLabel("Sheriff Gun:", "left")
local Sherlvl = Tab3:NewLabel("Sheriff Lvl:", "left")
local SherPres = Tab3:NewLabel("Sheriff Prestige:", "left")
local SherXP = Tab3:NewLabel("Sheriff XP:", "left")
Tab3:NewLabel("", "center")

rt.refresh = function(val :string) if val  then Notif:Notify(val, 1.5, "alert") end  local roles = rt:GetRoles(); rt.LoadRoleInfo(roles, {MurdName = MurdName, MurdKnife = MurdKnife, MurdKnifeEffect = MurdKnifeEffect, MurdPerk = MurdPerk, Murdlvl = Murdlvl, MurdPres = MurdPres, MurdXP = MurdXP }, { SherName = SherName,  SherGun = SherGun,  Sherlvl = Sherlvl,  SherPres = SherPres, SherXP = SherXP } ) end

rt.refresh("Init")
task.wait(1)
rt:UpdateRoles()
rt:MonitorTools()
-------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------

Tab3:NewSection("Actions Settings")

Tab3:NewToggle("Safe Gun Grab", false, function(value)
    local vers = value and "on" or "off"
    rt.Settings.Safe_Gun_Grab = value

    Notif:Notify("Safe Gun Grab is now: " .. vers, 1, "success")
    vers = nil
end)
Tab3:NewLabel("this will make sure you didnt die before getting gun", "center")
Tab3:NewLabel("", "center")


-------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------

Tab3:NewSection("Actions Section")
local spectateMurd 
local spectateMurdValueChanged = false
spectateMurd = Tab3:NewToggle("Spectate Murderer", false, function(value)
    local vers = value and "on" or "off"

    if spectateMurdValueChanged then spectateMurdValueChanged = not spectateMurdValueChanged return end
    if not rt.Murderer then spectateMurdValueChanged = true; Notif:Notify("No Murderer To View", 1, "error") return spectateMurd:Set(false) end

    if vers == "on" then
        rt:ViewMurderer()
    else
        rt:UnViewMurderer()
    end

    Notif:Notify("Murderer Spectate Status: " .. vers, 1, "success")
end)
Tab3:NewLabel("", "center")

Tab3:NewButton("Refresh Roles", function()
    Notif:Notify("Refreshing Roles...", 1, "information")
    rt.refresh("Refresh Roles Button -> Fire")

    if rt.sheriff or rt.Murderer then
        Notif:Notify("Found a role(s)", 1, "success") 
    else
        Notif:Notify("Did not find any roles", 1, "error")
    end
end)
Tab3:NewLabel("This will refresh murderer n sheriff roles", "center")

Tab3:NewButton("Get Gun", function()
    if rt.AutoFarmOn then return Notif:Notify("Cannot do this while autofarm is on", 1, "error") end
    rt:GetGun()
end)

Tab3:NewButton("Fling Murderer", function()
    if rt.AutoFarmOn then return Notif:Notify("Cannot do this while autofarm is on", 1, "error") end
    if not rt.Murderer then return Notif:Notify("There is no murderer", 1, "error") end
    
    Notif:Notify("Flinging Murderer...", 0.5, "information")

    coroutine.wrap(Fling)(rt.Murderer)
    if rt.flingActive == false then Notif:Notify("AdvanceFling is turned off", 1, "success") else Notif:Notify("AdvanceFling is turned on", 1, "success") end
end)

------------------------------------MISC TAB--------------------------------------------------
---------------------------------------------------------------------------------------------------

Tab4:NewSection("WayPoints Section")
local WayPointTable = Tab4:NewSelector("WayPoints Table", "Empty Table", rt.Settings.WayPoints, function(d)
    rt.CurrentWayPointName = d
    Notif:Notify("Selected: " .. d, 1, "success")
end)
Tab4:NewLabel("This waypoint table is buggy due to the UI LIB \n[use Iris WITH CAUTION]", "center")

Tab4:NewKeybind("Set WayPoint", Enum.KeyCode.Backspace, function(key)
    local name = #rt.Settings.WayPoints+1
    local newWaypoint = {name = "waypoint"..tostring(name), waypoint = rt:Character():GetPivot() }
    table.insert(rt.Settings.WayPoints, newWaypoint)

    WayPointTable:AddOption(newWaypoint.name)

    Notif:Notify("WayPoint has been Set", 1, "success")
end)

Tab4:NewKeybind("GoTo WayPoint", nil, function(key)
    if rt.AutoFarmOn then return Notif:Notify("Cannot do this while autofarm is on", 1, "error") end
    local pos = nil
    for _, waypoint in ipairs(rt.Settings.WayPoints) do
        if waypoint.name == rt.CurrentWayPointName then
            pos = waypoint.waypoint
            break
        end
    end

    if not pos then return Notif:Notify("No WayPoint Selected", 1, "error") end
    Notif:Notify("Going to WayPoint...", 1, "success")

    rt:Character():PivotTo(pos) 
end)
Tab4:NewLabel("", "center")

Tab4:NewButton("Remove WayPoint", function()
    for i, v in ipairs(rt.Settings.WayPoints) do
        if v.name == rt.CurrentWayPointName then
            table.remove(rt.Settings.WayPoints, i)
            WayPointTable:RemoveOption(rt.CurrentWayPointName)
            break
        end
    end

    Notif:Notify("WayPoint Removed", 1, "success")
end)
Tab4:NewLabel("", "center")

Tab4:NewSection("Iris")
Tab4:NewButton("Iris WayPointManager", function()
    if rt.AutoFarmOn then return Notif:Notify("Cannot do this while autofarm is on", 1, "error") end
    if rt.IWPM then return Notif:Notify("Iris is already loaded and cannot be removed until you leave", 2, "error") end

    rt.IWPM = true
    WayPointManager()
    Notif:Notify("Iris WayPointManager Loaded", 1, "success")
end)
Tab4:NewLabel("[Recommended] Only issue is that its a 1 time use and will stay until u leave", "center")
Tab4:NewLabel("", "center")

-------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------

Tab4:NewSection("HitBox Section")

local hitbox
hitbox = Tab4:NewTextbox("HitBox Size", "", "5", "all", "small", true, false, function(val)
    if rt.AutoFarmOn then return Notif:Notify("Cannot do this while autofarm is on", 1, "error") end
    local size = tonumber(val);
    print(size)
    --if size == 0 then return Notif:Notify("HitBox Size has been Reseted", 1, "success") end
     if size == 0 then createHitboxForPlayers(rt.Players:GetChildren(), 0); hitbox:Input("") return Notif:Notify("HitBox Size has been Reseted", 1, "success") end
   
    if not size then return Notif:Notify("HitBox Size is invalid", 1, "error") end
    -- if size == nil then hitbox:Input("") return Notif:Notify("HitBox Size is invalid", 1, "error") end

    createHitboxForPlayers(rt.Players:GetChildren(), tonumber(size))
    Notif:Notify("HitBox Size Set to: ".. val, 1, "success")
    hitbox:Input("")
end)
Tab4:NewLabel("Default size is 1, Max size is 15, enter 0\nto Remove them", "center")
Tab4:NewLabel("", "center")

-------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------

Tab4:NewSection("Other Stuff")

Tab4:NewToggle("Save Settings", false, function(value)
    local vers = value and "on" or "off"
    Notif:Notify("Saving Settings...", 1, "success")
end)
Tab4:NewLabel("This will save your Auto Farm Settings, Actions Settings, WayPoints, and KeyBinds", "center")
Tab4:NewLabel("", "center")

Tab4:NewToggle("Esp", false, function(value)
    local vers = value and "on" or "off"
    Notif:Notify("Esp is now " .. vers, 1, "success")

    if value then
        -- loops thru all the players and creates ESP
        rt.espON = value
        for _, player in pairs(rt.Players:GetPlayers()) do if player ~= rt.player then CreatePlayerESP(player) end end
    else
        --loops thru all the players and removes ESP
        rt.espON = value
        for _, player in pairs(rt.Players:GetPlayers()) do if player ~= rt.player then RemovePlayerESP(player) end end
    end
end)
Tab4:NewLabel("Uses My Custom Esp derived from Position Logger'", "left")
Tab4:NewLabel("", "center")

local teleportBox
teleportBox = Tab4:NewTextbox("TP to plr", "", "user", "all", "small", true, false, function(val)
    if rt.AutoFarmOn then return Notif:Notify("Cannot do this while autofarm is on", 1, "error") end
    if val == "" then return Notif:Notify("Please provide a Plrs name or display name", 1, "error") end
    local result = rt.FindPlayer(val)
    if not result then return Notif:Notify("No such person: ".. val, 1, "error") end

    Notif:Notify("Teleporting to: ".. val, 1, "success")
    rt:Character():PivotTo(result.Character:GetPivot())

    teleportBox:Input("")
end):Place("username/display name")

Tab4:NewLabel("just type in the first 3 letters of the user, 4 if someone else has the same first 3 letters", "center")
Tab4:NewLabel("", "center")

Tab4:NewButton("Tp to alive plr", function()
    if rt.AutoFarmOn then return Notif:Notify("Cannot do this while autofarm is on", 1, "error") end
    local AlivePlayers = rt:GetAlivePlayers()
    if not AlivePlayers then return Notif:Notify("Game not in progress", 1, "error") end

    local RandomPlr = AlivePlayers[math.random(1, #AlivePlayers)]
    RandomPlr = RandomPlr ~= rt.player and RandomPlr or AlivePlayers[math.random(1, #AlivePlayers)] --looks confusing? ikr but it will make sure it doesn't give the current plr
    Notif:Notify("Teleporting to: ".. RandomPlr.Name, 1, "success")

    TeleportToPlayer(RandomPlr)
end)
Tab4:NewLabel("Teleport you to a plr still alive in the round", "center")

Tab4:NewButton("Rejoin Server/Panic Button", function()
    Notif:Notify("Running Panic...", 1, "success")
    RejoinServer()
end)
Tab4:NewLabel("Lets say somehow u break the gui or jus want2 rejoin\nwell then, use this", "center")

Tab4:NewButton("Server Hop", function()
    Notif:Notify("Teleporting...", 1, "success")
    ServerHop()
end)

------------------------------------CREDITS TAB--------------------------------------------------
---------------------------------------------------------------------------------------------------

Tab5:NewSection("Creators:")
Tab5:NewLabel("Zynic", "left")
Tab5:NewLabel("", "center")

Tab5:NewSection("Tools I used:", "left")
Tab5:NewLabel("XSX UI Library", "left")
Tab5:NewLabel("Octree", "left")
Tab5:NewLabel("Infinite Yield", "left")
Tab5:NewLabel("", "center")

Tab5:NewSection("Special Thanks:", "left")
Tab5:NewLabel("Infinite Yield & Dark Dex Devs", "left")
Tab5:NewLabel("Swift Executor Devs", "left")


Notif:Notify("Loaded FoxAutofarm", 2, "success")
library:Watermark("FoxAutofarm | v" .. library.version ..  " | " .. library:GetUsername() .. " | rank: " .. library.rank)
        end)
        if not success then
            warn("Ошибка при запуске FoxAutofarm: " .. tostring(err))
        end
    end)
end

return Autofarm
