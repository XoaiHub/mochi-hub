--Auto Collect with Modules, its good af and u can make Collect Aura with it
--Happy Skidding
local CollectController = require(game:GetService("ReplicatedStorage").Modules.CollectController)

CollectController._lastCollected = 0
CollectController._holding = true
CollectController:_updateButtonState()
CollectController:Collect()
