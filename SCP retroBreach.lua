-- Sponsored by ntfofficial

_G.FOV = 50

local Workspace = cloneref(game:GetService("Workspace"))
local Players = cloneref(game:GetService("Players"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))

local CurrentCamera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Config = require(ReplicatedStorage.Config)
local BridgeNet2 = require(ReplicatedStorage.Assets.Modules.BridgeNet2)
local ClientBridges = {
    ["repSound"] = BridgeNet2.ClientBridge("repSound"),
    ["repReload"] = BridgeNet2.ClientBridge("repReload"),
    ["repHit"] = BridgeNet2.ClientBridge("__repHit"),
    ["fireWeapon"] = BridgeNet2.ClientBridge("__fireWeapon"),
    ["serverTracer"] = BridgeNet2.ClientBridge("serverTracer"),
    ["clientTracer"] = BridgeNet2.ClientBridge("clientTracer"),
    ["repTracer"] = BridgeNet2.ClientBridge("repTracer"),
    ["grenadeThrow"] = BridgeNet2.ClientBridge("grenadeThrow"),
    ["setBarriers"] = BridgeNet2.ClientBridge("setBarriers"),
    ["equipWeapon"] = BridgeNet2.ClientBridge("equipWeapon")
}
local ClientBridge = require(ReplicatedStorage.Assets.Modules.BridgeNet2.src.Client.ClientBridge)
local Functions = debug.getupvalue(ClientBridge, 2).__index

local ScriptEnv = nil
local WeaponSystem = nil
local Ignore = {}
local Target = nil
local Animator = nil

local function Message()

end

local function GroupCheck(Player)
	--[[if not Player:IsInGroupAsync(526116898) then
		return
	end

	local Role = Player:GetRoleInGroupAsync(526116898)

	if Role ~= "Member" then
		Message(Player.Name .. " is a " .. Role, 5)
	end]]
end

local function RetrieveTable()
	if WeaponSystem then
		return WeaponSystem
	end

	local Character = LocalPlayer.Character

	if not Character then
		return
	end

	local Script = getsenv(Character.WeaponSystem)
	local clientTracer = Script.clientTracer

	ScriptEnv = Script
	WeaponSystem = debug.getupvalue(clientTracer, 1)

	return WeaponSystem
end

local function GunMods()
	if not RetrieveTable() then
		return
	end
 
	local GunStats = WeaponSystem.wepStats

	if not GunStats then
		return
	end

	if GunStats.weaponType ~= "Gun" then
		return
	end

	setreadonly(GunStats, false)

	GunStats.Recoil.Horizontal = 0
	GunStats.Recoil.Vertical = 0
	GunStats.ViewPunch = 0
	-- GunStats.BulletsFired = 9e9
	GunStats.Spread = 0
	-- GunStats.FireRate = 9e9
	GunStats.FireMode = "Auto"
end

local function GetTarget()
	if not RetrieveTable() then
		return
	end

	local Target = nil
	local Closest = _G.FOV / 2

	local Character = LocalPlayer.Character

	if not Character then
		return Target
	end

	local Head = Character:FindFirstChild("Head")

	if not Head then
		return Target
	end
	
	for _, Player in pairs(Players:GetPlayers()) do
		if Player == LocalPlayer then
			continue
		end

		local Character = Player.Character

		if not Character then
			continue
		end

		if not Config.teamkillCheck(LocalPlayer, Player) then
			continue
		end

		local Humanoid = Character:FindFirstChildOfClass("Humanoid")

		if not Humanoid or Humanoid.Health <= 0 then
			continue
		end

		local RootPart = Humanoid.RootPart

		if not RootPart then
			continue
		end

		local Direction = (RootPart.Position - CurrentCamera.CFrame.Position).Unit
		local DotProduct = CurrentCamera.CFrame.LookVector:Dot(Direction)
		local Angle = math.deg(math.acos(DotProduct))

		if Angle > Closest then
			continue
		end

		local HitPart = Character:FindFirstChild("Head") or RootPart

		local Direction = (HitPart.Position - Head.Position).Unit
		local Distance = (HitPart.Position - Head.Position).Magnitude

		local RaycastParams = RaycastParams.new()
		RaycastParams.FilterDescendantsInstances = WeaponSystem.ignoreTable

		local RaycastResult = Workspace:Raycast(Head.Position, Direction * Distance, RaycastParams)

		if not RaycastResult or not RaycastResult.Instance or not RaycastResult.Instance:IsDescendantOf(Character) then
			continue
		end

		Closest = Angle
		Target = {
			Humanoid = Humanoid,
			HitPart = HitPart
		}
	end

	return Target
end

local function RetrieveAnimator()
	if Animator then
		return Animator
	end

	local Character = LocalPlayer.Character

	if not Character then
		return
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")

	if not Humanoid then
		return
	end

	Animator = Humanoid:FindFirstChildOfClass("Animator")

	return Animator
end

local function PlayAnimation(Animation, Settings, Looped)
	if not RetrieveAnimator() then
		return
	end

    if WeaponSystem.weaponModel then
        local Animation = Animator:LoadAnimation(Animation)
        Animation.Priority = Settings.priority
        Animation.Name = Animation.Name
        Animation.Looped = Looped
        Animation:Play(Settings.fade or 0.1, nil, Settings.speed or 1)

        table.insert(WeaponSystem, Animation)

        Animation.KeyframeReached:Connect(function(Name)
            if WeaponSystem.weaponModel and (WeaponSystem.weaponModel:FindFirstChild("_Handle") and WeaponSystem.weaponModel._Handle:FindFirstChild(Name)) then
                ClientBridges.repSound:Fire({
                    ["soundName"] = Name
                })
            end

            if Name == "MagIn" then
                ClientBridges.repReload:Fire()
            end
        end)

        if not Looped then
            Animation.Stopped:Once(function()
                table.remove(WeaponSystem, table.find(WeaponSystem, Animation))
            end)
        end

        return Animation
    end
