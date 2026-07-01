--!optimize 2

const warn = function(...): ()
	warn("[Combat]: ", ...);
end;

local global        = require(script.Parent.Parent.global);
local ServerNetwork = require(global.client.Modules.Static.Blink.Server);

local Knit          = global.modules.Knit;
local Util          = global.modules.Util;

local Players        = global.services.Players;
local CombatService  = Knit.CreateService { Name = "CombatService", Timers = { Reload = {}, Fire = {} }, Client = {} };
local NetworkService;

local random = math.random;
local rad    = math.rad;
local clamp  = math.clamp;
local floor  = math.floor;
local min    = math.min;


local function GetWallThickness(Result: RaycastResult, EndPoint: Vector3): (number)
	
	local Hit       = Result.Instance :: (BasePart);
	local Position  = Result.Position;
	local Direction = (EndPoint - Position).Unit;
	local Start     = Result.Position + (Direction * 20);
	
	local PierceResult = Util.Rustcast(Start, -Direction * 20, "Include", {Hit});
	
	if PierceResult then
		return (PierceResult.Position - Position).Magnitude;
	else
		return Hit.Size.Magnitude;
	end;
	
end;

local function GetInstanceFromAny(Obj: Instance): (Model)
	
	if Obj and not Obj:IsA("Model") and not Obj:FindFirstChildWhichIsA("Humanoid") then
		
		local Model = Obj:FindFirstAncestorWhichIsA("Model");
		
		if Model and Model:FindFirstChildWhichIsA("Humanoid") then
			return Model;
		end;
		
	elseif Obj and Obj:IsA("Model") and Obj:FindFirstChildWhichIsA("Humanoid") then
		return Obj;
	end;
	
end;

local function IsHead(Obj: Instance): (boolean)
	return Obj and (Obj.Name == 'Head' or Obj:HasTag("Head"));
end;

local function IsRicochetable(Hit: BasePart, Penetration: number): (boolean)
	return (Hit and Hit:GetAttribute("Ricochet") and Hit:GetAttribute("Ricochet") > Penetration);
end;

function CombatService.GetKillerFromTarget(Target: Humanoid | Model): (Player | Model)
	
	if Target then
		
		if Target:IsA("Humanoid") and Target:FindFirstChild("Owner") then
			return Target:FindFirstChild("Owner").Value;
		elseif Target:IsA("Model") and (Target:FindFirstChildWhichIsA("Humanoid") and Target:FindFirstChildWhichIsA("Humanoid"):FindFirstChild("Owner")) then
			return Target:FindFirstChildWhichIsA("Humanoid"):FindFirstChild("Owner").Value;
		end;
		
	end;
	
end;

local function IsReloading(Player: Player): (boolean)

	if Player then

		local Task = CombatService.Timers.Reload[Player.Name];
		local Now  = os.clock();

		if Task and Task["ST"] and Task["ES"] then

			if (Task and Task["ST"] and Task["ES"]) then
				return ((Now - Task["ST"]) <= Task["ES"]);
			end;

		end;

	end;

	return false;
end;

