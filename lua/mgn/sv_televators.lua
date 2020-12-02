local mgn = mgn

local doorloc = nil
local doorradius = nil
local roomcenter = nil
-- land position for emergency teleport target
local telearea1 = nil
local telearea2 = nil

if LMVector ~= nil then
	local mapversion = tonumber(string.match(game.GetMap(), "^gm_construct_m3_(%d+)$")) or -1

	if mapversion >= 225 then
		local loc  = LMVector(0, -1312, -159.5, "Smooth", true) --this is the base pos/center of the room
		roomcenter = loc
		doorradius = 100
		doorloc   = loc:pos() + Vector(32, -236, -63.5)
		telearea1 = loc:pos() + Vector(-165, -109, -88)
		telearea2 = loc:pos() + Vector(140, 81, -88)
		mgn.SafeLocation = loc
		mgn.SafeBounds = Vector(280, 280, 120)
	elseif mapversion >= 195 then
		local loc  = LMVector(1314, 12, -130, "Smooth", true)
		roomcenter = loc
		doorradius = 100
		doorloc   = loc:pos() + Vector(-182, 14, 44)
		telearea1 = loc:pos() + Vector(-161, -81, -88)
		telearea2 = loc:pos() + Vector(165, 109, -88)
		mgn.SafeLocation = loc
		mgn.SafeBounds = Vector(280, 280, 150)
	else
		local loc  = LMVector(-2083, 5142, -21, "land_caves", true)
		roomcenter = loc
		doorradius = 100
		doorloc   = loc:pos() + Vector(8, 230, 49)
		telearea1 = loc:pos() + Vector(-197, -180, -153)
		telearea2 = loc:pos() + Vector(206, 139, -153)
		mgn.SafeLocation = loc
		mgn.SafeBounds = Vector(400, 400, 200)
	end
end

local PLAYER = FindMetaTable("Player")

if roomcenter == nil or not roomcenter:inworld() then
	function mgn.SetEmergencyTelevationMode()
	end

	function PLAYER:EmergencyTelevate()
	end

	print("[MGN] Unable to find emergency televation destination!")
	return
end

local function GetDoor()
	local cbd1 = ents.FindByName("cbd1")[1]
	if IsValid(cbd1) then
		return cbd1
	end

	local doors = ents.FindInSphere(doorloc, doorradius)
	for i = 1, #doors do
		local door = doors[i]
		if door:GetClass() == "func_door" then
			return door -- there should be only one door with this setup
		end
	end
end

local function SetSafetyLockDoor(door, state)
	local ent, dist = ents.closest(ents.FindByClass("lua_screen"), door:GetPos())
	if dist < 200 and string.find(ent:GetPlace(), "door") and ent.SetSafetyLock then
		ent:SetSafetyLock(state)
	end
end

function mgn.SetEmergencyTelevationMode(state)
	local screens = ents.FindByClass("lua_screen")
	for i = 1, #screens do
		local screen = screens[i]
		if screen:GetPlace() == "elev" and screen.SetEmergency then
			screen:SetEmergency(state)
		end
	end

	local door = GetDoor()
	if door then
		local tid = "unlock_door_" .. door:EntIndex()
		if state then
			if timer.Exists(tid) then
				timer.Remove(tid)
			end

			door:Fire("close")
			door:Fire("lock")
			SetSafetyLockDoor(door, true)
		else
			timer.Create(tid, 5, 1,function()
				if IsValid(door) then
					door:Fire("unlock")
				end

				SetSafetyLockDoor(door, false)
			end)
		end
	end
end

