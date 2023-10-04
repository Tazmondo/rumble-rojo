local DebugUIController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataController = require(script.Parent.DataController)
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
            Iris.Window({ "Debug" })
                RenderTable(DataController.GetGameData():UnwrapOr(nil :: any), "Game Data")
                RenderTable(DataController.GetLocalData():UnwrapOr(nil :: any), "Local Data")
                RenderTable(DataController.GetPublicData():UnwrapOr(nil :: any), "Public Data")
                -- Iris.TextWrapped({TableUtil.EncodeJSON(DataController.GetGameData():UnwrapOr(nil :: any))})
                -- Iris.TextWrapped({TableUtil.EncodeJSON(DataController.GetLocalData():UnwrapOr(nil :: any))})
                -- Iris.TextWrapped({TableUtil.EncodeJSON(DataController.GetPublicData():UnwrapOr(nil :: any))})
            
            Iris.End()
        end)
    end)

end

DebugUIController.Initialize()

return DebugUIController
