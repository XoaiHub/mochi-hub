local Players = (cloneref(game:GetService('Players')))

repeat task.wait() until Players.LocalPlayer

local player = Players.LocalPlayer
local success, result = pcall(function()
    return player:GetMouse()
end)

local mouse = success and result or nil


local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "aristo.lua",
    SubTitle = "Attack on Titan: Revolution ( Paid Version Open-Source )",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "" }),
    Ts = Window:AddTab({ Title = "Thunder Spears", Icon = "" }),
    Misc = Window:AddTab({ Title = "Misc", Icon = "" }),
    Raids = Window:AddTab({ Title = "Raids", Icon = "" }),
    Esp = Window:AddTab({ Title = "Titans Esp", Icon = "" }),
    AutoMission = Window:AddTab({ Title = "Auto Mission" }),
    Modifiers = Window:AddTab({ Title = "Modifiers" }),
    Webhook = Window:AddTab({ Title = "Webhook", Icon = "" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "" })
}


local allowedPlaceId = 13379208636

if game.PlaceId == allowedPlaceId then
	Tabs.Mainmenu = Window:AddTab({ Title = "Mainmenu", Icon = "" })

	Tabs.Mainmenu:AddToggle("AutoRollToggle", {
		Title = "Auto Roll",
		Default = false,
		Callback = function(state)
			ENABLED = state
		end
	})
end


Window:SelectTab(Tabs.Main)



--============[ ⚙️. Settings ]========--

local HttpService = (cloneref(game:GetService('HttpService'))  )
local player = Players.LocalPlayer
local interface = player:WaitForChild("PlayerGui"):WaitForChild("Interface")

local RunService = game:GetService("RunService")
local VirtualInput = game:GetService("VirtualInputManager")

local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local retryRemote = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET")

local TeleportService = game:GetService("TeleportService")

local isFlying = false
local bodyPos

local LocalPlayer = Players.LocalPlayer

local startDelay = 5 -- ستارت ديلاي

local flyHeight = 250 -- الارتفاع للل ts + blades

--//==============================\\--
--||      👑 AUTO KILL TITANS     ||--
--\\==============================//--

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")
local gui = player:WaitForChild("PlayerGui")

local flySpeed = 250
local canHit = true
local isFlying = false
local moveMode = "Teleportation"
local notificationsEnabled = true
local notified = {}
local titanKillCount = 0
local autoRefill = false
local lastBladesEmpty = false
local lastSpearsEmpty = false

-- 🔁 تحميل آمن للـ POST
local POST = nil
task.spawn(function()
	local success, result = pcall(function()
		return ReplicatedStorage:WaitForChild("Assets", 10)
			:WaitForChild("Remotes", 10)
			:WaitForChild("POST", 10)
	end)
	if success then
		POST = result
	end
end)

