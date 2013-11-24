-- collection of utilities to make life easier

-- object oriented help
-- from http://stackoverflow.com/questions/1092832/how-to-create-a-class-subclass-and-properties-in-lua
clone = function(object, ...) 
    local ret = {}

    -- clone base class
    if type(object)=="table" then 
        for k,v in pairs(object) do 
            if type(v) == "table" then
                v = clone(v)
            end
            -- don't clone functions, just inherit them
            if type(v) ~= "function" then
                -- mix in other objects.
                ret[k] = v
            end
        end
    end
    -- set metatable to object
    setmetatable(ret, { __index = object })

    -- mix in tables
    for _,class in ipairs(arg) do
        for k,v in pairs(class) do 
            if type(v) == "table" then
                v = clone(v)
            end
            -- mix in v.
            ret[k] = v
        end
    end

    return ret
end

-- tables to strings
-- from http://lua-users.org/wiki/TableUtils
function table.val_to_str ( v )
    if "string" == type( v ) then
        v = string.gsub( v, "\n", "\\n" )
        if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
            return "'" .. v .. "'"
        end
        return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
    else
        return "table" == type( v ) and table.tostring( v ) or tostring( v )
    end
end

function table.key_to_str ( k )
    if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
        return k
    else
        return "[" .. table.val_to_str( k ) .. "]"
    end
end

function table.tostring( tbl )
    local result, done = {}, {}
    for k, v in ipairs( tbl ) do
        table.insert( result, table.val_to_str( v ) )
        done[ k ] = true
    end
    for k, v in pairs( tbl ) do
        if not done[ k ] then
          table.insert( result, table.key_to_str( k ) .. "=" .. table.val_to_str( v ) )
        end
    end
    return "{" .. table.concat( result, "," ) .. "}"
end

-- write some text to a log file
log = function(text)
    -- outputs to /home/usr/.love/gamefolder/log.txt
    if text == nil then
        -- convert a nil value into a string
        text = ""
    end
    local f = love.filesystem.newFile("log.txt", love.file_append)
    love.filesystem.open(f)
    love.filesystem.write(f, text.."\n")
    love.filesystem.close(f)
end

