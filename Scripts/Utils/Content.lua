local Config = sm.json.open("$CONTENT_DATA/description.json")
Maps = {}

for i, v in ipairs(Config.dependencies or {}) do
    if sm.json.fileExists("$CONTENT_" .. v.localId .. "/description.json") then
        local description = sm.json.open("$CONTENT_" .. v.localId .. "/description.json")
        if description.type == "Challenge Pack" then
            local pack = sm.json.open("$CONTENT_" .. v.localId .. "/challengePack.json")
            for _,map in ipairs(pack and pack.levelList or {}) do
                local id = "$CONTENT_".. v.localId.. "/".. map.uuid
                local desc = map
                if desc then
                    table.insert(Maps, 1, {desc,id,v.localId})
                end
            end
        end
    end
end