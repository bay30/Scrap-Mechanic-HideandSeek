dofile( "$CHALLENGE_DATA/Scripts/challenge/game_util.lua" )
dofile( "$CHALLENGE_DATA/Scripts/challenge/world_util.lua" )
dofile( "$CHALLENGE_DATA/Scripts/game/challenge_shapes.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_meleeattacks.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/EffectManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/UnitManager.lua" )
Game = class( nil )
Game.enableRestrictions = true

function Game.createCharacterOnSpawner( self, player, playerSpawners, defaultPosition )
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
	G_ChallengeStarted = false
	G_ChallengeStartTick = 0
	sm.challenge.hasStarted = function()
		return G_ChallengeStarted
	end
	sm.challenge.start = function()
		if not G_ChallengeStarted then
			G_ChallengeStarted = true
			G_ChallengeStartTick = os.clock()
			for key,plr in pairs(sm.player.getAllPlayers()) do
				sm.hideandseek.score[plr.id] = {plr=plr,tags=0,hidetime=0}
			end
		end
	end
	sm.challenge.stop = function()
		if G_ChallengeStarted then
			G_ChallengeStarted = false
		end
	end
	sm.hideandseek = {}
	sm.hideandseek.settings = {}
	sm.hideandseek.score = {}
	sm.hideandseek.seekers = {}
	sm.hideandseek.selectedseekers = {}
	self.sv.objectlist = {}
	self.sv.activeWorld = self.sv.saved.buildWorld
	self.sv.countdownStarted = false
	self.sv.gameRunning = true
	self.sv.countdownTime = 0
	sm.game.bindChatCommand("/return",{},"server_onCommand","Returns everyone to the build world.")
end

function Game.server_onFixedUpdate( self, delta )
	g_unitManager:sv_onFixedUpdate()
	if not self.sv.gameRunning then return end
	local Hiders = 0
	for key,info in pairs(sm.hideandseek.score) do
		if sm.hideandseek.seekers[key] == nil then
			info.hidetime = os.clock() - G_ChallengeStartTick
			Hiders = Hiders + 1
		end
	end
	if self.sv.objectlist.starters then
		for key,obj in pairs(self.sv.objectlist.starters) do
			if sm.exists(obj) then
				if obj.interactable.active and not self.sv.countdownStarted then
					self.sv.countdownStarted = true
					self.sv.countdownTime = tonumber(sm.hideandseek.settings.HideTime) or 60
					
					for key,plr in pairs(sm.player.getAllPlayers()) do
						if plr.character then
							if sm.hideandseek.seekers[plr.id] then
								if sm.hideandseek.seekers[plr.id]["seeker"] then
									self.network:sendToClients("client_setTag",{character=plr.character,name="[Seeker] "..plr:getName()})
								else
									self.network:sendToClients("client_setTag",{character=plr.character,name="[Hider] "..plr:getName()})
								end
							else
								self.network:sendToClients("client_setTag",{character=plr.character,name=""})
								sm.event.sendToWorld(self.sv.activeWorld,"createCharacterOnSpawner",{players=sm.player.getAllPlayers(),uuid="b5858089-b1f8-4d13-a485-fdcb204d9c6b"})
							end
						end
					end
					
					sm.event.sendToWorld(self.sv.activeWorld,"destructive",sm.hideandseek.settings.Destruction)
					
				end
			end
		end
	end
	if self.sv.activeWorld ~= self.sv.saved.buildWorld then
		if self.sv.countdownStarted and self.sv.countdownTime > 1 then
			self.sv.countdownTime = self.sv.countdownTime - delta
			local seconds = self.sv.countdownTime
			local minutes = seconds/60
			local hours = minutes/60
			self.network:sendToClients("client_displayAlert",string.format( "%02i:%02i:%02i", hours%60, minutes%60, seconds%60 ))
		elseif self.sv.countdownStarted and not sm.challenge.hasStarted() then
			sm.challenge.start()
			self.sv.countdownTime = self.sv.countdownTime - delta
			self.network:sendToClients("client_displayAlert","Seekers have been released")
			sm.event.sendToWorld(self.sv.activeWorld,"createCharacterOnSpawner",{players=sm.player.getAllPlayers(),uuid="b5858089-d1f8-4d13-a485-fdcb204d9c6b"})
		end
	end
	if sm.challenge.hasStarted() and sm.hideandseek.settings.GameTime and sm.hideandseek.settings.GameTime ~= 0 then
		local seconds = (G_ChallengeStartTick+sm.hideandseek.settings.GameTime)-os.clock()
		local minutes = seconds/60
		local hours = minutes/60
		self.network:sendToClients("client_displayTimer",string.format( "%02i:%02i:%02i", hours%60, minutes%60, seconds%60 ))
		if seconds <= 0 then
			self.sv.gameRunning = false
			self.network:sendToClients("client_displayTimer","00:00:00")
			self.network:sendToClients("client_displayAlert","Game over!")
			sm.event.sendToWorld(self.sv.activeWorld,"server_celebrate")
		end
	elseif sm.challenge.hasStarted() and Hiders < 1 then
		self.sv.gameRunning = false
		self.network:sendToClients("client_displayTimer","00:00:00")
		self.network:sendToClients("client_displayAlert","Game over!")
		sm.event.sendToWorld(self.sv.activeWorld,"server_celebrate")
	end
