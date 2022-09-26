dofile("$CHALLENGE_DATA/Scripts/challenge/ChallengeBaseWorld.lua")
dofile("$CHALLENGE_DATA/Scripts/challenge/world_util.lua")
dofile("$CHALLENGE_DATA/Scripts/game/challenge_shapes.lua")
dofile("$CHALLENGE_DATA/Scripts/game/challenge_tools.lua")
dofile("$SURVIVAL_DATA/Scripts/game/managers/WaterManager.lua")

---@class ChallengeBaseWorld : WorldClass

World = class(ChallengeBaseWorld)
World.terrainScript = "$CONTENT_DATA/Scripts/terrain.lua"
World.cellMinX = -6
World.cellMaxX = 5
World.cellMinY = -7
World.cellMaxY = 6
World.renderMode = "challenge"
World.enableSurface = true

function World.createCharacterOnSpawner(self, data, player)
	if not VaildateNetwork("World createCharacterOnSpawner",{player=player},{server=true,auth=true}) then return end
	local playerSpawners = self.filteredinteractables[tostring(data.uuid or "")] or {}
	for key, player in pairs(data.players or {}) do
		local spawnPosition = sm.vec3.new(2, 2, 20)
		local yaw = 0
		local pitch = 0
		if #playerSpawners > 0 then
			local spawnerIndex = ((player.id - 1) % #playerSpawners) + 1
			local spawner = playerSpawners[spawnerIndex]
			spawnPosition = spawner.shape.worldPosition + spawner.shape:getAt() * 0.825

			local spawnDirection = -spawner.shape:getUp()
			pitch = math.asin(spawnDirection.z)
			yaw = math.atan2(spawnDirection.x, -spawnDirection.y)

			local character = sm.character.createCharacter(player, self.world, spawnPosition, yaw, pitch)
			player:setCharacter(character)
		else
			local character = sm.character.createCharacter(player, self.world, spawnPosition, yaw, pitch)
			player:setCharacter(character)
		end
	end
end

table.find = function(tab, val)
	for key, obj in pairs(tab) do
		if obj == val then
			return key, obj
		end
	end
	return nil
end

function World.destructive(self, state, player)
	if not VaildateNetwork("World destructive",{player=player},{server=true,auth=true}) then return end
	for key, body in pairs(sm.body.getAllBodies()) do
		if sm.exists(body) then
			body.destructable = state
		end
	end
end

function World.server_onCreate(self)
	ChallengeBaseWorld.server_onCreate(self)
	self.waterManager = WaterManager()
	self.waterManager:sv_onCreate(self)
	self.sv = {}
	if self.data == nil then self.data = {} end
	local Value = self.data.play or false
	self.sv.displayFloor = not Value
	self.interactables = {}
	self.filteredinteractables = {}
end

function World:server_onAnnoyed()
	print("te")
end

function World.server_onFixedUpdate(self)
	ChallengeBaseWorld.server_onFixedUpdate(self)
	self.waterManager:sv_onFixedUpdate()
end

function World.server_onInteractableCreated(self, interactable)
	ChallengeBaseWorld.server_onInteractableCreated(self, interactable)
end

function World.server_onInteractableDestroyed(self, interactable)
	ChallengeBaseWorld.server_onInteractableDestroyed(self, interactable)
end

function World.server_onCollision(self, obj1, obj2, position)
	if sm.exists(obj1) and sm.exists(obj2) and sm.challenge.hasStarted() then
		if type(obj1) == "Character" and type(obj2) == "Character" then
			local plr1 = obj1:getPlayer()
			local plr2 = obj2:getPlayer()
			if plr1 and plr2 then
				sm.event.sendToGame("server_onTag", { tagger = plr1, tagged = plr2 })
				sm.event.sendToGame("server_onTag", { tagger = plr2, tagged = plr1 })
			end
		end
	end
end

function World.server_onProjectile(self, position, airTime, velocity, projectileName, shooter, damage, customData, normal
                                   , target, uuid)
	if sm.exists(target) and sm.exists(shooter) then
		if type(target) == "Character" then
			local player = target:getPlayer()
			if player then
				sm.event.sendToGame("server_onTag", { tagger = shooter, tagged = player })
			end
		end
	end
end

function World.server_onMelee(self, position, attacker, target, damage, power, direction, normal)
	local Down = attacker.character:isCrouching()
	if Down then
		sm.event.sendToGame("server_onTag", { tagger = attacker, tagged = attacker })
	end
	if sm.exists(target) and sm.exists(attacker) then
		if type(target) == "Character" then
			local player = target:getPlayer()
			if player then
				sm.event.sendToGame("server_onTag", { tagger = attacker, tagged = player, character = target })
			end
		end
	end
	if target and sm.exists(target) and type(target) == "Shape" and not target.destructable then
		local rot = sm.vec3.getRotation(sm.vec3.new(1, 0, 0), normal) * sm.quat.fromEuler(sm.vec3.new(0, 0, 90))
		self.network:sendToClients("client_createEffect", {
			name = "Barrier - ShieldImpact",
			pos = position,
			rot = rot,
		})
	end
end

function World.server_celebrate(self)
	self.network:sendToClients("client_celebrate")
end

function World:server_effect(args,player)
	if not VaildateNetwork("World server_effect",{player=player},{server=true,auth=true}) then return end
	self.network:sendToClients("client_createEffect",args)
end

function World.server_onCellLoaded(self, x, y)
	self.waterManager:sv_onCellReloaded(x, y)
	if x == 0 and y == 0 then
		FireEvent("WorldCenterLoaded",nil,self.world)
	end
end

function World.server_onCellUnloaded(self, x, y)
	self.waterManager:sv_onCellUnloaded(x, y)
end

function World.server_onInteractableCreated(self, interactable)
	if interactable.shape then
		self.interactables[interactable.id] = tostring(interactable.shape.uuid)
		if not self.filteredinteractables[tostring(interactable.shape.uuid)] then
			self.filteredinteractables[tostring(interactable.shape.uuid)] = {}
		end
		table.insert(self.filteredinteractables[tostring(interactable.shape.uuid)], interactable)
	end
end

function World.server_onInteractableDestroyed(self, interactable)
	if self.interactables[interactable.id] then
		local a = table.find(self.filteredinteractables[self.interactables[interactable.id]], interactable)
		if a then
			table.remove(self.filteredinteractables[self.interactables[interactable.id]], a)
		end
		self.interactables[interactable.id] = nil
	end
end

function World.client_onCreate(self)
	ChallengeBaseWorld.client_onCreate(self)
	self.cl = {}
	if self.sv and self.sv.displayFloor then
		self.cl.floorEffect = sm.effect.createEffect("BuildMode - Floor")
		self.cl.floorEffect:start()
	end
	if self.waterManager == nil then
		assert(not sm.isHost)
		self.waterManager = WaterManager()
	end
	self.waterManager:cl_onCreate()
end

function World.client_onDestroy(self)
	self:client_destroyFloor()
end

function World.client_destroyFloor(self)
	if not VaildateNetwork("World client_destroyFloor",{},{server=false}) then return end
	if self.floorEffect then
		self.cl.floorEffect:destroy()
		self.cl.floorEffect = nil
	end
end

function World.client_celebrate(self)
	if not VaildateNetwork("World client_celebrate",{},{server=false}) then return end
	sm.effect.playEffect("Horn", sm.vec3.new(0, 258, 162))
end

function World.client_createEffect(self, args)
	if not VaildateNetwork("World client_createEffect",{},{server=false}) then return end
	sm.effect.playEffect(args.name, args.pos or sm.camera.getPosition(), args.velocity or sm.vec3.new(0, 0, 0),
		args.rot or sm.quat.identity(), args.scale or sm.vec3.new(1, 1, 1), args.parameter or {})
end

function World.client_onCellLoaded(self, x, y)
	self.waterManager:cl_onCellLoaded(x, y)
	g_effectManager:cl_onWorldCellLoaded(self, x, y)
end

function World.client_onCellUnloaded(self, x, y)
	self.waterManager:cl_onCellUnloaded(x, y)
	g_effectManager:cl_onWorldCellUnloaded(self, x, y)
end

function World.client_onFixedUpdate(self)
	self.waterManager:cl_onFixedUpdate()
end