-- إشعار القتل
local activeNotifs = {}
function showKillNotification(count)
	if not notificationsEnabled then return end

	local gui = Instance.new("ScreenGui")
	gui.Name = "TitanNotif_" .. tick()
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = CoreGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 190, 0, 75)
	frame.Position = UDim2.new(1, 20, 0, 10 + (#activeNotifs * 80))
	frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	frame.BorderSizePixel = 2
	frame.BorderColor3 = Color3.fromRGB(184, 164, 101)
	frame.Parent = gui

	local label = Instance.new("TextLabel", frame)
	label.Size = UDim2.new(0.65, 0, 1, 0)
	label.Position = UDim2.new(0, 5, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = "Succesfully\nHit:"
	label.TextColor3 = Color3.fromRGB(184, 164, 101)
	label.Font = Enum.Font.Fantasy
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center

	local counter = Instance.new("TextLabel", frame)
	counter.Size = UDim2.new(0, 60, 0.5, 0)
	counter.Position = UDim2.new(1, -65, 0, 0)
	counter.BackgroundTransparency = 1
	counter.Text = tostring(count)
	counter.TextColor3 = Color3.fromRGB(255, 255, 255)
	counter.Font = Enum.Font.Fantasy
	counter.TextScaled = true
	counter.TextXAlignment = Enum.TextXAlignment.Right
	counter.TextYAlignment = Enum.TextYAlignment.Bottom

	local big = Instance.new("TextLabel", frame)
	big.Size = UDim2.new(0.6, 0, 0.5, 0)
	big.Position = UDim2.new(1, -115, 0.5, 0)
	big.BackgroundTransparency = 1
	big.Text = "Titans"
	big.TextColor3 = Color3.fromRGB(255, 255, 255)
	big.Font = Enum.Font.Fantasy
	big.TextScaled = true
	big.TextXAlignment = Enum.TextXAlignment.Right
	big.TextYAlignment = Enum.TextYAlignment.Top

	table.insert(activeNotifs, gui)

	TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, -210, 0, 10 + ((#activeNotifs - 1) * 80))
	}):Play()

	task.delay(5, function()
		TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Position = UDim2.new(1, 20, frame.Position.Y.Scale, frame.Position.Y.Offset),
			BackgroundTransparency = 1
		}):Play()
		task.wait(0.4)
		gui:Destroy()

		for i, v in ipairs(activeNotifs) do
			if v == gui then
				table.remove(activeNotifs, i)
				break
			end
		end

		for i, notif in ipairs(activeNotifs) do
			local f = notif:FindFirstChildWhichIsA("Frame")
			if f then
				TweenService:Create(f, TweenInfo.new(0.3), {
					Position = UDim2.new(1, -210, 0, 10 + ((i - 1) * 80))
				}):Play()
			end
		end
	end)
end

-- أقرب نيب صالح
local function getClosestValidNape()
	local titansFolder = workspace:FindFirstChild("Titans")
	
	if not titansFolder then 
		return nil
	end

	local priorityList = { "Attack_Titan", "Female_Titan", "Armored_Titan" }

	for _, titanName in ipairs(priorityList) do
		local titan = titansFolder:FindFirstChild(titanName)
		if titan and titan:FindFirstChild("Humanoid") and titan.Humanoid.Health > 0 then
			local hitbox = titan:FindFirstChild("Hitboxes") and titan.Hitboxes:FindFirstChild("Hit")
			local nape = hitbox and hitbox:FindFirstChild("Nape")
			if nape and nape:IsA("BasePart") then
				return nape
			end
		end
	end

	local closest, dist = nil, math.huge
	for _, titan in ipairs(titansFolder:GetChildren()) do
		if table.find(priorityList, titan.Name) then continue end
		local hitboxes = titan:FindFirstChild("Hitboxes")
		if hitboxes then
			local hit = hitboxes:FindFirstChild("Hit")
			if hit then
				local nape = hit:FindFirstChild("Nape")
				local hum = titan:FindFirstChildWhichIsA("Humanoid")
				if nape and hum and hum.Health > 0 then
					local d = (hrp.Position - nape.Position).Magnitude
					if d < dist then
						closest = nape
						dist = d
					end
				end
			end
		end
	end

	return closest
end

-- ✅ دالة تحاكي الضرر الحقيقي بناءً على السرعة والمسافة
local function getLegitDamage(nape)
	local char = player.Character
	if not char then return 0, 0.25 end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return 0, 0.25 end

	local velocity = hrp.AssemblyLinearVelocity.Magnitude
	local dist = (hrp.Position - nape.Position).Magnitude

	local dmg = math.floor(velocity * 2 + dist / 4)
	dmg = math.clamp(dmg, 200.3913042, 300.302815392)
    -- math.random(200.8028401830, 300.70193049502)

	local accuracy = math.random(20, 30) / 100
	return dmg, accuracy
end

-- ✅ النسخة المعدلة من killFromAbove()
local function killFromAbove()
	task.delay(startDelay, function()
		RunService.Heartbeat:Connect(function()
			if not isFlying or not character or not character:FindFirstChild("HumanoidRootPart") then return end

			local nape = getClosestValidNape()
			if not nape then return end

			local targetPos = nape.Position + Vector3.new(0, flyHeight, 0)

			if moveMode == "Gliding" then
				local direction = (targetPos - hrp.Position).Unit
				hrp.AssemblyLinearVelocity = direction * flySpeed
			else
				hrp.CFrame = CFrame.new(targetPos)
			end

			if (hrp.Position - nape.Position).Magnitude <= 1500 and canHit then
				canHit = false

				coroutine.wrap(function()
					local id = tostring(nape:GetDebugId())
					local hitPos = nape.Position + Vector3.new(0, flyHeight, 0)
					local dist = (nape.Position - hitPos).Magnitude

					-- ✅ نحصل على الدامج والدقة الحقيقية
					local dmg, accuracy = getLegitDamage(nape)

					if POST then
						POST:FireServer("Hitboxes", "Register", nape, dmg, accuracy)
						POST:FireServer("Attacks", "Slash", true)
					end

					if not notified[id] and math.abs(dist - flyHeight) <= 5 then
						notified[id] = true
						titanKillCount += 1
						showKillNotification(titanKillCount)
					end

					task.wait(0.25) -- delay لحماية إضافية
					canHit = true
				end)()
			end
		end)
	end)
end


local function isBladesZero()
	local sets = gui:FindFirstChild("Interface", true)
		and gui.Interface.HUD.Main.Top.Blades:FindFirstChild("Sets", true)
	if sets and sets:IsA("TextLabel") then
		return tonumber(sets.Text:match("^(%d+)") or "0") == 0
	end
	return false
end

local function isSpearsZero()
	local lbl = gui:FindFirstChild("Interface", true)
		and gui.Interface.HUD.Main.Top.Spears:FindFirstChild("Spears", true)
	if lbl and lbl:IsA("TextLabel") then
		return tonumber(lbl.Text:match("^(%d+)") or "0") == 0
	end
	return false
end

local refill = nil
local reloads = workspace:FindFirstChild("Unclimbable")
	and workspace.Unclimbable:FindFirstChild("Reloads")

if reloads then
	for _, obj in ipairs(reloads:GetChildren()) do
		if obj:FindFirstChild("Refill") then
			refill = obj.Refill
			break
		end
	end
end

task.spawn(function()
	while true do
		task.wait(0.1)
		if autoRefill and refill then
			local bladesEmptyNow = isBladesZero()
			local spearsEmptyNow = isSpearsZero()

			if bladesEmptyNow and not lastBladesEmpty and POST then
				POST:FireServer("Attacks", "Reload", refill)
			end
			if spearsEmptyNow and not lastSpearsEmpty and POST then
				POST:FireServer("Attacks", "Reload", refill)
			end

			lastBladesEmpty = bladesEmptyNow
			lastSpearsEmpty = spearsEmptyNow
		end
	end
end)


Tabs.Main:AddToggle("AutoKillTitans", {
	Title = "Auto Kill Titans",
    Description = "Dont Finish the mission under 17 sec",
	Default = false,
	Callback = function(state)
		isFlying = state
		if isFlying then
			task.spawn(killFromAbove)
		end
	end
})

Tabs.Main:AddDropdown("MoveMode", {
	Title = "Movement Mode",
	Values = { "Teleportation", "Gliding" },
	Default = 1,
	Callback = function(option)
		moveMode = option
	end
})

Tabs.Main:AddSlider("StartDelaySlider", {
	Title = "Farm Delay",
    Description = "MINIMUM 20 SECONDS For Thunder Spears / MINIMUM 10 SECONDS For Blades",
	Default = 5,
	Min = 1,
	Max = 50,
	Rounding = 0,
	Callback = function(value)
		startDelay = value
	end
})

Tabs.Main:AddSlider("FlySpeedSlider", {
	Title = "Gliding Speed",
	Default = 300,
	Min = 50,
	Max = 500,
	Rounding = 0,
	Callback = function(value)
		flySpeed = value
	end
})

Tabs.Main:AddSlider("FlyHeightSlider", {
	Title = "Float Height",
	Default = 250,
	Min = 50,
	Max = 300,
	Rounding = 0,
	Callback = function(value)
		flyHeight = value
	end
})


Tabs.Misc:AddToggle("ToggleNotifications", {
	Title = "Notifications",
	Default = false,
	Callback = function(value)
		notificationsEnabled = value
	end
})

--//==============================\\--
--||           👑 AUTO Ts         ||--
--\\==============================//--


local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")
local gui = player:WaitForChild("PlayerGui")

local GET = ReplicatedStorage.Assets.Remotes.GET
local POST = ReplicatedStorage.Assets.Remotes.POST

local isHovering = false
local hoverPos = nil
local autoTSRunning = false
local killMode = "Safe"

local function getCurrentSpearSlot()
	local lbl = gui:FindFirstChild("Interface")
		and gui.Interface:FindFirstChild("HUD")
		and gui.Interface.HUD:FindFirstChild("Main")
		and gui.Interface.HUD.Main:FindFirstChild("Top")
		and gui.Interface.HUD.Main.Top:FindFirstChild("Spears")
		and gui.Interface.HUD.Main.Top.Spears:FindFirstChild("Spears")
	if lbl and lbl:IsA("TextLabel") then
		local current = tonumber(lbl.Text:match("^(%d+)") or "0")
		return tostring(current), current > 0
	end
	return "0", false
end

local function getClosestNapes(limit)
	local priority = { "Female_Titan", "Attack_Titan", "Armored_Titan" }
	local selected = {}

	for _, titan in ipairs(workspace.Titans:GetChildren()) do
		if table.find(priority, titan.Name) then
			local hum = titan:FindFirstChild("Humanoid")
			local hitbox = titan:FindFirstChild("Hitboxes") and titan.Hitboxes:FindFirstChild("Hit")
			local nape = hitbox and hitbox:FindFirstChild("Nape")
			if hum and hum.Health > 0 and nape and nape:IsA("BasePart") then
				for i = 1, limit do
					table.insert(selected, { part = nape, dist = (hrp.Position - nape.Position).Magnitude })
				end
			end
		end
	end

	if #selected > 0 then
		table.sort(selected, function(a, b) return a.dist < b.dist end)
		local out = {}
		for i = 1, math.min(limit, #selected) do
			table.insert(out, selected[i].part)
		end
		return out
	end

	for _, titan in ipairs(workspace.Titans:GetChildren()) do
		if not table.find(priority, titan.Name) then
			local hum = titan:FindFirstChild("Humanoid")
			local hitbox = titan:FindFirstChild("Hitboxes") and titan.Hitboxes:FindFirstChild("Hit")
			local nape = hitbox and hitbox:FindFirstChild("Nape")
			if hum and hum.Health > 0 and nape and nape:IsA("BasePart") then
				table.insert(selected, { part = nape, dist = (hrp.Position - nape.Position).Magnitude })
			end
		end
	end

	table.sort(selected, function(a, b) return a.dist < b.dist end)
	local out = {}
	for i = 1, math.min(limit, #selected) do
		table.insert(out, selected[i].part)
	end
	return out
end

local function teleportAbove(part)
	local targetPos = part.Position + Vector3.new(0, flyHeight, 0)
	local distance = (hrp.Position - targetPos).Magnitude

	if distance > 150 then
		character:PivotTo(CFrame.new(targetPos))
	else
		hrp.CFrame = CFrame.new(targetPos)
	end

	hoverPos = targetPos
	isHovering = true
end

RunService.Heartbeat:Connect(function()
	if isHovering and hoverPos then
		hrp.Velocity = Vector3.zero
		hrp.CFrame = CFrame.new(hoverPos)
	end
end)

local function autoTS_KillLoop()
	local firstRun = true

	while autoTSRunning do
		task.wait(1)

		if workspace:FindFirstChild("Debris") and workspace.Debris:FindFirstChild("Roar") then
			repeat task.wait(0.1) until not workspace.Debris:FindFirstChild("Roar")
		end


		local slot, hasAmmo = getCurrentSpearSlot()
		if hasAmmo then
			local killCount
			if killMode == "Risk" then
				killCount = math.random(10, 25)-- risk mode
			else
				killCount = math.random(3, 10) -- safe mode
			end

			local napes = getClosestNapes(killCount)
			if #napes > 0 then
				teleportAbove(napes[1])

				if firstRun then
					task.wait(startDelay)
					firstRun = false
				end

				GET:InvokeServer("Spears", "S_Fire", slot)

				for _, nape in ipairs(napes) do
					if nape and nape.Position then
						POST:FireServer("Spears", "S_Explode", nape.Position, 0.501303055920385, 450.20495501920485) -- args الافضل مانعدل عليها عشان البان
					end
				end
			end
		end

		if not hoverPos then
			hoverPos = hrp.Position + Vector3.new(0, flyHeight, 0)
		end
		isHovering = true
	end
end



local function findRefill()
	local reloads = workspace:FindFirstChild("Unclimbable")
		and workspace.Unclimbable:FindFirstChild("Reloads")

	if reloads then
		for _, obj in ipairs(reloads:GetChildren()) do
			if obj:FindFirstChild("Refill") then
				return obj.Refill
			end
		end
	end
	return nil
end

local function isBladesZero()
	local sets = gui:FindFirstChild("Interface", true)
		and gui.Interface.HUD.Main.Top.Blades:FindFirstChild("Sets", true)
	if sets and sets:IsA("TextLabel") then
		local text = sets.Text
		if text and text ~= "" then
			local current = tonumber(text:match("(%d+)/%d+"))
			if current then
				return current == 0
			end
		end
	end
	return false
end

local function isSpearsZero()
	local lbl = gui:FindFirstChild("Interface", true)
		and gui.Interface.HUD.Main.Top.Spears:FindFirstChild("Spears", true)
	if lbl and lbl:IsA("TextLabel") then
		local text = lbl.Text
		if text and text ~= "" then
			local current = tonumber(text:match("(%d+)/%d+"))
			if current then
				return current == 0
			end
		end
	end
	return false
end

task.spawn(function()
	repeat task.wait() until POST 

	while true do
		task.wait(0.3)

		if autoRefill then
			local refill = findRefill()
			if not refill then continue end

			local bladesEmptyNow = isBladesZero()
			local spearsEmptyNow = isSpearsZero()

			if bladesEmptyNow and not lastBladesEmpty then
				POST:FireServer("Attacks", "Reload", refill)
				task.wait(0.2)
			end

			if spearsEmptyNow and not lastSpearsEmpty then
				POST:FireServer("Attacks", "Reload", refill)
				task.wait(0.2)
			end

			lastBladesEmpty = bladesEmptyNow
			lastSpearsEmpty = spearsEmptyNow
		end
	end
end)

local function handleAutoTS_Toggle(state)
	autoTSRunning = state
	if state then
		task.spawn(autoTS_KillLoop)
	end
end

Tabs.Ts:AddToggle("AutoTS_Free", {
	Title = "Auto Thunder Spears",
	Default = false,
	Callback = handleAutoTS_Toggle
})


Tabs.Ts:AddDropdown("KillModeDropdown", {
	Title = "Kill Mode",
	Values = {"Safe", "Risk"},
	Multi = false,
	Default = "Safe",
	Callback = function(value)
		killMode = value
	end
})


--//==============================\\--
--||        👑 AUTO Mission       ||--
--\\==============================//--


local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local POST = ReplicatedStorage.Assets.Remotes.POST
local GET = ReplicatedStorage.Assets.Remotes.GET
local Missions = ReplicatedStorage:FindFirstChild("Missions")

getgenv().selectedMap = "Shiganshina"
getgenv().selectedDifficulty = "Hard"
getgenv().selectedObjective = "Skirmish"

local selectedModifiers = {}

local mapOptions = {"Shiganshina", "Trost", "Outskirts", "Giant Forest", "Utgard", "Loading Docks", "Stohess"}
Tabs.AutoMission:AddDropdown("MapDropdown", {
    Title = "Select Map",
    Values = mapOptions,
    Multi = false,
    Default = "Shiganshina",
    Callback = function(value)
        getgenv().selectedMap = value
    end
})

local difficultyOptions = {"Easy", "Normal", "Hard", "Severe", "Aberrant"}
Tabs.AutoMission:AddDropdown("DifficultyDropdown", {
    Title = "Select Difficulty",
    Values = difficultyOptions,
    Multi = false,
    Default = "Hard",
    Callback = function(value)
        getgenv().selectedDifficulty = value
    end
})

local objectiveOptions = {"Skirmish", "Breach", "Protect", "Escort", "Defend", "Stall", "Guard", "Random"}
Tabs.AutoMission:AddDropdown("ObjectiveDropdown", {
    Title = "Select Objective",
    Values = objectiveOptions,
    Multi = false,
    Default = "Skirmish",
    Callback = function(value)
        getgenv().selectedObjective = value
    end
})

local modifierOptions = {
    "No Perks", "No Skills", "No Talents", "Nightmare", "Oddball",
    "Injury Prone", "Chronic Injuries", "Fog", "Glass Cannon",
    "Time Trial", "Boring", "Simple"
}

for _, mod in ipairs(modifierOptions) do
    selectedModifiers[mod] = false
    Tabs.Modifiers:AddToggle("Mod_"..mod, {
        Title = mod,
        Default = false,
        Callback = function(value)
            selectedModifiers[mod] = value
        end
    })
end

Tabs.AutoMission:AddButton({
    Title = "Start Auto Mission",
    Callback = function()
        if not Missions then
            return
        end

        GET:InvokeServer("Missions", "Open")
        task.wait(1.5)

        local activeModifiers = {}
        for _, mod in ipairs(modifierOptions) do
            if selectedModifiers[mod] then
                table.insert(activeModifiers, mod)
            end
        end

        local mapData = {
            Name = getgenv().selectedMap,
            Difficulty = getgenv().selectedDifficulty,
            Type = "Missions",
            Objective = getgenv().selectedObjective
        }

        POST:FireServer("S_Missions", "Create", mapData)

        local isLeader = false
        local timeout = 10
        local elapsed = 0
        local mission = nil

        while elapsed < timeout do
            for _, m in pairs(Missions:GetChildren()) do
                local leader = m:FindFirstChild("Leader")
                if leader and leader.Value == player.Name then
                    mission = m
                    isLeader = true
                    break
                end
            end
            if isLeader then break end
            task.wait(1)
            elapsed += 1
        end

        if isLeader and mission then
            for _, mod in ipairs(activeModifiers) do
                GET:InvokeServer("S_Missions", "Modify", mod)
                task.wait(0.1)
            end

            task.wait(1)
            POST:FireServer("S_Missions", "Start")
        end
    end
})




--//==============================\\--
--||        👑 AUTO Reload        ||--
--\\==============================//--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GET = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local BladeBar = nil

do
    local success, err = pcall(function()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        local interface = playerGui and playerGui:FindFirstChild("Interface")
        local hud = interface and interface:FindFirstChild("HUD")
        local main = hud and hud:FindFirstChild("Main")
        local top = main and main:FindFirstChild("Top")
        local blades = top and top:FindFirstChild("Blades")
        local inner = blades and blades:FindFirstChild("Inner")
        local bar = inner and inner:FindFirstChild("Bar")
        BladeBar = bar and bar:FindFirstChild("Gradient")
    end)
end

local autoReloadRunning = false
local autoReloadThread

Tabs.Main:AddToggle("AutoReload", {
    Title = "Auto Reload Blades",
    Default = false,
    Callback = function(Value)
        if not BladeBar then
            return
        end

        if Value then
            autoReloadRunning = true
            autoReloadThread = task.spawn(function()
                while autoReloadRunning do
                    if BladeBar.Offset == Vector2.new(-0.15, 0) then
                        pcall(function()
                            GET:InvokeServer("Blades", "Reload")
                        end)
                    end
                    task.wait(0.3)
                end
            end)
        else
            autoReloadRunning = false
        end
    end
})




Tabs.Main:AddToggle("AutoRefillToggle", {
	Title = "Auto Refill",
	Default = false,
	Callback = function(state)
		autoRefill = state
	end
})


--//==============================\\--
--||        👑 AUTO Retry         ||--
--\\==============================//--

local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local autoRetryEnabled = false

local function updateNavigation(guiObject: GuiObject | nil)
	GuiService.SelectedObject = guiObject
end

local function pressRetryKey(retryBtn)
	updateNavigation(retryBtn)

	VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)

	task.wait(0.01)
	updateNavigation(nil)
end

local function shouldClickRetry()
	local interface = player:FindFirstChild("PlayerGui")
		and player.PlayerGui:FindFirstChild("Interface")

	local rewards = interface and interface:FindFirstChild("Rewards")
	local rewardsMain = rewards and rewards:FindFirstChild("Main")
	local info = rewardsMain and rewardsMain:FindFirstChild("Info")
	local infoMain = info and info:FindFirstChild("Main")
	local buttons = infoMain and infoMain:FindFirstChild("Buttons")
	local retryBtn = buttons and buttons:FindFirstChild("Retry")

	if retryBtn
		and rewards and rewards.Visible
		and rewardsMain and rewardsMain.Visible
		and retryBtn.Visible
		and retryBtn.AbsoluteSize.Magnitude > 10
	then
		return retryBtn
	end

	return nil
end

task.spawn(function()
	while true do
		if autoRetryEnabled then
			local retryBtn = shouldClickRetry()
			if retryBtn then
				task.wait(1)
				if shouldClickRetry() then
					pressRetryKey(retryBtn)
					task.wait(3.5)
				end
			end
		end
		task.wait(0.5)
	end
end)

local Toggle = Tabs.Main:AddToggle("AutoRetryToggle", {
	Title = "Auto Retry",
	Default = false,
	Callback = function(state)
		autoRetryEnabled = state
	end
})



--//==============================\\--
--||        👑 AUTO Escape        ||--
--\\==============================//--


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = game.Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local POST = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("POST")

local escapeRunning = false
local escapeThread = nil
local cleanGUIThread = nil
local lastEscapeButton = nil

Tabs.Main:AddToggle("Escape", {
    Title = "Auto Escape",
    Default = false,
    Callback = function(Value)
        escapeRunning = Value

        if escapeRunning then
            escapeThread = task.spawn(function()
                while escapeRunning do
                    local interface = gui:FindFirstChild("Interface")
                    local buttons = interface and interface:FindFirstChild("Buttons")

                    if buttons then
                        local currentButtons = buttons:GetChildren()

                        if #currentButtons > 0 then
                            local newestButton = currentButtons[1]

                            if newestButton ~= lastEscapeButton then
                                lastEscapeButton = newestButton

                                POST:FireServer(table.unpack({
                                    "Attacks",
                                    "Slash_Escape"
                                }))
                            end
                        else
                            lastEscapeButton = nil
                        end
                    else
                        lastEscapeButton = nil
                    end

                    task.wait(0.1)
                end
            end)

            cleanGUIThread = task.spawn(function()
                while escapeRunning do
                    local interface = gui:FindFirstChild("Interface")
                    local buttons = interface and interface:FindFirstChild("Buttons")

                    if buttons then
                        for _, btn in pairs(buttons:GetChildren()) do
                            btn:Destroy()
                        end
                    end

                    task.wait(0.1)
                end
            end)
        else
            escapeRunning = false
            lastEscapeButton = nil
        end
    end
})



--//==============================\\--
--||        👑 Delete map         ||--
--\\==============================//--


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local hiddenFolder = ReplicatedStorage:FindFirstChild("aristo_deletemap")
if not hiddenFolder then
    hiddenFolder = Instance.new("Folder")
    hiddenFolder.Name = "aristo_deletemap"
    hiddenFolder.Parent = ReplicatedStorage
end

local Toggle = Tabs.Misc:AddToggle("del", {
    Title = "Delete Map", 
    Default = false,
    Callback = function(state)
        if state then
            -- Climbable
            local climbable = Workspace:FindFirstChild("Climbable")
            if climbable then
                local fakeClimbable = Instance.new("Folder")
                fakeClimbable.Name = "Climbable"
                fakeClimbable.Parent = Workspace

                climbable.Parent = hiddenFolder
            end

            -- Unclimbable
            local unclimbable = Workspace:FindFirstChild("Unclimbable")
            if unclimbable then
                for _, child in ipairs(unclimbable:GetChildren()) do
                    local name = child.Name
                    local shouldKeep = (name == "Reloads" or name == "Objective" or name == "Cutscene")
                    
                    if not shouldKeep and not child:IsA("Terrain") and not (child:IsA("BasePart") and child.Size.Magnitude > 100) then
                        pcall(function()
                            child.Parent = hiddenFolder
                        end)
                    end
                end

                -- تعطيل Collider
                local objective = unclimbable:FindFirstChild("Objective")
                if objective then
                    local guard = objective:FindFirstChild("Guard")
                    if guard then
                        local collider = guard:FindFirstChild("Collider")
                        if collider and collider:IsA("BasePart") then
                            collider.CanTouch = false
                            collider.CanCollide = false
                            collider.Transparency = 1
                        end
                    end
                end
            end

        else
            for _, item in ipairs(hiddenFolder:GetChildren()) do
                if item.Name == "Climbable" then
                    item.Parent = Workspace
                elseif item:IsA("Instance") then
                    item.Parent = Workspace:FindFirstChild("Unclimbable") or Workspace
                end
            end
        end
    end
})



local delaySeconds = 180 -- عدد الثواني قبل تنفيذ Force Retry
local toggleActive = false

Tabs.Misc:AddToggle("ForceRetryToggle", {
    Title = "Fail Safe",
    Default = false,
    Callback = function(state)
        toggleActive = state

        if state then
            task.delay(delaySeconds, function()
                if toggleActive then
                    pcall(function()
                        retryRemote:InvokeServer("Functions", "Retry", "Add")
                    end)
                end
            end)
        end
    end
})


--//==============================\\--
--||         👑 Anti Inj          ||--
--\\==============================//--


local Toggle = Tabs.Misc:AddToggle("injjj", {
    Title = "Anti Injuries",
    Default = false,
    Callback = function(state)
        if state then
            local Players = game:GetService("Players")
            local player = Players.LocalPlayer
            local char = player.Character or player.CharacterAdded:Wait()
            local injuriesFolder = char:WaitForChild("Injuries", 10)

            if not injuriesFolder then
                return
            end

            for _, injury in pairs(injuriesFolder:GetChildren()) do
                injury:Destroy()
            end

            getgenv().AntiInjuryConnection = injuriesFolder.ChildAdded:Connect(function(child)
                task.wait()
                child:Destroy()
            end)

        else
            if getgenv().AntiInjuryConnection then
                getgenv().AntiInjuryConnection:Disconnect()
                getgenv().AntiInjuryConnection = nil
            end
        end
    end
})




--//==============================\\--
--||          👑 dmg txt          ||--
--\\==============================//--


local Players = game:GetService("Players")
local player = Players.LocalPlayer
local interface = player:WaitForChild("PlayerGui"):WaitForChild("Interface")

local damageConnection

local Toggle = Tabs.Misc:AddToggle("dmg", 
{
    Title = "Remove Dmg Text", 
    Default = false,
    Callback = function(state)
        if state then

            for _, obj in pairs(interface:GetDescendants()) do
                if obj:IsA("TextLabel") and obj.Name == "Number" then
                    obj.Visible = false
                end
            end


            damageConnection = interface.DescendantAdded:Connect(function(obj)
                if obj:IsA("TextLabel") and obj.Name == "Number" then
                    obj.Visible = false
                end
            end)
        else

            if damageConnection then
                damageConnection:Disconnect()
                damageConnection = nil
            end
        end
    end 
})


--//==============================\\--
--||       👑 Main + Lobby        ||--
--\\==============================//--


-- PlaceIds
local lobbyPlaceId = 14916516914
local mainMenuPlaceId = 13379208636

-- زر الانتقال إلى الـ Lobby
Tabs.Misc:AddButton({
    Title = "Return to Lobby",
    Callback = function()
        TeleportService:Teleport(lobbyPlaceId, player)
    end
})

-- زر الانتقال إلى الـ Main Menu
Tabs.Misc:AddButton({
    Title = "Return to Main Menu",
    Callback = function()
        TeleportService:Teleport(mainMenuPlaceId, player)
    end
})

Tabs.Misc:AddButton({
    Title = "Force Retry",
    Callback = function()
        pcall(function()
            retryRemote:InvokeServer("Functions", "Retry", "Add")
        end)
    end,
})

--//==============================\\--
--||        👑 Nape extend        ||--
--\\==============================//--


local newSize = Vector3.new(1500, 1500, 1500)
local connection 

local function resizeNapes()
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and v.Name == "Nape" then
            v.Size = newSize
            local cf = v.CFrame
            v.CFrame = cf
        end
    end
end

local Toggle = Tabs.Main:AddToggle("nape", {
    Title = "Nape extend",
    Default = false,
    Callback = function(state)
        if state then
            resizeNapes()
            connection = workspace.DescendantAdded:Connect(function(desc)
                if desc:IsA("BasePart") and desc.Name == "Nape" then
                    task.wait(0.1)
                    desc.Size = newSize
                    local cf = desc.CFrame
                    desc.CFrame = cf
                end
            end)
        else
            if connection then
                connection:Disconnect()
                connection = nil
            end
        end
    end
})


--//==============================\\--
--||         👑 Auto Roll         ||--
--\\==============================//--



-- Auto Roll Script for Roblox

local VIM = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local Gui = player:WaitForChild("PlayerGui")

-- إعدادات السكربت
local CLICK_DELAY = 0.2  -- التأخير بين الضغطات
local WAIT_DELAY = 1     -- التأخير عند غياب الزر
local ENABLED = false    -- التفعيل يتم عن طريق التوقل

-- دالة للتحقق من إمكانية الضغط على الزرار
local function canClick(btn)
	return btn and btn.Visible and btn.AbsoluteSize.Magnitude > 10
end

-- دالة للتحقق من أن العنصر مرئي فعلياً
local function isActuallyVisible(obj)
	if not obj then return false end
	local current = obj
	while current and current ~= Gui do
		local success, result = pcall(function()
			return current.Visible
		end)
		if success and not result then
			return false
		end
		current = current.Parent
	end
	return obj.AbsoluteSize.Magnitude > 10
end

-- دالة للضغط على الزر
local function clickButton(btn)
	if not btn then return false end
	local pos = btn.AbsolutePosition
	local size = btn.AbsoluteSize
	local inset = GuiService:GetGuiInset()
	local x = pos.X + size.X / 2
	local y = pos.Y + size.Y / 2 + inset.Y

	VIM:SendMouseMoveEvent(x, y, game)
	task.wait(0.05)
	VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
	task.wait(0.05)
	VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)

	return true
end

-- دالة للبحث عن الزرار بالاسم
local function findButton(parent, buttonName)
	if not parent then return nil end
	local function searchRecursive(obj)
		if obj.Name == buttonName and obj:IsA("GuiButton") then
			return obj
		end
		for _, child in pairs(obj:GetChildren()) do
			local result = searchRecursive(child)
			if result then return result end
		end
		return nil
	end
	return searchRecursive(parent)
end

-- دالة للبحث عن الزر بالنص
local function findButtonByText(parent, text)
	if not parent then return nil end
	local function searchRecursive(obj)
		if obj:IsA("GuiButton") or obj:IsA("TextButton") then
			local hasText = obj:FindFirstChild("Text") or obj.Text
			if hasText and string.find(string.lower(tostring(hasText)), string.lower(text)) then
				return obj
			end
		end
		for _, child in pairs(obj:GetChildren()) do
			local result = searchRecursive(child)
			if result then return result end
		end
		return nil
	end
	return searchRecursive(parent)
end

-- الحلقة الرئيسية للضغط التلقائي
task.spawn(function()
	local interface = Gui:WaitForChild("Interface", 10)
	if not interface then return end

	local rollButton = nil
	local searchPaths = {
		"Customisation.Family.Buttons_2.Roll",
		"Roll",
		"RollButton"
	}

	for _, path in pairs(searchPaths) do
		local pathParts = string.split(path, ".")
		local current = interface
		for _, part in pairs(pathParts) do
			if current then
				current = current:FindFirstChild(part)
			end
		end
		if current and current:IsA("GuiButton") then
			rollButton = current
			break
		end
	end

	if not rollButton then
		rollButton = findButton(interface, "Roll")
	end
	if not rollButton then
		rollButton = findButtonByText(interface, "roll")
	end
	if not rollButton then
		return
	end

	while true do
		if ENABLED then
			if canClick(rollButton) and isActuallyVisible(rollButton) then
				clickButton(rollButton)
				task.wait(CLICK_DELAY)
			else
				task.wait(WAIT_DELAY)
			end
		else
			task.wait(1)
		end
	end
end)

--//==============================\\--
--||            👑 ESP            ||--
--\\==============================//--


-- متغيرات التحكم
local ESPEnabled = false
local ESPColor = Color3.fromRGB(96, 205, 255)
local ESPSize = Vector3.new(50, 50, 50)

-- دالة إنشاء ESP على النيب
local function createNapeESP(nape)
    if not nape:FindFirstChild("NapeESP") then
        local esp = Instance.new("BoxHandleAdornment")
        esp.Name = "NapeESP"
        esp.Adornee = nape
        esp.AlwaysOnTop = true
        esp.ZIndex = 5
        esp.Size = ESPSize
        esp.Transparency = 0.5
        esp.Color3 = ESPColor
        esp.Parent = nape
    end
end

local function applyNapeESP()
    local titansFolder = workspace:FindFirstChild("Titans")
    if not titansFolder then
        return
    end

    for _, titan in ipairs(titansFolder:GetChildren()) do
        local hitboxes = titan:FindFirstChild("Hitboxes")
        if hitboxes then
            local hit = hitboxes:FindFirstChild("Hit")
            if hit then
                local nape = hit:FindFirstChild("Nape")
                if nape and nape:IsA("BasePart") then
                    createNapeESP(nape)
                end
            end
        end
    end
end

local function removeAllNapeESP()
    local titansFolder = workspace:FindFirstChild("Titans")
    if not titansFolder then
        return
    end

    for _, titan in ipairs(titansFolder:GetChildren()) do
        local hitboxes = titan:FindFirstChild("Hitboxes")
        if hitboxes then
            local hit = hitboxes:FindFirstChild("Hit")
            if hit then
                local nape = hit:FindFirstChild("Nape")
                if nape and nape:FindFirstChild("NapeESP") then
                    nape.NapeESP:Destroy()
                end
            end
        end
    end
end

-- تحديث اللون الحالي
local function updateNapeESPColor()
    local titansFolder = workspace:FindFirstChild("Titans")
    if not titansFolder then
        return
    end

    for _, titan in ipairs(titansFolder:GetChildren()) do
        local hitboxes = titan:FindFirstChild("Hitboxes")
        if hitboxes then
            local hit = hitboxes:FindFirstChild("Hit")
            if hit then
                local nape = hit:FindFirstChild("Nape")
                if nape then
                    local esp = nape:FindFirstChild("NapeESP")
                    if esp then
                        esp.Color3 = ESPColor
                    end
                end
            end
        end
    end
end

-- دعم العمالقة الجدد تلقائيًا
local titansFolder = workspace:FindFirstChild("Titans")

if titansFolder then
    titansFolder.ChildAdded:Connect(function(titan)
        if not ESPEnabled then return end
        task.wait(0.5)
        local hitboxes = titan:FindFirstChild("Hitboxes")
        if hitboxes then
            local hit = hitboxes:FindFirstChild("Hit")
            if hit then
                local nape = hit:FindFirstChild("Nape")
                if nape then
                    createNapeESP(nape)
                end
            end
        end
    end)
end

Tabs.Esp:AddToggle("NapeESP", {
    Title = "Enable Nape ESP",
    Default = false,
    Callback = function(value)
        ESPEnabled = value
        if value then
            applyNapeESP()
        else
            removeAllNapeESP()
        end
    end
})

local Colorpicker = Tabs.Esp:AddColorpicker("ESPColorPicker", {
    Title = "ESP Color",
    Default = ESPColor
})

Colorpicker:OnChanged(function(newColor)
    ESPColor = newColor
    updateNapeESPColor()
end)

Colorpicker:SetValueRGB(Color3.fromRGB(96, 205, 255))



--//==============================\\--
--||           👑 Raids           ||--
--\\==============================//--



--============[ 1. Auto Skip Cutscene ]============--

local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local interface = player:FindFirstChild("PlayerGui")
    and player.PlayerGui:FindFirstChild("Interface")

local skipBtn = interface and interface:FindFirstChild("Skip")

local autoSkipEnabled = false

local function updateNavigation(guiObject: GuiObject | nil)
    GuiService.SelectedObject = guiObject
end

local function shouldClickSkip()
	return skipBtn
		and skipBtn.Visible
		and skipBtn.AbsoluteSize.Magnitude > 10
end

local function pressSkipKey()
    updateNavigation(skipBtn)

    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)

    task.wait(0.01)
    updateNavigation(nil)
