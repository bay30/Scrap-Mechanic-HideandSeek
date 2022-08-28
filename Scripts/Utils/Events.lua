local ServerEvents = {}
local ClientEvents = {}

function FireEvent(Name, Time)
    if type(Name) ~= "string" then assert(false, "EventName must be a string!") return end
    if type(Time) ~= "number" then Time = 0 end
    local Target = sm.isServerMode() and ServerEvents or ClientEvents
    if Target[Name] then
        local i = 1
        while Target[Name][i] ~= nil do
            if Time >= Target[Name][i][3] then
                local v = Target[Name][i]
                if v[2] == false then
                    table.remove(Target[Name], i)
                else
                    i = i + 1
                end
                local Success, Value = pcall(function()
                    v[1]()
                end)
                if not Success then
                    print(i, Value)
                end
            else
                i = i + 1
            end
        end
    end
end

function Event(Name, Callback, Repeating, Time)
    if type(Name) ~= "string" then assert(false, "EventName must be a string!") return end
    if type(Callback) ~= "function" then assert(false, "Callback must be a function!") return end
    if type(Repeating) ~= "boolean" then Repeating = false end
    if type(Time) ~= "number" then Time = 0 end
    local Target = sm.isServerMode() and ServerEvents or ClientEvents
    if not Target[Name] then
        Target[Name] = {}
    end
    table.insert(Target[Name], { Callback, Repeating, Time })
end
