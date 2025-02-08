if game.PlaceId == 2753915549 then
        World1 = true
    elseif game.PlaceId == 4442272183 then
        World2 = true
    elseif game.PlaceId == 7449423635 then
        World3 = true
    end
function CheckLevel()
       local Lv = game:GetService("Players").LocalPlayer.Data.Level.Value
       if Old_World then
            if Lv == 1 or Lv <=9 then
                Ms = "Bandit"
                NameQuest = "BanditQuest"
                QuestLv = 1
                CFrameQ = CFrame.new(1064.86487, 12.1020861, 1537.29382, 0.358377755, 0, 0.933576643, 0, 1, 0, -0.933576643, 0, 0.358377755)
                CFrameMon = CFrame.new(1103.56787, 14.9715738, 1588.93726, -0.769942164, 0, -0.638113678, 0, 1, 0, 0.638113678, 0, -0.769942164)
            elseif Lv == 10 or Lv <= 14 then
                Ms = "Monkey"
                NameQuest = "JungleQuest"
                QuestLv = 1
                CFrameQ = CFrame.new(-1598.08911, 35.5501175, 153.377838, 0, 0, 1, 0, 1, -0, -1, 0, 0)
                CFrameMon = CFrame.new(-1448.51806640625, 67.85301208496094, 11.46579647064209)
            elseif Lv == 15 or Lv <= 29 then
                Ms = "Gorilla"
                NameQuest = "JungleQuest"
                QuestLv = 2
                CFrameQ = CFrame.new(-1598.08911, 35.5501175, 153.377838, 0, 0, 1, 0, 1, -0, -1, 0, 0)
                CFrameMon = CFrame.new(-1129.8836669921875, 40.46354675292969, -525.4237060546875)
             end
          end
        end
---บินฟาร์ม--
function Hop()
	local PlaceID = game.PlaceId
	local AllIDs = {}
	local foundAnything = ""
	local actualHour = os.date("!*t").hour
	local Deleted = false
	function TPReturner()
		local Site;
		if foundAnything == "" then
			Site = game.HttpService:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Asc&limit=100'))
		else
			Site = game.HttpService:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Asc&limit=100&cursor=' .. foundAnything))
		end
		local ID = ""
		if Site.nextPageCursor and Site.nextPageCursor ~= "null" and Site.nextPageCursor ~= nil then
			foundAnything = Site.nextPageCursor
		end
		local num = 0;
		for i,v in pairs(Site.data) do
			local Possible = true
			ID = tostring(v.id)
			if tonumber(v.maxPlayers) > tonumber(v.playing) then
				for _,Existing in pairs(AllIDs) do
					if num ~= 0 then
						if ID == tostring(Existing) then
							Possible = false
						end
					else
						if tonumber(actualHour) ~= tonumber(Existing) then
							local delFile = pcall(function()
								AllIDs = {}
								table.insert(AllIDs, actualHour)
							end)
						end
					end
					num = num + 1
				end
				if Possible == true then
					table.insert(AllIDs, ID)
					wait()
					pcall(function()
						wait()
						game:GetService("TeleportService"):TeleportToPlaceInstance(PlaceID, ID, game.Players.LocalPlayer)
					end)
					wait(4)
				end
			end
		end
	end
	function Teleport() 
		while wait() do
			pcall(function()
				TPReturner()
				if foundAnything ~= "" then
					TPReturner()
				end
			end)
		end
	end
	local Hello = instance.new("Messange",workspace)
	Hello.Text = " "
	wait(.53)
	Teleport()
