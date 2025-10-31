getgenv().configs = getgenv().configs or {
    coinFarm = true,
    safeHeight = 100,
    murderDistance = 30,
    coinWaitTime = 0.5,
    loopDelay = 0.4,
    safeWaitTime = 2,
    resetInterval = 300,
    enableAutoReset = false,
	hopifnocandy = true,
	hoptime = 180,
    buybattlepass = true,
	openBox = false,
    coinNames = {"Coin_Server"},
	webhookurl = "https://discord.com/api/webhooks/"
}


repeat task.wait() until game:IsLoaded()
repeat task.wait() until game:GetService("Players").LocalPlayer:GetAttribute("ClientLoaded")
if getgenv().MyMM2ScriptUI then return end
getgenv().MyMM2ScriptUI = true
getgenv().battlepasslock = false

function CheckKick(v)
    if v.Name == "ErrorPrompt" then
        if v.TitleFrame.ErrorTitle.Text == "Teleport Failed" then
            while task.wait() do end
        else
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, game:GetService("Players").LocalPlayer)
            v:Destroy()
        end
    end
end

game:GetService('CoreGui').RobloxPromptGui.promptOverlay.ChildAdded:Connect(CheckKick)

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local localPlayer = Players.LocalPlayer
local processedCoins = {}
local currentMurder = nil
local isSafe = false
local circleMovement = nil
local currentCoinCenter = nil

Players.LocalPlayer.Idled:Connect(function()
	game:GetService("VirtualUser"):CaptureController()
	game:GetService("VirtualUser"):ClickButton2(Vector2.new())
end)

game:GetService("RunService"):Set3dRenderingEnabled(false)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = localPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true

local BlackFrame = Instance.new("Frame")
BlackFrame.Parent = ScreenGui
BlackFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
BlackFrame.BorderSizePixel = 0
BlackFrame.Size = UDim2.new(1, 0, 1, 0)
BlackFrame.Position = UDim2.new(0, 0, 0, 0)
BlackFrame.ZIndex = -1

local LogoFrame = Instance.new("Frame")
LogoFrame.Parent = ScreenGui
LogoFrame.BackgroundTransparency = 1
LogoFrame.Size = UDim2.new(0, 600, 0, 180) 
LogoFrame.Position = UDim2.new(0.5, -300, 0.5, -90)
LogoFrame.ZIndex = 10

local MainTitle = Instance.new("TextLabel")
MainTitle.Parent = LogoFrame
MainTitle.BackgroundTransparency = 1
MainTitle.Size = UDim2.new(1, 0, 0.5, 0)
MainTitle.Position = UDim2.new(0, 0, 0, 0)
MainTitle.Text = "Quang Huy"
MainTitle.TextColor3 = Color3.fromRGB(0, 255, 255)
MainTitle.TextScaled = true
MainTitle.Font = Enum.Font.GothamBold
MainTitle.TextStrokeTransparency = 0
MainTitle.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
MainTitle.ZIndex = 11

local SubTitle = Instance.new("TextLabel")
SubTitle.Parent = LogoFrame
SubTitle.BackgroundTransparency = 1
SubTitle.Size = UDim2.new(1, 0, 0.20, 0)
SubTitle.Position = UDim2.new(0, 0, 0.5, 0)
SubTitle.Text = "Murder Mystery 2"
SubTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
SubTitle.TextScaled = true
SubTitle.Font = Enum.Font.Gotham
SubTitle.ZIndex = 11

local CoinsLabel = Instance.new("TextLabel")
CoinsLabel.Parent = LogoFrame
CoinsLabel.BackgroundTransparency = 1
CoinsLabel.Size = UDim2.new(1, 0, 0.23, 0)
CoinsLabel.Position = UDim2.new(0, 0, 0.7, 10)
CoinsLabel.Text = "Coin: 0 (+0)"
CoinsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
CoinsLabel.Font = Enum.Font.Gotham
CoinsLabel.TextScaled = true
CoinsLabel.ZIndex = 11

