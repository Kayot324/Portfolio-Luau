--!strict
--!optimize 2

local type_marshaller  = require(script.Parent.type_marshaller);
local ProximityMethods = {};
local TaskProximity    = { __index = ProximityMethods };
local TaskManager:   (any);

function ProximityMethods:andCall(callback: (...any) -> (...any)): (type_marshaller.IntelliThread)

	local selfInternal = (self :: any) :: (type_marshaller.IntelliThreadInternal);
	local nextSmartObj = ProximityMethods.createIntelliThread();

	local function wrapper()
		if (typeof(callback) == "function") then

			local currentThread = selfInternal.RawThread;
			local result = callback(currentThread);

			if (typeof(result) == "thread") then
				local internalNext = (nextSmartObj :: any) :: (type_marshaller.IntelliThreadInternal);
				internalNext.RawThread = result;
			end;
		end;
		ProximityMethods.fireComplete(nextSmartObj);
	end;

	if (selfInternal._isDone) then
		task.spawn(wrapper);
	else
		table.insert(selfInternal._onComplete, wrapper);
	end;

	return nextSmartObj;
end;

function ProximityMethods:andSafeCall(callback: (...any) -> (...any)): (type_marshaller.IntelliThread)

	local selfInternal = (self :: any) :: (type_marshaller.IntelliThreadInternal);
	local nextSmartObj = ProximityMethods.createIntelliThread();

	local function wrapper()
		if (typeof(callback) == "function") then

			local currentThread = selfInternal.RawThread;
			local result = callback(currentThread);

			if (typeof(result) == "thread") then
				local internalNext = (nextSmartObj :: any) :: (type_marshaller.IntelliThreadInternal);
				internalNext.RawThread = result;
			end;
		end;
		ProximityMethods.fireComplete(nextSmartObj);
	end;

	if (selfInternal._isDone) then
		--// Добавляем pcall, так как метод безопасный
		pcall(function() task.spawn(wrapper); end);
	else
		table.insert(selfInternal._onComplete, wrapper);
	end;

	return nextSmartObj;
end;

function ProximityMethods:andClear(): (type_marshaller.IntelliThread)
	local selfInternal = (self :: any) :: (type_marshaller.IntelliThreadInternal);

	local currentThread = selfInternal.RawThread;
	local isDone        = selfInternal._isDone;

	if (currentThread and not isDone) then
		local status = coroutine.status(currentThread);
		if (status == "suspended" or status == "running") then
			task.cancel(currentThread);
		end;
	end;

	return self :: (any);
end;

--// constructor lego
function ProximityMethods.createIntelliThread(): (type_marshaller.IntelliThread)
	local smartObj: (type_marshaller.IntelliThreadInternal) = {
		RawThread    = nil;
		_onComplete  = {};
		_isProtected = false;
		_isDone      = false;
	};
	return setmetatable(smartObj, TaskProximity) :: (any);
end;

function ProximityMethods.fireComplete(smartObj: type_marshaller.IntelliThread): ()
	local internal = smartObj :: (type_marshaller.IntelliThreadInternal);
	internal._isDone = true;
	for _, callback in internal._onComplete do
		task.spawn(callback, internal.RawThread);
	end;
	table.clear(internal._onComplete);
end;

return function(a)
	TaskManager = a;

	return setmetatable({}, {
		__index = ProximityMethods,
		__newindex = function(): () 
			error("Cannot write new index to protected table", 2);
		end,
		__metatable = "The metatable is locked",
	});
end;