end

task.spawn(function()
	while true do
		if autoSkipEnabled and shouldClickSkip() then
			pressSkipKey()
			task.wait(1) -- تقلل الانتظار عشان يضغط بسرعة
		end
		task.wait(0.5)
	end
end)

local Toggle = Tabs.Raids:AddToggle("AutoSkipCutscene", {
    Title = "Auto Skip Cutscene",
    Default = false,
    Callback = function(state)
        autoSkipEnabled = state
    end
})


--============[ 1. Auto Open Chests ]============--


local VIM = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local player = game.Players.LocalPlayer
local Gui = player:WaitForChild("PlayerGui")

-- تحكم التوقلات
local autoFreeEnabled = false
local autoPremiumEnabled = false

local function canClick(btn)
	return btn and btn.Visible and btn.AbsoluteSize.Magnitude > 10
end

local function isActuallyVisible(obj)
	if not obj then return false end
	local current = obj
	while current and current ~= Gui do
		local success, result = pcall(function() return current.Visible end)
		if success and not result then
			return false
		end
		current = current.Parent
	end
	return obj.AbsoluteSize.Magnitude > 10
end

local function clickButton(btn)
	local pos = btn.AbsolutePosition
	local size = btn.AbsoluteSize
	local inset = GuiService:GetGuiInset()

	local x = pos.X + size.X / 2
	local y = pos.Y + size.Y / 2 + inset.Y

	VIM:SendMouseMoveEvent(x, y, game)
	task.wait(0.05)
	VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
	task.wait(0.05)
	VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

