dofile( "$CHALLENGE_DATA/Scripts/challenge/game_util.lua" )
dofile( "$CHALLENGE_DATA/Scripts/challenge/world_util.lua" )
dofile( "$CHALLENGE_DATA/Scripts/game/challenge_shapes.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_meleeattacks.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/EffectManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/UnitManager.lua" )
dofile( "$CONTENT_DATA/Scripts/Utils/Events.lua" )
dofile( "$CONTENT_DATA/Scripts/Utils/Network.lua")
dofile( "$CONTENT_DATA/Scripts/Utils/Content.lua" )

---@class Game : GameClass
---@field sv table
---@field cl table

Game = class( nil )
Game.enableRestrictions = true

function Game:createCharacterOnSpawner( player, playerSpawners, defaultPosition )
	if not VaildateNetwork("Game createCharacterOnSpawner",{player=playerSpawners},{server=true,auth=true}) then return end
	local spawnPosition = defaultPosition
	local yaw = 0
	local pitch = 0
	if #playerSpawners > 0 and self.sv.activeWorld ~= self.sv.saved.buildWorld then
		local spawnerIndex = ( ( player.id - 1 ) % #playerSpawners ) + 1
		local spawner = playerSpawners[spawnerIndex]
		local pos = spawner.pos
		local at = spawner.at * 0.825
		spawnPosition = pos + at
	end
	return spawnPosition,pitch,yaw
end
			
function Game.server_onCreate( self )
	g_unitManager = UnitManager()
	g_unitManager:sv_onCreate()
	
	print("Game.server_onCreate")
    self.sv = {}
	self.sv.saved = self.storage:load()
    if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.buildWorld = sm.world.createWorld( "$CONTENT_DATA/Scripts/World.lua", "World", {tiles={"$CONTENT_DATA/Terrain/Tiles/ChallengeBuilderDefault.tile","$CONTENT_DATA/Terrain/Tiles/challengebuilder_env_DT.tile"}} )
		self.storage:save( self.sv.saved )
	end
	self.sv.G_ChallengeStarted = false
	self.sv.G_ChallengeStartTick = 0
	self.sv.settings = {}
	self.sv.score = {}
	self.sv.seekers = {}
	self.sv.seekerqueue = {}
	self.sv.objectlist = {}
	self.sv.activeWorld = self.sv.saved.buildWorld
	self.sv.countdownStarted = false
	self.sv.gameRunning = true
	self.sv.countdownTime = 0

end

function Game:sv_hasStarted()
	if not VaildateNetwork("Game sv_hasStarted",{},{server=true}) then return end
	return self.sv.G_ChallengeStarted
end

function Game:cl_hasStarted()
	if not VaildateNetwork("Game cl_hasStarted",{},{server=false}) then return end
	return self.cl.G_ChallengeStarted
end

function Game:sv_prestart(args, player)
	if not VaildateNetwork("Game sv_start", { player = player }, { server = true, auth = true }) or self.sv.countdownStarted
		or self.sv.activeWorld == self.sv.saved.buildWorld then return end
	self.sv.countdownStarted = true
	self.sv.countdownTime = sm.game.getCurrentTick()

	if self.sv.settings.PickSeekers == nil or self.sv.settings.PickSeekers == false then
		local Selection = sm.player.getAllPlayers()
		local Seekers = 1
		if self.sv.settings.Seekers and #self.sv.settings.Seekers <= #Selection then
			Seekers = self.sv.settings.Seekers
		end

		self.sv.seekers = {}

		for i = 1, Seekers do
			local plr = self.sv.seekerqueue[1]
			self.sv.seekers[plr.id] = { plr, seeker = true }
			table.insert(self.sv.seekerqueue, plr)
			table.remove(self.sv.seekerqueue, 1)
		end
		self.network:sendToClients("client_onJankyUpdate", { Variable = "seekers", Value = self.sv.seekers })
	end

	for key, plr in pairs(sm.player.getAllPlayers()) do
		if plr.character then
			if self.sv.seekers[plr.id] == nil then
				sm.event.sendToWorld(self.sv.activeWorld, "createCharacterOnSpawner",
					{ players = { plr }, uuid = "b5858089-b1f8-4d13-a485-fdcb204d9c6b" }) -- Hider Spawn
			else
				sm.event.sendToWorld(self.sv.activeWorld, "createCharacterOnSpawner",
					{ players = { plr }, uuid = "b5858089-b1f8-4d13-a485-fdaa204d9c6b", speedmodifyer = 0 }) -- Spectator Spawn
			end
		end
	end

	sm.event.sendToWorld(self.sv.activeWorld, "destructive", self.sv.settings.Destruction)
end


function Game:sv_start(args, player)
	if not VaildateNetwork("Game sv_start", { player = player }, { server = true, auth = true }) or
		self.sv.G_ChallengeStarted or self.sv.activeWorld == self.sv.saved.buildWorld then return end

	for key, plr in pairs(sm.player.getAllPlayers()) do
		local character = plr:getCharacter()
		self.sv.score[plr.id] = { plr = plr, tags = 0 }
		if self.sv.seekers[plr.id] then
			self.sv.score[plr.id].hidetime = sm.game.getCurrentTick()
		elseif character then
			character.publicData.waterMovementSpeedFraction = .75
		end
	end

	self.sv.gameRunning = true
	self.sv.G_ChallengeStarted = true
	self.sv.G_ChallengeStartTick = sm.game.getCurrentTick()
	self.network:sendToClients("client_onJankyUpdate",
		{ { Variable = "G_ChallengeStarted", Value = self.sv.G_ChallengeStarted },
			{ Variable = "G_ChallengeStartTick", Value = self.sv.G_ChallengeStartTick },
			{ Variable = "score", Value = self.sv.score }, { Variable = "gameRunning", Value = self.sv.gameRunning } })
end


function Game:sv_stop(args, player)
	if not VaildateNetwork("Game sv_start", { player = player }, { server = true, auth = true }) or
		not self.sv.G_ChallengeStarted or self.sv.activeWorld == self.sv.saved.buildWorld then return end

	self.sv.gameRunning = false
	self.sv.G_ChallengeStarted = false
	self.sv.countdownStarted = false
	Event("Tick", function() self.sv.gameRunning = true end, false, sm.game.getCurrentTick() + 2)
	
	for key, plr in pairs(sm.player.getAllPlayers()) do
		local character = plr:getCharacter()
		if self.sv.seekers[plr.id] == nil then
			self.sv.score[plr.id].hidetime = sm.game.getCurrentTick()
		end
		if character then
			character.publicData.waterMovementSpeedFraction = 1
		end
	end

	if self.sv.objectlist.starters then
		for key, obj in pairs(self.sv.objectlist.starters) do
			if sm.exists(obj) then
				obj.interactable.active = false
			end
		end
	end

	self.network:sendToClients("client_onJankyUpdate",
		{ { Variable = "score", Value = self.sv.score }, { Variable = "gameRunning", Value = self.sv.gameRunning },
			{ Variable = "G_ChallengeStarted", Value = self.sv.G_ChallengeStarted } })
	self.network:sendToClients("client_displayAlert", "Game over!")
	sm.event.sendToWorld(self.sv.activeWorld, "server_celebrate")

end

function Game.server_onFixedUpdate( self, delta )
	FireEvent("Tick",sm.game.getCurrentTick())
	g_unitManager:sv_onFixedUpdate()
	if not self.sv.gameRunning then return end
	local Hiders = 0
	for key,info in pairs(self.sv.score) do
		if self.sv.seekers[key] == nil then
			Hiders = Hiders + 1
		end
	end
	if self.sv.objectlist.starters then
		for key,obj in pairs(self.sv.objectlist.starters) do
			if sm.exists(obj) then
				if obj.interactable.active then
					self:sv_prestart()
				end
			end
		end
	end
	if self.sv.activeWorld ~= self.sv.saved.buildWorld then
		local CountdownNumber = self.sv.countdownTime + (tonumber(self.sv.settings.HideTime) or 60) * 40 - sm.game.getCurrentTick()
		if self.sv.countdownStarted and CountdownNumber > 0 then
			local seconds = CountdownNumber/40 + 1
			local minutes = seconds/60
			local hours = minutes/60
			self.network:sendToClients("client_displayAlert",string.format( "%02i:%02i:%02i", hours%60, minutes%60, seconds%60 ))
		elseif self.sv.countdownStarted and not self:sv_hasStarted() then
			self:sv_start()
			self.network:sendToClients("client_displayAlert","Seekers have been released")
			local FilteredPlayers = {}
			for _,plr in pairs(sm.player.getAllPlayers()) do
				if self.sv.seekers[plr.id] then
					table.insert(FilteredPlayers,plr)
				end
			end
			sm.event.sendToWorld(self.sv.activeWorld,"createCharacterOnSpawner",{players=FilteredPlayers,uuid="b5858089-d1f8-4d13-a485-fdcb204d9c6b"})
		end
	end
	if self:sv_hasStarted() and self.sv.settings.GameTime and self.sv.settings.GameTime ~= 0 then
		local milliseconds = (self.sv.G_ChallengeStartTick+self.sv.settings.GameTime*40)-sm.game.getCurrentTick()
		local seconds = milliseconds/40
		local minutes = seconds/60
		local hours = minutes/60
		self.network:sendToClients("client_displayTimer",string.format( "%02i:%02i:%02i", hours%60, minutes%60, seconds%60 ))
		if seconds <= 0 then
			self:sv_stop()
		end
	elseif self:sv_hasStarted() and Hiders < 1 then
		self:sv_stop()
	end
end

function Game.server_onTag(self, args, player)
	if not VaildateNetwork("Game server_onTag", { player = player }, { server = true, auth = true }) then return end
	if args["tagger"] and args["tagged"] and self.sv.activeWorld ~= self.sv.saved.buildWorld and self.sv.gameRunning then
		if self.sv.seekers[args["tagger"].id] and self:sv_hasStarted() then
			if not self.sv.seekers[args["tagged"].id] and self.sv.seekers[args["tagger"].id]["seeker"] then
				if self.sv.BecomeSeekers then
					self.sv.seekers[args["tagged"].id] = { args["tagged"], seeker = true }
				else
					self.sv.seekers[args["tagged"].id] = { args["tagged"], seeker = false }
				end
				local character = args["tagged"]:getCharacter()
				if character then
					character.publicData.waterMovementSpeedFraction = 1
				end
				self.sv.score[args["tagger"].id].tags = self.sv.score[args["tagger"].id].tags + 1
				self.sv.score[args["tagged"].id].hidetime = sm.game.getCurrentTick()
				self.network:sendToClients("client_onJankyUpdate",
					{ { Variable = "seekers", Value = self.sv.seekers }, { Variable = "score", Value = self.sv.score } })
				sm.event.sendToWorld(self.sv.activeWorld, "server_effect",
					{ name = "Woc - Destruct", pos = args["tagged"].character.worldPosition })
			end
		elseif args["tagger"].id == 1 and self.sv.settings.PickSeekers and not self:sv_hasStarted() and
			not self.sv.countdownStarted then
			if self.sv.seekers[args["tagged"].id] then
				self.sv.seekers[args["tagged"].id] = nil
				self.sv.score[args["tagged"].id].hidetime = nil
				self.network:sendToClients("client_onJankyUpdate",
					{ { Variable = "seekers", Value = self.sv.seekers }, { Variable = "score", Value = self.sv.score } })
			else
				self.sv.seekers[args["tagged"].id] = { args["tagged"], seeker = true }
				self.sv.score[args["tagged"].id].hidetime = nil
				self.network:sendToClients("client_onJankyUpdate",
					{ { Variable = "seekers", Value = self.sv.seekers }, { Variable = "score", Value = self.sv.score } })
			end
		end
	end
end


function Game.server_onTaunt( self, args, player )
	if not VaildateNetwork("Game server_onTaunt",{player=player},{server=true}) then return end
	if player.character then
		self.network:sendToClients("client_createEffect",{name="Horn",pos=player.character:getWorldPosition()})
	end
end

function Game:server_setValues( args, player )
	if not VaildateNetwork("Game server_setValues",{player=player},{server=true,auth=true}) then return end
	self.sv.settings = args[1].settings or {}
	self.sv.tiles = args[1].tiles or { "$CONTENT_DATA/Terrain/Tiles/challengemode_env_DT.tile",
	"$CONTENT_DATA/Terrain/Tiles/ChallengeBuilderDefault.tile" }
	self.sv.world = args[1].world or ""
	self.sv.blueprints = args[1].blueprints or {}
	self.network:sendToClients("client_onJankyUpdate",{Variable="settings",Value=self.sv.settings})
	if args[2] then
		self.network:sendToClient(args[3],"client_createSettings", { isBlock = true, open = true, play = true, explore = true })
	end
end

function Game.server_getTableLength( self, tab )
	local a = 0
	for key,item in pairs(tab) do
		a=a+1
	end
	return a
end

function Game:reload_inventory(args,player)
	if not VaildateNetwork("Game reload_inventory",{player=player},{server=true,auth=true}) then return end
	local Array = {}
	if self.sv.settings.Hammer then
		table.insert(Array,"09845ac0-4785-4ce8-98b3-0aa4a88c4bdd")
	end
	if self.sv.settings.Spudgun then
		table.insert(Array,"041d874e-46b3-49ec-8b26-e3db9770c6fd")
	end

	for _,plr in pairs(sm.player.getAllPlayers()) do 
		local inventoryContainer = self.sv.settings.Limited and plr:getHotbar() or plr:getInventory()
		sm.container.beginTransaction()
		for i = 0,inventoryContainer.size do
			sm.container.setItem( inventoryContainer, i, sm.uuid.new(Array[i+1] or "00000000-0000-0000-0000-000000000000"), 1 )
		end
		sm.container.endTransaction()
	end
end

function Game.server_load( self, args, player )
	if not VaildateNetwork("Game server_load",{player=player},{server=true,auth=true}) then return end
	if args == false then

		sm.game.setLimitedInventory(not self.sv.settings.Limited)
		self.sv.countdownStarted = false
	
		-- Inv --
		self:reload_inventory()
		-- Inv --
		
	else
		self.sv.countdownStarted = true
	end
	
	self:server_setWorld("play")
	
	self.sv.SpawnerList = {}
	local function Blueprints()
		for key,creation in pairs(self.sv.blueprints or {}) do
			local creation = sm.creation.importFromString( self.sv.activeWorld, creation, sm.vec3.zero(), sm.quat.identity(), true )
			for _,body in ipairs(creation) do
				body.erasable = false
				body.buildable = false
				body.usable = false
				body.liftable = false
				body.destructable = self.sv.settings.Destruction
				for key,shape in pairs(body:getShapes()) do
					if shape.uuid == sm.uuid.new("4a9929e9-aa85-4791-89c2-f8799920793f") then
						if not self.sv.objectlist.starters then
							self.sv.objectlist.starters = {}
						end
						table.insert(self.sv.objectlist.starters,shape)
					elseif shape.uuid == sm.uuid.new("b5858089-b1f8-4d13-a485-fdaa204d9c6b") then
						table.insert(self.sv.SpawnerList,{pos=shape.worldPosition,at=shape:getAt(),up=shape:getUp()})
					end
				end
			end
		end
	end
	Event("Tick",Blueprints,false,sm.game.getCurrentTick()+1)
	
	local function SpawnPlayers()
		for key,plr in pairs(sm.player.getAllPlayers()) do
			self:sv_createPlayerCharacter( self.sv.activeWorld, 0, 0, plr )
		end
	end
	Event("Tick",SpawnPlayers,false,sm.game.getCurrentTick()+1)
	
	if args ~= false then
		self:sv_start()
		self.sv.gameRunning = false
		self.network:sendToClients("client_onJankyUpdate",{Variable="gameRunning",Value=self.sv.gameRunning})
	end
end

function Game.server_onCommand( self, args, player )
	if not VaildateNetwork("Game server_onCommand",{player=player},{server=true,auth=true}) then return end
	if args[1] == "/return" then
		self:server_setWorld("build")
	elseif args[1] == "/start" then
		self:sv_prestart()
	elseif args[1] == "/stop" then
		self:sv_stop( args, player )
	elseif args[1] == "/map" then
		local map
		for i,v in ipairs(Maps) do
			if string.sub(v[1].name,1,#args[2]) == args[2] or i == tonumber(args[2]) then
				map = v
				break
			end
		end
		if map then
			local blueprints = {}
			local tiles = {}
			for _,item in ipairs(map[1].data.levelCreations) do
				local strang = item
				local a1,a2 = string.find(item,"$CONTENT_DATA")
				if a1 and a2 then
					strang = "$CONTENT_".. map[3].. string.sub(strang,a2+1,#strang)
				end
				table.insert(blueprints,sm.json.writeJsonString(sm.json.open(strang)))
			end
			for _,item in ipairs(map[1].data.tiles) do
				local strang = item
				local a1,a2 = string.find(item,"$CONTENT_DATA")
				if a1 and a2 then
					strang = "$CONTENT_".. map[3].. string.sub(strang,a2+1,#strang)
				end
				table.insert(tiles,strang)
			end
			table.insert(tiles,"$CONTENT_DATA/Terrain/Tiles/challengemode_env_DT.tile")
			self:server_setValues({{blueprints=blueprints,tiles=tiles},true,player})
		end
	end
end

function Game.server_setWorld( self, args, player )
	if not VaildateNetwork("Game server_setWorld",{player=player},{server=true,auth=true}) then return end
	if args == "build" then
		self.sv.seekers = {}
		self.network:sendToClients("client_onJankyUpdate",{Variable="seekers",Value=self.sv.seekers})
		self:sv_stop()
		sm.game.setLimitedInventory(false)
		self.sv.gameRunning = false
		self.network:sendToClients("client_displayTimer","00:00:00")
		self.sv.G_ChallengeStartTick = 0
		self.network:sendToClients("client_onJankyUpdate",{ {Variable="G_ChallengeStartTick",Value=self.sv.G_ChallengeStartTick}, {Variable="gameRunning",Value=self.sv.gameRunning} })
		if self.sv.activeWorld.id ~= self.sv.saved.buildWorld.id then
			self.sv.objectlist = {}
			self.sv.activeWorld:destroy()
			self.sv.activeWorld = self.sv.saved.buildWorld
		end
		sm.event.sendToWorld(self.sv.activeWorld,"createCharacterOnSpawner",{players=sm.player.getAllPlayers(),uuid="b5858089-b1f8-4d13-a485-fdaa204d9c6b"})
	elseif args == "play" then
		self:sv_stop()
		self.sv.gameRunning = true
		if self.sv.activeWorld.id ~= self.sv.saved.buildWorld.id then
			self.sv.objectlist = {}
			self.sv.activeWorld:destroy()
		end
		self.sv.activeWorld = sm.world.createWorld( "$CONTENT_DATA/Scripts/World.lua", "World", { world=self.sv.world, tiles=self.sv.tiles, play=true } )
		self.network:sendToClients("client_onJankyUpdate",{Variable="gameRunning",Value=self.sv.gameRunning})
	end
end

function Game.server_onPlayerJoined( self, player, isNewPlayer )
	g_unitManager:sv_onPlayerJoined( player )
	
    if not sm.exists( self.sv.activeWorld ) then
        sm.world.loadWorld( self.sv.activeWorld )
    end
	
	if player.id == 1 then
		sm.gui.chatMessage("[------------------------]\nWelcome to hide & seek gamemode!\nType /help for the commands!")
	end
	
	self.sv.score[player.id] = {plr=player,tags=0,hidetime=(self.sv.G_ChallengeStartTick or 0)}

	if self:sv_hasStarted() then
		if self.sv.BecomeSeekers then
			self.sv.seekers[player.id] = {player,seeker=true}
		else
			self.sv.seekers[player.id] = {player,seeker=false}
		end
		self.network:sendToClients("client_onJankyUpdate",{Variable="seekers",Value=self.sv.seekers})
	end
	if isNewPlayer then
		local function Spawn()
			sm.event.sendToWorld(self.sv.activeWorld,"createCharacterOnSpawner",{players={player},uuid="b5858089-b1f8-4d13-a485-fdaa204d9c6b"})
		end
		Event("Tick",Spawn,false,sm.game.getCurrentTick()+1)
	end

	table.insert(self.sv.seekerqueue,math.random(1,#self.sv.seekerqueue),player)

	self.network:sendToClients("client_onJankyUpdate",{ {Variable="G_ChallengeStartTick",Value=self.sv.G_ChallengeStartTick}, {Variable="score",Value=self.sv.score}, {Variable="gameRunning",Value=self.sv.gameRunning} })
	
end

function Game.server_onPlayerLeft( self, player )
	self.sv.score[player.id] = nil
	table.remove(self.sv.seekerqueue,table.find(self.sv.seekerqueue,player))
	self.network:sendToClients("client_onJankyUpdate",{Variable="score",Value=self.sv.score})
end

function Game.sv_createPlayerCharacter( self, world, x, y, player, params, handle )
	if not VaildateNetwork("Game sv_createPlayerCharacter",{player=x},{server=true,auth=true}) then return end
	local pos,pitch,yaw = self:createCharacterOnSpawner(player,self.sv.SpawnerList or {},sm.vec3.new( 2, 2, 20 ))
    local character = sm.character.createCharacter( player, world, pos, pitch,yaw )
	player:setCharacter( character )
end

function Game.server_updateSettings(self,args, player)
	if not VaildateNetwork("Game server_updateSettings",{player=player},{server=true,auth=true}) then return end
	self.sv.settings[args["editbox"]] = args["value"]
	if self.sv.activeWorld ~= self.sv.saved.buildWorld then
		sm.game.setLimitedInventory(not self.sv.settings.Limited)
		sm.event.sendToWorld(self.sv.activeWorld,"destructive",self.sv.settings.Destruction)
		self:reload_inventory()
	end
	if Main and Main.one and sm.exists(Main.one) then
		local interactable = Main.one:getInteractable()
		if interactable and sm.exists(interactable) then
			sm.event.sendToInteractable(interactable,"server_setSettings",self.sv.settings)
		end
	end
	self.network:sendToClients("client_onJankyUpdate",{Variable="settings",Value=self.sv.settings})
end

function Game.server_fly( self, params, player )
	if not VaildateNetwork("Game server_fly",{player=player},{server=true}) then return end
	if player and player.character and player.character:getWorld() == self.sv.saved.buildWorld then
		if not player.character:isSwimming() then
			player.character.publicData.waterMovementSpeedFraction = 5
		else
			player.character.publicData.waterMovementSpeedFraction = 1
		end
		player.character:setSwimming(not player.character:isSwimming())
	end
end

-- Client --

function Game.client_onLoadingScreenLifted( self )
	g_effectManager:cl_onLoadingScreenLifted()
end

function Game.client_displayAlert( self, text )
	if not VaildateNetwork("Game client_displayAlert",{},{server=false}) then return end
	sm.gui.displayAlertText(text)
end

function Game.client_displayTimer( self, text )
	if not VaildateNetwork("Game client_displayTimer",{},{server=false}) then return end
	if self:cl_hasStarted() and self.cl.gameRunning then
		self.cl.gui["timer"]:setVisible("Time",true)
		self.cl.gui["timer"]:setText("Time", text)
	else
		self.cl.gui["timer"]:setVisible("Time",false)
	end
end

function Game.client_onCreate( self )
	
	self.cl = {}

	self.cl.G_ChallengeStarted = false
	self.cl.G_ChallengeStartTick = 0
	self.cl.settings = {}
	self.cl.score = {}
	self.cl.seekers = {}
	self.cl.selectedseekers = {}

	sm.challenge.hasStarted = function()
		return self.cl.G_ChallengeStarted
	end

	if g_unitManager == nil then
		assert( not sm.isHost )
		g_unitManager = UnitManager()
	end
	g_unitManager:cl_onCreate()
	
	g_effectManager = EffectManager()
	g_effectManager:cl_onCreate()
	
	sm.game.bindChatCommand("/score",{},"client_onCommand","Opens the score menu.")
	sm.game.bindChatCommand("/fly",{},"client_onCommand","Let's you fly around.")
	if sm.isHost then
		sm.game.bindChatCommand("/settings",{},"client_onCommand","Opens the settings menu.")
		sm.game.bindChatCommand("/return",{},"client_onCommand","Returns everyone to the build world.")
		sm.game.bindChatCommand("/start",{},"client_onCommand","Start's the game.")
		sm.game.bindChatCommand("/stop",{},"client_onCommand","Stops the game.")
		sm.game.bindChatCommand("/maps",{},"client_onCommand","Lists the maps.")
		sm.game.bindChatCommand("/map",{ { "string", "mapname", true } },"client_onCommand","Selects the map.")
	end
	
	self.cl.gui = {}
	
	self.cl.gui["timer"] = sm.gui.createChallengeHUDGui()
	self.cl.gui["timer"]:open()
	self.cl.gui["timer"]:setVisible("Time",false)

	self.cl.gui["pointer"] = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/Pointer.layout",true,{isHud=true,isInteractive=false})
	self.cl.gui["pointer"]:setImage("Image2","$CONTENT_DATA/Gui/Pointer/Center.png")
	self.cl.gui["pointer"]:setVisible("Image2",false)
	self.cl.gui["pointer"]:open()

end

function Game:client_onRefresh()
end

function getTablePosition(tab,pos)
	local num = 0
	for key,obj in pairs(tab) do
		num = num + 1
		if num == pos then
			return key,obj
		end
	end
	return nil,nil
end

function CamCross(pos)
	local dir = sm.camera.getDirection()
	local dif = (sm.camera.getPosition()-pos)
	if dif == sm.vec3.new(0,0,0) then
		dif = sm.vec3.new(0,0,1)
	end
	local norm = dif:normalize()
	return dir:cross( norm ), dir:dot( norm )
end

function Game.client_onFixedUpdate( self )
	FireEvent("Tick",sm.game.getCurrentTick())
	self.cl.timer = (self.cl.timer or 0) + 1
	if self.cl.gui["score"] and self.cl.gui["score"]["gui"] and sm.exists(self.cl.gui["score"]["gui"]) then
		for i = 1, 8 do
			local plr,score = getTablePosition(self.cl.score,i)
			if plr and score then
				local NameColor = ""
				if self.cl.seekers[score.plr.id] then
					NameColor = self.cl.seekers[score.plr.id].seeker and "#ff4949" or "#4949ff"
				end

				self.cl.gui.score.gui:setText("Player"..i,NameColor..tostring(score.plr:getName()))
				self.cl.gui.score.gui:setText("TextScore"..i,tostring(score.tags))
				
				local seconds = 0
				local minutes = 0
				local hours = 0
				if self.cl.G_ChallengeStartTick ~= 0 then
					local milliseconds = ( score.hidetime or sm.game.getServerTick() ) - self.cl.G_ChallengeStartTick
					seconds = milliseconds/40
					minutes = seconds/ 60 % 60
					hours = minutes/ 60 % 60
				end
				
				self.cl.gui.score.gui:setText("TextTime"..i,string.format( "%02i:%02i:%02i", hours, minutes, seconds % 60 ))
			else
				self.cl.gui.score.gui:setText("Player"..i, "Player")
				self.cl.gui.score.gui:setText("TextScore"..i,"N/A")
				self.cl.gui.score.gui:setText("TextTime"..i,"N/A")
			end
		end
	end
	local Player = sm.localPlayer.getPlayer()
	local AmSeeker = false
	if self.cl.seekers and self.cl.seekers[Player.id] and self.cl.seekers[Player.id]["seeker"] then
		AmSeeker = true
	end
	if Player and Player.character then
		for key,plr in pairs(sm.player.getAllPlayers()) do
			if plr.character then
				if not AmSeeker and self.cl.settings.Nametag or self.cl.seekers[plr.id] then
					local Distance = math.floor((plr.character:getWorldPosition()-Player.character:getWorldPosition()):length2())
					local Color = sm.color.new(1,1,1)
					if self.cl.seekers[plr.id] then
						if self.cl.seekers[plr.id]["seeker"] then
							Color = sm.color.new(1,0.294,0.294)
						else
							Color = sm.color.new(0.294,0.294,1)
						end
					end
					plr.character:setNameTag( "[ "..tostring(Distance).." Blocks ] ".. plr:getName(), Color )
				else
					plr.character:setNameTag( "" )
				end
			end
		end
	end
end

function Game.client_makeGui(self,layout,val,data)
	if not VaildateNetwork("Game client_makeGui",{},{server=false}) then return end
	if self.cl.gui[val] then
		self.cl.gui[val] = nil
	end
	self.cl.gui[val] = {gui=sm.gui.createGuiFromLayout(layout,true,data or {})}
	return self.cl.gui[val]
end

function Game.client_buttonGui(self,btn)
	if not VaildateNetwork("Game client_buttonGui",{},{server=false}) then return end
	if btn == "Play" then
		self.network:sendToServer("server_load",false)
	elseif btn == "Explore" then
		self.network:sendToServer("server_load",true)
	elseif btn == "Stop game" then
		self.network:sendToServer("server_setWorld","build")
	end
	self.cl.gui["settings"]["gui"]:close()
end

function Game.client_createSettings( self, args )
	if not VaildateNetwork("Game client_createSettings",{},{server=false}) then return end
	local Gui = self:client_makeGui("$CONTENT_DATA/Gui/Layouts/HideAndSeekMenu.layout","settings")
	Gui["gui"]:setTextChangedCallback("GameTime","client_settingsUpdate")
	Gui["gui"]:setTextChangedCallback("HideTime","client_settingsUpdate")
	Gui["gui"]:setTextChangedCallback("Seekers","client_settingsUpdate")
	Gui["gui"]:setText("HideTime",self.cl.settings.HideTime or "60")
	Gui["gui"]:setText("GameTime",self.cl.settings.GameTime or "0")
	Gui["gui"]:setText("Seekers",self.cl.settings.Seekers or "1")
	local buttons = {"BecomeSeekers","PickSeekers","Limited","Destruction","Hammer","Spudgun","Nametag"}
	for _,obj in pairs(buttons) do
		Gui["gui"]:setButtonCallback(obj.."Y","client_settingsUpdate2")
		Gui["gui"]:setButtonCallback(obj.."N","client_settingsUpdate2")
		local state = self.cl.settings[obj] or false
		Gui["gui"]:setButtonState(obj.."Y",state)
		Gui["gui"]:setButtonState(obj.."N",not state)
	end
	Gui["gui"]:setVisible("Play",args.play or args.all)
	Gui["gui"]:setVisible("Explore",args.explore or args.all)
	Gui["gui"]:setVisible("Workshop",args.workshop or args.all)
	Gui["gui"]:setVisible("Reset score",args.resetscore or args.all)
	Gui["gui"]:setVisible("Stop game",args.stopgame or args.all)
	Gui["gui"]:setButtonCallback("Play","client_buttonGui")
	Gui["gui"]:setButtonCallback("Explore","client_buttonGui")
	Gui["gui"]:setButtonCallback("Stop game","client_buttonGui")
	if args.open then
		Gui["gui"]:open()
	end
	return Gui
end

function Game.client_settingsUpdate( self, editbox, text )
	if not VaildateNetwork("Game client_settingsUpdate",{},{server=false}) then return end
	local Result = tostring( tonumber(text) or self.cl.gui["settings"][editbox] or 0 )
	self.cl.gui["settings"]["gui"]:setText(editbox,Result)
	self.cl.gui["settings"][editbox] = Result
	self.network:sendToServer("server_updateSettings",{editbox=editbox,value=Result})
end

function Game.client_settingsUpdate2( self, editbox2 )
	if not VaildateNetwork("Game client_settingsUpdate2",{},{server=false}) then return end
	local bool = false
	local editbox = string.sub(editbox2,1,#editbox2-1)
	if string.upper(string.sub(editbox2,#editbox2,#editbox2)) == "Y" then
		bool = true
	end
	self.cl.gui["settings"]["gui"]:setButtonState(editbox.."Y",bool)
	self.cl.gui["settings"]["gui"]:setButtonState(editbox.."N",not bool)
	self.network:sendToServer("server_updateSettings",{editbox=editbox,value=bool})
end

function Game.client_onCommand( self, args )
	if not VaildateNetwork("Game client_onCommand",{},{server=false}) then return end
	if args[1] == "/settings" and Authorised() then
		local Gui = self:client_createSettings({isBlock=false,stopgame=true})
		Gui["gui"]:open()
	elseif args[1] == "/score" then
		if self.cl.gui["score"] then
			self.cl.gui["score"]["gui"]:destroy()
			self.cl.gui["score"] = nil
			return
		end
		local Gui = self:client_makeGui("$CONTENT_DATA/Gui/Layouts/HideAndSeekScore.layout","score",{isHud=true,isInteractive=false})
		Gui["gui"]:open()
	elseif args[1] == "/fly" then
		self.network:sendToServer("server_fly")
	elseif args[1] == "/maps" then
		for i,v in ipairs(Maps) do 
			sm.gui.chatMessage(i.." "..v[1].name)
		end
	elseif Authorised() then
		self.network:sendToServer("server_onCommand",args)
	end
end

function Game.client_onTaunt( self, args )
	if not VaildateNetwork("Game client_onTaunt",{},{server=false}) then return end
	self.network:sendToServer("server_onTaunt",args)
end

function Game.client_createEffect( self, args )
	if not VaildateNetwork("Game client_createEffect",{},{server=false}) then return end
	sm.event.sendToWorld(sm.localPlayer.getPlayer().character:getWorld(),"client_createEffect",args)
	if args.name == "Horn" then
		local v, dot = CamCross(args.pos)
		local val = math.floor( ((math.atan2(v.y,v.z)/math.pi) * 4)+.5 )
		self.cl.pointerval = val
		self.cl.gui["pointer"]:setImage("Image","$CONTENT_DATA/Gui/Pointer/".. val.. ".png")
		self.cl.gui["pointer"]:setVisible("Image",true)
		self.cl.gui["pointer"]:setVisible("Image2",dot > 0.25 and true or false)
		local function Update()
			self.cl.gui["pointer"]:setVisible("Image",false)
			self.cl.gui["pointer"]:setVisible("Image2",false)
		end
		Event("Tick",Update,false,sm.game.getCurrentTick()+40,"tauntwait")
	end
end

function Game:client_onJankyUpdate( data, channel )
	if not VaildateNetwork("Game client_onJankyUpdate",{},{server=false}) then return end
	if data["Variable"] ~= nil and data["Value"] ~= nil then
		self.cl[data["Variable"]] = data["Value"]
	elseif type(data) == "table" and #data > 0 then
		for i,v in ipairs(data) do
			self.cl[v["Variable"]] = v["Value"]
		end
	end
end