local Name = "[UtilsNetwork] "
local Warnings = "[Warning] "
local Errors = "[Error] "

local AuthorisedIds = {[1] = true} -- Id 1 should always be host, if it isn't well. obviously something isn't right with the game.

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
			print(Name.. Errors.. LoggingName.. ", Cannot Authorise Without Player!",FetchPlayerDetails(Values.player))
			return false
		end
	end
    return true
end

function Authorise(id) -- This should be server only.
	if not VaildateNetwork("UtilsNetwork",{},{ServerOnly=true}) then return end
	AuthorisedIds[id] = true
end

function Unauthorise(id) -- This should be server only.
	if not VaildateNetwork("UtilsNetwork",{},{ServerOnly=true}) then return end
	AuthorisedIds[id] = nil
end