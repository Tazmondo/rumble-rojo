--!strict
print("init purchasecontroller")
local PurchaseController = {}

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

function PurchaseController.Purchase(id: number)
	print("purchasing", id)
	MarketplaceService:PromptProductPurchase(player, id)

	MarketplaceService.PromptProductPurchaseFinished:Wait()
end

return PurchaseController
