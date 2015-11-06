-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

require "io"
require "heka_stream_reader"
require "string"

local hsr = heka_stream_reader.new("stdin")
local cnt = 0

function process_message()
    local found, read, need = false, 0, 8192
    while true do
        local buf = io.stdin:read(need)
        if not buf then break end

        repeat
            found, read, need = hsr:find_message(buf)
            if found then
                cnt = cnt + 1
                inject_message(hsr)
            end
            buf = nil
        until not found
    end

    return 0, tostring(cnt)
end
