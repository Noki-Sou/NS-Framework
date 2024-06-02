--!nocheck

-- // NOTES;
-- This was made in hopes of Type Soul devs finding this and fixing their clan system, it's literally so buggy.
-- It's recommended to use any other DataStore you are currently using, Example: ProfileStore, DataStore2, MongoStore, etc...

-- Tip: Players:GetNameFromUserIdAsync to get their Name for other purpose

--[[ (Advised to write your own code handling it). Example Usage:

local ClanManager = require(game.ServerStorage.Modules.ClanManager)
shared.ClanManager = ClanManager

Players.PlayerAdded:Connect(function(Player: Player)
	-- Data Stuff here...
	
	if HasClan then
		local PlayerClan = ClanManager.new(HasClan, Player)
		Player:SetAttribute('Clan', PlayerClan.Name)
		Player:SetAttribute('ClanRank', PlayerClan:GetRank())
		
		PlayerClan.ClanUpdated:Connect(function()
			Player:SetAttribute('Clan', PlayerClan.Name)
			Player:SetAttribute('ClanRank', PlayerClan:GetRank())
		end)
	end
end)

CreateClan.OnServerInvoke = function(Player: Player)
	local Clan = Player:GetAttribute('Clan')
	if Clan then return end
	
	local Success = shared.ClanManager.new(Clan, Player)
	if not Success then
		return 'Failed'
	end
	
	return 'Success'
end

PromotePlayer.OnServerEvent:Connect(function(Player: Player, Target: Player)
	local Clan = Player:GetAttribute('Clan')
	if not Clan then return end
	
	local ClanManager = shared.ClanManager.new(Clan, Player)
	ClanManager:Promote(Target)
end)

DemotePlayer.OnServerEvent:Connect(function(Player: Player, Target: number | string | Player)
	local Clan = Player:GetAttribute('Clan')
	if not Clan then return end
	
	if typeof(Target) == 'string' then
		Target = Players:GetUserIdFromNameAsync(Target)
	end

	if typeof(Target) == 'Instance' then
		Target = Target.UserId
	end

	local ClanManager = shared.ClanManager.new(Clan, Player)
	ClanManager:Demote(Target)
end)

DisbandClan.OnServerEvent:Connect(function(Player: Player)
	local Clan = Player:GetAttribute('Clan')
	if not Clan then return end
	
	local ClanManager = shared.ClanManager.new(Clan, Player)
	ClanManager:Disband()
end)

TransferClan.OnServerEvent:Connect(function(Player: Player, Target: Player)
	local Clan = Player:GetAttribute('Clan')
	if not Clan then return end
	
	local ClanManager = shared.ClanManager.new(Clan, Player)
	ClanManager:Transfer(Target)
end)

]]

-- // Export Types

export type ClanManager = {
	Promote: (self, Player: Player) -> nil,
	Demote: (self, UserId: number) -> nil,
	Transfer: (self, UserId: number) -> nil,
	Disband: (self) -> nil,
	GetRank: (self) -> nil,
	OnDisband: RBXScriptSignal,
	OnPromote: RBXScriptSignal,
	OnDemote: RBXScriptSignal,
	OnTransfer: RBXScriptSignal,
	ClanUpdated: RBXScriptSignal,
	Members: { [number]: number },
	Leader: number,
	Name: string
}

-- // Services

local HttpService = game:GetService('HttpService')
local MessagingService = game:GetService('MessagingService')
local DataStoreService = game:GetService('DataStoreService')
local ClanDataStore = DataStoreService:GetDataStore('ClanData_Alpha')

-- // Permission level for Promote / Demote
local Permission_Level = 2

-- // Permission Sort
local Permissions = {
	[3] = 'Captain',
	[2] = 'Officer',
	[1] = 'Member'
}

-- // Signals

local Signal = {}
function Signal:Connect(Callback)
	local Event = self.Signal

	if not Event then
		Event = Instance.new('BindableEvent')
		self.Signal = Event
	end

	return Event.Event:Connect(function(Status: Type_Status)
		Callback(Status)
	end)
end

function Signal:Fire(Status: Type_Status)
	local Event: BindableEvent = self.Signal

	if Event then
		Event:Fire(Status)
	end
end

-- // Clan Manager

local ClanManager = {} :: {
	new: (Name: string, RequestPlayer: Player) -> ClanManager,
	Clans: {ClanManager}
}

ClanManager.Clans = {}
ClanManager.__index = ClanManager

-- // Promote a member of the clan
function ClanManager:Promote(Player: Player)
	local UserId = Player.UserId
	local ClanData = ClanManager.Clans[self.Name]
	local PlayerRank = ClanData.Members[UserId]

	if ClanData.Members[self.RequestPlayer] < Permission_Level then
		return 'No Permission'
	end

	if UserId == ClanData.Leader then
		return 'Unauthorized (Leader)'
	end

	if PlayerRank >= Permission_Level then
		return 'Unauthorized (Higher Rank)'
	end
	
	ClanData.OnPromote:Fire(UserId, ClanData.Members[UserId] or 1)

	if not PlayerRank then
		ClanData.Members[UserId] = 1
		return true
	end

	ClanData.Members[UserId] += 1
	ClanData.ClanUpdated:Fire()

	return true
