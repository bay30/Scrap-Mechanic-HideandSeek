local ServerEvents = {}
local ClientEvents = {}

function FireEvent(Name, Time, ...)
    if type(Name) ~= "string" then assert(false, "EventName must be a string!") return end
    if type(Time) ~= "number" then Time = 0 end
    local Target = sm.isServerMode() and ServerEvents or ClientEvents
    if Target[Name] then
        local i = 1
        while Target[Name][i] ~= nil do
            if Time >= Target[Name][i][3] then
                local v = Target[Name][i]
                if not v[2] then
                    table.remove(Target[Name], i)
                else
                    i = i + 1
                end
                local Success, Value = pcall(function(...)
                    local Break = v[1](...)
                    if Break and v[2] then
                        table.remove(Target[Name], i)
                    end
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

function Event(Name, Callback, Repeating, Time, Id) -- Id is used if you wanna overwrite preexisting events.
    if type(Name) ~= "string" then assert(false, "EventName must be a string!") return end
    if type(Callback) ~= "function" then assert(false, "Callback must be a function!") return end
    if type(Repeating) ~= "boolean" then Repeating = false end
    if type(Time) ~= "number" then Time = 0 end
    local Target = sm.isServerMode() and ServerEvents or ClientEvents
    if not Target[Name] then
        Target[Name] = {}
    end
    if Id and Target[Name] then
        local i = 1
        repeat
            if Target[Name][i] and Target[Name][i][4] == Id then
                table.remove(Target[Name],i)
            else
                i = i + 1
            end
        until i >= #Target[Name]
    end
    table.insert(Target[Name], { Callback, Repeating, Time, Id })
end
