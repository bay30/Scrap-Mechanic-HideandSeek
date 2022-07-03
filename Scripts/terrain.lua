dofile( "$SURVIVAL_DATA/Scripts/terrain/terrain_util2.lua" )

tiles = nil
terraindata = {}
gnd = {
	uuid = sm.uuid.new( "688b6f02-3831-496b-9f80-8808bd5ff180" ), --Builder ground
	pos = sm.vec3.new( 32, 32, 0 ),
	rot = sm.quat.identity(),
	scale = sm.vec3.one()
}

function Init()
	print( "Init terrain" )
end

function Create( xMin, xMax, yMin, yMax, seed, data )

	g_uuidToPath = {}
	g_cellData = {
		bounds = { xMin = xMin, xMax = xMax, yMin = yMin, yMax = yMax },
		seed = seed,
		-- Per Cell
		uid = {},
		xOffset = {},
		yOffset = {},
		rotation = {}
	}

	for cellY = yMin, yMax do
		g_cellData.uid[cellY] = {}
		g_cellData.xOffset[cellY] = {}
		g_cellData.yOffset[cellY] = {}
		g_cellData.rotation[cellY] = {}

		for cellX = xMin, xMax do
			g_cellData.uid[cellY][cellX] = sm.uuid.getNil()
			g_cellData.xOffset[cellY][cellX] = 0
			g_cellData.yOffset[cellY][cellX] = 0
			g_cellData.rotation[cellY][cellX] = 0
		end
	end

	if data.world and data.world ~= "" then
		local jWorld = sm.json.open( data.world )
		for _, cell in pairs( jWorld.cellData ) do
			if cell.path ~= "" then
				local uid = sm.terrainTile.getTileUuid( cell.path )
				g_cellData.uid[cell.y][cell.x] = uid
				g_cellData.xOffset[cell.y][cell.x] = cell.offsetX
				g_cellData.yOffset[cell.y][cell.x] = cell.offsetY
				g_cellData.rotation[cell.y][cell.x] = cell.rotation

				g_uuidToPath[tostring(uid)] = cell.path
			end
		end
	end

	if data.tiles then
		tiles = {}
		for _,tile in ipairs( data.tiles ) do
			local uid = sm.terrainTile.getTileUuid( tile )
			tiles[tostring(uid)] = tile
		end
	end
	
	if data.play == true then
		gnd.uuid = sm.uuid.getNil()
	end
	
	terraindata = g_cellData.uid

	--sm.terrainData.save( { g_uuidToPath, g_cellData } ) not challenge mode gg rekt
end

function Load()
	--if sm.terrainData.exists() then
	--	local data = sm.terrainData.load()
	--	g_uuidToPath = data[1]
	--	g_cellData = data[2]
	--	return true
	--end
	return false -- mimic challenge mode :|
end

function GetTilePath( uid )
	if not uid:isNil() then
		if g_uuidToPath[tostring(uid)] then
			return g_uuidToPath[tostring(uid)]
		else
			return tiles[tostring(uid)]
		end
	end
	return ""
end

function GetCellTileUidAndOffset( cellX, cellY )
	if InsideCellBounds( cellX, cellY ) then
		return	g_cellData.uid[cellY][cellX],
				g_cellData.xOffset[cellY][cellX],
				g_cellData.yOffset[cellY][cellX]
	end
	return sm.uuid.getNil(), 0, 0
end

function GetTileLoadParamsFromWorldPos( x, y, lod )
	local cellX, cellY = GetCell( x, y )
	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )
	local rx, ry = InverseRotateLocal( cellX, cellY, x - cellX * CELL_SIZE, y - cellY * CELL_SIZE )
	if lod then
		return  uid, tileCellOffsetX, tileCellOffsetY, lod, rx, ry
	else
		return  uid, tileCellOffsetX, tileCellOffsetY, rx, ry
	end
end

function GetTileLoadParamsFromCellPos( cellX, cellY, lod )
	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )
	if lod then
		return  uid, tileCellOffsetX, tileCellOffsetY, lod
	else
		return  uid, tileCellOffsetX, tileCellOffsetY
	end
end

function GetHeightAt( x, y, lod )
	local Height = sm.terrainTile.getHeightAt( GetTileLoadParamsFromWorldPos( x, y, lod ) )
	local X, Y = GetCell(x,y)
	if terraindata[Y] and terraindata[Y][X] and not terraindata[Y][X]:isNil() and Height ~= nil then
		return Height
	end
	return -3000
end

function GetColorAt( x, y, lod )
	local R,G,B = sm.terrainTile.getColorAt( GetTileLoadParamsFromWorldPos( x, y, lod ) )
	local X, Y = GetCell(x,y)
	if terraindata[Y] and terraindata[Y][X] and not terraindata[Y][X]:isNil() and Color ~= nil then
		return Color
	end
	return R,G,B
end

function GetMaterialAt( x, y, lod )
	local V1,V2,V3,V4,V5,V6,V7,V8 = sm.terrainTile.getMaterialAt( GetTileLoadParamsFromWorldPos( x, y, lod ) )
	local X, Y = GetCell(x,y)
	if terraindata[Y] and terraindata[Y][X] and not terraindata[Y][X]:isNil() and Material ~= nil then
		return V1,V2,V3,V4,V5,V6,V7,V8
	end
	return 0, 0, 0, 0, 0, 0, 0, 0
end

function GetClutterIdxAt( x, y )
	local Clutter = sm.terrainTile.getClutterIdxAt( GetTileLoadParamsFromWorldPos( x, y ) )
	local X, Y = GetCell(x,y)
	if terraindata[Y] and terraindata[Y][X] and not terraindata[Y][X]:isNil() and Clutter ~= nil then
		return Clutter
	end
	return -1
