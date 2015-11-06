-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

require "io"
require "os"
require "string"

--[[
*Example Configuration*
filename        = "heka_by_day.lua"
message_matcher = "TRUE"
ticker_interval = 0
thread          = 0
--location where the payload is written
output_dir      = "/tmp"
output_prefix   = "heka"
output_ns_field = "Timestamp"
--]]
local output_dir    = read_config("output_dir") or "/tmp"
local output_prefix = read_config("output_prefix") or "heka"
local output_ns_field = read_config("output_ns_field") or "Timestamp"
local files = {}

function process_message()
local ts = read_message(output_ns_field)
if not ts then return -1, "missing timestamp" end
local ds = os.date("%Y%m%d", ts / 1e9)

local fh = files[ds]
if not fh then
    fn = string.format("%s/%s.%s.log", output_dir, output_prefix, ds)
    local err
    fh, err = io.open(fn, "a")
    if err then return -1, err end
    files[ds] = fh
end

local msg = read_message("framed")
fh:write(msg)

return 0
end

function timer_event(ns)
-- no op
end 