local TimerLabel = Instance.new("TextLabel")
TimerLabel.Parent = LogoFrame
TimerLabel.BackgroundTransparency = 1
TimerLabel.Size = UDim2.new(1, 0, 0.20, 0)
TimerLabel.Position = UDim2.new(0, 0, 1.05, 0)
TimerLabel.Text = string.format("FPS: %d | Elapsed time: %d:%d:%d", 0, 0, 0, 0)
TimerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TimerLabel.Font = Enum.Font.GothamBold
TimerLabel.TextScaled = true
TimerLabel.ZIndex = 11

local RenderButton = Instance.new("TextButton")
RenderButton.Parent = ScreenGui
RenderButton.Size = UDim2.new(0, 80, 0, 80)
RenderButton.Position = UDim2.new(0, 50, 0.5, -40)
RenderButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
RenderButton.BorderSizePixel = 2
RenderButton.BorderColor3 = Color3.fromRGB(0, 255, 255)
RenderButton.Text = "3D\nOFF"
RenderButton.TextColor3 = Color3.fromRGB(255, 255, 255)
RenderButton.TextScaled = true
RenderButton.Font = Enum.Font.GothamBold
RenderButton.ZIndex = 12

local isUIVisible = true
RenderButton.MouseButton1Click:Connect(function()
    isUIVisible = not isUIVisible
    
    if isUIVisible then
        game:GetService("RunService"):Set3dRenderingEnabled(false)
        BlackFrame.Visible = true
        LogoFrame.Visible = true
        RenderButton.Text = "3D\nOFF"
        RenderButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    else
        game:GetService("RunService"):Set3dRenderingEnabled(true)
        BlackFrame.Visible = false
        LogoFrame.Visible = false
        RenderButton.Text = "3D\nON"
        RenderButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    end
end)

local debounce = false

game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if debounce then return end

	if input.KeyCode == Enum.KeyCode.RightControl then
		debounce = true
		isUIVisible = not isUIVisible

		if isUIVisible then
			game:GetService("RunService"):Set3dRenderingEnabled(false)
			BlackFrame.Visible = true
			LogoFrame.Visible = true
			RenderButton.Text = "3D\nOFF"
			RenderButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		else
			game:GetService("RunService"):Set3dRenderingEnabled(true)
			BlackFrame.Visible = false
			LogoFrame.Visible = false
			RenderButton.Text = "3D\nON"
			RenderButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
		end
		debounce = false
	end
end)

task.spawn(function()
    while task.wait(1) do
        for _, gui in pairs(game.Players.LocalPlayer.PlayerGui:GetChildren()) do
			if gui ~= ScreenGui then
                pcall(function()
				    gui.Enabled = false
                end)
			end
		end
    end
end)

local startTime = tick()
local lastUpdate = tick()
local fps = 0

RunService.Heartbeat:Connect(function()
	fps += 1
	local now = tick()
	if now - lastUpdate >= 1 then
		lastUpdate = now
		local elapsed = tick() - startTime
		local h = math.floor(elapsed / 3600)
		local m = math.floor((elapsed % 3600) / 60)
		local s = math.floor(elapsed % 60)
		TimerLabel.Text = string.format("FPS: %d | Elapsed time: %dh %dm %ds", fps, h, m, s)
		fps = 0
	end
end)

function Hop()
	pcall(function()
		local success, response = pcall(function()
			return game:HttpGet("https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100")
		end)
		if success then
			local jsonData = game:GetService("HttpService"):JSONDecode(response)
			if jsonData then
				for i = 1, #jsonData.data do
					k = jsonData.data[i].id
					if k and k ~= game.JobId then
						game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, k, game:GetService("Players").LocalPlayer)
						task.wait(3)
					end
				end
			end
		else
			warn(response)
		end
	end)
end

local EventInfoService = require(game:GetService("ReplicatedStorage"):WaitForChild("SharedServices"):WaitForChild("EventInfoService"))
local Sync = require(game:GetService("ReplicatedStorage"):WaitForChild("Database"):WaitForChild("Sync"))
local CoinCollected = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Gameplay"):WaitForChild("CoinCollected")
local ProfileData = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("ProfileData"))
local eventData = EventInfoService:GetCurrentEvent()
local battlepassData = EventInfoService:GetBattlePass()
local eventRemote = EventInfoService:GetEventRemotes()
local currency = eventData.Currency
local keyName = eventData.KeyName
local mysteryBox = eventData.MysteryBox.Name
local totalFarmed = 0
local lastChangeTime = tick()
local currentCoins = 0
local stoppls = false
local hihihi = 0

