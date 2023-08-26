-- variables
local Main = {
	CachedFunctions = {}
}

local Player = game.Players.LocalPlayer
local Remotes = game.ReplicatedStorage.Modules.Events

-- services
local RunService = game:GetService("RunService")

-- load modules
local Loader = require(game.ReplicatedStorage.Modules.Shared.Loader)

-- functions
function Main:TraceCallback(Text)
	warn(debug.traceback(Text, 3))
end

-- client
function Main:FireServer(...)
	if RunService:IsServer() then
		self:TraceCallback("Attempt to call FireServer on the Server")
		return
	end

	Remotes.RemoteEvent:FireServer(...)
end
function Main:InvokeServer(...)
	if RunService:IsServer() then
		self:TraceCallBack("Attempt to call InvokeServer on the Server")
		return
	end

	return Remotes.RemoteFunction:InvokeServer(...)
end

function Main:OnClientEvent(Type, Function)
	if RunService:IsServer() then
		self:TraceCallBack("Attempt to call OnClientEvent on the Server")
		return
	end

	if not self.CachedFunctions[Type] then
		self.CachedFunctions[Type] = Function
	else
		self:TraceCallBack(Type.." is already cached")
	end
end

function Main:OnClientInvoke(Type, Function)
	if RunService:IsServer() then
		self:TraceCallBack("Attempt to call OnClientInvoke on the Server")
		return
	end

	if not self.CachedFunctions[Type] then
		self.CachedFunctions[Type] = Function
	else
		self:TraceCallBack(Type.." is already cached")
	end
end

-- server
function Main:FireClient(...)
	if RunService:IsClient() then
		self:TraceCallBack("Attempt to call FireClient on the Client")
		return
	end

	Remotes.RemoteEvent:FireClient(...)
end

function Main:FireAllClients(...)
	if RunService:IsClient() then
		self:TraceCallBack("Attempt to call FireAllClients on the Client")
		return
	end

	Remotes.RemoteEvent:FireAllClients(...)
end

function Main:InvokeClient(...)
	if RunService:IsClient() then
		self:TraceCallBack("Attempt to call InvokeClient on the Client")
		return
	end

	return Remotes.RemoteFunction:InvokeClient(...)
end

function Main:OnServerEvent(Type, Function)
	if RunService:IsClient() then
		self:TraceCallBack("Attempt to call OnServerEvent on the Client")
		return
	end

	if not self.CachedFunctions[Type] then
		self.CachedFunctions[Type] = Function
	else
		self:TraceCallBack(Type.." is already cached")
	end
end

function Main:OnServerInvoke(Type, Function)
	if RunService:IsClient() then
		self:TraceCallBack("Attempt to call OnServerInvoke on the Client")
		return
	end

	if not self.CachedFunctions[Type] then
		self.CachedFunctions[Type] = Function
	else
		self:TraceCallBack(Type.." is already cached")
	end
end

-- shared
function Main:BindableFire(...)
	Remotes.BindableEvent:Fire(...)
end

function Main:BindableInvoke(...)
	local Type = ...

	if self.CachedFunctions[Type] then
		-- custom implimentation of bindable invoke otherwise it can cause an infinite yield
		local ToSend = table.pack(...)
		table.remove(ToSend, 1)

		return self.CachedFunctions[Type](table.unpack(ToSend))
	end
end

function Main:OnBindableFire(Type, Function)
	if not self.CachedFunctions[Type] then
		self.CachedFunctions[Type] = Function
	else
		self:TraceCallBack(Type.." is already cached")
	end
end

function Main:OnBindableInvoke(Type, Function)
	if not self.CachedFunctions[Type] then
		self.CachedFunctions[Type] = Function
	else
		self:TraceCallBack(Type.." is already cached")
	end
end


-- routing requests
function Main:Initialize()
	print("Network initialized")
	if RunService:IsServer() then
		Remotes.RemoteEvent.OnServerEvent:Connect(function(Player, Type, ...)
			if self.CachedFunctions[Type] then
				self.CachedFunctions[Type](Player, ...)
			else
				warn("OnServerEvent function", Type, "is not cached")
			end
		end)

		Remotes.RemoteFunction.OnServerInvoke = function(Player, Type, ...)
			if self.CachedFunctions[Type] then
				return self.CachedFunctions[Type](Player, ...)
			else
				warn("OnServerInvoke function", Type, "is not cached")
			end
		end
	else
		Remotes.RemoteEvent.OnClientEvent:Connect(function(Type, ...)
			if self.CachedFunctions[Type] then
				self.CachedFunctions[Type](...)
			else
				warn("OnClientEvent function", Type, "is not cached")
			end
		end)

		Remotes.RemoteFunction.OnClientInvoke = function(Type, ...)
			if self.CachedFunctions[Type] then
				return self.CachedFunctions[Type](...)
			else
				warn("OnClientInvoke function", Type, "is not cached")
			end
		end
	end

	-- bindables
	Remotes.BindableEvent.Event:Connect(function(Type, ...)
		if self.CachedFunctions[Type] then
			self.CachedFunctions[Type](...)
		else
			warn("OnBindableFire function", Type, "is not cached")
		end
	end)

	Remotes.BindableFunction.OnInvoke = function(Type, ...)
		if self.CachedFunctions[Type] then
			return self.CachedFunctions[Type](...)
		else
			warn("OnBindableInvoke function", Type, "is not cached")
		end
	end
end

return Main;