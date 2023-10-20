local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CursorController = {}

local InputType = require(script.Parent.InputType)

local PlayerGui = Players.LocalPlayer.PlayerGui
local CursorGui: ScreenGui
local CursorImage: ImageLabel

local icons = {
	lobby = "rbxassetid://15120716391",
	hover = "rbxassetid://15121577574",
	press = "rbxassetid://15120716391",
	attack = "rbxassetid://15120629418",
	attackActive = "rbxassetid://15120629418",
	attackDisabled = "rbxassetid://15120629705",
	super = "rbxassetid://15120629902",
	superActive = "rbxassetid://15120629902",
	superDisabled = "rbxassetid://15120629262",
}
CursorController.Icons = icons

local iconOverride: string?
local hoverButton: ImageButton?
local pressedButton: ImageButton?

function CursorController.UpdateIcon(icon: string?)
	iconOverride = icon
end

function Render()
	if InputType.GetType() ~= "KBM" then
		CursorGui.Enabled = false
		return
	end

	local mousePosition = UserInputService:GetMouseLocation()
	if not mousePosition then
		CursorGui.Enabled = false
		return
	end

	CursorGui.Enabled = true
	CursorImage.Position = UDim2.fromOffset(mousePosition.X, mousePosition.Y)

	-- print(PlayerGui:GetGuiObjectsAtPosition(mousePosition.X, mousePosition.Y - 36))

	-- Make sure the hovered UI hasn't disappeared
	if hoverButton and not iconOverride then
		local currentUI: any = hoverButton
		local visible = false
		while not currentUI:IsA("GuiObject") or currentUI.Visible == true do
			if not currentUI.Parent then
				break
			end
			assert(currentUI.Parent)

			if currentUI.Parent:IsA("ScreenGui") then
				visible = true
				break
			end

			currentUI = currentUI.Parent
		end

		if not visible then
			hoverButton = nil
		end
	end

	local newImage
	if iconOverride then
		newImage = iconOverride
	elseif pressedButton then
		newImage = icons.press
	elseif hoverButton then
		newImage = icons.hover
	else
		newImage = icons.lobby
	end

	if newImage ~= CursorImage.Image then
		CursorImage.Image = newImage
	end
end

function RegisterButton(button)
	if not button:IsA("TextButton") and not button:IsA("ImageButton") then
		return
	end
	button = button :: ImageButton

	button.MouseEnter:Connect(function(x, y)
		if not button.Active then
			return
		end
		hoverButton = button
	end)

	button.MouseLeave:Connect(function()
		if hoverButton == button then
			hoverButton = nil
		end
	end)

	button.MouseButton1Down:Connect(function()
		if not button.Active or not hoverButton then
			return
		end

		pressedButton = button
	end)
end

function Initialize()
	CursorGui = PlayerGui:WaitForChild("Cursor")
	CursorImage = CursorGui:FindFirstChild("Cursor") :: ImageLabel
	CursorImage.Image = icons.lobby

	UserInputService.MouseIconEnabled = false

	RunService.RenderStepped:Connect(Render)

	PlayerGui.DescendantAdded:Connect(RegisterButton)
	for i, descendant in ipairs(PlayerGui:GetDescendants()) do
		RegisterButton(descendant)
	end

	UserInputService.InputEnded:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			pressedButton = nil
		end
	end)
end

Initialize()

return CursorController