end
function TP(Pos)
	Distance = (Pos.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
	if _G.bypt and Distance > 1200 then
		tween:Cancel()
		wait(.1)
		game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(111111,111111,111111)
		wait()
		game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = Pos
		wait()
		game.Players.LocalPlayer.Character.Head:Destroy()
		wait()
		game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = Pos
		wait()
		local args = {
			[1] = "SetSpawnPoint"
		}
		
		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
		wait()
		game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = Pos
		
		wait()
		local args = {
			[1] = "SetSpawnPoint"
		}
		
		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
		wait(0.1)
		game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = Pos
		wait()
		local args = {
			[1] = "SetSpawnPoint"
		}
		
		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
		wait()
		game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(111111,111111,111111)
		wait()
		game.Players.LocalPlayer.Character.Head:Destroy()
		game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(99999999,99999999,99999999)
		wait()
		local args = {
			[1] = "SetLastSpawnPoint",
			[2] = tostring(game:GetService("Players").LocalPlayer.Data.SpawnPoint.Value)
		}
		
		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
		wait()
		game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = Pos
		wait()
		local args = {
			[1] = "SetSpawnPoint"
		}
		
		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
		wait()
		game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(99999999,99999999,99999999)
		wait()
		game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(99999999,99999999,99999999)
		wait()
		local args = {
			[1] = "SetLastSpawnPoint",
			[2] = tostring(game:GetService("Players").LocalPlayer.Data.SpawnPoint.Value)
		}
		
		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
		wait()
		local args = {
			[1] = "SetLastSpawnPoint",
			[2] = tostring(game:GetService("Players").LocalPlayer.Data.SpawnPoint.Value)
		}
		
		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
		wait(0.5)
		local args = {
			[1] = "SetLastSpawnPoint",
			[2] = tostring(game:GetService("Players").LocalPlayer.Data.SpawnPoint.Value)
		}
		
		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
		wait()
		wait()
		game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = Pos
		wait()
		game.Players.LocalPlayer.Character.Head:Destroy()
		wait()
		game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = Pos
		wait()
	else
    Distance = (Pos.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
    if game.Players.LocalPlayer.Character.Humanoid.Sit == true then game.Players.LocalPlayer.Character.Humanoid.Sit = false end
    pcall(function() tween = game:GetService("TweenService"):Create(game.Players.LocalPlayer.Character.HumanoidRootPart,TweenInfo.new(Distance/190, Enum.EasingStyle.Linear),{CFrame = Pos}) end)
	pcall(function()
    tween:Play()
	end)
    if Distance <= 250 then
        tween:Cancel()
        task.wait(0.3)
        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = Pos
    end
end
end
function EquipTools(Hello)
	pcall(function()
		if game.Players.LocalPlayer.Backpack:FindFirstChild(Hello) then 
			local Found = game.Players.LocalPlayer.Backpack:FindFirstChild(Hello) 
			game.Players.LocalPlayer.Character.Humanoid:EquipTool(Found) 
		end
	end)
end

function UnEquipTool(Tool)
    pcall(function()
    game.Players.LocalPlayer.Character.Humanoid:UnequipTools(game.Players.LocalPlayer.Backpack[Tool])
    end)
end

Buso = function()
    if not game:GetService("Players").LocalPlayer.Character:FindFirstChild("HasBuso") then
        game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Buso")
    end
end

do
    local pussy = workspace:FindFirstChild("Hee")
    if pussy then
        pussy:Destroy()
    end
end

local helloguy = Instance.new("Part",workspace)
helloguy.Size = Vector3.new(30,5,30)
helloguy.Name = "Hee"
helloguy.Transparency = 1
helloguy.CanCollide = true
helloguy.Anchored = true

spawn(function()
    pcall(function()
        while task.wait() do
            if _G.AutoFarm or _G.AutoFarmBone or _G.AutoHallowEssence  or _G.AutoChest or _G.FarmQuestBoss or _G.FarmBoss or _G.FarmAllBoss or _G.AutoFarmCakePrince or _G.EliteHunter or _G.Start_Tween_Island or _G.Tweenfruit or _G.AutoFarmDungeon or _G.NextIsland or  _G.Awakening or _G.Auto_Complete_Trial or _G.AutoGhostShip then
                helloguy.CFrame = game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0,-5,0)
            end
        end
    end)
end)

spawn(function()
	pcall(function()
		while wait() do
			if _G.AutoFarm or _G.AutoFarmBone or _G.AutoHallowEssence  or _G.AutoChest or _G.FarmQuestBoss or _G.FarmBoss or _G.FarmAllBoss or _G.AutoFarmCakePrince or _G.EliteHunter or _G.Start_Tween_Island or _G.Tweenfruit or _G.AutoFarmDungeon or _G.NextIsland or  _G.Awakening or _G.Auto_Complete_Trial or _G.AutoGhostShip then
				if not game:GetService("Players").LocalPlayer.Character.HumanoidRootPart:FindFirstChild("BodyClip") then
					local Noclip = Instance.new("BodyVelocity")
					Noclip.Name = "BodyClip"
					Noclip.Parent = game:GetService("Players").LocalPlayer.Character.HumanoidRootPart
					Noclip.MaxForce = Vector3.new(100000,100000,100000)
					Noclip.Velocity = Vector3.new(0,0,0)
				end
            else
                if game:GetService("Players").LocalPlayer.Character.HumanoidRootPart:FindFirstChild("BodyClip") then
                    game:GetService("Players").LocalPlayer.Character.HumanoidRootPart:FindFirstChild("BodyClip"):Destroy()
                end
			end
		end
	end)
end)

spawn(function()
    while game:GetService("RunService").Stepped:wait() do
		pcall(function()
        	if _G.AutoFarm or _G.AutoFarmBone or _G.AutoHallowEssence or _G.AutoChest or _G.FarmQuestBoss or _G.FarmBoss or _G.FarmAllBoss or _G.AutoFarmCakePrince or _G.EliteHunter or _G.Start_Tween_Island or _G.Tweenfruit or _G.AutoFarmDungeon or _G.NextIsland or  _G.Awakening or _G.Auto_Complete_Trial or _G.AutoGhostShip then
				local character = game.Players.LocalPlayer.Character
				for _, v in pairs(character:GetChildren()) do
					if v:IsA("BasePart") then
						v.CanCollide = false
					end
				end
			end
        end)
    end
end)

function StopTween(target)
	if not target then
		tween:Cancel()
		if game:GetService("Players").LocalPlayer.Character.HumanoidRootPart:FindFirstChild("BodyClip") then
			game:GetService("Players").LocalPlayer.Character.HumanoidRootPart:FindFirstChild("BodyClip"):Destroy()
		end
		wait(0.2)
	end
end
--------
_G.AutoFarm = true
StopTween(_G.AutoFarm)
---------
spawn(function()
    while wait() do
        if _G.AutoFarm then
            pcall(function()
                CheckLevel()
                if not string.find(game:GetService("Players").LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text, NameMon) then
                    hitler = false
                    game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("AbandonQuest")
                end  
                if game:GetService("Players").LocalPlayer.PlayerGui.Main.Quest.Visible == false then
                    repeat wait() TP(CFrameQ) until (CFrameQ.Position - game:GetService("Players").LocalPlayer.Character.HumanoidRootPart.Position).Magnitude <= 3 or not _G.AutoFarm
                    if (CFrameQ.Position - game:GetService("Players").LocalPlayer.Character.HumanoidRootPart.Position).Magnitude <= 3 then
                        game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("StartQuest",NameQuest,QuestLv)
                    end
                elseif game:GetService("Players").LocalPlayer.PlayerGui.Main.Quest.Visible == true then
                    CheckLevel()
					TP(CFrameMon)
                    if game:GetService("Workspace").Enemies:FindFirstChild(Ms) then
                        for i,v in pairs(game:GetService("Workspace").Enemies:GetChildren()) do
                            if v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                                if v.Name == Ms then
                                    if string.find(game:GetService("Players").LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text, NameMon) then
                                        repeat task.wait()
                                            EquipTools(_G.SelectWeapon)
                                            Buso()                                            
                                            PosMon = v.HumanoidRootPart.CFrame
                                            OldPos = game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame
                                            v.HumanoidRootPart.CanCollide = false
                                            v.Humanoid.WalkSpeed = 0
                                            v.Head.CanCollide = false
											hitler = true
                                            TP(v.HumanoidRootPart.CFrame * CFrame.new(0,20,3))
											game:GetService("VirtualUser"):CaptureController()
											game:GetService("VirtualUser"):Button1Down(Vector2.new(1280, 670),workspace.CurrentCamera.CFrame)
                                        until not _G.AutoFarm or v.Humanoid.Health <= 0 or not v.Parent or game:GetService("Players").LocalPlayer.PlayerGui.Main.Quest.Visible == false
                                    else
                                        game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("AbandonQuest")
                                    end
                                end
                            end
                        end
                    else
						hitler = false
                        if game:GetService("ReplicatedStorage"):FindFirstChild(Ms) then
                            TP(game:GetService("ReplicatedStorage"):FindFirstChild(Ms).HumanoidRootPart.CFrame * F)
						else
							hitler = false
							if (CFrameQ.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude <= 15 then
                                if PosMon ~= nil then
								    TP(PosMon)
                                else
                                    if OldPos ~= nil then
                                        TP(OldPos.Position)
                                    end
                                end
							end
                        end
                    end
                end
            end)
        end
    end
end)
