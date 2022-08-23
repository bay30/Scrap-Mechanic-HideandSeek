Main = class()
Main.one = nil
Main.id = 0

function Main.server_onCreate(self)
	if Main.one == nil and self.shape:getBody():getWorld().id == 1 then
		Main.one = self.shape
	else
		self.shape:destroyShape()
		return
	end
	self.sv = {}
	self.sv.saved = self.storage:load()
	local FromStorage = true
	if self.sv.saved == nil then
		FromStorage = false
		self.sv.saved = {}
		self.sv.saved.tiles = { "$CONTENT_DATA/Terrain/Tiles/challengemode_env_DT.tile",
			"$CONTENT_DATA/Terrain/Tiles/ChallengeBuilderDefault.tile" } -- Array of tiles {"$CONTENT_UUID/TILENAME.tile"} (requires them to install tile btw)
		self.sv.saved.world = "" -- Point to world "$CONTENT_UUID/WORLDNAME.world" (requires them to install world)
		self.sv.saved.settings = { Hammer = true }
		self.sv.saved.blueprints = {}
		self.storage:save(self.sv.saved)
	end
	print(self.sv.saved.settings)
	if FromStorage then
		if Main.id ~= self.shape.id then
			self:server_load()
			self:server_setValues(true,sm.player.getAllPlayers()[1])
			Main.id = self.shape.id
		end
	end
end

function Main.server_onDestroy(self)
	if self.shape == Main.one then
		Main.one = nil
	end
end

function Main.server_setValues(self,boolean,player)
	if player and player.id ~= 1 then print(player:getName().. " Fired \"Main.server_setValues!\"") return end
	sm.event.sendToGame("server_setValues", {self.sv.saved,boolean,player})
end

function Main.server_setSettings(self,values)
	self.sv.saved.settings = values
end

function Main.server_save(self, args, player)
	if player and player.id ~= 1 then print(player:getName().. " Fired \"Main.server_save!\"") return end
	local CustomWorld
	local CustomTiles
	--CustomWorld = "$CONTENT_8b575391-5eb4-488e-980e-01352a88a1ad/world.world" -- Make sure your world and any custom tiles are include the blueprint $CONTENT_BLUEPRINTUUID/worldname.world (includes terrain)
	--CustomTiles = {} -- Make sure the tiles are instead your blueprint $CONTENT_BLUEPRINTUUID/tilename.tile (these include no terrain)
	self.sv.saved = self.sv.saved or {}

	self.sv.saved.blueprints = {}
	self.storage:save(self.sv.saved)
	for key, creation in pairs(sm.body.getCreationsFromBodies(sm.body.getAllBodies())) do
		local blueprint = sm.creation.exportToString(creation[1], true, creation[1]:isOnLift())
		table.insert(self.sv.saved.blueprints, blueprint)
	end

	self.sv.saved.world = CustomWorld or ""
	self.sv.saved.tiles = CustomTiles or
		{ "$CONTENT_DATA/Terrain/Tiles/challengemode_env_DT.tile", "$CONTENT_DATA/Terrain/Tiles/ChallengeBuilderDefault.tile" }

	local success, result = pcall(function()
		self.storage:save(self.sv.saved)
	end)
	if not success then
		sm.gui.chatMessage("#f22015Failure saving, replace block and try again")
	end
end

function Main.server_load(self, args, player)
	if player and player.id ~= 1 then print(player:getName().. " Fired \"Main.server_load!\"") return end
	local ContentMissing = false
	local String = "----[Content Verifyer]----\n"
	for key, tile in pairs(self.sv.saved.tiles) do
		if not sm.json.fileExists(tile) then
			String = String .. "[Tile]: " .. tile .. " Missing\n"
			ContentMissing = true
		end
	end
	if self.sv.saved.world and type(self.sv.saved.world) == "string" and self.sv.saved.world ~= "" then
		if sm.json.fileExists(self.sv.saved.world) then
			local jWorld = sm.json.open(self.sv.saved.world)
			for _, cell in pairs(jWorld.cellData) do
				if cell.path ~= "" then
					if not sm.json.fileExists(cell.path) then
						String = String .. "[World]: " .. cell.path .. " Missing\n"
						ContentMissing = true
					end
				end
			end
		else
			String = String .. "[World]: Missing " .. self.sv.saved.world .. "\n"
			ContentMissing = true
		end
	end
	if ContentMissing then
		sm.gui.chatMessage(String .. "Check the blueprint required items or ask the creator what they used.")
	end
end

function Main.client_onInteract(self, character, state)
	if not state or not sm.isHost then return end
	self.network:sendToServer("server_setValues",true)
	self.network:sendToServer("server_load")
end

function Main.client_onTinker(self, character, state)
	if not state then return end
	self.network:sendToServer("server_save")
	return sm.isHost
end

function Main.client_canInteract(self)
	sm.gui.setInteractionText("", sm.gui.getKeyBinding("Use"), "Open Gui")
	sm.gui.setInteractionText("", sm.gui.getKeyBinding("Tinker"), "Save")
	return sm.isHost
end