-- всякая хуйня с броней
CombatService.Armor = {
	
	-- надевает бронбку на персонажа короче
	Wear = function(Character: Model, Armor: string)
	
		local Mdl: Folder;

		if type(Armor) == 'string' and type(Armor) ~= 'table' and global.server.Storage.Items.Armors:FindFirstChild(Armor) then
			Mdl = global.server.Storage.Items.Armors:FindFirstChild(Armor):Clone();
		elseif type(Armor) ~= 'string' and type(Armor) ~= 'table' and Armor:IsA("Folder") and Armor then
			Mdl = Armor;
		else
			return;
		end;


		local function Weld(A: BasePart, B: BasePart?, Origin: BasePart): ()

			local Weld = Instance.new("Weld");

			Weld.Name   = tostring(A) .. " -> " .. tostring(B);
			Weld.Parent = B;

			Weld.Part0 = A;
			Weld.Part1 = B;

			Weld.C0 = Origin.CFrame:Inverse()
			Weld.C1 = B.CFrame:Inverse()

			B.Anchored   = false;
			B.CanCollide = false;
			B.CanTouch   = false;
			B.Massless   = true;

		end;
		
		
		if (type(Mdl) ~= 'string' and Mdl:IsA("Folder")) and not (table.find(CombatService.Armor.GetArmor(Character, true), Mdl.Name)) then

			global.services.RunService.Heartbeat:Wait();

			if Mdl:GetAttribute("RemoveAccessories") then

				local Accessories = Mdl:GetAttribute("RemoveAccessories"):split(',') :: {string};

				for _, Accessory in pairs(Character:GetChildren()) do

					if Accessory:IsA("Accessory") and
						table.find(Accessories, Accessory.AccessoryType.Name) 
					then
						--
						Accessory:Destroy();
					end;

				end;

			end;

			if global.services.Players:GetPlayerFromCharacter(Character) and
				Mdl:GetAttribute("EnableEffect")
			then

				shared.SendCliReplicated(
					global.services.Players:GetPlayerFromCharacter(Character),
					'SetEffectVisibility',
					{
						Mdl:GetAttribute("EnableEffect") or '',
						true,
					}
				);

			end;


			if not Mdl:HasTag("IsArmor") then Mdl:AddTag("IsArmor"); end;

			for _, Limb: BasePart in ipairs(Character:GetChildren()) do

				if Limb:IsA("BasePart") then

					local Found = Mdl:FindFirstChild(tostring(Limb));

					if Found ~= nil and Found:FindFirstChild("Origin") and not CombatService.Armor.GetArmorOfLimb(Character, tostring(Limb)) then

						local Origin = Found:FindFirstChild("Origin");

						Origin.Anchored     = false;
						Origin.Transparency = 1;

						if Origin:FindFirstChildWhichIsA("SpecialMesh") then Origin:FindFirstChildWhichIsA("SpecialMesh"):Destroy(); end;
						if Origin:FindFirstChildWhichIsA("Decal") then Origin:FindFirstChildWhichIsA("Decal"):Destroy(); end;

						for _, Part in ipairs(Found:GetDescendants()) do
							if Part:IsA("BasePart") and tostring(Part) ~= "Origin" then Weld(Limb, Part, Origin); end;
						end;

					end;

				end;

			end;

			Mdl.Parent = Character;

			return Mdl;
		end;
		
	end;
	
	-- возращает броню которая надета на персонажа
	GetArmor = function(Character: Model, returnNames: boolean?)
		
		local Armors    = {};

		if Character:IsA("Player") then
			Character = Character.Character;
		end;

		if Character and Character:IsA("Model") then

			for _, Armor in ipairs(Character:GetChildren()) do

				if Armor:IsA("Folder") and Armor:HasTag("IsArmor") then

					if returnNames then
						table.insert(Armors, Armor.Name);
					else
						table.insert(Armors, Armor);
					end;

				end;

			end;

		end;

		return Armors;
		
	end;

	-- возращает броню с определенной конечности персонажа
	GetArmorOfLimb = function(Character: Model, Limb: string)
		
		local Armor_: Folder;

		if Character and Character:IsA("Model") then

			for _, Armor in ipairs(Character:GetChildren()) do

				if Armor:IsA("Folder") and
					Armor:HasTag("IsArmor") and Armor:FindFirstChild(Limb)
				then
					Armor_ = Armor; break;
				end;

			end;

		end;

		return Armor_;
		
	end;
	
};

-- приблуды с модификаторами для оружия (скорость перезарядки все такое)
CombatService.Modifications = function(Tool: Tool)
	
	local methods = {};
	
	local Modifiers: Configuration;
	
	if not Tool:FindFirstChild("Modifiers") then
		Modifiers = Instance.new("Configuration");
		Modifiers.Name   = "Modifiers";
		Modifiers.Parent = Tool;
	else
		Modifiers = Tool:FindFirstChild("Modifiers");
	end;
	
	-- Записывает новый модификатор в хранилище
	function methods:New(Modifier: string, Value: any)
		Modifiers:SetAttribute(Modifier, Value);
		return methods;
	end;
	
	-- Обновляет модификаторы, чтобы сервер заметил и обновил клиент
	function methods:Update()
		Modifiers:SetAttribute("Update", true);
		return methods;
	end;
	
	-- Удаляет все модификаторы, но оствляя само хранилище с модификаторами
	function methods:Reset()
		
		for Name, _ in pairs(Modifiers:GetAttributes()) do
			Modifiers:SetAttribute(Name, nil);
		end;
		
		return methods;
	end;
	
	-- Обязательно вызывать, когда работа с модификаторами закончена
	function methods:End(): ()
		
		for Name, _ in pairs(methods) do
			methods[Name] = nil;
		end;

		Modifiers = nil;
		methods = nil;
	end;
	
	return methods;
end;

