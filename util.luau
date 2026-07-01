--!optimize 2

local RunService    = game:GetService("RunService");
local ServerStorage = game:GetService("ServerStorage");

local Util = {};
local Sift = require("@game/ReplicatedStorage/Storage/Modules/Static/Sift");

function Util.CleanConnections(t: {}): ()
	
	if not t then return; end;

	for key, value in pairs(t) do
		
		if typeof(key) == 'thread' then
			task.cancel(key);
			t[key] = nil;
			continue;
		elseif typeof(key) == 'RBXScriptConnection' then
			if key.Connected then key:Disconnect(); end;
			t[key] = nil;
			continue;
		end;

		if typeof(value) == 'thread' then
			
			if coroutine.status(value) ~= "dead" then
				task.cancel(value);
			end;
			
			t[key] = nil;
		elseif typeof(value) == 'RBXScriptConnection' then
			if value.Connected then 
				value:Disconnect(); 
			end;
			t[key] = nil;
		end;
		
	end;
	
end;


-- Возращает загрузчик (модуль), который находится в папке Loaders.
function Util.GetLoader(name: string): (ModuleScript)
	local Loader = ServerStorage.Storage.Loaders:FindFirstChild(name) :: ModuleScript?;
	if Loader then return Loader; end;
end;

-- Возращает модуль, который совпадает с запросом.
function Util.DeepGetModule(name: string): (ModuleScript)
	local Module = ServerStorage.Storage:FindFirstChild(name, true) :: ModuleScript?;
	if Module and Module:IsA("ModuleScript") then return Module; end;
end;

function Util.GetConfig(name: string): (ModuleScript)
	if not ServerStorage.Storage:FindFirstChild("Configurations") then return; end;
	local Module = ServerStorage.Storage.Configurations:FindFirstChild(name, true) :: ModuleScript;
	if Module and Module:IsA("ModuleScript") then return Module; end;
end;

-- упрощеный рейкаст без создания для него пакета параметров
function Util.Rustcast(Origin: Vector3, Direction: Vector3, FilterType: string, FilterInstances: {Instance}, IgnoreWater: boolean): (RaycastResult | nil)

	if not Origin or not Direction then warn("Missing arguments for Rustcast:", Origin, Direction); return nil; end;
	if not FilterType then FilterType = "Exclude"; end;
	if not FilterInstances then FilterInstances = {}; end;

	local Params = RaycastParams.new();
	Params.FilterType = Enum.RaycastFilterType[FilterType];
	Params.FilterDescendantsInstances = FilterInstances;
	Params.IgnoreWater = IgnoreWater;

	return workspace:Raycast(Origin, Direction, Params);
end;

Util.Sift = table.freeze(Sift);
local ClientCall = RunService:IsClient();
if ClientCall then
	ServerStorage = game:GetService("ReplicatedStorage");
	return table.freeze(Util);
else
	return Util;
end;