-- 🔁 Auto Free Chest
task.spawn(function()
	local interface = Gui:WaitForChild("Interface")
	local chests = interface:WaitForChild("Chests")
	local freeBtn = chests:WaitForChild("Free")
	local finishBtn = chests:WaitForChild("Finish")

	while true do
		if autoFreeEnabled and isActuallyVisible(finishBtn) then
			if canClick(freeBtn) then
				clickButton(freeBtn)
				task.wait(7)
			end
			if canClick(finishBtn) then
				clickButton(finishBtn)
				task.wait(2)
			end
			while isActuallyVisible(finishBtn) do
				task.wait(1)
			end
		else
			task.wait(1)
		end
	end
end)

-- 🔁 Auto Premium Chest
task.spawn(function()
	local interface = Gui:WaitForChild("Interface")
	local chests = interface:WaitForChild("Chests")
	local premiumBtn = chests:WaitForChild("Premium")
	local finishBtn = chests:WaitForChild("Finish")

	while true do
		if autoPremiumEnabled and isActuallyVisible(finishBtn) then
			if canClick(premiumBtn) then
				clickButton(premiumBtn)
				task.wait(7)
			end
			if canClick(finishBtn) then
				clickButton(finishBtn)
				task.wait(2)
			end
			while isActuallyVisible(finishBtn) do
				task.wait(1)
			end
		else
			task.wait(1)
		end
	end
end)