CombatService.ValidateFire = function(Player: Player, RequestData: any)
	
	local AnticheatSettings = global.settings.Anticheat.Firearms;
	
	--
	local Origin: Vector3, Direction: Vector3 = RequestData.Origin, RequestData.Direction;
	local AttackerCharacter = Player.Character;
	
	if (Origin and Direction) and
		(AttackerCharacter and
		AttackerCharacter:FindFirstChild("HumanoidRootPart") and
		AttackerCharacter:FindFirstChild("Head") and
		not AttackerCharacter:GetAttribute("Ragdolled") and
		AttackerCharacter:FindFirstChildWhichIsA("Humanoid") and
		AttackerCharacter:FindFirstChildWhichIsA("Tool"))
	then
	
		------
		local Tool 			   = AttackerCharacter:FindFirstChildWhichIsA("Tool")     :: (Tool);
		local AttackerHead     = AttackerCharacter:FindFirstChild("Head")             :: (Part);
		local AttackerHumanoid = AttackerCharacter:FindFirstChildWhichIsA('Humanoid') :: (Humanoid);
		local AttackerRootPart = AttackerCharacter:FindFirstChild("HumanoidRootPart") :: (Part);
		
		local Found, Config    = global:worry(require, Util.GetConfig(Tool.Name));
		
		if (not Found or not Config) or
			(not Tool:FindFirstChild("FirePoint", true) or
			not Tool:FindFirstChild("EjectPoint", true) or
			not Tool:FindFirstChild("SoundPoint", true)) or
			(not Tool:FindFirstChild("Client") or
			not Tool:FindFirstChild("Cfg", true) or
			Tool:GetAttribute("Magazine") <= 0)
		then
			return;
		end;
		
		--
		local Magazine = Tool:GetAttribute("Magazine") or 0 :: (number);
		local Ammo     = Tool:GetAttribute("Ammo")     or 0 :: (number);
		--
		local FirePoint  = Tool:FindFirstChild("FirePoint", true)  :: (Attachment);
		local EjectPoint = Tool:FindFirstChild("EjectPoint", true) :: (Attachment);
		local SoundPoint = Tool:FindFirstChild("SoundPoint", true) :: (Attachment);
		--
		
		
		--
		do 
			if (FirePoint.WorldPosition - Origin).Magnitude > AnticheatSettings.OriginPingDistance.Value then
				return warn(`@{Player.Name} reached FirePoint distance limit: {(FirePoint.WorldPosition - Origin).Magnitude}`);
			end;

			if (AttackerHead.CFrame.LookVector:Dot(Direction.Unit) < 0.19) then
				return warn(`@{Player.Name} fired on a strange angle: {AttackerHead.CFrame.LookVector:Dot(Direction.Unit)}`);
			end;
		end;
		--
		
		
		Tool:SetAttribute("Magazine", Magazine - 1);
		
		local Spread = Config.Settings.Spread or 1;
		local SpreadDirectivity = Vector3.new(
			rad(random(-Spread / 50, Spread / 50)),
			rad(random(-Spread / 50, Spread / 50)),
			rad(random(-Spread / 50, Spread / 50))
		);
		local TargetDirection = (Direction.Unit * AnticheatSettings.MaximumBulletDistance.Value + SpreadDirectivity);
		
		local Damage  = Config.Settings.Damage.Basic         :: (number);
		local HSMulti = Config.Settings.Damage.HeadshotMulti :: (number);
		--
		local TargetCharacter: Model;
		local TargetHumanoid: Humanoid;
		local TargetRootPart: Part;
		local HitPart: BasePart;
		local IsHeadshot: boolean;
		--
		local FireResult = Util.Rustcast(Origin, TargetDirection, "Exclude", {AttackerCharacter, workspace.World.Debris});
		
		if FireResult then
			
			HitPart         = FireResult.Instance :: (BasePart);
			TargetCharacter = GetInstanceFromAny(HitPart);
			
			if TargetCharacter and
				TargetCharacter:FindFirstChildWhichIsA("Humanoid") and
				TargetCharacter:FindFirstChild("HumanoidRootPart")
			then
				TargetHumanoid = TargetCharacter:FindFirstChildWhichIsA("Humanoid");
				TargetRootPart = TargetCharacter:FindFirstChild("HumanoidRootPart");
			end;
			
			if IsRicochetable(HitPart, Config.Settings.APP or 0) then
				Damage  = 0;
				HSMulti = 0;
			end;
			
			--
			if not TargetHumanoid and HitPart.CanCollide then
				
				local Thickness   = GetWallThickness(FireResult, Origin + TargetDirection);
				local Penetration = Config.Settings.Projectile.PierceStrength or 0;
				
				if Thickness <= Penetration then
					
					local ThickOffset = (Direction.Unit * (Thickness + 0.1));
					local PierceResult = Util.Rustcast(FireResult.Position + ThickOffset, TargetDirection, "Exclude", {AttackerCharacter, workspace.World.Debris});
					
					if PierceResult then
						
						local Hit = PierceResult.Instance;
						local Character = GetInstanceFromAny(Hit);
						
						if IsRicochetable(Hit, Config.Settings.APP or 0) then
							Damage  = 0;
							HSMulti = 0;
						else
							Damage *= clamp(1 - (Thickness - Penetration), 0.1, 0.7);
						end;
						
						if Character then
							TargetHumanoid = Character:FindFirstChildWhichIsA("Humanoid");
							if IsHead(Hit) then Damage *= HSMulti; IsHeadshot = true; end;
						end;
						
					end;
										
				end;
				
			elseif TargetHumanoid then
				
				if IsHead(HitPart) then
					Damage *= HSMulti;
					IsHeadshot = true;
				end;
				
			end;
			
		end;
		
		--
		if TargetHumanoid and (TargetCharacter ~= AttackerCharacter or TargetCharacter.Name ~= Player.Name) then
			
			local IsFatal = (TargetHumanoid.Health - Damage) <= 0;
			
			if TargetHumanoid.Health > 0 then
				TargetHumanoid:TakeDamage(Damage);
			elseif TargetHumanoid.Health <= 0 then
				
			end;
			
		end;
		
		--
		if (not IsHeadshot and TargetCharacter and TargetHumanoid) and not IsHead(HitPart) then
			IsHeadshot = false;
		end;
		
		
		--
		if NetworkService then

			NetworkService.ReplicateData('all', "EmitateFire", {
				Owner          = Player,
				Origin         = RequestData.Origin,
				Direction      = RequestData.Direction.Unit,
				Velocity       = Config.Settings.Projectile.Speed,
				BulletName     = Config.Settings.Projectile.Name,
				FirePoint      = FirePoint,
				EjectPoint     = EjectPoint,
				HoleSize       = Config.Settings.Projectile.HoleSize,
				PierceStrength = Config.Settings.Projectile.PierceStrength,
				FireSound      = SoundPoint:FindFirstChild("Fire"),
				Caliber        = Config.Caliber,
				IsHead         = IsHeadshot,
			});

		else 
			warn(`[{script.Name}] Awaiting of Knit Service initalization: "Network", skipping functions that requires Network services.`)
		end;
		
	end;
	
