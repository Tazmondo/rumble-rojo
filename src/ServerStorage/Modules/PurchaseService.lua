--!strict
-- Handles purchasing of developer products
local PurchaseService = {}

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Modules.Shared.Data)
local DataService = require(script.Parent.DataService)

local MAXSTOREDPURCHASES = 50

type BuyFunction = (Player, Data.PrivatePlayerData) -> nil

type Product = {
	Disabied: boolean?,
	BuyFunction: BuyFunction,
	CanBuy: (Player) -> boolean,
	Name: string?,
}

function TrueFunction()
	return true
end

function RumbleBuckPurchase(count: number): Product
	return {
		Name = "x" .. count .. " Rumble Bucks",
		BuyFunction = function(player, profile)
			profile.Money += count
		end,
		CanBuy = TrueFunction,
	}
end

local products: { [number]: Product } = {
	[1654327287] = RumbleBuckPurchase(240),
	[1654324789] = RumbleBuckPurchase(1200),
	[1654328177] = RumbleBuckPurchase(3000),
	[1654328497] = RumbleBuckPurchase(6000),
}

-- Stolen from ProfileService documentation with adjustments
function PurchaseIdCheckAsync(
	player: Player,
	profile: DataService.Profile,
	purchase_id: number,
	grant_product_callback: () -> nil
): Enum.ProductPurchaseDecision
	-- Yields until the purchase_id is confirmed to be saved to the profile or the profile is released

	if profile:IsActive() ~= true then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	else
		local meta_data = profile.MetaData

		local local_purchase_ids = meta_data.MetaTags.ProfilePurchaseIds
		if local_purchase_ids == nil then
			local_purchase_ids = {}
			meta_data.MetaTags.ProfilePurchaseIds = local_purchase_ids
		end

		-- Granting product if not received:

		if table.find(local_purchase_ids, purchase_id) == nil then
			while #local_purchase_ids >= MAXSTOREDPURCHASES do
				table.remove(local_purchase_ids, 1)
			end
			table.insert(local_purchase_ids, purchase_id)
			task.spawn(grant_product_callback)
		end

		-- Waiting until the purchase is confirmed to be saved:

		local result = nil

		local function check_latest_meta_tags()
			local saved_purchase_ids = meta_data.MetaTagsLatest.ProfilePurchaseIds
			if saved_purchase_ids ~= nil and table.find(saved_purchase_ids, purchase_id) ~= nil then
				result = Enum.ProductPurchaseDecision.PurchaseGranted
			end
		end

		check_latest_meta_tags()

		local meta_tags_connection = profile.MetaTagsUpdated:Connect(function()
			check_latest_meta_tags()
			-- When MetaTagsUpdated fires after profile release:
			if profile:IsActive() == false and result == nil then
				result = Enum.ProductPurchaseDecision.NotProcessedYet
			end
		end)

		while result == nil do
			task.wait()
		end

		meta_tags_connection:Disconnect()

		return result
	end
end

function GrantPurchaseCallback(player: Player, profile: Data.PrivatePlayerData, buyFunction: BuyFunction)
	return function()
		buyFunction(player, profile)
	end
end

function ProcessReceipt(receipt_info)
	local player = Players:GetPlayerByUserId(receipt_info.PlayerId)

	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local profile = DataService.GetProfile(player):Await()
	local data = DataService.GetPrivateData(player):Await()
	if not profile or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local product = products[receipt_info.ProductId]
	if not product then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	if product.Disabied then
		-- Award when the product is re-enabled
		-- We do not allow the initial purchase prompt for a disabled product, so this won't cause security issues
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if profile ~= nil then
		return PurchaseIdCheckAsync(
			player,
			profile,
			receipt_info.PurchaseId,
			GrantPurchaseCallback(player, data, product.BuyFunction)
		)
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

MarketplaceService.ProcessReceipt = ProcessReceipt

function PlayerAdded(player: Player) end

function Initialize()
	Players.PlayerAdded:Connect(PlayerAdded)
	for i, player in pairs(Players:GetPlayers()) do
		PlayerAdded(player)
	end
end

Initialize()
return PurchaseService
