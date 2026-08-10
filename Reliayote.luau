--!strict
--!optimize 2

--[[
	hi im kayote im dumbass and i have zero knowledge in programming but i like do larp like larp coding you know yeah
	also please please PLEASE PLEASE ignore that every gawd dayum function or 99% of string will contain "yote" or "oyote" or kayote
	
	guhhuhuhuu wululuululluluu
]]

local Reliayote  = {};
local TypeSolver = require(script.TypeSolver);
local Types      = require(script.TypeMarshaller);


--[[Wraps function with arguments (optional) to a defered-spawned task]]
Reliayote.Wrap = function(f: (...any) -> (...any), ...): (thread | nil)
	
	if TypeSolver.StrictIsA(f, "function") then
		return task.defer(task.spawn, f, ...);
	end;
	
	return nil;
end;

--[[Wraps function with arguments (optional) to a protected enviroment]]
Reliayote.ProtectedCall = function(f: (...any) -> (...any), ...): (boolean, any)
	
	if TypeSolver.StrictIsA(f, 'function') then
		return pcall(f, ...)
	end;
	
	return false, "#1 argument is not a function";
end;

--[[Throttles a function, preventing it from being called more than once every <strong>duration</strong> seconds]]
Reliayote.ThottlingCall = function(f: (...any) -> (...any), duration: number): (...any)
	
	if (not TypeSolver.StrictIsA(f, "function") or not TypeSolver.StrictIsA(duration, "number")) then
		return;	
	end;
	
	local lastCall = 0;
	return function(...: any): ()
		local now = os.clock();
		if (now - lastCall) >= duration then
			lastCall = now;
			task.spawn(f, ...);
		end;
	end;
end;

--[[Retries a protected call <strong>attempts</strong> times if it fails before throwing an error]]
Reliayote.RetryingCall = function(attempts: number, delayTime: number, f: () -> (), ...): (...any)
	if not TypeSolver.StrictIsA(f, "function") then 
		return false, "#3 argument is not a function"; 
	end;

	local success: (boolean), result: (any);
	for i = 1, attempts do
		success, result = pcall(f, ...);
		if success then 
			return true, result; 
		end;
		if i < attempts then 
			task.wait(delayTime); 
		end;
	end;

	return false, result;
end;

--[[Runs a function in a protected environment (optional) with a maximum execution time limit]]
Reliayote.Timeout = function(limit: number, f: (...any) -> (...any), ...: any): (boolean, any)
	if not TypeSolver.StrictIsA(f, "function") then 
		return false, "#2 argument is not a function"; 
	end;

	local currentThread = coroutine.running();
	local finished = false;
	local success, result;

	--// cock is ticking
	task.delay(limit, function()
		if not finished then
			task.cancel(currentThread);
			task.spawn(currentThread, false, "Execution timed out"); --// oh noes
		end;
	end);

	--// completion
	success, result = pcall(function(...: any)
		local res = {f(...)};
		finished = true;
		return table.unpack(res);
	end, ...);

	return success, result;
end;

--[[Wraps a function ensuring it will execute strictly once, caching and returning the first result later]]
Reliayote.Once = function(f: (...any) -> (...any)): (...any) -> (...any)
	if TypeSolver.StrictIsA(f, "function") then 
		local exec = false;
		local results: {any} = {};

		return function(...: any): ...any
			if not exec then
				exec = true;
				results = {f(...)};
			end;
			return table.unpack(results);
		end;
		
	end;

	return function() end;
end;

--[[Creates a proxy wrapper around table to track and log any changes with a debug traceback]]
Reliayote.CreateProxy = function(OriginalTable: {[any]: any}, ProxyName: string?, RecursiveProxy: boolean?): (any)
	
	if (not TypeSolver.IsA(OriginalTable, "table")) then
		return error(string.format("%s, #1 argument must be a table", tostring(TypeSolver)));
	end;

	local Name = ProxyName or "ProtectedTable";
	local Proxy = {};

	local ProxyMeta = {
		
		__index = function(tbl, key)
			
			local value = rawget(OriginalTable, key);
			--// recursive proxy thing (if option is on)
			if typeof(value) == "table" and RecursiveProxy == true then
				local subProxyName = string.format("%s.%s", Name, tostring(key));
				return Reliayote.CreateProxy(value, subProxyName);
			end;

			return value;
		end;

		--// attempting to detect changes
		__newindex = function(tbl, key, value)
			local oldValue = rawget(OriginalTable, key);

			print(string.format("\n--- Protected proxy changed '%s' ---", Name));
			print(string.format("Key Changed:  [%s]", tostring(key)));
			print(string.format("Old Value:    %s", tostring(oldValue)));
			print(string.format("New Value:    %s", tostring(value)));
			print("--- end of changes ---");

			warn(debug.traceback());
			print("---------------------------------------\n");

			--// writing to original table
			rawset(OriginalTable, key, value);
		end;

		--// protecting from other scritps bluuh
		__metatable = "* Reliayote locked *";
		__tostring = function()
			return string.format("Proxy wrapper for '%s'", Name);
		end;
	};

	return setmetatable(Proxy, ProxyMeta);
