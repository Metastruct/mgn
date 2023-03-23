AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

function ENT:Initialize()
	self:SetModel("models/props_junk/PopCan01a.mdl")
	self:SetMoveType(MOVETYPE_NONE)
	self:SetNotSolid(true)
	self:AddEFlags(EFL_NO_THINK_FUNCTION)
end

function ENT:OnRemove()
	self:SetEnabled(false)
end
