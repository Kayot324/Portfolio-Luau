--!optimize 2
--!strict

local warn = function(...: any): ()
	warn(`[TaskManager]:`, ...);
end;

local TaskManager   = {};
local ActiveThreads = 0;

local methods          = require(script.proximity_methods)(TaskManager);
local type_marshaller  = require(script.type_marshaller);
local parallel_states  = require(script.parallel_states);


--[[
	Wraps a function execution in a protected call (pcall) with the given arguments.
]]
TaskManager.safecall = function(Function: (...any) -> (...any), ...: any): (boolean, ...any)
	return pcall(Function, ...);
end;

--[[
	Schedules a function or thread to be executed deferredly after the frame simulation ends (post-physics and animations).
]]
TaskManager.defer = function(FunctionOrThread: (...any) -> (...any) | thread, ...: any): (type_marshaller.IntelliThread)
	local smartObj = methods.createIntelliThread();

	local thread = task.defer(function(...: any)
		if (typeof(FunctionOrThread) == "function") then
			FunctionOrThread(...);
		else
			task.spawn(FunctionOrThread, ...);
		end;
		methods.fireComplete(smartObj);
	end, ...);

	(smartObj :: any).RawThread = thread;
	return smartObj;
end;

--[[
	Yields the current thread for the specified <strong>duration</strong> in seconds without throttling.
]]
TaskManager.wait = function(duration: number?): (number)
	return task.wait(duration);
end;

--[[
	Yields the current thread for a specific amount of heartbeat frames.
]]
TaskManager.waitframes = function(frames: number?): (number)

	local c = frames or 1;
	local s = os.clock();

	for _ = 1, c do
		task.wait();
	end;

	return (os.clock() - s);
end;

--[[
	Schedules a function or thread to be executed after the specified <strong>duration</strong> in seconds.
]]
TaskManager.delay = function(duration: number?, FunctionOrThread: (...any) -> (...any) | thread, ...: any): (type_marshaller.IntelliThread)
	local smartObj = methods.createIntelliThread();

	local thread = task.delay(duration, function(...: any)
		if (typeof(FunctionOrThread) == "function") then
			FunctionOrThread(...);
		else
			task.spawn(FunctionOrThread, ...);
		end;
		methods.fireComplete(smartObj);
	end, ...);

	(smartObj :: any).RawThread = thread;
	return smartObj;
end;

--[[
	Instantly schedules a function or thread to run on a new thread within' the task scheduler.
]]
TaskManager.spawn = function(FunctionOrThread: (...any) -> (...any) | thread, ...: any): (type_marshaller.IntelliThread)
	local smartObj = methods.createIntelliThread();

	local thread = task.spawn(function(...: any)
		if (typeof(FunctionOrThread) == "function") then
			FunctionOrThread(...);
		else
			task.spawn(FunctionOrThread, ...);
		end;
		methods.fireComplete(smartObj);
	end, ...);

	(smartObj :: any).RawThread = thread;
	return smartObj;
end;

--[[
	<strong>[SAFE-CALLABLE]</strong>
	Cancels the specified thread and prevents it from being resumed.
]]
TaskManager.cancel = function(thread: thread): ()
	if typeof(thread) == "thread" then
		local status = coroutine.status(thread);

		if (status == "suspended" or status == "running") then
			task.cancel(thread);
		end;

	end;
end;

--[[
	<strong>[PLANNER CONTEXT]</strong>
	Shifts the current thread execution back to serial mode, returning to the main processor thread.
	Must be invoked when parallel code needs to access non-thread-safe Luau resources.
]]
TaskManager.synchronize = function(): ()
	if parallel_states.IsParallel() then return task.synchronize(); end;
	warn("Skipped synchronization attempt; the thread is already running in serial mode.");
end;

--[[
	<strong>[PLANNER CONTEXT]</strong>
	Shifts the current thread execution to parallel mode for high-loaded network or heavy native math processing.
	Must be executed from within an Actor instance context.
]]
TaskManager.desynchronize = function(): ()
	if not parallel_states.IsParallel() then task.desynchronize(); end;
	warn("Skipped desynchronization attempt; the thread is already running in parallel mode.");
end;


return setmetatable({}, {
	__index    = TaskManager,
	__newindex = function(): () 
		error("Cannot write new index to protected table", 2);
	end,
	__metatable = "The metatable is locked",
});