end;

CombatService.ValidateReload = function(Player: Player, RequestData: string): (boolean, number)
	
	if (Player and Player.Character) then
		
		local Character = Player.Character;
		local Tool      = Character:FindFirstChildWhichIsA("Tool") :: (Tool);
		local _, Config = global:worry(require, Util.GetConfig(Tool.Name));
		
		if RequestData == "RequestReload" then
			
			if (Tool and Tool:HasTag("Firearm")) and Config and not IsReloading(Player) then

				local Ammo        = Tool:GetAttribute("Ammo") or 0     :: (number);
				local Magazine    = Tool:GetAttribute("Magazine") or 0 :: (number);
				local MaxMagazine = Config.Settings.Magazine or 0      :: (number);
				local ReloadTime  = Config.Settings.ReloadTime or 0    :: (number);

				local Required = floor(MaxMagazine - Magazine);

				if (Ammo > 0 and Required > 0) then

					if (Magazine > 0 and Config.Settings.TacticalReload) then
						ReloadTime = Config.Settings.TacticalReload or 0;
					else ReloadTime = Config.Settings.ReloadTime or 0;
					end;

					local Start = os.clock();
					local Use   = min(Ammo, Required);
					
					Tool:SetAttribute("Magazine", Magazine + Use);
					Tool:SetAttribute("Ammo", Ammo - Use);

					CombatService.Timers.Reload[Player.Name] = {ST = Start, ES = ReloadTime};
					
					return true, (Magazine + Use);
				end;

			end;
			
			return false, 0;
			
		elseif RequestData == "RequestCancel" then
			
			if (Tool and Tool:HasTag("Firearm")) and Config and IsReloading(Player) then
				CombatService.Timers.Reload[Player.Name] = nil;
				return true, -1;
			end;
			
		end;
		
	end;
	
end;

function CombatService:KnitInit(): ()
	
	NetworkService = Knit.GetService("Network");
	
	ServerNetwork.Shoot.On(function(Player, data)
		CombatService.ValidateFire(Player, data);
	end);

	ServerNetwork.Reload.On(function(Player, requestData)
		
		local canReload, newMagazine = CombatService.ValidateReload(Player, requestData);
		return {
			CanReload = canReload,
			NewMagazine = newMagazine
		};
		
	end);
	
end;

return CombatService;
