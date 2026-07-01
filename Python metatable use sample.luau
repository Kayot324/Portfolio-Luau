--!optimize 2
-- всякая хуета
const global = require("@game/ReplicatedStorage/Storage/Modules/global");
const ClientNetwork = require(script.Parent.Parent.Static.Blink.Client);

const Util   = global.modules.Util;
const Knit   = global.modules.Knit;
const Class  = global.modules.Class;
const Math   = global.modules.Math;

const RunService       = global.services.RunService;
const TweenService     = global.services.TweenService;
const UserInputService = global.services.UserInputService;
const StarterGui       = global.services.StarterGui;

-- привет это я
const Me     = global.me;
const Mouse  = Me:GetMouse();
const Camera = workspace.CurrentCamera;
const CharacterController = Knit.CreateController { Name = "CharacterController" };
const PrivateFunctions    = {};

local function Tween(Obj: Instance, Info: TweenInfo, Values: {any}): (Tween)
	return TweenService:Create(Obj, Info, Values);
end;

local metaclass = Class {

	__init__ = function(self, Character: Model): ()

		const Humanoid = Character:WaitForChild("Humanoid", 5) :: Humanoid;
		const HumanoidRootPart = Character:WaitForChild("HumanoidRootPart", 5) :: Part;

		self.MoveDirection = true;
		self.Model    = Character;
		self.Humanoid = Humanoid;
		self.RootPart = HumanoidRootPart;		self.Tool     = nil;
		self.Garbage  = {};
		self.Joints   = {
			RightArm = Character:FindFirstChild("Right Shoulder", true);
			LeftArm  = Character:FindFirstChild("Left Shoulder", true);
			RightHip = Character:FindFirstChild("Right Hip", true);
			LeftHip  = Character:FindFirstChild("Left Hip", true);
			Neck     = Character:FindFirstChild("Neck", true);
		};
		self.NeckY = self.Joints.Neck.C0.Y;
		
		_G.JS94a = {
			R = CFrame.new(); -- right arm
			L = CFrame.new(); -- left arm
			T = CFrame.new(); -- tool
			
			-- оффсеты
			OR = CFrame.new();
			OL = CFrame.new();
			OT = CFrame.new();
		};
		
		
		table.insert(self.Garbage, Humanoid.Died:Once(function(): ()
			self:OnDeath();
		end));
		
		table.insert(self.Garbage, Character.ChildAdded:Connect(function(New): ()
			self:OnChildAdded(New);
		end));
		
		table.insert(self.Garbage, RunService.RenderStepped:Connect(function(dt)
			self:OnRenderStep(dt);
		end));
		
		table.insert(self.Garbage, task.spawn(function()
			
			while task.wait(0.25) do
				self:CheckToReplicate();
			end;
			
		end));

	end,
	
	CheckToReplicate = function(self): ()
		if self.JointsToReplicate then ClientNetwork.VMReplica.Fire(self.JointsToReplicate); end;
	end,
	
	OnChildAdded = function(self, New: Instance): ()
				
		if New:IsA("Tool") then
			
			self.Tool = New; -- я хуесос
			
			table.insert(self.Garbage, New.Unequipped:Connect(function()
				self.Tool = nil;
			end));
			
		end;
		
	end,
	
	OnDeath = function(self): ()
		_G.JS94a = nil;
		Util.CleanConnections(self.Garbage);
	end,
	
	TrackAttributeChanging = function(self): ()
		
		local Character = self.Model :: (Model);
		
		table.insert(self.Garbage, Character.AttributeChanged:Connect(function(Attribute: string)
			
			local Value = Character:GetAttribute(Attribute);
			
			if Value ~= nil then
				
				if (Attribute == "BP" and type(Value) == 'boolean') then
					return StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, Value);
				end;
				
			end;
			
		end));
		
	end,

	OnRenderStep = function(self, dt: number): ()
		
		if self and (self.Humanoid and self.Humanoid.Health > 0) then
			
			debug.profilebegin("character_render");

			local Humanoid  = self.Humanoid :: (Humanoid);
			local InFP      = shared.FP()       :: (boolean);
			local RootPart  = self.RootPart :: (Part);
			local Tool      = self.Tool         :: (Tool);
			local Joints    = self.Joints     :: ({Motor6D});
			local Handle6D: (Motor6D);
			local Viewmodel = {
				R  = CFrame.new();
				L  = CFrame.new();
				T  = CFrame.new();
				T2 = CFrame.new();
			};
			
			local CameraDirection = RootPart.CFrame:ToObjectSpace(Camera.CFrame).LookVector;
			local MousePoint      = math.asin((Mouse.Origin.Position - Mouse.Hit.Position).Unit.Y);
			local Direction       = RootPart.CFrame:VectorToObjectSpace(Humanoid.MoveDirection);

			if Direction.Z < 0 then
				self.MoveDirection = true;
			elseif Direction.Z > 0 then
				self.MoveDirection = false;
			end;
			
			
			if Tool and Tool:FindFirstChild("Handle6D", true) then
				
				Handle6D = Tool:FindFirstChild("Handle6D", true);
				
				if Handle6D:FindFirstChild("v1") then Viewmodel.T  *= Handle6D.v1.Value; end;
				if Handle6D:FindFirstChild("v2") then Viewmodel.T2 *= Handle6D.v2.Value; end;
				
			end;
			
			
			if (not InFP and Tool) then
								
				if Joints.RightArm then
					Viewmodel.R = CFrame.new(1, 0.5, 0) * CFrame.Angles(-MousePoint, 1.55, 0) * (_G.JS94a.R * _G.JS94a.OR * script.right.Value);
					Tween(Joints.RightArm, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {C0 = Viewmodel.R}):Play();
				end;

				if Joints.LeftArm then
					Viewmodel.L = CFrame.new(-1, 0.5, 0) * CFrame.Angles(-MousePoint, -1.55, 0) * (_G.JS94a.L * _G.JS94a.OL * script.left.Value);
					Tween(Joints.LeftArm, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {C0 = Viewmodel.L}):Play();
				end;

				if Handle6D then
					Viewmodel.T = Viewmodel.T * CFrame.Angles(-MousePoint, 0, 0) * (_G.JS94a.T * _G.JS94a.OT * script.tool.Value);
					Tween(Handle6D, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {C0 = Viewmodel.T, C1 = Viewmodel.T2}):Play();
				end;
				
			elseif (InFP and Tool) then

				if Joints.RightArm then
					Viewmodel.R = CFrame.new(1, 0.5, 0) * CFrame.Angles(-MousePoint, 1.55, 0) * (_G.JS94a.R * _G.JS94a.OR);
					Joints.RightArm.C0 = CFrame.new(1, 0.5, 0) * CFrame.Angles(0, 1.55, 0)
				end;

				if Joints.LeftArm then
					Viewmodel.L = CFrame.new(-1, 0.5, 0) * CFrame.Angles(-MousePoint, -1.55, 0) * (_G.JS94a.L * _G.JS94a.OL);
					Joints.LeftArm.C0 = CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -1.55, 0);
				end;

				if Handle6D then
					Viewmodel.T = Viewmodel.T * CFrame.new(0, 0.5, 0) * CFrame.Angles(-MousePoint, 0, 0) * (_G.JS94a.T * _G.JS94a.OT);
					Handle6D.C0 = CFrame.new();
					Handle6D.C1 = CFrame.new();
				end;

			else

				if Handle6D then
					Viewmodel.T  = CFrame.new();
					Viewmodel.T2 = CFrame.new();
					Handle6D.C0  = CFrame.new();
					Handle6D.C1  = CFrame.new();
				end;

				if Joints.RightArm and (Joints.RightArm.C0 ~= CFrame.new(1, 0.5, 0) * CFrame.Angles(0, 1.55, 0)) then
					Viewmodel.R = (CFrame.new(1,0.5,0) * CFrame.Angles(0, 1.55, 0))
					Joints.RightArm.C0 = (CFrame.new(1,0.5,0) * CFrame.Angles(0, 1.55, 0));
				end;

				if Joints.LeftArm and (Joints.LeftArm.C0 ~= CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -1.55, 0)) then
					Viewmodel.L = (CFrame.new(-1,0.5,0) * CFrame.Angles(0, -1.55, 0))
					Joints.LeftArm.C0 = (CFrame.new(-1,0.5,0) * CFrame.Angles(0, -1.55, 0));
				end;
				
			end

			if Joints.Neck then

				local S  = 0.26;
				local Cf = CFrame.new(0, self.NeckY, 0) * CFrame.Angles(3 * math.pi / 2, 0, math.pi) * CFrame.Angles(0, 0, -math.asin(CameraDirection.X)) * CFrame.Angles(-math.asin(CameraDirection.Y), 0, 0) :: CFrame;
				
				Viewmodel.N = Cf;

				Tween(Joints.Neck, TweenInfo.new(S), {C0 = Cf}):Play()

			end;
			
			local rawNeckX = math.asin(CameraDirection.X);
			local rawNeckY = math.asin(CameraDirection.Y);

			self.JointsToReplicate = {
				rightArm = Math.CompactCFrame(Viewmodel.R),
				leftArm  = Math.CompactCFrame(Viewmodel.L),
				tool     = Math.CompactCFrame(Viewmodel.T),
				neckX    = Math.CompressAngle(rawNeckX),
				neckY    = Math.CompressAngle(rawNeckY),
			};
			
			debug.profileend();
			
		end;
		
	end,

};

function CharacterController.new(Character: Model)
	return metaclass.new(Character);
end;

table.freeze(PrivateFunctions);
return table.freeze(CharacterController);
