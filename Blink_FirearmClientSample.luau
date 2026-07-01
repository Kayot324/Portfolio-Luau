local Tool = script.Parent :: Tool;
local Mod  = script:WaitForChild("Cfg", 5) :: ModuleScript;

-- оборачивает кучу в изолированый блок кода
(function()
	
	--// инициатор
	const global = require("@game/ReplicatedStorage/Storage/Modules/global");
	
	-- сервисы \ модули
	const TweenService     = global.services.TweenService;
	const RunService       = global.services.RunService;
	const UserInputService = global.services.UserInputService
	
	const ClientNetwork  = require(global.client.Modules.Static.Blink.Client);
	const Spring         = require(global.client.Modules.Public.Spring);
	const TypeMath       = global.modules.Math;
	const Util           = global.modules.Util;
	const Knit           = global.modules.Knit;
	const AnimController = Knit.GetController("AnimationController");

	const Priorities    = global.settings.Firearms.Priorities;
	const _, Config     = global:worry(require, Mod);

	-- импорт сюда чтобы роблох не нагружался от ссылок
	const rand    = math.random;
	const rad     = math.rad;
	const abs     = math.abs;
	const task    = task;
	const rand2   = TypeMath.Randomize2;
	
	-- это ты типо
	local Camera    = workspace.CurrentCamera;
	local Player    = global.me;
	local Character = Player.Character or Player.CharacterAdded:Wait();
	local Humanoid  = Character:WaitForChild("Humanoid")          :: Humanoid;
	local Animator  = Humanoid:FindFirstChildWhichIsA("Animator") :: Animator;
	
	local OffsetFolder: Folder; --> Папка где хранятся значения для вьюмодельки
	const Handle = Tool:FindFirstChild(Config.HandleName);
	
	-- всякая хуйня
	const Animations = {}; --> готовый к работе анимации 
	const ClientData = {
		FirstEquip = true;
		LastFire   = 0;
		Firemode   = {1, "Semi"};
	}; --> всякая динмаическая инфа типо лазера и модификаций
	const Offsets    = {}; --> для вьюмодели
	const Points     = {}; --> для оригинальных аттачментов (не вьюмодельных)
	const Bin        = {}; --> шлакоблок
	const Springs    = {}; --> хранилка для пружинок
	
	-- переменные
	local Aiming    = false;
	local Equipped  = false;
	local Switching = false;
	local Reloading = false;
	local Holding   = false; --> жмет ли игрок левую мышку
	local FireDelay = false; --> задержка перед след. выстрелом RPM
	local Holsting  = false; --> убрано ли оружие в безопасное состояние (но не в инвентарь йоу)
	
	local CurrentAimTween = nil;
	local CurrentFovTween = nil;
	
	local Magazine  = Config.Settings.Magazine :: number;

	--// ФУНКЦИИ СУЧКИ \\--
	
	-- Создаёт новый Tween.
	local function Tween(Obj: Instance, Info: TweenInfo, Values: {any?}): (Tween)
		return TweenService:Create(Obj, Info, Values);
	end;
	
	-- Возращает вьюмодельку, если её нету, вернёт nil.
	local function GetViewmodel(): (Model)
		return if _G.VM and _G.VM.CloneTool then _G.VM.CloneTool else nil;
	end;
	
	local function SetBackpackStatus(b: boolean): ()
		return global.services.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, b);
	end;
	
	local function TrackAttribute(Name: string, Func: () -> (any?)?): ()
		return table.insert(Bin, Tool:GetAttributeChangedSignal(Name):Connect(Func));
	end;
	
	local function GetViewmodelObject(Name: string): (BasePart | Attachment | Model | GuiObject)
		if GetViewmodel() and GetViewmodel():FindFirstChild(Name, true) then
			return GetViewmodel():FindFirstChild(Name, true);
		end;
	end;
	
	-- Создает новую пружину
	local function CreateSpring(Name: string, Start: Vector3, Damper: number, Speed: number)
		local New = Spring.spring.new(Start);
		New.d    = Damper or 0;
		New.s    = Speed  or 1;
		Springs[Name] = New;
		return New;
	end;
	
	-- Создает \ меняет аттрибут, который присваевается оружию
	local function SetState(Name: string, Value: any?): ()
		return Tool:SetAttribute(Name, Value);
	end;
	
	-- Создает как его это самое то блять называется ой похуй короче
	local function CrosshairState(State: boolean | string, ...: number): ()
		
		if Config.Settings.Crosshair then
			
			if State == true then
				
				local Crosshair = global.client.Instances.Interface.Crosshair:Clone();
				local Billboard = Crosshair.BillboardGui;

				Billboard.ExtentsOffsetWorldSpace = Config.Settings.Crosshair.Offset or Vector3.new();
				Billboard.Enabled = true;
				
				ClientData.CrosshairData = {
					Length     = 0;
					Velocity   = 0;
					BaseLength = Config.Settings.Crosshair.MaximumLength or 9;
				};

				Crosshair.Parent = workspace.Terrain;
				Bin.Crosshair = Crosshair;
				
			elseif State == false and Bin.Crosshair then

				Bin.Crosshair:Destroy();
				ClientData.CrosshairData = nil;
								
			elseif State == 'Transparency' and Bin.Crosshair then
				
				const Crosshair = Bin.Crosshair :: Part;
				const Num = ... :: number;
				
				for _, Obj: GuiObject in pairs(Crosshair.BillboardGui.Frame.Crosshair:GetDescendants()) do
					if Obj:IsA("Frame") then Tween(Obj, TweenInfo.new(0.5), {BackgroundTransparency = Num}):Play(); end;
				end;
				
			end;
			
		end;
		
	end;
	
	-- функция для рендеринга прицела
	local function CrosshairRender(DT: number): ()
		
		const Crosshair = Bin.Crosshair;
		const Directory = Config.Settings.Crosshair;
		const Data = ClientData.CrosshairData;
		
		if Crosshair and Data and Equipped then
			
			const Damper     = Directory.Dampering or 0;
			const Length     = Data.Length;
			const BaseLength = Data.BaseLength;
			const Velocity   = Data.Velocity;
			
			local Force   = (BaseLength - Length) * Damper;
			Data.Velocity = Velocity + (Force - Velocity * Damper) * DT;
			Data.Length   = Length + Velocity * DT;
			
		end;
		
	end;
	
	-- Пушает симулировать отдачу на кроссхеер
	local function SimulateCrosshair(Force: number): ()
				
		const Directory = Config.Settings.Crosshair;
		const Data = ClientData.CrosshairData;
		
		if Directory and Data then
			ClientData.CrosshairData.Velocity = Data.Velocity + Force;
		end;
		
	end;
	
	-- Отображает информацию о оружии
	local function SetTableInfo(b: boolean): ()
		
		const Gui = global.GetCoreUi();
		
		if Gui and Gui:FindFirstChild("ItemStatusTab", true) then
			
			const Frame = Gui:FindFirstChild("ItemStatusTab", true) :: Frame;
			const Main  = Frame.Main :: Frame;
			
			if b == true then
				
				Frame.Visible = true;
				
				for _, Obj in pairs(Frame:GetDescendants()) do

					if Obj:IsA("TextLabel") then
						Tween(Obj, TweenInfo.new(0.15), {TextTransparency = 0}):Play();
					elseif Obj:IsA("ImageLabel") then
						Tween(Obj, TweenInfo.new(0.15), {ImageTransparency = 0.75}):Play();
					end;

				end;

				Tween(Main, TweenInfo.new(0.35), {Size = UDim2.new(18.45, 0, 1, 0)}):Play();
				
				task.delay(0.35, function()
					
					if Magazine <= 0 then Main.Counters.Magazine.TextColor3 = Color3.new(1, 0, 0); else Main.Counters.Magazine.TextColor3 = Color3.new(1, 1, 1); end;
					if (Tool:GetAttribute("Ammo") or 0) <= 0 then Main.Counters.Ammo.TextColor3 = Color3.new(1, 0, 0); else Main.Counters.Ammo.TextColor3 = Color3.new(1, 1, 1); end;

					Main.NameTab.NameLabel.Text = Config.Name;
					Main.Counters.Firemode.Text = ClientData.Firemode[2] or '';
					Main.Counters.Ammo.Text = Tool:GetAttribute("Ammo") or '???';
					Main.Counters.Magazine.Text = tostring(Magazine);
					Main.WeaponIcon.Image = Tool.TextureId or '';
					
				end);
				
			elseif b == false then
				
				for _, Obj in pairs(Frame:GetDescendants()) do

					if Obj:IsA("TextLabel") then
						Tween(Obj, TweenInfo.new(0.17), {TextTransparency = 1}):Play();
					elseif Obj:IsA("ImageLabel") then
						Tween(Obj, TweenInfo.new(0.17), {ImageTransparency = 1}):Play();
					end;

				end;

				Tween(Frame.Main, TweenInfo.new(0.35), {Size = UDim2.new(0, 0, 1, 0)}):Play();
				
				task.delay(0.35, function()
					
					Frame.Visible = false;
					Main.NameTab.NameLabel.Text = '';
					Main.Counters.Firemode.Text = '';
					Main.Counters.Ammo.Text = ''
					Main.Counters.Magazine.Text = '';
					Main.WeaponIcon.Image = '';

					Main.Counters.Ammo.TextColor3 = Color3.new(1, 1, 1);
					Main.Counters.Magazine.TextColor3 = Color3.new(1, 1, 1);
					
				end);
				
			elseif b == 'Update' then
				
				if Magazine <= 0 then Main.Counters.Magazine.TextColor3 = Color3.new(1, 0, 0); else Main.Counters.Magazine.TextColor3 = Color3.new(1, 1, 1); end;
				if (Tool:GetAttribute("Ammo") or 0) <= 0 then Main.Counters.Ammo.TextColor3 = Color3.new(1, 0, 0); else Main.Counters.Ammo.TextColor3 = Color3.new(1, 1, 1); end;
				
				Main.NameTab.NameLabel.Text = Config.Name;
				Main.Counters.Firemode.Text = ClientData.Firemode[2] or '';
				Main.Counters.Ammo.Text = Tool:GetAttribute("Ammo") or '???';
				Main.Counters.Magazine.Text = tostring(Magazine);
				Main.WeaponIcon.Image = Tool.TextureId or '';
				
			end;
			
		end;
		
	end;
	
	-- Ищет функцию в конфиге оружия, которую нужно исполнить. Если функция не найдена, ничего не будет ахуеть да
	local function GetAndCall(Name: string, ...): ()
		local Directory = Config.SpecialEffects;
		if Directory[Name] and type(Directory[Name]) == 'function' then Directory[Name](...); end;
	end;
	
	-- Возращает время с модификатором
	local function GetModifierTime(x: number): (number)
		if x == 1 then return 1; end;
		return (1 / x);
	end;
	
	-- Возращает модификатор из клиентской даты таблицы
	local function GetModifier(Name: string): (number | string | Vector3 | Color3)
		if ClientData[Name] then
			return ClientData[Name];
		end;
	end;
	
	-- Очищает память от всего: анимации, связи, цепи, рутины.
	local function CleanGarbage(): ()
		
		AnimController:ClearAllWeaponAnimations();
		Util.CleanConnections(Bin);
		
		for Name, Spring in pairs(Springs) do
			Springs[Name] = nil;
			Spring = nil;
		end;
		
	end;
	
	-- Аккселерация пружинки
	local function Accelerate(Spring, Target: Vector3): ()
		Spring:Accelerate(Target);
	end;
	
	-- Пушает пружину симулировать отдачу для вьюмодели (рендерится в Render)
	local function SimulateProceduralRecoil(): ()
		
		local Directory = Config.Settings.FireProceduralAnimation;

		local CurrentPosition = Offsets.RecoilPosition;
		local CurrentAngle    = Offsets.RecoilAngle;

		local Kickback = Vector3.new(0, 0, rand(Directory.KickbackStrength.Min, Directory.KickbackStrength.Max));
		local Angle    = Vector3.new(
			rand(Directory.Angle.X.Min, Directory.Angle.X.Max) * 0.85,
			rand(Directory.Angle.Y.Min, Directory.Angle.Y.Max),
			rand(Directory.Angle.Z.Min, Directory.Angle.Z.Max)
		);
		
		Offsets.RecoilPosition = Kickback;
		Offsets.RecoilAngle    = Angle;
		
		table.insert(Bin, task.spawn(function()
			
			Accelerate(Springs["RecoilPosition"], Kickback);
			Accelerate(Springs["RecoilAngle"], Angle);

			local startTime = os.clock();
			while (os.clock() - startTime) < (Directory.EndSpeed or 0.1) do
				RunService.RenderStepped:Wait();
			end;

			Accelerate(Springs["RecoilPosition"], Vector3.new());
			Accelerate(Springs["RecoilAngle"], Vector3.new());
			
		end));
		
	end;
	
	-- Симуляция отдачи ебать при помощи камеры нахуй
	local function SimulateCameraRecoil(): ()
		
		local Directory = Config.Settings.Recoil;
		
		if Directory.Allowed then
			
			local Power = Directory.Power       :: number;
			local Accuracy = Directory.Accuracy :: number;

			local Spring = Springs["RecoilCamera"];
			local RecoilMultiplier = Power * (Aiming and 1 - Directory.AimRedution or 1);
			local RecoilVector     = Vector3.new(
				rad(RecoilMultiplier * rand2(Directory.X.Min, Directory.X.Max, Accuracy)),
				rad(RecoilMultiplier * rand2(Directory.Y.Min, Directory.Y.Max, Accuracy)),
				rad(RecoilMultiplier * rand2(Directory.Z.Min, Directory.Z.Max, Accuracy))
			);
			
			-- отделяемся qje
			table.insert(Bin, task.spawn(function()
				
				local Start = os.clock();
				
				Accelerate(Spring, RecoilVector);
				
				while (os.clock() - Start) < Directory.EndSpeed do
					RunService.Heartbeat:Wait();
				end;

				Accelerate(Spring, -RecoilVector * 0.6);

			end));
			
		end;
		
	end;
	
	-- Рендеринг вьюмодели, позиции, пружин, и прочей хуеты
	local function Render(): ()
		
		Bin.Render = RunService.Heartbeat:Connect(function(dt: number): ()
			
			const Pos, Ang = Springs.RecoilPosition, Springs.RecoilAngle;
			const Rec = Springs.RecoilCamera;
			const Crosshair = Bin.Crosshair;
			
			if Pos and Ang then
				
				local RecoilPos   = Vector3.new(Pos.p.X, Pos.p.Y, Pos.p.Z);
				local RecoilAngle = Vector3.new(Ang.p.X, Ang.p.Y, Ang.p.Z);
				
				-- нахуй вообще так делают я не понимаю хуйня какая то
				Offsets.Values.Recoil_Offset.Value = RecoilPos;
				Offsets.Values.Recoil_Angle.Value  = RecoilAngle;
				
			end;
			
			if Rec then
				Camera.CFrame = Camera.CFrame * CFrame.fromEulerAnglesXYZ(Rec.p.X, Rec.p.Y, Rec.p.Z);
			end;
			
			if Crosshair and ClientData.CrosshairData then
				
				local Point = Points.FirePoint;
				local Billboard = Crosshair.BillboardGui.Frame.Crosshair;
				local Length = ClientData.CrosshairData.Length;
				
				if GetViewmodel() and GetViewmodelObject("FirePoint") and shared.FP() then
					Point = GetViewmodelObject("FirePoint");
				end;
				
				CrosshairRender(dt);
				Crosshair.CFrame = Point.WorldCFrame;
				
				Billboard.Top.Position    = UDim2.new(0.5, 0, 0.48, -Length);
				Billboard.Bottom.Position = UDim2.new(0.5, 0, 0.52, Length);
				
				Billboard.Left.Position  = UDim2.new(0.48, -Length, 0.5, 0);
				Billboard.Right.Position = UDim2.new(0.52, Length, 0.5, 0);
				
			end;
			
		end);
		
	end;
	
	-- Переключение режима огня
	local function Switch(): ()
		
		if Config.Settings.Firemodes and (not FireDelay and not Reloading and Equipped and not Switching) then
			
			Switching = true;
			
			local Directory   = Config.Settings.Firemodes;
			local Time        = Directory.Time or 0;
			local CurrentMode = ClientData.Firemode[1] :: number;
			
			if #Directory <= ClientData.Firemode[1] then
				ClientData.Firemode[1] = 1;
				ClientData.Firemode[2] = Directory[1];
			else
				ClientData.Firemode[1] = ClientData.Firemode[1] + 1;
				ClientData.Firemode[2] = Directory[ClientData.Firemode[1]];
			end;
			
			AnimController:PlayWeaponAnimation('Switch', 0.3);
			SetTableInfo('Update');
			
			if Time > 0 then
				task.wait(Time);
			end;
			
			Switching = false;
			
		end;
		
	end;
	
	-- Логика прицеливания типо йоу да
	local function Aim(): ()
		
		local Directory = Config.Settings.AimSettings;
		
		if Directory and shared.FP() then
		
			-- сброс активного треда если он вообще сука появится
			if Aiming then Aiming = false; end;
			if Bin.AimTask then task.cancel(Bin.AimTask); Bin.AimTask = nil; end;
		
			Aiming    = true;
			_G.ISADSZ = true;

			if CurrentAimTween then CurrentAimTween:Cancel() end;
			if CurrentFovTween then CurrentFovTween:Cancel() end;

			GetAndCall('OnAiming', true, Tool);

			local AimingOffset = Directory.AimOffset   or Vector3.new();
			local AimingFOV    = Directory.AimFOV      or 70;
			local AimingSpeed  = Directory.AimInSpeed  or 0.5;
			local FovInSpeed   = Directory.FOVIn       or 0.5;
			local Sensetive    = Directory.AimSenstive or 0.5;
			
			UserInputService.MouseDeltaSensitivity = Sensetive;
			
			CurrentAimTween = Tween(Offsets.Values.FP_Offset, TweenInfo.new(AimingSpeed, Enum.EasingStyle.Exponential), {Value = AimingOffset});
			CurrentFovTween = Tween(Camera, TweenInfo.new(FovInSpeed, Enum.EasingStyle.Exponential), {FieldOfView = AimingFOV});

			CurrentAimTween:Play();
			CurrentFovTween:Play();
			
			CrosshairState("Transparency", 1);
		
			Bin.AimTask = task.spawn(function()
				
				while task.wait() do
					
					if (not Aiming or
						not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)) or
						Holsting or
						not shared.FP()
					then
						
						Aiming    = false;
						_G.ISADSZ = false;

						if CurrentAimTween then CurrentAimTween:Cancel() end;
						if CurrentFovTween then CurrentFovTween:Cancel() end;
						if Equipped then CrosshairState("Transparency", 0.3); end;

						GetAndCall('OnAiming', false, Tool);

						local AimingSpeed  = Directory.AimOutSpeed or 0.5;
						local FovInSpeed   = Directory.FOVOut      or 0.5;

						CurrentAimTween = Tween(Offsets.Values.FP_Offset, TweenInfo.new(AimingSpeed, Enum.EasingStyle.Exponential), {Value = Offsets.StartPosition});
						CurrentFovTween = Tween(Camera, TweenInfo.new(FovInSpeed, Enum.EasingStyle.Exponential), {FieldOfView = 70});

						CurrentAimTween:Play();
						CurrentFovTween:Play();
						
						UserInputService.MouseDeltaSensitivity = 1;
						
						break;
					end;
					
				end;
				
			end);
		
		end;
		
	end;
	
	-- Ну стрельба да
	local function Fire(): ()
		
		local RPM = 60 / Config.Settings.RPM;
		if Magazine > 0 and (not FireDelay and not Reloading and Equipped and (os.clock() - ClientData.LastFire) >= RPM) then
			
			FireDelay = true;
			Magazine -= 1;
			
			local Point = Points.FirePoint :: Attachment;
			
			if (GetViewmodel() and GetViewmodelObject("FirePoint") and shared.FP()) then
				Point = GetViewmodelObject("FirePoint");
			end;
					
			
			local Origin    = Point.WorldCFrame.Position;
			local Direction = Point.WorldCFrame.LookVector;
			
			
			ClientNetwork.Shoot.Fire({
				Origin = Origin, 
				Direction = Direction,	
			});
			
			AnimController:PlayWeaponAnimation('Fire', 0.1);
			SimulateProceduralRecoil();
			SimulateCameraRecoil();
			
			local TotalForce = (Offsets.RecoilPosition.Magnitude + Offsets.RecoilAngle.Magnitude);
			SimulateCrosshair(TotalForce);
			SetTableInfo('Update');
			
			task.wait(RPM);
			
			FireDelay = false;
			
		end;
		
	end;
	
	-- Вызывается, когда игрок хочет перезарядится
	local function Reload(): ()

		if Reloading or FireDelay or not Equipped then return; end;
		local WasEmpty = (Magazine <= 0);
		local Success, Response = ClientNetwork.Reload.Invoke("RequestReload"):await();

		if Success and Response and Response.CanReload then
			
			do
				
				GetAndCall('OnReloading', true, Magazine, Tool);
				SetBackpackStatus(false);

				local Anim     = 'Reload';
				local Time     = 0;

				if (AnimController:GetWeaponAnimation('Reload', true) and WasEmpty) or not AnimController:GetWeaponAnimation('TacticalReload', true) then
					Time = Config.Settings.ReloadTime or 0;
				elseif (not AnimController:GetWeaponAnimation('Reload', true) or not WasEmpty) and AnimController:GetWeaponAnimation('TacticalReload', true) then
					Anim = 'TacticalReload';
					Time = Config.Settings.TacticalReload or 0;
				end;

				Reloading = true;
				AnimController:PlayWeaponAnimation(Anim, 0.3);

				Bin.ReloadTask = task.delay(Time, function()
					Magazine  = Response.NewMagazine; 
					Reloading = false;
					SetTableInfo('Update');
					SetBackpackStatus(true);
				end);
				
			end;
			
		end;

	end;
	
	local function KeyDetection(): ()
		
		local Directory = Config.Settings.AimSettings;

		Bin.KeyRenderingBegan = UserInputService.InputBegan:Connect(function(Input, Processed): ()
			
			if Processed then return end;

			local UserInput = Input.UserInputType;
			local KeyCode   = Input.KeyCode;

			if KeyCode == Enum.KeyCode.R then
				Reload();
			elseif KeyCode == Enum.KeyCode.V then
				Switch();
			end;

			if UserInput == Enum.UserInputType.MouseButton1 and not ClientData.__env_getgc then
				
				Holding = true;
				
				local Mode = ClientData.Firemode[2];
				
				if Mode == 'Auto' then
					
					repeat
						Fire();
					until not Holding or Magazine <= 0 or not Equipped or Reloading;
					
				elseif Mode == 'Burst' then
					
					local CurrentlyShooting = ClientData.__env_getgc or false;
					
					if not CurrentlyShooting then
						
						ClientData.__env_getgc = true;
						local Repeats = Config.Settings.BurstShots or 3;

						repeat
							Fire();
							Repeats -= 1;
						until Repeats <= 0 or Magazine <= 0 or not Equipped or Reloading or not ClientData.__env_getgc;
						
						ClientData.__env_getgc = nil;
						
					end;
					
				else
					Fire();
				end;
				
			elseif UserInput == Enum.UserInputType.MouseButton2 then
				Aim();
			end;

		end);

		Bin.KeyRenderingEnded = UserInputService.InputEnded:Connect(function(Input, Processed): ()

			local UserInput = Input.UserInputType;

			if UserInput == Enum.UserInputType.MouseButton1 then
				Holding = false;
			end;

		end);

	end;
	

	-- Вызывается, когда оружие было убрано в инвентарь
	local function OnUnequip(): ()
		
		CrosshairState(false);
		
		Equipped  = false;
		Reloading = false;
		Holsting  = false;
		Holding   = false;
		Aiming    = false;
		
		UserInputService.MouseDeltaSensitivity = 1;
		UserInputService.MouseIconEnabled = true;
		
		SetTableInfo(false);
		CleanGarbage();

	end;
	
	-- Вызывается, когда оружие было экипировано
	local function OnEquip(): ()

		AnimController:LoadWeaponAnimations(Config.Animations);
		UserInputService.MouseIconEnabled = false;
		
		Magazine = Tool:GetAttribute("Magazine") or Magazine;
		TrackAttribute("Magazine", function(): ()
			Magazine = Tool:GetAttribute("Magazine") :: (number);
		end);
		
		SetBackpackStatus(false);

		if Config.Settings.FireProceduralAnimation then

			local Directory = Config.Settings.FireProceduralAnimation;

			CreateSpring("RecoilAngle", Vector3.new(), Directory.Damper, Directory.StartSpeed);
			CreateSpring("RecoilPosition", Vector3.new(), Directory.Damper, Directory.StartSpeed);

		end;

		if Config.Settings.Recoil and Config.Settings.Recoil.Allowed then
			local Directory = Config.Settings.Recoil;
			CreateSpring("RecoilCamera", Vector3.new(), Directory.Damper, Directory.Speed);
		end;

		local Time = 0;
		local Anim = 'Equip';

		if ClientData['FirstEquip'] and AnimController:GetWeaponAnimation("FirstEquip", true) then
			ClientData["FirstEquip"] = nil;
			Anim = 'FirstEquip';
			Time = Config.Settings.FirstEquip or 0;
		elseif AnimController:GetWeaponAnimation('Equip', true) then
			Time = Config.Settings.EquipTime or 0;
		end;

		AnimController:PlayWeaponAnimation('Idle', nil, nil, nil);
		AnimController:PlayWeaponAnimation(Anim, 0.3, nil, nil);

		table.insert(Bin, task.delay(Time, function()
			
			SetBackpackStatus(true);
			
			Render();
			KeyDetection();
			
			SetTableInfo(true);
			CrosshairState(true);
			
			CrosshairState("Transparency", 0.3);
			SimulateCrosshair(Config.Settings.Spread or 0);
			
			Equipped = true;
		end));

		table.insert(Bin, Humanoid.Died:Once(function()
			OnUnequip();
		end));

	end;
	
	-- Запускается только один раз за клиент. Вызывается, когда клиент попадает в оружие.
	local function OnLoad(): ()
		
		debug.profilebegin("_getgcload");
		
		if (Character and Tool and Player) and
			(Tool:IsDescendantOf(Character) and Player.Character == Character)
		then
			
			Points.FirePoint  = Tool:FindFirstChild("FirePoint",  true) or nil;
			Points.EjectPoint = Tool:FindFirstChild("EjectPoint", true) or nil;
			Points.SoundPoint = Tool:FindFirstChild("SoundPoint", true) or nil;
			
			local Total = 0;
			for _, _ in pairs(Points) do
				Total += 1;
			end;
		
			-- сначала проверяет на базовые компачи оружия
			if Total ~= 3 then
				script:Destroy();
				return warn("[Firearm-Client]: Client presetup failed");
			end;
			
			-- пошел нахуй из памяти
			Total = nil;
			
			-- здесь логика загрузки короче
			if Tool:FindFirstChild("Offsets") then

				OffsetFolder = Tool:FindFirstChild("Offsets");

				Offsets.StartPosition  = OffsetFolder.FP_Offset.Value;
				Offsets.StartAngle     = OffsetFolder.FP_Offset_Angle.Value;
				Offsets.RecoilPosition = Vector3.new(0, 0, 0);
				Offsets.RecoilAngle    = Vector3.new(0, 0, 0);

				Offsets.Values = {

					--// дефолтные
					FP_Offset = OffsetFolder.FP_Offset;
					FP_Angle  = OffsetFolder.FP_Offset_Angle;

					--// для имитации отдачи
					Recoil_Offset = OffsetFolder.FP_Offset4;
					Recoil_Angle  = OffsetFolder.FP_Offset_Angle2;

				};

			end;
			
			if Config.Settings.Firemodes then
				ClientData.Firemode = {1, Config.Settings.Firemodes[1]};
			end;
			
			SetState('Equipped',     false);
			SetState('FireDebounce', false);
			SetState('Reloading',    false);
			SetState('Holsting',     false);
			
			Tool.Equipped:Connect(OnEquip);
			Tool.Unequipped:Connect(OnUnequip);
			
			debug.profileend("_getgcload");
			
		else
			-- если валидацию не прошел - пошел нахуй
			debug.profileend("_getgcload");
			script:Destroy();
			return warn("[Firearm-Client]: Client validation not passed");
		end;
		
	end;
	
	OnLoad();
	
end)();

-- чистим память
Mod  = nil;