end;

--[[
	Transforms a table into an observable state object that fires a signal every time any key is updated.
	<strong>TableCleanFireChanges</strong>: determines should proxy fire Changed event when table was cleaned via <code>.clear</code> (by default: <code>true</code>).
]]
Reliayote.CreateEventoyte = function(OriginalTable: {[any]: any}, TableCleanFireChanges: boolean?): (Types.Eventoyte)
	
	if not TypeSolver.IsA(OriginalTable, "table") then
		return error(string.format("%s, #1 argument must be a table", tostring(TypeSolver)));
	end;
	
	if (not TypeSolver.IsNull(TableCleanFireChanges) and not TypeSolver.IsA(TableCleanFireChanges, 'boolean')) then
		return error(`{TypeSolver}, #2 argument was given, but value must be boolean, got: {typeof(TableCleanFireChanges)}`);
	end;

	--// ooohh eeeehh aaahh woooh buuuuuuuuuuuuuuuh
	local ChangedEvent = Instance.new("BindableEvent");
	local Blank = {}; --// that's whatchu get blumh
	local EventData;

	EventData = {
		
		__index = function(tbl, key: string): (...any)
			
			--// oh my good what is gooooing oonnn
			if key == "Changed" then
				
				return ChangedEvent.Event;
			elseif key == "Destroy" then
				--// more space please
				return function(): (...any)
					
					ChangedEvent:Destroy();
					table.clear(Blank);
					table.clear(OriginalTable);
				end;
			elseif key == "remove" then
				
				return function(index: number): (...any)
					
					local oldValue = OriginalTable[index];
					if oldValue ~= nil then
						table.remove(OriginalTable, index);
						ChangedEvent:Fire(index, nil, oldValue);
					end;
					
					return oldValue;
				end;
			elseif key == "insert" then
				
				return function(value: any): (...any)
					
					table.insert(OriginalTable, value);
					ChangedEvent:Fire(#OriginalTable, value, nil);
				end;
			elseif key == 'k' or key == "key" then
				
				return function(name: string, value: any): (...any)

					OriginalTable[name] = value;
					ChangedEvent:Fire("new_key", name, value);
				end;
			elseif key == "clear" then
				
				return function(): ()
					
					if #OriginalTable > 0 or next(OriginalTable) ~= nil then
						table.clear(OriginalTable);
						if TableCleanFireChanges ~= false then ChangedEvent:Fire("table_cleaned", nil, nil); end;
					end;
				end;
			end;
			
			--// i like trees but i dont touch grass anyway if elseif elseif
			
			return rawget(OriginalTable, key);
		end;

		--// catch
		__newindex = function(tbl, key, value)
			local oldValue = rawget(OriginalTable, key);

			--// set to original woooooooowww
			rawset(OriginalTable, key, value);

			--// did actually changed = fire in the holee
			if oldValue ~= value then
				ChangedEvent:Fire(key, value, oldValue);
			end;
		end;

		--// yeah yeah so cool bro
		__metatable = "* Reliayote locked *";
		__tostring = function()
			return "* Reliayote read not allowed *";
		end;
	};
	
	
	setmetatable(Blank, EventData);
	return (Blank :: (any)) :: (Types.Eventoyte);
end;

--[[Creates a table that automatically records changes and supports Undo/Redo operations]]
Reliayote.CreateStateHistoroyte = function(OriginalTable: {[any]: any}): (Types.Historyoyte)
	if not TypeSolver.IsA(OriginalTable, "table") then
		return error(string.format("%s, #1 argument must be a table", tostring(TypeSolver)));
	end;

	local History = {} :: {[number]: any}; --// stack of logies
	local CurrentPointer = 0;
	local Proxy = {};

	local HistoryMeta = {
		__index = function(tbl, key)
			--// method of last change
			if key == "undo" or key == 'u' then
				return function(): ()
					if CurrentPointer > 0 then
						local record = History[CurrentPointer];
						CurrentPointer -= 1;
						rawset(OriginalTable, record.Key, record.OldValue);
						print(string.format("Undo: [%s] вернулся к %s", tostring(record.Key), tostring(record.OldValue)));
					else
						warn("nothing to undo");
					end;
				end;
			end;

			--// rollback
			if key == "redo" or key == 'r' then
				return function(): ()
					if CurrentPointer < #History then
						CurrentPointer += 1;
						local record = History[CurrentPointer];
						rawset(OriginalTable, record.Key, record.NewValue);
						print(string.format("Redo: [%s] изменён на %s", tostring(record.Key), tostring(record.NewValue)));
					else
						warn("nothing to redo");
					end;
				end;
			end;

			return rawget(OriginalTable, key);
		end;

		__newindex = function(tbl, key, value)
			local oldValue = rawget(OriginalTable, key);

			if oldValue ~= value then
			
				if CurrentPointer < #History then
					for i = #History, CurrentPointer + 1, -1 do
						table.remove(History, i);
					end;
				end;

				--// writing dis step
				table.insert(History, { Key = key, OldValue = oldValue, NewValue = value });
				CurrentPointer = #History;
			end;

			rawset(OriginalTable, key, value);
		end;

		__metatable = "* Reliayote locked *";
	};

	return (setmetatable(Proxy, HistoryMeta) :: Types.Historyoyte);
end;

--[[Creates a table that automatically spawns sub-tables when indexing a non-existent key]]
Reliayote.CreateAutoTablyote = function(): (any)
	
	local MasterTable = {};
	local AutoMeta;
	
	AutoMeta = {
		__index = function(tbl, key)
			--// no key? ok im sorry
			local newSubTable = setmetatable({}, AutoMeta);
			rawset(tbl, key, newSubTable);
			return newSubTable;
		end;

		__metatable = "* Reliayote locked *";
	};

	return setmetatable(MasterTable, AutoMeta);
end;

Reliayote.ReplicatedPlayerBuffers = {};
Reliayote.ReplicatedDirtyPlayers  = {};

--[[ 
	<strong>[SERVER ONLY]</strong>
	Transforms a server-side state table into a high-performance buffered replicating proxy.
]]
Reliayote.CreateReplicatedState = function(OriginalTable: {[any]: any}, TargetPlayer: Player): (any)
	if not TypeSolver.IsA(OriginalTable, "table") then
		return error(string.format("%s, #1 argument must be a table", tostring(TypeSolver)));
	end;

	local PlayerBuffers = Reliayote.ReplicatedPlayerBuffers;
	local DirtyPlayers  = Reliayote.ReplicatedDirtyPlayers;

	if not PlayerBuffers[TargetPlayer] then
		PlayerBuffers[TargetPlayer] = {};
	end;

	local Proxy = {};
	local BufferedMeta = {
		__index = function(tbl, key)
			return rawget(OriginalTable, key);
		end;

		__newindex = function(tbl, key, value)
			local oldValue = rawget(OriginalTable, key);
			rawset(OriginalTable, key, value);

			if oldValue ~= value then
				PlayerBuffers[TargetPlayer][tostring(key)] = value;
				DirtyPlayers[TargetPlayer] = true;
			end;
		end;

		__metatable = "* Reliayote locked *";
	};

	TargetPlayer.AncestryChanged:Once(function()
		DirtyPlayers[TargetPlayer] = nil;
		if PlayerBuffers[TargetPlayer] then
			table.clear(PlayerBuffers[TargetPlayer]);
			PlayerBuffers[TargetPlayer] = nil;
		end;
	end);

	return setmetatable(Proxy, BufferedMeta);
end;

return setmetatable({}, {
	__index    = Reliayote;
	__newindex = function() return error("Reliayote metadata cannot be modified"); end;
	__tostring = function()
		return "Reliayote, version 0.0.1, Author: Jacket_Howla";
	end;
});
