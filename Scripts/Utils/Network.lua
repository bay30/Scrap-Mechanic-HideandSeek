local Name = "[UtilsNetwork] "
local Warnings = "[Warning] "
local Errors = "[Error] "

AuthorisedIds = {[1]=true} -- Id 1 is creator of the save, not the host.

local function FetchPlayerDetails(player)
	if player and type(player) == "Player" then
		return player:getName()
	end
	return player
end

function VaildateNetwork(LoggingName,Values,Statements) -- Returns true if vaildated, Returns false is not
    if Statements.server and sm.isServerMode() ~= Statements.server then
		print(Name.. Warnings.. LoggingName.. ", Mismatching Server Mode!",FetchPlayerDetails(Values.player))
		return false
	end
    if Statements.auth then
		if Values.player and type(Values.player) == "Player" then
			if not AuthorisedIds[Values.player.id] then
				print(Name.. Warnings.. LoggingName.. ", Unauthorised Player!",FetchPlayerDetails(Values.player))
				return false
			end
		else
			--print(Name.. Errors.. LoggingName.. ", Cannot Authorise Without Player!",FetchPlayerDetails(Values.player))
			return true --[[ Player will be nil if server fires server function. ]]
		end
	end
    return true
end

function Authorise(id) -- This should be server only.
	if not VaildateNetwork("UtilsNetwork Authorise",{},{server=true}) then return end
	AuthorisedIds[id] = true
end

function Unauthorise(id) -- This should be server only.
	if not VaildateNetwork("UtilsNetwork Unauthorise",{},{server=true}) then return end
	AuthorisedIds[id] = nil
end

function Authorised() -- Client only unsure how localplayer works serverside.
	return AuthorisedIds[sm.localPlayer.getPlayer().id] or false
end

--[[
	TODO:
	Sync authorised ids across clients so we can modify them during runtime
	uhh unsure if i actually will tho, stuff is a proper pain.
]]