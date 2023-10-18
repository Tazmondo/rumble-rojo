local DebugUIController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatPlayerController = require(ReplicatedStorage.Modules.Client.CombatController.CombatPlayerController)
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local DataController = require(script.Parent.DataController)
local InputController = require(script.Parent.InputController)
local Iris = require(ReplicatedStorage.Modules.Shared.Iris)
local Spawn = require(ReplicatedStorage.Packages.Spawn)

local player = Players.LocalPlayer

function RenderTable(table: {[any]: any}, name)
    if table then
        Iris.Tree({name})
        for k,v in pairs(table) do
            if typeof(v) == "table" then
                RenderTable(v, tostring(k))
            else
                Iris.Text({tostring(k) .. " : " .. tostring(v)})
            end
        end
        Iris.End()
    end
end

function DebugUIController.Initialize()
	if player.UserId ~= 68252170 and player.CharacterAppearanceId ~= 68252170 then
		return
	end

    
    Spawn(function()
        DataController.HasLoadedData():Await()
        Iris.Init()

        -- Iris:Connect(Iris.ShowDemoWindow)
        
        Iris:Connect(function()
            local unCollapsed = Iris.State(false)
            Iris.Window({ "Debug" }, {isUncollapsed = unCollapsed})
                RenderTable(DataController.GetGameData():UnwrapOr(nil :: any), "Game Data")
                RenderTable(DataController.GetLocalData():UnwrapOr(nil :: any), "Local Data")
                RenderTable(DataController.GetPublicData():UnwrapOr(nil :: any), "Public Data")

                local combatPlayer = CombatPlayer.GetClientCombatPlayer()
                if combatPlayer then
                    RenderTable(combatPlayer :: any, "CombatPlayer")
                end
                local combatData = CombatPlayerController.GetCurrentdata()
                RenderTable(combatData, "CombatPlayerData")
                
                local inputController = InputController.Instance
                if inputController then
                    RenderTable(inputController, "Input Controller")
                end
            
            Iris.End()
        end)
    end)

end

DebugUIController.Initialize()

return DebugUIController
