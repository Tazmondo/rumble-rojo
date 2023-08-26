local CombatController = {}
CombatController.__index = CombatController

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local FastCast = require(ReplicatedStorage.Modules.Shared.FastCastRedux)

-- Controller Variables
-- (Since controllers are singletons (there is only ever one of them), we don't need to store the variables within the table)
local lastMouseCast
local character: Model?
local humanoid: Humanoid?
local HRP: BasePart?

local function VisualiseRay(ray: Ray)
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 0.5
    part.Color = Color3.new(0.411765, 0.913725, 0.494118)
    part.CFrame = CFrame.lookAt((ray.Origin + (ray.Direction * 0.5)), ray.Origin + ray.Direction)
    part.Size = Vector3.new(0.2, 0.2, ray.Direction.Magnitude)

    part.Parent = workspace

    Debris:AddItem(part, 15)
end

-- Returns hit position, instance, normal
local function ScreenPointCast(x: number, y: number, params: RaycastParams?)
    if not params then
        params = RaycastParams.new()
        assert(params) -- To appease type checker
        local mapFolder = workspace:FindFirstChild("Map")
        assert(mapFolder, "map folder not found")
        params.FilterDescendantsInstances = {mapFolder}
        params.FilterType = Enum.RaycastFilterType.Include
    end

    local cam = workspace.CurrentCamera
    local ray = cam:ScreenPointToRay(x, y)

    local cast = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
    if cast then
        return {cast.Position, cast.Instance, cast.Normal}
    else
        return {ray.Origin + ray.Direction * 1000, nil, nil} -- Mimics the behaviour of Player.Mouse
    end
end

local function CharacterAdded(char)
    humanoid = char:WaitForChild("Humanoid") :: Humanoid
    assert(humanoid)
    HRP = humanoid.RootPart
    character = char

    humanoid.AutoRotate = false
    humanoid.JumpHeight = 0
end

local function CharacterRemoving()  
    character = nil
    humanoid = nil
    HRP = nil
end

function CombatController:Initialize()
    localPlayer.CharacterAdded:Connect(CharacterAdded)
    localPlayer.CharacterRemoving:Connect(CharacterRemoving)

    UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean) 
        if processed then return end

        if input.UserInputType == Enum.UserInputType.MouseMovement then
            if not character or not humanoid or not HRP then return end
            
            local screenPosition = input.Position
            lastMouseCast = ScreenPointCast(screenPosition.X, screenPosition.Y)

            local hitPosition = lastMouseCast[1]

            HRP.CFrame = CFrame.lookAt(HRP.Position, Vector3.new(hitPosition.X, HRP.Position.Y, hitPosition.Z))
        end
    end)

    UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean) 
        if processed then return end

        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if not character or not humanoid or not HRP or not lastMouseCast then return end

            local lastPosition = lastMouseCast[1]
            local lastInstance = lastMouseCast[2]
            local lastNormal = lastMouseCast[3]

            
            local targetHeight = HRP.Position.Y
            
            if lastInstance and lastInstance.Parent:FindFirstChild("Humanoid") then
                -- If they clicked on a player, we do not need to correct the aim height
                targetHeight = lastInstance.Parent.HumanoidRootPart.Position.Y
            else
                -- Here we are making sure they clicked on a sloped surface, so a player could actually be standing on it.
                -- If the angle is greater than 80, then the surface is pretty much a wall, and it would not make sense to target it.
                if lastNormal then
                    local angleToVertical = math.deg(Vector3.new(0, 1, 0):Angle(lastNormal))
                    if angleToVertical <= 80 then
                        targetHeight = lastPosition.Y + 3
                    end
                end
            end


            local ray = Ray.new(HRP.Position, Vector3.new(lastPosition.X, targetHeight, lastPosition.Z) - HRP.Position)
            VisualiseRay(ray)

        end
    end)
end

return CombatController
