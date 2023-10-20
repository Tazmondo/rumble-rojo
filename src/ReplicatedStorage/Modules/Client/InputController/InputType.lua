local InputType = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Signal = require(ReplicatedStorage.Packages.Signal)

type InputMode = "KBM" | "Mobile"
local lastInputMode: InputMode = "Mobile"

InputType.InputModeChanged = Signal()

function InputTypeChanged()
	local inputType = UserInputService:GetLastInputType()
	local oldMode = lastInputMode
	if inputType == Enum.UserInputType.Keyboard or string.find(inputType.Name, "Mouse") then
		lastInputMode = "KBM"
	elseif inputType == Enum.UserInputType.Touch then
		lastInputMode = "Mobile"
	end

	if oldMode ~= lastInputMode then
		InputType.InputModeChanged:Fire(lastInputMode)
	end
	return
end

function InputType.GetType(): InputMode
	return lastInputMode
end

function InputType.Initialize()
	InputTypeChanged()
	UserInputService.LastInputTypeChanged:Connect(InputTypeChanged)
end

InputType.Initialize()

return InputType
