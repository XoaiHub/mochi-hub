local players_service = cloneref(game:GetService("Players"))
local local_player = players_service.LocalPlayer
local workspace_ref = cloneref(workspace)
local farm_model = nil

-- Config
local pickup_enabled = true

for _, descendant in next, workspace_ref:FindFirstChild("Farm"):GetDescendants() do
    if descendant.Name == "Owner" and descendant.Value == local_player.Name then
        farm_model = descendant.Parent and descendant.Parent.Parent
        break
    end
end

task.spawn(function()
    while pickup_enabled and farm_model do
        local plants_folder = farm_model:FindFirstChild("Plants_Physical")
        if plants_folder then
            for _, plant_model in next, plants_folder:GetChildren() do
                if plant_model:IsA("Model") then
                    for _, object in next, plant_model:GetDescendants() do
                        if object:IsA("ProximityPrompt") then
                            -- Temporarily move the root part near the prompt
                            local character = local_player.Character
                            if character and character:FindFirstChild("HumanoidRootPart") then
                                local root = character.HumanoidRootPart
                                local originalCFrame = root.CFrame

                                -- Move close to the prompt
                                root.CFrame = CFrame.new(object.Parent.Position + Vector3.new(0, 2, 0))
                                task.wait(0.05)
                                fireproximityprompt(object)
                                task.wait(0.05)

                                -- Move back to original position
                                root.CFrame = originalCFrame
                            end
                        end
                    end
                end
            end
        end
        task.wait(1) -- Cooldown to avoid server spam
    end
end)