Tabs.Raids:AddToggle("AutoPremiumChest", {
	Title = "Auto Premium Chest",
	Default = false,
	Callback = function(state)
		autoPremiumEnabled = state
	end
})


-- ✅ التوقلين باستخدام Fluent UI
Tabs.Raids:AddToggle("AutoFreeChest", {
	Title = "Auto Free Chest",
	Default = false,
	Callback = function(state)
		autoFreeEnabled = state
	end
})


--//==============================\\--
--||           👑 Webhook         ||--
--\\==============================//--

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local webhookURL = ""
local sendWebhook = false
local showUsername = false
local thumbnailURL = "https://media.discordapp.net/attachments/1375563869367435344/1382238069121482893/g2XBB0B.png?ex=684a6d04&is=68491b84&hm=43c78606310dd13f2241727ad200be03226aba7328ba3fc233f84cde2f246048&=&format=webp&quality=lossless&width=968&height=968"


local function formatWithCommas(number)
    number = tonumber(number)
    if not number then return "0" end
    local formatted = tostring(number)
    local k
    while true do  
        formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

-- ✅ UI Toggles
Tabs.Webhook:AddToggle("SendWebhookToggle", {
    Title = "Notify Webhook",
    Default = false,
    Callback = function(Value) sendWebhook = Value end
})