print("Loaded")

game:GetService("ReplicatedStorage"):WaitForChild("Remotes").Gameplay:WaitForChild("LoadingMap").OnClientEvent:Connect(function()
	lastChangeTime = tick()
	stoppls = false
	hihihi = 0
end)

game.Players.LocalPlayer.Character:FindFirstChild("Humanoid").StateChanged:Connect(function(_, v)
	if v == Enum.HumanoidStateType.Dead then
		print("Chet roi")
		stoppls = true
		if hihihi < 20 then
			while task.wait(5) do
				Hop()
			end
		end
	end
end)

game:GetService("ReplicatedStorage"):WaitForChild("Remotes").Gameplay.RoundEndFade.OnClientEvent:connect(function(p32)
	hihihi = 0
end)

CoinCollected.OnClientEvent:Connect(function(p11, p12, p13, _)
    lastChangeTime = tick()
    totalFarmed = totalFarmed + _.Value
	hihihi = hihihi + _.Value
    currentCoins = ProfileData.Materials.Owned[currency] or 0
    CoinsLabel.Text = "Coin: " .. tostring(currentCoins) .. " (+" .. totalFarmed .. ")"
    if p12 >= p13 then
        stoppls = true
		Players.LocalPlayer.Character:FindFirstChild("Humanoid").Health = 0
    end
end)

task.spawn(function()
    while true do
        local success, err = pcall(function()
            if ProfileData and ProfileData.Materials and ProfileData.Materials.Owned then
                currentCoins = ProfileData.Materials.Owned[currency] or 0
                CoinsLabel.Text = "Coin: " .. tostring(currentCoins) .. " (+" .. totalFarmed .. ")"
            end
        end)
        
        if not success then
            CoinsLabel.Text = "Coin: Error"
        end
        
        task.wait(10)
    end
end)

repeat task.wait() until Players.LocalPlayer and Players.LocalPlayer.PlayerGui

local LocalPlayer = Players.LocalPlayer

-- Wait for DeviceSelect GUI and auto-select Phone
spawn(function()
	while LocalPlayer.PlayerGui:FindFirstChild("DeviceSelect") do
		task.wait(0.1)
		local deviceSelect = LocalPlayer.PlayerGui:FindFirstChild("DeviceSelect")
		if deviceSelect then
			local container = deviceSelect:WaitForChild("Container", 5)
			if container then
				local phoneButton = container:WaitForChild("Phone", 5)
				if phoneButton then
					local button = phoneButton:WaitForChild("Button", 5)
					if button then
						-- Try multiple methods to click the button
						pcall(function()
							if button.MouseButton1Click then
								if replicatesignal then
									replicatesignal(button.MouseButton1Click)
								else
									for _, v in pairs(getconnections(button.MouseButton1Click)) do
										v:Fire()
									end
								end
							end
						end)
						
						-- Alternative method: direct click simulation
						pcall(function()
							if button.MouseButton1Down then
								if replicatesignal then
									replicatesignal(button.MouseButton1Down)
								else
									for _, v in pairs(getconnections(button.MouseButton1Down)) do
										v:Fire()
									end
								end
							end
						end)
						
						-- Backup method: GuiService click
						pcall(function()
							game:GetService("GuiService"):FireClick(button)
						end)
						
						task.wait(0.5)
					end
				end
			end
		end
		task.wait(1)
	end
end)

local function teleportTo(targetCFrame)
	local character = Players.LocalPlayer.Character
	if character and character:FindFirstChild('HumanoidRootPart') then
		character.HumanoidRootPart.CFrame = targetCFrame
		return true
	end
	return false
end

local function startCircleMovement(centerPosition)
	if circleMovement then
		circleMovement:Disconnect()
	end

	currentCoinCenter = centerPosition
	local angle = 0
	local radius = 0.5
	local speed = 2

	circleMovement = RunService.Heartbeat:Connect(function()
		local character = Players.LocalPlayer.Character
		if character and character:FindFirstChild('HumanoidRootPart') and currentCoinCenter then
			angle = angle + speed * 0.1
			local x = currentCoinCenter.X + math.cos(angle) * radius
			local z = currentCoinCenter.Z + math.sin(angle) * radius
			character.HumanoidRootPart.CFrame = CFrame.new(x, currentCoinCenter.Y, z)
		end
	end)