local vec = Vector(0, 0, telearea1.z)
local function FindEscapePos(ply, inplayers)
	vec.z = telearea1.z

	for i = 1, 100 do
		vec.x = math.Rand(telearea1.x, telearea2.x)
		vec.y = math.Rand(telearea1.y, telearea2.y)
		local stuck, inwhat = ply:IsStuck(false, vec)
		if not stuck then
			return vec
		elseif inplayers and IsValid(inwhat) and inwhat:IsPlayer() then
			return vec, inwhat
		end
	end

	vec.z = telearea1.z + 80
	for i = 1, 100 do
		vec.x = math.Rand(telearea1.x, telearea2.x)
		vec.y = math.Rand(telearea1.y, telearea2.y)
		local stuck, inwhat = ply:IsStuck(true, vec)
		if not stuck then
			return vec
		elseif inplayers and IsValid(inwhat) and inwhat:IsPlayer() then
			return vec, inwhat
		end
	end

	return telearea1
end

local function Tesla(pos)
	local tesla = ents.Create("point_tesla")
	tesla:SetKeyValue("texture", "models/effects/comball_sphere.vmt")
	tesla:SetKeyValue("m_flRadius", "300")
	tesla:SetKeyValue("m_Color", "255 255 255")
	tesla:SetKeyValue("beamcount_min", "20")
	tesla:SetKeyValue("beamcount_max", "50")
	tesla:SetKeyValue("thick_min", "5")
	tesla:SetKeyValue("thick_max", "10")
	tesla:SetKeyValue("lifetime_min", "0.5")
	tesla:SetKeyValue("lifetime_max", "1")
	tesla:SetKeyValue("interval_min", "0.1")
	tesla:SetKeyValue("interval_max", "0.1")
	tesla:SetPos(pos)
	tesla:Spawn()
	tesla:Activate()
	tesla:Fire("DoSpark")
	tesla:Fire("Kill", "", 1)
end

hook.Add("PlayerShouldTakeDamage", "DissolveDamageHack", function(vic)
	if vic.__mgn_ignore_god then
		vic.__mgn_ignore_god = nil
		return true
	end
end)

local function Dissolve(vic, att)
	local dmg = DamageInfo()
	dmg:SetDamage(vic:Health())
	dmg:SetDamageForce(VectorRand() * 300)
	dmg:SetDamageType(bit.bor(DMG_DISSOLVE, DMG_ALWAYSGIB))
	dmg:SetInflictor(game.GetWorld())
	dmg:SetAttacker(att)
	vic:EmitSound("ambient/energy/weld2.wav")

	vic.__mgn_ignore_god = true
	vic:TakeDamageInfo(dmg)
end

local function EnsureValid(ply)
	if not IsValid(ply) or not ply:Alive() or (IsValid(ply:GetParent()) and not ply:InVehicle()) then
		coroutine.yield()
	end
end

local function TelevateCoroutine(ply, scr, edat)
	ply:EmitSound("buttons/button1.wav")

	co.sleep(0.1)
	EnsureValid(ply)

	ply:EmitSound("hl1/ambience/port_suckout1.wav")

	util.ScreenShake(ply:GetPos(), 0.6, 4, 4, 128)

	co.sleep(2.5)
	EnsureValid(ply)

	local white = Color(255, 255, 255, 255)
	ply:EmitSound("ambient/voices/citizen_beaten3.wav")
	ply:ScreenFade(SCREENFADE.IN, white, 1, 1)

	co.sleep(0.5)
	EnsureValid(ply)

	if ply:InVehicle() then
		ply:ExitVehicle()
	end

	local center = ply:OBBCenter()
	Tesla(ply:GetPos() + center)
	local escpos, ply2 = FindEscapePos(ply, true)
	ply:SetPos(escpos)
	Tesla(escpos + center)
	ply:ScreenFade(SCREENFADE.IN, white, 1, 1)
	if ply2 ~= nil then
		Dissolve(ply, ply2)
		Dissolve(ply2, ply)
	end
end

function PLAYER:EmergencyTelevate(screen, edat)
	if self.EmergencyTelevator and coroutine.status(self.EmergencyTelevator) == "suspended" then
		return
	end

	self.EmergencyTelevator = co(TelevateCoroutine, self, screen, edat)
end
