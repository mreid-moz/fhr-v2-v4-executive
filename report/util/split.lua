require "io"
require "string"
require "table"

files = {}
fields = {}
for line in io.lines() do
    -- Strip trailing EOLs from the line
    local field_count = 0
    -- for field in string.gmatch(line, "([^\t]*)[\t\r]") do
    for field in string.gmatch(line, "^.*\t([^\t]+)\r$") do
        field_count = field_count + 1
        fields[field_count] = field
        --print("Field", field_count, "is", field)
    end
    if field_count ~= 18 then
        io.stderr:write("Wrong number of fields:", field_count, ":")
        io.stderr:write(line, "\n")
    else
        local day = fields[18]
        local f = files[day]
        if not f then
            f = io.open("split_l/"..day, "w+")
            files[day] = f
        end
        f:write(line, "\n")
    end
end

for k, v in pairs(files) do
  v:close()
end