end

function GetAssetsForCell( cellX, cellY, lod )
	local assets = sm.terrainTile.getAssetsForCell( GetTileLoadParamsFromCellPos( cellX, cellY, lod ) ) or {}
	for _, asset in ipairs( assets ) do
		local rx, ry = RotateLocal( cellX, cellY, asset.pos.x, asset.pos.y )
		asset.pos = sm.vec3.new( rx, ry, asset.pos.z )
		asset.rot = GetRotationQuat( cellX, cellY ) * asset.rot
	end
	if tiles and cellX == 0 and cellY == 0 then
		for sUid,_ in pairs( tiles ) do
			local tileAssets = sm.terrainTile.getAssetsForCell( sm.uuid.new( sUid ), 0, 0, lod )
			for _,a in ipairs( tileAssets ) do
				assets[#assets + 1] = a
			end
		end
	end
	if not gnd.uuid:isNil() then
		assets[#assets + 1] = gnd
	end
	return assets
end

function GetNodesForCell( cellX, cellY )
	local nodes = sm.terrainTile.getNodesForCell( GetTileLoadParamsFromCellPos( cellX, cellY ) ) or {}
	for _, node in ipairs( nodes ) do
		local rx, ry = RotateLocal( cellX, cellY, node.pos.x, node.pos.y )
		node.pos = sm.vec3.new( rx, ry, node.pos.z )
		node.rot = GetRotationQuat( cellX, cellY ) * node.rot
	end
	if tiles and cellX == 0 and cellY == 0 then
		for sUid,_ in pairs( tiles ) do
			local tileNodes = sm.terrainTile.getNodesForCell( sm.uuid.new( sUid ), 0, 0 )
			for _,node in ipairs( tileNodes ) do
				nodes[#nodes + 1] = node
			end
		end
	end
	return nodes
end

function GetCreationsForCell( cellX, cellY )
	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )
	if not uid:isNil() then
		local cellCreations = sm.terrainTile.getCreationsForCell( uid, tileCellOffsetX, tileCellOffsetY )
		for i,creation in ipairs( cellCreations ) do
			local rx, ry = RotateLocal( cellX, cellY, creation.pos.x, creation.pos.y )

			creation.pos = sm.vec3.new( rx, ry, creation.pos.z )
			creation.rot = GetRotationQuat( cellX, cellY ) * creation.rot
		end
		if tiles and cellX == 0 and cellY == 0 then
			for sUid,_ in pairs( tiles ) do
				local tileCreations = sm.terrainTile.getCreationsForCell( sm.uuid.new( sUid ), 0, 0 )
				for _,c in ipairs( tileCreations ) do
					cellCreations[#cellCreations + 1] = c
				end
			end
		end
		return cellCreations
	end
	return {}
end

function GetHarvestablesForCell( cellX, cellY, lod )
	local harvestables = sm.terrainTile.getHarvestablesForCell( GetTileLoadParamsFromCellPos( cellX, cellY, lod ) ) or {}
	for _, harvestable in ipairs( harvestables ) do
		local rx, ry = RotateLocal( cellX, cellY, harvestable.pos.x, harvestable.pos.y )
		harvestable.pos = sm.vec3.new( rx, ry, harvestable.pos.z )
		harvestable.rot = GetRotationQuat( cellX, cellY ) * harvestable.rot
	end
	if tiles and cellX == 0 and cellY == 0 then
		for sUid,_ in pairs( tiles ) do
			local tileharvestables = sm.terrainTile.getHarvestablesForCell( sm.uuid.new( sUid ), 0, 0 )
			for _,c in ipairs( tileharvestables ) do
				harvestables[#harvestables + 1] = c
			end
		end
	end
	return harvestables
end

function GetKinematicsForCell( cellX, cellY, lod )
	local kinematics = sm.terrainTile.getKinematicsForCell( GetTileLoadParamsFromCellPos( cellX, cellY, lod ) ) or {}
	for _, kinematic in ipairs( kinematics ) do
		local rx, ry = RotateLocal( cellX, cellY, kinematic.pos.x, kinematic.pos.y )
		kinematic.pos = sm.vec3.new( rx, ry, kinematic.pos.z )
		kinematic.rot = GetRotationQuat( cellX, cellY ) * kinematic.rot
	end
	if tiles and cellX == 0 and cellY == 0 then
		for sUid,_ in pairs( tiles ) do
			local tilekinematics = sm.terrainTile.getKinematicsForCell( sm.uuid.new( sUid ), 0, 0 )
			for _,c in ipairs( tilekinematics ) do
				kinematics[#kinematics + 1] = c
			end
		end
	end
	return kinematics
end

function GetDecalsForCell( cellX, cellY, lod )
	local decals = sm.terrainTile.getDecalsForCell( GetTileLoadParamsFromCellPos( cellX, cellY, lod ) ) or {}
	for _, decal in ipairs( decals ) do
		local rx, ry = RotateLocal( cellX, cellY, decal.pos.x, decal.pos.y )
		decal.pos = sm.vec3.new( rx, ry, decal.pos.z )
		decal.rot = GetRotationQuat( cellX, cellY ) * decal.rot
	end
	if tiles and cellX == 0 and cellY == 0 then
		for sUid,_ in pairs( tiles ) do
			local tiledecals = sm.terrainTile.getDecalsForCell( sm.uuid.new( sUid ), 0, 0 )
			for _,c in ipairs( tiledecals ) do
				decals[#decals + 1] = c
			end
		end
	end
	return decals
end