end

local function BonusShot()
	local Bonus = 1

	local WeaponDamage = WeaponSystem.wepStats.BodyDamage

	if Target.HitPart.Name == "Head" then
		WeaponDamage *= 1.25
	end

	local Health = Target.Humanoid.Health - WeaponDamage

	while Health > 0 do
		Health -= WeaponDamage
		Bonus += 1
	end

	return Bonus
end

local function Ragebot()
	if not Target then
		return
	end

	if not WeaponSystem then
		return
	end

	if WeaponSystem.equipped == nil then
		return
	end

	if WeaponSystem.wepStats == nil then
		return
	end

	if WeaponSystem.wepStats.weaponType ~= "Gun" then
		return
	end

	if WeaponSystem.reloading then
		return
	end

	if WeaponSystem.running then
		return
	end

	if not WeaponSystem.canFire then
		return
	end

	if not WeaponSystem.cycled then
		return
	end

	if WeaponSystem.equipped.Ammo.Mag.Value <= 0 then -- add reload nig
		return
	end

	local Fire = WeaponSystem.equipped.Animations:FindFirstChild("Fire")

    if Fire and (Fire:IsA("Animation") and Fire.AnimationId ~= "") then
        PlayAnimation(WeaponSystem.equipped.Animations.Fire, {
            ["priority"] = Enum.AnimationPriority.Action2
        }, false)
    elseif not Fire then
        ClientBridges.repSound:Fire({
            ["soundName"] = "Fire"
        })
    end

	if not (WeaponSystem.weaponModel and WeaponSystem.weaponModel:FindFirstChild("_Handle")) then
		return
	end

	if not WeaponSystem.weaponModel._Handle:FindFirstChild("Barrel") then
		return
	end

	-- WeaponSystem.equipped.Ammo.Mag -= 1

	--[[ClientBridges.fireWeapon:Fire({
		["arg1"] = CFrame.new(),
		["arg2"] = ClientBridges.equipped.Ammo.Mag.Value,
		["arg3"] = ClientBridges.equipped.Ammo.Reserve.Value
	})]]

	local BulletsFired = WeaponSystem.wepStats.BulletsFired

	for _ = 1, math.clamp(BulletsFired, 1, 20) do
		task.spawn(ScriptEnv.clientTracer, {
			["position"] = Target.HitPart.Position
		})

		ClientBridges.serverTracer:Fire({
			["position"] = Target.HitPart.Position
		})

		for _ = 1, BonusShot() do
			ClientBridges.repHit:Fire({
				["__arg1"] = {
					["1"] = Target.HitPart,
					["2"] = Target.HitPart.Position
				}
			})
		end

		-- task.spawn(v_u_49, v62.Instance)
	end

	WeaponSystem.cycled = false

	task.wait(60 / WeaponSystem.wepStats.FireRate)

	WeaponSystem.cycled = true
end

Players.PlayerAdded:Connect(function(Player)
	GroupCheck(Player)
end)

local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = true
FOVCircle.Color = Color3.fromRGB(255, 255, 255)

RunService.Heartbeat:Connect(function()
	local Character = LocalPlayer.Character
	
	if not Character then
		return
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")

	if not Humanoid or Humanoid.Health <= 0 then
		return
	end

	FOVCircle.Position = UserInputService:GetMouseLocation()
	FOVCircle.Radius = _G.FOV / CurrentCamera.FieldOfView * CurrentCamera.ViewportSize.X

	Target = GetTarget()

	-- Ragebot()
end)

ClientBridges.equipWeapon:Connect(function(Args)
	GunMods()
end)

ClientBridges.setBarriers:Connect(function(Args)
	RetrieveTable()
end)

for _, Player in pairs(Players:GetPlayers()) do
	if Player == LocalPlayer then
		continue
	end

	GroupCheck(Player)
end

GunMods()

local OldFire; OldFire = hookfunction(Functions.Fire, function(Bridge, Args)
	local Name = Bridge._name

	if Name == "__fireWeapon" then
		return
	elseif Name == "__repHit" then
		OldFire(Bridge, Args)
	end

	return OldFire(Bridge, Args)
end)

local Index; Index = hookmetamethod(game, "__index", function(Self, Key)
	if not checkcaller() and (Index(Self, "Name") == "Mag" or Index(Self, "Name") == "Reserve") and Key == "Value" and string.find(debug.getinfo(3).source, "WeaponSystem") then
		return Index(Self, "MaxValue")
	end

	return Index(Self, Key)
end)

local NewIndex; NewIndex = hookmetamethod(game, "__newindex", function(Self, Key, Value)
	if not checkcaller() and Self.Name == "ViewmodelBox" and Key == "CFrame" then
		if Target then
			return NewIndex(Self, Key, CFrame.new(Value.Position, Target.HitPart.Position))
		end
	end

	return NewIndex(Self, Key, Value)
end)

local Namecall; Namecall = hookmetamethod(game, "__namecall", function(Self, ...)
	local Method = getnamecallmethod()
	local Args = {...}

	if not checkcaller() and Method == "Raycast" and string.find(debug.getinfo(3).source, "WeaponSystem") then
		if Target then
			local Direction = (Target.HitPart.Position - Args[1]).Unit
			local Distance = (Target.HitPart.Position - Args[1]).Magnitude

			Args[2] = Direction * Distance

			return Namecall(Self, unpack(Args))
		end
	end

	return Namecall(Self, ...)
end)