Tabs.Webhook:AddToggle("DisplayUsernameToggle", {
    Title = "Display Roblox Username",
    Default = false,
    Callback = function(Value) showUsername = Value end
})

Tabs.Webhook:AddInput("WebhookInput", {
    Title = "Webhook",
    Placeholder = "https://discord.com/api/webhooks/...",
    Finished = true,
    Callback = function(Value) webhookURL = Value end
})

-- ✅ التحقق من ظهور الزر فعليًا
local function isActuallyVisible(instance)
    if not instance or not instance:IsDescendantOf(player.PlayerGui) then return false end
    while instance and instance ~= player.PlayerGui do
        if instance:IsA("GuiObject") and not instance.Visible then return false end
        instance = instance.Parent
    end
    return true
end

-- ✅ جلب زر Retry
local function getRetryButton()
    local gui = player:FindFirstChild("PlayerGui")
    return gui and gui:FindFirstChild("Interface")
        and gui.Interface:FindFirstChild("Rewards")
        and gui.Interface.Rewards:FindFirstChild("Main")
        and gui.Interface.Rewards.Main:FindFirstChild("Info")
        and gui.Interface.Rewards.Main.Info:FindFirstChild("Main")
        and gui.Interface.Rewards.Main.Info.Main:FindFirstChild("Buttons")
        and gui.Interface.Rewards.Main.Info.Main.Buttons:FindFirstChild("Retry")
