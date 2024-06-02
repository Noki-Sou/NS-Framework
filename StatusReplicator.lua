--!nocheck

-- // FullName: ReplicatedStorage.StatusReplicated
-- // Type: Client Module (Client Only)

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local HttpService = game:GetService('HttpService')
local Requests = ReplicatedStorage:WaitForChild('Requests')
local Status = Requests:WaitForChild('Status')

export type Type_Status = {
	ID: string,
	Class: string,
	Value: any,
	Created: number,
	Disabled: boolean,
	Remove: (self) -> nil,
	Debris: (self, Lifetime: number) -> Type_Status
} -- Type of the Status

local module = {
	Container = nil,
	Effects = {}
}

local Signal = {}
function Signal:Connect(Callback) -- Connect to the Signal
	local Event = self.Signal

	-- Check if Event exist or not.
	if not Event then
		-- Event does not exist, assinging a new bindable event to communicate.
		Event = Instance.new('BindableEvent')
		self.Signal = Event
	end

	Event.Event:Connect(function(Status: Type_Status)
		-- Return the Status to the Callback assigned.
		Callback(Status)
	end)
end

function Signal:Fire(Status: Type_Status) -- Fire the Signal if exist
	local Event: BindableEvent = self.Signal

	-- Check if there's a script listening to the Signal Connect
	if Event then
		-- If there is, fire the signal.
		Event:Fire(Status)
	end
end

local StatusFunctions = {}

-- Removes Status
function StatusFunctions:Remove()
	-- Send a signal to RemovedStatus
	if module.OnStatusRemoved then
		module.OnStatusRemoved:Fire(self.ID)
	end

	-- Remove Status from module's Effect
	module.Effects[self.ID] = nil
end

-- Queue the Status to remove after a certain time
function StatusFunctions:Debris(Lifetime: number): Type_Status
	-- Delay until the specified Lifetime is reached
	task.delay(Lifetime, function()
		-- Call Remove function
		self:Remove()
	end)
	
	-- Return incase we still need to use it.
	return self
end

-- Creates a new Status.
function module:Add(Class: string, Properties): Type_Status
	-- Checks if Properties exist or not, if not assign a table instead.
	local Properties = Properties or {}

	-- Create the status with properties, and assign StatusFunction as the new __index
	local Status = setmetatable({
		ID = HttpService:GenerateGUID(false),
		Class = Class,
		Value = Properties.Value or true,
		Disabled = Properties.Disabled or false,
		Domain = 'Client'
	},{__index = StatusFunctions})

	-- Assign the Status to module's Effect list
	module.Effects[Status.ID] = Status
	
	if module.OnStatusAdded then
		module.OnStatusAdded:Fire(Status)
	end

	return Status
end

-- Returns a Class specified
function module:FindClass(Class: string, IncludeDisabled: boolean): Type_Status
	for _, v in pairs(self.Effects) do
		-- Check if the class is the same as the one specified in the Parameters.
		if v.Class ~= Class then
			continue
		end

		-- Check whether we should include disabled statuses or not.
		if v.Disabled and not IncludeDisabled then
			continue
		end

		return v
	end
	
	return nil
end

-- Returns a Status with specified Value
function module:FindValue(Value: any, IncludeDisabled: boolean): Type_Status
	for _, v in pairs(self.Effects) do
		-- Check if the value is the same as the one specified in the Parameters.
		if v.Value ~= Value then
			continue
		end

		-- Check whether we should include disabled statuses or not.
		if v.Disabled and not IncludeDisabled then
			continue
		end

		return v
	end
	
	return nil
end

-- Returns a table with active classes.
function module:GetStatusHash(IncludeDisabled: boolean): {[any]: string}
	local Hash = {}
	
	for _, v in pairs(self.Effects) do
		if v.Disabled and not IncludeDisabled then
			continue
		end

		Hash[v.Class] = true
	end
	
	return Hash
end

-- Yield until container is added by the server.
function module:WaitForContainer(): boolean
	repeat
		task.wait()
	until module.Container

	return true
end

-- OnStatus Signals
module.OnStatusAdded = setmetatable({},{__index = Signal})
module.OnStatusRemoved = setmetatable({},{__index = Signal})

-- Update the client's status from server
Status.Update.OnClientEvent:Connect(function(Args: {Status: Type_Status, UpdateType: string})

	-- Assign the module's Container, the status should be Humanoid.
	if Args.UpdateType == 'Update' then
		module.Container = Args.Status
	end

	-- Clear the container and player's Status
	if Args.UpdateType == 'Clear' then
		module.Container = nil		
		for _,v in pairs(module.Effects) do
			v:Remove()
		end
	end

	-- Remove a specified Status from the server.
	if Args.UpdateType == 'Remove' then
		if module.Effects[Args.Status] then
			module.Effects[Args.Status]:Remove()
		end
	end

	-- Add a new status to the client, from the server.
	if Args.UpdateType == 'Add' then
		local Status = Args.Status

		-- Check if the Status already existed
		if module.Effects[Status.ID] then
			-- Status already existed, updating the old status instead of adding a new one.
			module.Effects[Status.ID] = Args.Status
		else
			-- Status doesn't exist, creating a new one.
			local New_Status = setmetatable({
				ID = Status.ID,
				Class = Status.Class,
				Value = Status.Value or true,
				Disabled = Status.Disabled or false,
				Domain = 'Server'
			},{__index = StatusFunctions})

			module.Effects[Status.ID] = New_Status
			
			if module.OnStatusAdded then
				module.OnStatusAdded:Fire(New_Status)
			end
		end
	end
end)

return module