end

local function stopCircleMovement()
	if circleMovement then
		circleMovement:Disconnect()
		circleMovement = nil
	end
	currentCoinCenter = nil
end

local function NoclipLoop()
    speaker = localPlayer
    if speaker.Character ~= nil then
        for _, child in pairs(speaker.Character:GetDescendants()) do
            if child:IsA("BasePart") and child.CanCollide == true and child.Name ~= nil then
                child.CanCollide = false
            end
        end
    end
end

RunService.Stepped:Connect(NoclipLoop)

function ConvertTo(Type, Data)
    return Type.new(Data.x, Data.y, Data.z)
end

function CaculateDistance(Origin, Destination)
	if not Destination then
		Destination = LocalPlayer.Character:GetPrimaryPartCFrame()
	end

	local Origin, Destination = ConvertTo(Vector3, Origin), ConvertTo(Vector3, Destination)

	return (Origin - Destination).Magnitude
end

function TweenTo(huy)
    if not huy or not huy.CFrame then
        return
	end
	Position = huy.CFrame

    if game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer.Character and game:GetService("Players").LocalPlayer.Character:FindFirstChild("Humanoid") and game:GetService("Players").LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and game:GetService("Players").LocalPlayer.Character.Humanoid.Health > 0 and game:GetService("Players").LocalPlayer.Character.HumanoidRootPart then
        local Position = typeof(Position) ~= "CFrame" and ConvertTo(CFrame, Position) or Position

        if TweenInstance then
            pcall(
                function()
                    TweenInstance:Cancel()
                end
            )
        end

        for _, Part in localPlayer.Character:GetDescendants() do
            if Part:IsA("BasePart") then
                Part.CanCollide = false
            end
        end

        local Head = game.Players.LocalPlayer.Character:WaitForChild("Head")
        if not Head:FindFirstChild("cho nam gg") then
            local BodyVelocity = Instance.new("BodyVelocity")
            BodyVelocity.Name = "cho nam gg"
            BodyVelocity.MaxForce = Vector3.new(0, math.huge, 0)
            BodyVelocity.Velocity = Vector3.zero
            BodyVelocity.Parent = Head
        end

        if localPlayer.Character.Humanoid.Sit then
            game.Players.LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
        Position = CFrame.new(Position.x, math.max(Position.y, 5), Position.z)

        local PlayerPos = localPlayer.Character.HumanoidRootPart.CFrame
        localPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(PlayerPos.X, Position.Y, PlayerPos.Z)
        local Dist = CaculateDistance(localPlayer.Character.HumanoidRootPart.CFrame, Position)
        TweenInstance = game:GetService("TweenService"):Create(
            localPlayer.Character.HumanoidRootPart,
            TweenInfo.new(Dist / 60, Enum.EasingStyle.Linear),
            {CFrame = Position}
        )
        TweenInstance:Play()
		task.spawn(function()
			while TweenInstance.PlaybackState == Enum.PlaybackState.Playing do
				task.wait(0.1)
				if not huy.Parent or not localPlayer.Character then
					pcall(function()
						TweenInstance:Cancel()
					end)
					break
				end
			end
		end)
		TweenInstance.Completed:Wait()
    end
end

local function findMurder()
	for _, p in pairs(Players:GetPlayers()) do
		if p == Players.LocalPlayer then continue end
		local items = p.Backpack
		local character = p.Character
		if (items and items:FindFirstChild("Knife")) or (character and character:FindFirstChild("Knife")) then
			return p
		end
	end
	return nil
end

local function getDistanceToMurder()
	if not currentMurder or not currentMurder.Character then return math.huge end
	local myChar = Players.LocalPlayer.Character
	if not myChar or not myChar:FindFirstChild('HumanoidRootPart') then return math.huge end
	local murderChar = currentMurder.Character
	if not murderChar or not murderChar:FindFirstChild('HumanoidRootPart') then return math.huge end
	return (myChar.HumanoidRootPart.Position - murderChar.HumanoidRootPart.Position).Magnitude
end