end

-- // Demote a member of the clan
function ClanManager:Demote(UserId: number)
	local CurrentRank = self.Members[UserId]
	local ClanData = ClanManager.Clans[self.Name]

	if ClanData.Members[self.RequestPlayer] < Permission_Level then
		return 'Unauthorized (No Permission)'
	end

	if UserId == ClanData.Leader then
		return 'Unauthorized (Leader)'
	end

	ClanData.OnDemote:Fire(UserId, ClanData.Members[UserId] - 1)

	if self.RequestPlayer <= 1 then
		ClanData.Members[UserId] = nil
		return true
	end

	ClanData.Members[UserId] -= 1
	ClanData.ClanUpdated:Fire()

	return true
end

-- // Disband the clan
function ClanManager:Disband()
	local ClanData = ClanManager.Clans[self.Name]
	
	if self.RequestPlayer ~= ClanData.Leader then
		return 'Unauthorized (Leader Only)'
	end

	ClanManager.Clans[self.Name] = nil
	
	ClanData.OnDisband:Fire()
	ClanData.ClanUpdated:Fire()

	return true
end

-- // Transfer ownership of clan to another player
function ClanManager:Transfer(Player: Player)
	local UserId = Player.UserId
	local ClanData = ClanManager.Clans[self.Name]
	local PlayerRank = ClanData.Members[UserId]

	if self.RequestPlayer ~= ClanData.Leader then
		return
	end
	
	-- // Additional if you are using the Example Script
	if Player:GetAttribute('Clan') and Player:GetAttribute('Clan') ~= self.Name then
		return 'Already in another clan'
	end
	
	ClanData.Members[ClanData.Leader] = 1
	ClanData.Members[UserId] = #Permissions
	ClanData.Leader = UserId

	ClanData.OnTransfer:Fire(UserId)
	ClanData.ClanUpdated:Fire()
	
	return true
end

-- // Returns Rank Rich Name, ex: Captain, Officer, Member
function ClanManager:GetRank()
	local ClanData = ClanManager.Clans[self.Name]
	
	return Permissions[ClanData.Members[self.RequestPlayer]]
end

-- // Create or Return an already existing clan
function ClanManager.new(Name: string, RequestPlayer: Player)
	local BaseInfo = {
		Name = Name,
		Leader = RequestPlayer.UserId,
		Members = {
			[RequestPlayer.UserId] = #Permissions
		}
	}

	local ClanData = ClanManager.Clans[Name] or ClanDataStore:GetAsync(Name) or (ClanDataStore:SetAsync(Name, BaseInfo) and BaseInfo)
	if ClanData.Leader and ClanData.Leader ~= RequestPlayer.UserId and not ClanData.Members[RequestPlayer.UserId] then
		return
	end
	
	if not ClanData.Leader then
		ClanData = BaseInfo
		ClanDataStore:SetAsync(Name, BaseInfo)
	end
	
	local ClanData = ClanManager.Clans[Name] or {}
	BaseInfo.OnDisband = ClanData.OnDisband or setmetatable({},{__index = Signal})
	BaseInfo.OnDemote = ClanData.OnDemote or setmetatable({},{__index = Signal})
	BaseInfo.OnPromote = ClanData.OnPromote or setmetatable({},{__index = Signal})
	BaseInfo.OnTransfer = ClanData.OnTransfer or setmetatable({},{__index = Signal})
	BaseInfo.ClanUpdated = ClanData.ClanUpdated or setmetatable({},{__index = Signal})
	
	if not ClanManager.Clans[Name] then
		BaseInfo.ClanUpdated:Connect(function(noPublish)
			local ClanData = ClanManager.Clans[Name] or {}
			local BaseInfo = {
				Name = ClanData.Name,
				Leader = ClanData.Leader,
				Members = ClanData.Members
			}
			
			ClanDataStore:SetAsync(Name, BaseInfo)
			
			if noPublish then
				return
			end
			
			MessagingService:PublishAsync('ClanChanged', HttpService:JSONEncode(BaseInfo))
		end)
		
		ClanManager.Clans[Name] = setmetatable(BaseInfo, ClanManager)
	end

	BaseInfo.RequestPlayer = RequestPlayer.UserId
	return setmetatable(BaseInfo, ClanManager)
end

-- // Cross-Server Update
MessagingService:SubscribeAsync('ClanChanged', function(Message)
	local Data = HttpService:JSONDecode(Message.Data)
	local ClanData = ClanManager.Clans[Data.Name]
	
	if ClanData then
		for i,v in pairs(Data) do
			ClanData[i] = v
		end
		
		if not Data.Leader then
			ClanData.OnDisband:Fire()
			ClanData = {}
		end
		
		ClanData.ClanUpdated:Fire(true)
	end
end)

return ClanManager
