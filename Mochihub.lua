local pickup_enabled = true
local CollectController = require(game:GetService("ReplicatedStorage").Modules.CollectController)
local local_player = game:GetService("Players").LocalPlayer
local workspace_ref = game:GetService("Workspace")

CollectController._lastCollected = 0
CollectController._holding = true
CollectController:_updateButtonState()

-- Find player's farm model
local farm_model
local farm_root = workspace_ref:FindFirstChild("Farm")
if farm_root then
    for _, descendant in ipairs(farm_root:GetDescendants()) do
        if descendant.Name == "Owner" and descendant:IsA("ObjectValue") and descendant.Value == local_player.Name then
            farm_model = descendant:FindFirstAncestorOfClass("Model")
            break
        end
    end
end

-- Main loop to collect from plants
task.spawn(function()
    while pickup_enabled and farm_model and farm_model.Parent do
        local plants_folder = farm_model:FindFirstChild("Plants_Physical")
        if plants_folder then
            for _, plant_model in ipairs(plants_folder:GetChildren()) do
                if plant_model:IsA("Model") then
                    -- Collect the whole model first
                    CollectController._lastCollected = 0
                    CollectController:_updateButtonState()
                    CollectController:Collect(plant_model)
                    task.wait(0.01)

                    -- Then try collecting individual parts or components
                    for _, object in ipairs(plant_model:GetDescendants()) do
                        if object:IsA("BasePart") or object:IsA("Model") then
                            CollectController._lastCollected = 0
                            CollectController:_updateButtonState()
                            CollectController:Collect(object)
                            task.wait(0.01)
                        end
                    end
                end
            end
        end
        task.wait(0.1)
    end
end)
