dofile( "$CHALLENGE_DATA/Scripts/challenge/ChallengeBaseWorld.lua")
dofile( "$CHALLENGE_DATA/Scripts/challenge/world_util.lua" )
dofile( "$CHALLENGE_DATA/Scripts/game/challenge_shapes.lua" )
dofile( "$CHALLENGE_DATA/Scripts/game/challenge_tools.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/WaterManager.lua" )

World = class( ChallengeBaseWorld )
World.terrainScript = "$CONTENT_DATA/Scripts/terrain.lua"
World.cellMinX = -6
World.cellMaxX = 5
World.cellMinY = -7
World.cellMaxY = 6
World.renderMode = "challenge"
World.enableSurface = true

function World.createCharacterOnSpawner( self, data )
	local playerSpawners = self.filteredinteractables[tostring(data.uuid or "")] or {}
	print(playerSpawners)
	for key,player in pairs(data.players or {}) do
		local spawnPosition = sm.vec3.new(0,0,100)
		local yaw = 0
		local pitch = 0
		if #playerSpawners > 0 then
			local spawnerIndex = ( ( player.id - 1 ) % #playerSpawners ) + 1
			local spawner = playerSpawners[spawnerIndex]
			spawnPosition = spawner.shape.worldPosition + spawner.shape:getAt() * 0.825
		
			local spawnDirection = -spawner.shape:getUp()
			pitch = math.asin( spawnDirection.z )
			yaw = math.atan2( spawnDirection.x, -spawnDirection.y )
			
			local character = sm.character.createCharacter( player, self.world, spawnPosition, yaw, pitch )
			player:setCharacter( character )
		else
			print("not enough spawners")
		end
	end
end

table.find = function(tab,val)
	for key,obj in pairs(tab) do
		if obj == val then
			return key,obj
		end
	end
	return nil
end

function World.destructive( self, state )
	for key,body in pairs(sm.body.getAllBodies()) do
		if sm.exists(body) then
			body.destructable = state
		end
	end
end

function World.server_onCreate( self )
	ChallengeBaseWorld.server_onCreate( self )
    self.waterManager = WaterManager()
	self.waterManager:sv_onCreate( self )
	self.sv = {}
	if data == nil then data = {} end
	local Value = data.play or false
	self.sv.displayFloor = Value
	self.interactables = {}
	self.filteredinteractables = {}
end

function World.server_onFixedUpdate( self )
	ChallengeBaseWorld.server_onFixedUpdate( self )
	self.waterManager:sv_onFixedUpdate()
end

function World.server_onInteractableCreated( self, interactable )
	ChallengeBaseWorld.server_onInteractableCreated( self, interactable )
end

function World.server_onInteractableDestroyed( self, interactable )
	ChallengeBaseWorld.server_onInteractableDestroyed( self, interactable )
end

function World.server_onProjectile( self, position, airTime, velocity, projectileName, shooter, damage, customData, normal, target, uuid )
	if sm.exists(target) and sm.exists(shooter) then
		if type(target) == "Character" then
			local player = target:getPlayer()
			if player then
				sm.event.sendToGame("server_onTag",{tagger=shooter,tagged=player})
			end
		end
	end
end

function World.server_onMelee( self, position, attacker, target, damage, power, direction, normal )
	local Down = attacker.character:isCrouching()
	if Down then
		if sm.exists(target) and sm.exists(attacker) then
			if type(target) == "Character" and not Down then
				local player = target:getPlayer()
				if player then
					sm.event.sendToGame("server_onTag",{tagger=attacker,tagged=player})
				end
			end
		end
	else
		sm.event.sendToGame("server_onTag",{tagger=attacker,tagged=attacker})
	end
end

function World.server_celebrate( self )
	self.network:sendToClients("client_celebrate")
end

function World.server_onCellLoaded( self, x, y )
	self.waterManager:sv_onCellReloaded( x, y )
end

function World.server_onCellUnloaded( self, x, y )
	self.waterManager:sv_onCellUnloaded( x, y )
end

function World.server_onInteractableCreated( self, interactable )
	if interactable.shape then
		self.interactables[interactable.id] = tostring(interactable.shape.uuid)
		if not self.filteredinteractables[tostring(interactable.shape.uuid)] then
			self.filteredinteractables[tostring(interactable.shape.uuid)] = {}
		end
		table.insert(self.filteredinteractables[tostring(interactable.shape.uuid)],interactable)
	end
end

function World.server_onInteractableDestroyed( self, interactable )
	if self.interactables[interactable.id] then
		local a = table.find(self.filteredinteractables[self.interactables[interactable.id]],interactable)
		if a then
			table.remove(self.filteredinteractables[self.interactables[interactable.id]],a)
		end
		self.interactables[interactable.id] = nil
	end
end

function World.client_onCreate( self )
	ChallengeBaseWorld.client_onCreate( self )
	self.cl = {}
	if self.sv and self.sv.displayFloor then
		self.cl.floorEffect = sm.effect.createEffect( "BuildMode - Floor" )
		self.cl.floorEffect:start()
	end
	if self.waterManager == nil then
		assert( not sm.isHost )
		self.waterManager = WaterManager()
	end
	self.waterManager:cl_onCreate()
end

function World.client_onDestroy( self )
	self:client_destroyFloor()
end

function World.client_destroyFloor( self )
	if self.floorEffect then
		self.cl.floorEffect:destroy()
		self.cl.floorEffect = nil
	end
end

function World.client_celebrate( self )
	sm.effect.playEffect( "Horn", sm.vec3.new( 0, 258, 162 ) )
end

function World.client_createEffect( self, args )
	sm.effect.playEffect( args.name, args.pos or sm.vec3.new(0,0,0), args.velocity or sm.vec3.new(0,0,0), args.rot or sm.quat.identity(), args.scale or sm.vec3.new(1,1,1), args.parameter or {} )
end

function World.client_onCellLoaded( self, x, y )
	self.waterManager:cl_onCellLoaded( x, y )
	g_effectManager:cl_onWorldCellLoaded( self, x, y )
end

function World.client_onCellUnloaded( self, x, y )
	self.waterManager:cl_onCellUnloaded( x, y )
	g_effectManager:cl_onWorldCellUnloaded( self, x, y )
end

function World.client_onFixedUpdate( self )
	self.waterManager:cl_onFixedUpdate()
end