local function flyToSafety()
	local character = Players.LocalPlayer.Character
	if character and character:FindFirstChild('HumanoidRootPart') then
		local currentPos = character.HumanoidRootPart.Position
		local safePos = Vector3.new(currentPos.X, currentPos.Y + getgenv().configs.safeHeight, currentPos.Z)
		character.HumanoidRootPart.CFrame = CFrame.new(safePos)
		isSafe = true
		stopCircleMovement()
	end
end

local function returnToGround()
	local character = Players.LocalPlayer.Character
	if character and character:FindFirstChild('HumanoidRootPart') then
		local raycast = workspace:Raycast(character.HumanoidRootPart.Position, Vector3.new(0, -1000, 0))
		if raycast then
			local groundPos = raycast.Position + Vector3.new(0, 5, 0)
			character.HumanoidRootPart.CFrame = CFrame.new(groundPos)
		end
		isSafe = false
	end
end

local function autoReset()
	while getgenv().configs.enableAutoReset do
		task.wait(getgenv().configs.resetInterval)
		if Players.LocalPlayer.Character then
			Players.LocalPlayer.Character:FindFirstChild("Humanoid").Health = 0
		end
	end
end

local function findNearestCoin()
	local CoinContainer = workspace:FindFirstChild("CoinContainer", true)
	while not CoinContainer do
		task.wait(1)
		CoinContainer = workspace:FindFirstChild("CoinContainer", true)
	end
	local LocalPlayer = game:GetService("Players").LocalPlayer
	local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local Root = Character:WaitForChild("HumanoidRootPart")

	local nearestCoin = nil
	local shortestDistance = math.huge

	for _, child in pairs(CoinContainer:GetChildren()) do
		if child:IsA("BasePart") and table.find(getgenv().configs.coinNames, child.Name) and not processedCoins[child] and not child:GetAttribute("Collected") then
			local distance = (child.Position - Root.Position).Magnitude
			if distance < shortestDistance then
				shortestDistance = distance
				nearestCoin = child
			end
		end
	end

	return {nearestCoin}
end

local function findKnife()
	local function search(container)
		return container:FindFirstChild("Knife")
	end
	return search(localPlayer.Character) or search(localPlayer.Backpack)
end

task.spawn(function()
	while task.wait() do
		local knife = findKnife()
		if not knife then return end
		game:GetService("Players").LocalPlayer.Character:WaitForChild("Knife"):WaitForChild("Stab"):FireServer("Slash")
	end
end)

local function coinFarm()
	while getgenv().configs.coinFarm == true and task.wait() do
		if not LocalPlayer:GetAttribute("Alive") then continue end

		if stoppls then
			continue
		end

		--[[currentMurder = findMurder()
		local distanceToMurder = getDistanceToMurder()
		if distanceToMurder < getgenv().configs.murderDistance then
			if not isSafe then
				flyToSafety()
				task.wait(getgenv().configs.safeWaitTime)
			end
		else
			if isSafe then
				returnToGround()
				task.wait(0.5)
			end
		end]]

		if not isSafe then
			local coins = findNearestCoin()
			if #coins > 0 then
				local targetCoin = coins[1]
				processedCoins[targetCoin] = true

				TweenTo(targetCoin)
				startCircleMovement(targetCoin.CFrame)
				task.wait(getgenv().configs.coinWaitTime)
				stopCircleMovement()
				--[[if teleportTo(targetCoin.CFrame * CFrame.new(0, 2, 0)) then
					task.wait(getgenv().configs.coinWaitTime)
				end]]

				task.wait(math.random(0.3, 0.8))

				task.spawn(function()
					task.wait(2)
					processedCoins[targetCoin] = nil
				end)
			else
				stopCircleMovement()
			end
		end

		task.wait(getgenv().configs.loopDelay)
	end
end

