local Config = sm.json.open("$CONTENT_DATA/description.json")
Maps = {}

for i, v in ipairs(Config.dependencies or {}) do
    if v.localId ~= "00000000-0000-0000-0000-000000000000" and pcall(function() return sm.json.fileExists("$CONTENT_" .. v.localId .. "/description.json") end) then
        local description = sm.json.open("$CONTENT_" .. v.localId .. "/description.json")
        if description.type == "Challenge Pack" then
            local pack = sm.json.open("$CONTENT_" .. v.localId .. "/challengePack.json")
            for _,map in ipairs(pack and pack.levelList or {}) do
                local id = "$CONTENT_".. v.localId.. "/".. map.uuid
                local desc = map
                if desc then
                    table.insert(Maps, 1, {desc,id,v})
                end
            end
        end
    else
        Event("Tick", function ()
            sm.gui.chatMessage("#ff645eMap with invaild localId, you can find the localId at.\nSteam\\steamapps\\workshop\\content\\387990\\".. v.fileId.. "\\description.json")
        end, false, 0)
    end
end