end

function Game.server_onTag( self, args )
	print(self.sv.countdownStarted)
	if args["tagger"] and args["tagged"] and self.sv.activeWorld ~= self.sv.saved.buildWorld and self.sv.gameRunning then
		if sm.hideandseek.seekers[args["tagger"].id] and sm.challenge.hasStarted() then
			if not sm.hideandseek.seekers[args["tagged"].id] and sm.hideandseek.seekers[args["tagger"].id]["seeker"] then
				if sm.hideandseek.BecomeSeekers then
					sm.hideandseek.seekers[args["tagged"].id] = {args["tagged"],seeker=true}
					self.network:sendToClients("client_setTag",{character=args["tagged"].character,name="[Seeker] "..args["tagged"]:getName()})
				else
					sm.hideandseek.seekers[args["tagged"].id] = {args["tagged"],seeker=false}
					self.network:sendToClients("client_setTag",{character=args["tagged"].character,name="[Hider] "..args["tagged"]:getName()})
				end
				sm.hideandseek.score[args["tagger"].id].tags = sm.hideandseek.score[args["tagger"].id].tags + 1
			end
		elseif args["tagger"].id == 1 and sm.hideandseek.settings.PickSeekers and not sm.challenge.hasStarted() and not self.sv.countdownStarted then
			if sm.hideandseek.seekers[args["tagged"].id] then
				sm.hideandseek.seekers[args["tagged"].id] = nil
				self.network:sendToClients("client_setTag",{character=args["tagged"].character,name=""})
			else
				sm.hideandseek.seekers[args["tagged"].id] = {args["tagged"],seeker=true}
				self.network:sendToClients("client_setTag",{character=args["tagged"].character,name="[Seeker] "..args["tagged"]:getName()})
			end
		end
	end
end

function Game.client_setTag(self,args)
	args["character"]:setNameTag(args["name"])
end

function Game.server_getTableLength( self, tab )
	local a = 0
	for key,item in pairs(tab) do
		a=a+1
	end
	return a
end