end

-- ✅ جلب قيمة نص معين
local function getText(path)
    local node = player:FindFirstChild("PlayerGui")
    for _, part in ipairs(string.split(path, ".")) do
        if not node then return "0" end
        node = node:FindFirstChild(part)
    end
    return node and node.Text or "0"
end

local aliasMap = {
    Serum = { "Attack Serum", "Armored Serum", "Female Serum" },
}

local function getDropQuantity(dropName)
    local base = player:FindFirstChild("PlayerGui")
    base = base and base:FindFirstChild("Interface")
    base = base and base:FindFirstChild("Rewards")
    base = base and base:FindFirstChild("Main")
    base = base and base:FindFirstChild("Info")
    base = base and base:FindFirstChild("Main")
    base = base and base:FindFirstChild("Items")

    local total = 0
    if base then
        local names = aliasMap[dropName] or { dropName }

        for _, name in ipairs(names) do
            for _, drop in ipairs(base:GetChildren()) do
                if drop.Name == name then
                    for _, sub in pairs(drop:GetDescendants()) do
                        if sub:IsA("TextLabel") then
                            local raw = sub.Text:match("[%d,.]+")
                            if raw then
                                raw = raw:gsub(",", "")
                                local number = tonumber(raw)
                                if number then
                                    total += number
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return tostring(total)
end

