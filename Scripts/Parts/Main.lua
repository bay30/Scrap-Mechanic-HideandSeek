Main = class()
Main.one = nil

function Main.server_onCreate( self )
	if Main.one == nil then
		Main.one = self.shape
	else
		self.shape:destroyShape()
		return
	end
	self.sv = {}
	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.tiles = {"$CONTENT_DATA/Terrain/Tiles/challengemode_env_DT.tile","$CONTENT_DATA/Terrain/Tiles/ChallengeBuilderDefault.tile"} -- Array of tiles {"$CONTENT_UUID/TILENAME.tile"} (requires them to install tile btw)
		self.sv.saved.world = "" -- Point to world "$CONTENT_UUID/WORLDNAME.world" (requires them to install world)
		self.sv.saved.settings = {Hammer=true}
		self.sv.saved.blueprints = {}
		self.storage:save( self.sv.saved )
	end
end

function Main.server_onDestroy( self )
	if self.shape == Main.one then
		Main.one = nil
	end
end

function Main.server_setValues( self )
	sm.hideandseek.settings = self.sv.saved.settings
	sm.hideandseek.tiles = self.sv.saved.tiles
	sm.hideandseek.world = self.sv.saved.world
	sm.hideandseek.blueprints = self.sv.saved.blueprints
end

function Main.server_save( self )
	if sm.hideandseek then
		self.sv.saved.settings = sm.hideandseek.settings
	end
	self.sv.saved.blueprints = {}
	for key,creation in pairs(sm.body.getCreationsFromBodies(sm.body.getAllBodies())) do
		local blueprint = sm.creation.exportToString( creation[1], true, false )
		table.insert(self.sv.saved.blueprints,blueprint)
	end
	self.storage:save( self.sv.saved )
end

function Main.client_onInteract( self, character, state )
	if not state or not sm.isHost then return end
	self.network:sendToServer("server_setValues")
	sm.event.sendToGame("client_createSettings",{isBlock=true,open=true,play=true,explore=true})
end

function Main.client_onTinker( self, character, state )
	if not state then return end
	print("Save")
	self.network:sendToServer("server_save")
end

function Main.client_canInteract( self )
	sm.gui.setInteractionText("", sm.gui.getKeyBinding("Use"), "Open Gui")
	sm.gui.setInteractionText("", sm.gui.getKeyBinding("Tinker"), "Save")
	return true
end

function Main.server_load()
	print("Load")
	local ContentMissing = false
	local String = "----[Loader]----\n"
	for key,tile in pairs(self.sv.saved.tiles) do
		if not sm.json.fileExists(tile) then
			String = String.. "[Tile]: "..tile.. " Missing\n"
			ContentMissing = true
		end
	end
	if self.sv.saved.world and type(self.sv.saved.world) == "string" and self.sv.saved.world ~= "" then
		if sm.json.fileExists(self.sv.saved.world) then
			local jWorld = sm.json.open( data.world )
			for _, cell in pairs( jWorld.cellData ) do
				if cell.path ~= "" then
					if not sm.json.fileExists(cell.path) then
						String = String.. "[World]: "..cell.path.. " Missing\n"
						ContentMissing = true
					end
				end
			end
		else
			String = String.. "[World]: Missing "..self.sv.saved.world.."\n"
			ContentMissing = true
		end
	end
	if ContentMissing then
		sm.gui.chatMessage(String.."Check the blueprint required items or ask the creator what they used.")
	end
end