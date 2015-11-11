-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

require "io"
require "heka_stream_reader"
require "string"
require "snappy"

local hsr = heka_stream_reader.new("stdin")
local dhsr = heka_stream_reader.new("snappy")
local cnt = 0

local function snappy_decode(msgbytes)
    local ok, uc = pcall(snappy.uncompress, msgbytes)
    if ok then
        return uc
    end
    return msgbytes
end

function process_message()
    local fh = io.stdin
    local found, read, consumed
    repeat
        repeat
            found, consumed, read = hsr:find_message(fh, false) -- don't protobuf decode
            if found then
                local pbm = snappy_decode(hsr:read_message("raw"))
                local ok = pcall(dhsr.decode_message, dhsr, pbm)
                if ok then
                    inject_message(dhsr)
                    cnt = cnt + 1
                end
            end
        until not found
    until read == 0
    return 0
end