function Game.server_load( self, args )

	local Edited = args == nil and false or args

	if args then

		sm.game.setLimitedInventory(not sm.hideandseek.settings.Limited)
		self.sv.countdownStarted = false
	
		-- Seekers --
	
		if sm.hideandseek.settings.PickSeekers == nil or sm.hideandseek.settings.PickSeekers == false then
			local Selection = sm.player.getAllPlayers()
			local Seekers = 1
			if sm.hideandseek.settings.Seekers and #sm.hideandseek.settings.Seekers <= #Selection then
				Seekers = sm.hideandseek.settings.Seekers
			end
			print(Selection,self:server_getTableLength(sm.hideandseek.selectedseekers))
			if Seekers < #Selection-self:server_getTableLength(sm.hideandseek.selectedseekers) then
				for key,plr in pairs(Selection) do
					if sm.hideandseek.selectedseekers[plr.id] then
						table.remove(Selection,key)
					end
				end
			end
			sm.hideandseek.selectedseekers = {}
			print(Selection)
			for i = 1, Seekers do
				local Number = math.random(1,#Selection)
				local Selected = Selection[Number]
				sm.hideandseek.selectedseekers[Selected.id] = Number
				sm.hideandseek.seekers[Selected.id] = {Selected,seeker=true}
				table.remove(Selection,Number)
			end
		end
	
		-- Seekers --
	
		-- Inv --
		local Array = {}
		if sm.hideandseek.settings.Hammer then
			table.insert(Array,"09845ac0-4785-4ce8-98b3-0aa4a88c4bdd")
		end
		if sm.hideandseek.settings.Spudgun then
			table.insert(Array,"041d874e-46b3-49ec-8b26-e3db9770c6fd")
		end
		for _,plr in pairs(sm.player.getAllPlayers()) do 
			local inventoryContainer = plr:getInventory()
			sm.container.beginTransaction()
			for i = 0,inventoryContainer.size do
				sm.container.setItem( inventoryContainer, i, sm.uuid.new(Array[i+1] or "00000000-0000-0000-0000-000000000000"), 1 )
			end
			sm.container.endTransaction()
		end
		-- Inv --
		
	else
		self.sv.countdownStarted = true
	end
	
	self:server_setWorld("play")
	
	sm.hideandseek.SpawnerList = {}
	for key,creation in pairs(sm.hideandseek.blueprints or {}) do
		local creation = sm.creation.importFromString( self.sv.activeWorld, creation, sm.vec3.zero(), sm.quat.identity(), true )
		for _,body in ipairs(creation) do
			body.erasable = Edited
			body.buildable = Edited
			body.usable = Edited
			body.liftable = Edited
			body.destructable = Edited
			for key,shape in pairs(body:getShapes()) do
				if shape.uuid == sm.uuid.new("4a9929e9-aa85-4791-89c2-f8799920793f") then
					if not self.sv.objectlist.starters then
						self.sv.objectlist.starters = {}
					end
					table.insert(self.sv.objectlist.starters,shape)
				elseif shape.uuid == sm.uuid.new("b5858089-b1f8-4d13-a485-fdaa204d9c6b") then
					table.insert(sm.hideandseek.SpawnerList,{pos=shape.worldPosition,at=shape:getAt(),up=shape:getUp()})
				end
			end
		end
	end
	
	for key,plr in pairs(sm.player.getAllPlayers()) do
		self.sv.activeWorld:loadCell( 0, 0, plr, "sv_createPlayerCharacter" )
	end
	
	if args then
		sm.challenge.start()
		self.sv.gameRunning = false
	end
	
end

function Game.server_onCommand( self, args )
	if args[1] == "/return" then
		self:server_setWorld("build")
	end
end

function Game.server_setWorld( self, args )
	if args == "build" then
		sm.hideandseek.seekers = {}
		sm.challenge.stop()
		sm.game.setLimitedInventory(false)
		self.sv.gameRunning = false
		self.network:sendToClients("client_displayTimer","00:00:00")
		if self.sv.activeWorld ~= self.sv.saved.buildWorld then
			self.sv.objectlist = {}
			self.sv.activeWorld:destroy()
			self.sv.activeWorld = self.sv.saved.buildWorld
		end
		for key,plr in pairs(sm.player.getAllPlayers()) do
			self.sv.activeWorld:loadCell( 0, 0, plr, "sv_createPlayerCharacter" )
		end
	elseif args == "play" then
		sm.challenge.stop()
		self.sv.gameRunning = true
		if self.sv.activeWorld ~= self.sv.saved.buildWorld then
			self.sv.objectlist = {}
			self.sv.activeWorld:destroy()
		end
		self.sv.activeWorld = sm.world.createWorld( "$CONTENT_DATA/Scripts/World.lua", "World", { world=sm.hideandseek.world, tiles=sm.hideandseek.tiles, play=true } )
	end
end

function Game.server_onPlayerJoined( self, player, isNewPlayer )
	g_unitManager:sv_onPlayerJoined( player )
	
    if not sm.exists( self.sv.activeWorld ) then
        sm.world.loadWorld( self.sv.activeWorld )
    end
    self.sv.activeWorld:loadCell( 0, 0, player, "sv_createPlayerCharacter" )
	
	if player.id == 1 then
		sm.gui.chatMessage("[------------------------]\nWelcome to hide & seek gamemode!")
	end
	
	sm.hideandseek.score[player.id] = {plr=player,tags=0,hidetime=0}
	
	if self.sv.activeWorld ~= self.sv.saved.buildWorld then
		for _,player in pairs(sm.player.getAllPlayers()) do
			local character = player.character
			if sm.hideandseek.seekers[player.id] then
				if sm.hideandseek.seekers[player.id]["seeker"] then
					self.network:sendToClients("client_setTag",{character=character,name="[Seeker] "..player:getName()})
				else
					self.network:sendToClients("client_setTag",{character=character,name="[Hider] "..player:getName()})
				end
			else
				self.network:sendToClients("client_setTag",{character=character,name=""})
			end
		end
	end
	
end

function Game.server_onPlayerLeft( self, player )
	sm.hideandseek.score[player.id] = nil
end

function Game.sv_createPlayerCharacter( self, world, x, y, player, params )
	local pos,pitch,yaw = self:createCharacterOnSpawner(player,sm.hideandseek.SpawnerList or {},sm.vec3.new( 2, 2, 20 ))
    local character = sm.character.createCharacter( player, world, pos,pitch,yaw )
	player:setCharacter( character )
end

function Game.client_onLoadingScreenLifted( self )
	g_effectManager:cl_onLoadingScreenLifted()
end

function Game.client_displayAlert( self, text )
	sm.gui.displayAlertText(text)
end

function Game.client_displayTimer( self, text )
	if sm.challenge.hasStarted() and self.sv.gameRunning then
		self.cl.gui["timer"]:setVisible("Time",true)
		self.cl.gui["timer"]:setText("Time", text)
	else
		self.cl.gui["timer"]:setVisible("Time",false)
	end
end

function Game.client_onCreate( self )
	
	sm.challenge.hasStarted = function()
		return G_ChallengeStarted
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
	end
	
	self.cl = {}
	self.cl.gui = {}
	
	self.cl.gui["timer"] = sm.gui.createChallengeHUDGui()
	self.cl.gui["timer"]:open()
	self.cl.gui["timer"]:setVisible("Time",false)
	
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

function Game.client_onFixedUpdate( self )
	if self.cl.gui["score"] and self.cl.gui["score"]["gui"] and sm.exists(self.cl.gui["score"]["gui"]) then
		for i = 1, 8 do
			local plr,score = getTablePosition(sm.hideandseek.score,i)
			if plr and score then
				self.cl.gui.score.gui:setText("Player"..i,tostring(score.plr:getName()))
				self.cl.gui.score.gui:setText("TextScore"..i,tostring(score.tags))
				
				local seconds = score.hidetime % 60
				local minutes = ( score.hidetime / 60 ) % 60
				local hours = ( ( score.hidetime / 60 ) / 60 ) % 60
				
				self.cl.gui.score.gui:setText("TextTime"..i,string.format( "%02i:%02i:%02i", hours, minutes, seconds ))
			else
				self.cl.gui.score.gui:setText("Player"..i, "Player")
				self.cl.gui.score.gui:setText("TextScore"..i,"N/A")
				self.cl.gui.score.gui:setText("TextTime"..i,"N/A")
			end
		end
	end
end

function Game.client_makeGui(self,layout,val,data)
	if self.cl.gui[val] then
		self.cl.gui[val] = nil
	end
	self.cl.gui[val] = {gui=sm.gui.createGuiFromLayout(layout,true,data or {})}
	return self.cl.gui[val]
end

function Game.client_buttonGui(self,btn)
	if btn == "Play" then
		self.network:sendToServer("server_load",false)
	elseif btn == "Explore" then
		self.network:sendToServer("server_load",true)
	elseif btn == "Stop game" then
		self.network:sendToServer("server_setWorld","build")
	end
end

function Game.client_createSettings( self, args )
	local Gui = self:client_makeGui("$CONTENT_DATA/Gui/Layouts/HideAndSeekMenu.layout","settings")
	Gui["gui"]:setTextChangedCallback("GameTime","client_settingsUpdate")
	Gui["gui"]:setTextChangedCallback("HideTime","client_settingsUpdate")
	Gui["gui"]:setTextChangedCallback("Seekers","client_settingsUpdate")
	Gui["gui"]:setText("GameTime",sm.hideandseek.settings.GameTime or "0")
	Gui["gui"]:setText("HideTime",sm.hideandseek.settings.HideTime or "60")
	Gui["gui"]:setText("Seekers",sm.hideandseek.settings.Seekers or "1")
	local buttons = {"BecomeSeekers","PickSeekers","Limited","Destruction","Hammer","Spudgun"}
	for _,obj in pairs(buttons) do
		Gui["gui"]:setButtonCallback(obj.."Y","client_settingsUpdate2")
		Gui["gui"]:setButtonCallback(obj.."N","client_settingsUpdate2")
		local state = sm.hideandseek.settings[obj] or false
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

function Game.server_updateSettings(self,args)
	sm.hideandseek.settings[args["editbox"]] = args["value"]
end

function Game.client_settingsUpdate( self, editbox, text )	
	local Result = tostring( tonumber(text) or self.cl.gui["settings"][editbox] or 0 )
	self.cl.gui["settings"]["gui"]:setText(editbox,Result)
	self.cl.gui["settings"][editbox] = Result
	self.network:sendToServer("server_updateSettings",{editbox=editbox,value=Result})
end

function Game.client_settingsUpdate2( self, editbox2 )
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
	if args[1] == "/settings" and sm.isHost then
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
	end
end

function Game.server_fly( self, params, player )
	if player and player.character then
		if not player.character:isSwimming() then
			player.character.publicData.waterMovementSpeedFraction = 5
		else
			player.character.publicData.waterMovementSpeedFraction = 1
		end
		player.character:setSwimming(not player.character:isSwimming())
	end
end