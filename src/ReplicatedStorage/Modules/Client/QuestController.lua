-- Handles rendering of quest UI, though its visibility is controlled by the UI controller
local QuestController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataController = require(script.Parent.DataController)
local PurchaseController = require(script.Parent.PurchaseController)

local ClaimQuestEvent = require(ReplicatedStorage.Events.Quest.ClaimQuestEvent):Client()

local Player = Players.LocalPlayer

local PlayerGui = Player:WaitForChild("PlayerGui") :: PlayerGui

local QuestUI = (PlayerGui:WaitForChild("MainUI") :: any).Interface.Quest

local questListFrame = QuestUI.Content.Rows.ScrollingFrame

local template = questListFrame.Template
template.Parent = nil -- So we can clear children without destroying this template

local REFRESHID = 1669000393

local claimableQuests = 0

function RenderQuests()
	local data = DataController.GetLocalData():Await().Private
	local quests = data.Quests

	claimableQuests = 0

	for i, child in ipairs(questListFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for i, quest in ipairs(quests) do
		local newQuest = template:Clone()

		newQuest.Title.Text = quest.Text

		local progress = math.clamp(quest.CurrentNumber / quest.RequiredNumber, 0, 1)
		local progressBar = newQuest.Details.OuterBar.InnerBar :: Frame

		progressBar.Size = UDim2.fromScale(progress, 1)

		local rewardLabel = newQuest.Details.Progress.Reward.GBucksCount
		rewardLabel.Text = quest.Reward

		local progressFrame = newQuest.Details.Progress

		local claimable = quest.CurrentNumber >= quest.RequiredNumber and not quest.Claimed
		if claimable then
			progressFrame.Claim.Visible = true
			progressFrame.Progress.Visible = false
			progressFrame.Reward.Visible = false

			progressFrame.Claim.Claim.Activated:Connect(function()
				ClaimQuestEvent:Fire(i)
				quest.Claimed = true
				RenderQuests()
			end)

			claimableQuests += 1
		else
			progressFrame.Claim.Visible = false
			progressFrame.Progress.Visible = true
			progressFrame.Reward.Visible = true

			if quest.Claimed then
				progressFrame.Progress.Claimed.Visible = true
				progressFrame.Progress.Progress.Visible = false
			else
				progressFrame.Progress.Claimed.Visible = false
				progressFrame.Progress.Progress.Visible = true

				local progressText
				if quest.RequiredNumber > 1000 then
					local current = math.floor(quest.CurrentNumber / 1000)
					local required = math.floor(quest.RequiredNumber / 1000)
					if current == 0 then
						progressText = string.format("0/%ik", required) -- No k when 0
					else
						progressText = string.format("%ik/%ik", current, required)
					end
				else
					progressText = quest.CurrentNumber .. "/" .. quest.RequiredNumber
				end
				progressFrame.Progress.Progress.Text = progressText
			end
		end

		newQuest.Visible = true
		newQuest.Parent = questListFrame
	end
end

function QuestController.GetClaimableQuests()
	return claimableQuests
end

function QuestController.Initialize()
	DataController.LocalDataUpdated:Connect(function()
		RenderQuests()
	end)

	QuestUI.Content.Rows.ResetFrame.Reset.Activated:Connect(function()
		PurchaseController.Purchase(REFRESHID)
	end)
end

QuestController.Initialize()

return QuestController