-- ✅ Main loop
local lastMissionTime = nil
task.spawn(function()
    while true do
        local retryBtn = getRetryButton()
        if isActuallyVisible(retryBtn) and sendWebhook and webhookURL ~= "" then
            local currentTime = getText("Interface.Rewards.Main.Info.Main.Stats.Time_Taken.Amount")
            if currentTime ~= "0" and currentTime ~= lastMissionTime then
                lastMissionTime = currentTime

                local gold = getDropQuantity("Gold")
                local xp = getDropQuantity("XP")
                local bp_xp = getDropQuantity("BP_XP")
                local gems = getDropQuantity("Gems")
                local serum = getDropQuantity("Serum")
                local scarf = getDropQuantity("Scarf")
                local common = getDropQuantity("Common_Perk")
                local rare = getDropQuantity("Rare_Perk")
                local epic = getDropQuantity("Epic_Perk")
                local leg = getDropQuantity("Legendary_Perk")
                local prestige = getDropQuantity("Prestige_Scroll")
                local mythical = getDropQuantity("Secret_Perk")

                local damage = getText("Interface.Rewards.Main.Info.Main.Stats.Damage_Dealt.Amount")
                local kills = getText("Interface.Rewards.Main.Info.Main.Stats.Titans_Killed.Amount")
                local crits = getText("Interface.Rewards.Main.Info.Main.Stats.Critical_Hits.Amount")

                local timeString = os.date("%d-%b-%Y %I:%M %p")

                local fields = {
                    {name = "**User:**", value = tostring(showUsername and player.Name or "Disabled"), inline = false},
                    {name = "**Stats:**", value = string.format(
                        "%s Time Taken\n%s Damage Dealt\n%s Titan Kills\n%s Critical Hits",
                        currentTime, formatWithCommas(damage:gsub(",", "")), kills, crits
                    ), inline = true},
                    {name = "**Rewards:**", value = string.format(
                        "%s Gold\n%s XP\n%s Gems",
                        formatWithCommas(gold), formatWithCommas(xp), formatWithCommas(gems)
                    ), inline = true},
                    {name = "**Drops:**", value = string.format(
                        "Battle Bass XP: %s\nCommon Perks: %s\nRare Perks: %s\nEpic Perks: %s\nLegendary Perks: %s\nPrestige Scroll: %s",
                        formatWithCommas(bp_xp), formatWithCommas(common), formatWithCommas(rare),
                        formatWithCommas(epic), formatWithCommas(leg), formatWithCommas(prestige)
                    ), inline = true},
                    {name = "**Special Rewards:**", value = string.format(
                        "Serum: %s\nMythical Perk: %s\nScarf: %s",
                        formatWithCommas(serum), formatWithCommas(mythical), formatWithCommas(scarf)
                    ), inline = false}
                }

                local embed = {
                    title = "AOT:R Rewards Logger",
                    thumbnail = { url = thumbnailURL },
                    fields = fields,
                    footer = { text = "Sent at: " .. timeString }
                }

                local data = {
                    content = ((tonumber(serum) or 0) > 0 or (tonumber(mythical) or 0) > 0 or (tonumber(scarf) or 0) > 0) and "@everyone" or nil,
                    embeds = {embed}
                }

                request({
                    Url = webhookURL,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = HttpService:JSONEncode(data)
                })
            end
        end
        task.wait(1)
    end
end)



--//==============================\\--
--||       👑  Titan Ripper       ||--
--\\==============================//--


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Event = ReplicatedStorage.Assets.Remotes.GET

local SkillData
local success, result = pcall(function()
    return ReplicatedStorage:WaitForChild("Modules", 5)
        :WaitForChild("Storage", 5)
        :WaitForChild("Skill", 5)
end)

if success and result then
    SkillData = require(result)
else
    SkillData = {}
end

local autoSkillEnabled = false

local skills = {
    ["14"] = { lastUsed = 0, initialDelay = 0 },
    ["23"] = { lastUsed = 0, initialDelay = 0.4 }
}

for skillID, info in pairs(skills) do
    task.spawn(function()
        task.wait(info.initialDelay)
        while true do
            task.wait(0.1)
            if autoSkillEnabled then
                local now = tick()
                local skillInfo = typeof(SkillData) == "table" and SkillData[skillID]

                if skillInfo and skillInfo.Cooldown then
                    if now - info.lastUsed >= skillInfo.Cooldown then
                        local success = pcall(function()
                            Event:InvokeServer("S_Skills", "Usage", skillID, false)
                        end)
                        if success then
                            info.lastUsed = tick()
                        end
                    end
                end
            end
        end
    end)
end

Tabs.Main:AddToggle("AutoSkillNapeToggle", {
    Title = "Titan Ripper",
    Default = false,
    Callback = function(state)
        autoSkillEnabled = state

        if state then
            for _, info in pairs(skills) do
                info.lastUsed = 0
                info.initialDelayDone = false
            end

            resizeNapes()
            connection = workspace.DescendantAdded:Connect(function(desc)
                if desc:IsA("BasePart") and desc.Name == "Nape" then
                    task.wait(0.1)
                    desc.Size = newSize
                    desc.CFrame = desc.CFrame
                end
            end)
        else
            if connection then
                connection:Disconnect()
                connection = nil
            end
        end
    end
})

local newSize = Vector3.new(1500, 1500, 1500)
local connection

local function resizeNapes()
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and v.Name == "Nape" then
            v.Size = newSize
            v.CFrame = v.CFrame
        end
    end
end




SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
SaveManager:LoadAutoloadConfig()