local function battlepass()
    if ProfileData then
        local cac = ProfileData[eventData.Title]
        if cac.CurrentTier < battlepassData.TotalTiers then
            getgenv().battlepasslock = true
            local coins = ProfileData.Materials.Owned[currency] or 0
            if coins >= battlepassData.TierCost then
                eventRemote.BuyTiers:FireServer(1)
				game.ReplicatedStorage.UpdateDataClient:Fire()
            end
        else
            getgenv().battlepasslock = false
        end
        for v_u_85, v86 in battlepassData.Rewards do
            local v94 = v_u_85
            local v95 = tostring(v94)
            local v96 = tonumber(v95)
            if not cac.ClaimedRewards[v95] and cac.CurrentTier >= v96 then
                print("lum")
                eventRemote.ClaimBattlePassReward:FireServer((v96))
				task.wait(1)
            end
        end
		if (ProfileData.Materials.Owned[currency] or 0) >= battlepassData.FinalRewardCost then
            eventRemote.BuyFinalReward:FireServer()
		end
    end
end

if getgenv().configs.buybattlepass then
	task.spawn(function()
		while task.wait(2) do
			battlepass()
		end
	end)
end

local function getimg(asset_id)
    local a, b = pcall(function()
        return game:GetService("HttpService"):JSONDecode(
            request({
                Url = "https://thumbnails.roblox.com/v1/assets?assetIds=" .. asset_id .. "&size=420x420&format=Png&isCircular=false",
                Method = "GET",
            }).Body
        ).data[1].imageUrl
    end)
    if a then
        return b
    else
        warn(b)
    end
end

local function openBox(resource)
	if ProfileData and ProfileData.Materials and ProfileData.Materials.Owned then
		local cost = Sync.Shop.Weapons[mysteryBox].Price[resource] or 0
		local owned = ProfileData.Materials.Owned[resource] or 0

		if owned >= cost and cost > 0 then
			local startTime = os.clock()
			local result = game:GetService("ReplicatedStorage").Remotes.Shop.OpenCrate:InvokeServer(mysteryBox, "MysteryBox", resource)
			task.wait(0.75 - (os.clock() - startTime))
			if result then
				local huhu = Sync.Weapons[result]
				if huhu.Rarity and huhu.Rarity == "Godly" then
					local embed = {
						title = "Murder Mystery 2",
						author = {
							name = "Quang Huy"
						},
						color = 0x2f3136,
						fields = {
							{
								name = "Username:",
								value = "||" .. Players.LocalPlayer.Name .. "||",
								inline = false
							},
							{
								name = "Item Name:",
								value = huhu.ItemName,
								inline = false
							},
							{
								name = "Item Type:",
								value = huhu.ItemType,
								inline = false
							},
							{
								name = "Year:",
								value = huhu.Year,
								inline = false
							},
							{
								name = "Rarity:",
								value = huhu.Rarity,
								inline = false
							},
							{
								name = "Event:",
								value = huhu.Event,
								inline = false
							},
						},
						footer = {
							text = "Made by Quang Huy",
							icon_url = "https://i.imgur.com/LYgkSs1.jpeg"
						},
						thumbnail = {
							url = getimg(huhu.ItemID)
						},
						timestamp = DateTime.now():ToIsoDate()
					}

					local payload = {
						embeds = {embed},
						avatar_url = "https://i.imgur.com/LYgkSs1.jpeg",
						username = "Quang Huy",
					}

					local a, b = pcall(function()
						return request({
							Url = getgenv().configs.webhookurl,
							Method = "POST",
							Headers = {
								["Content-Type"] = "application/json",
							},
							Body = game:GetService("HttpService"):JSONEncode(payload)
						})
					end)
					if not a then warn(b) end
				end
				game:GetService("ReplicatedStorage").Remotes.Shop.BoxController:Fire(mysteryBox, result)
			end
			return true
		else
			return false
		end
	end
end

if getgenv().configs.openBox then
	task.spawn(function()
		while task.wait(2) do
			if not getgenv().battlepasslock then
				openBox(currency)
			end
			openBox(keyName)
		end
	end)
end

local function cleanupProcessedCoins()
	for coin, _ in pairs(processedCoins) do
		if not coin.Parent then
			processedCoins[coin] = nil
		end
	end
end

task.spawn(function()
	while true do
		task.wait(10)
		cleanupProcessedCoins()
	end
end)

task.spawn(function()
	autoReset()
end)

task.spawn(function()
	coinFarm()
end)

if getgenv().configs.hopifnocandy then
    task.spawn(function()
        while task.wait() do
            if tick() - lastChangeTime > getgenv().configs.hoptime then
                while task.wait(5) do
                    Hop()
                end
            end
        end
    end)
end
