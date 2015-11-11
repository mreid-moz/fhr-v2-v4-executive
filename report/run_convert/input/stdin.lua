-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

require "io"
require "lpeg"
require "math"
require "string"
require "table"
local dt = require "date_time"

local fx = require "fx"

local crash_fields = {
    docType                     = {value = ""},
    submissionDate              = {value = ""},
    activityTimestamp           = {value = 0},
    profileCreationTimestamp    = {value = 0},
    clientId                    = {value = ""},
    documentId                  = {value = ""},
    country                     = {value = ""},
    channel                     = {value = ""},
    os                          = {value = ""},
    osVersion                   = {value = ""},
    default                     = {value = false},
    buildId                     = {value = ""},
    app                         = {value = ""},
    version                     = {value = ""},
    vendor                      = {value = ""},
}

local main_fields = {
    docType                     = crash_fields.docType,
    submissionDate              = crash_fields.submissionDate,
    activityTimestamp           = crash_fields.activityTimestamp,
    profileCreationTimestamp    = crash_fields.profileCreationTimestamp,
    clientId                    = crash_fields.clientId,
    documentId                  = crash_fields.documentId,
    country                     = crash_fields.country,
    channel                     = crash_fields.channel,
    os                          = crash_fields.os,
    osVersion                   = crash_fields.osVersion,
    default                     = crash_fields.default,
    buildId                     = crash_fields.buildId,
    app                         = crash_fields.app,
    version                     = crash_fields.version,
    vendor                      = crash_fields.vendor,
    reason                      = {value = ""},
    hours                       = {value = 0},
    google                      = {value = 0, value_type = 2},
    bing                        = {value = 0, value_type = 2},
    yahoo                       = {value = 0, value_type = 2},
    other                       = {value = 0, value_type = 2},
    pluginHangs                 = {value = 0, value_type = 2},
}

local msg = {
    Timestamp   = nil,
    Logger      = "fx",
    Type        = "executive_summary",
    Fields      = main_fields,
}

local cnt = 0;

local date_grammar = dt.build_strftime_grammar("%Y-%m-%d")

local function parse_date(date)
   if type(date) ~= "string" then return nil end

   -- local t = dt.rfc3339:match(date)
   local t = date_grammar:match(date)
   if not t then
      return nil
   end

   return dt.time_to_ns(t) -- The timezone of the ping has always zero UTC offset
end

local function parse_int(strnum)
    if strnum == nil then return nil end
    local n = tonumber(strnum)
    if n == nil then return nil end
    return math.floor(n)
end

local function get_default(something)
    local n = tonumber(something)
    if n ~= nil and n > 0 then
        return true
    else
        return false
    end
end

num_fields = 18

CID = 1
DID = 2
COUNTRY = 3
CHANNEL = 4
OS = 5
PCT = 6
IN_OUT = 7
HOURS = 8
GOOGLE = 9
BING = 10
YAHOO = 11
OTHER = 12
DEFAULT = 13
BID = 14
VERSION = 15
CRASHES = 16
PHANGS = 17
ACTIVITY = 18

local fields = {}
local field_count = 0
function process_message()
    for line in io.lines() do
        -- Example line:
        -- clientid    documentid    AU      release WINNT   16291.0 in      0.122     0.0     0.0     0.0     1.0     0.0     20150122        35      0.0    0.0      2015-08-05
        field_count = 0
        for field in string.gmatch(line, "([^\t]*)[\t\r]") do
            field_count = field_count + 1
            fields[field_count] = field
        end
        if field_count == num_fields then
            local ts = parse_date(fields[ACTIVITY])
            msg.Timestamp = ts
            msg.Fields.docType                     = "main"
            msg.Fields.submissionDate              = fields[ACTIVITY]
            msg.Fields.activityTimestamp           = ts
            msg.Fields.profileCreationTimestamp    = parse_int(fields[PCT])
            msg.Fields.clientId                    = fields[CID]
            msg.Fields.documentId                  = fields[DID]
            msg.Fields.country                     = fx.normalize_country(fields[COUNTRY])
            msg.Fields.channel                     = fx.normalize_channel(fields[CHANNEL])
            msg.Fields.os                          = fx.normalize_os(fields[OS])
            --msg.Fields.osVersion                   = fields[]
            msg.Fields.default                     = get_default(fields[DEFAULT])
            msg.Fields.buildId                     = fields[BID]
            -- TODO: confirm
            msg.Fields.app                         = fields["Firefox"]
            msg.Fields.version                     = fields[VERSION]
            -- TODO: confirm
            msg.Fields.vendor                      = fields["Mozilla"]
            msg.Fields.reason                      = fields["fhr"]
            msg.Fields.hours                       = tonumber(fields[HOURS])
            msg.Fields.google                      = parse_int(fields[GOOGLE])
            msg.Fields.bing                        = parse_int(fields[BING])
            msg.Fields.yahoo                       = parse_int(fields[YAHOO])
            msg.Fields.other                       = parse_int(fields[OTHER])
            msg.Fields.pluginHangs                 = parse_int(fields[PHANGS])

            -- Check if this msg should be in or out:
            if fields[IN_OUT] == "in" then
                -- It's FHR only
                inject_message(msg, cnt)
                cnt = cnt + 1
                local num_crashes = parse_int(fields[CRASHES])

                -- Reset count fields, then inject a bunch of crashes.
                msg.Fields.docType = "crash"
                msg.Fields.hours = 0
                msg.Fields.google = 0
                msg.Fields.bing = 0
                msg.Fields.yahoo = 0
                msg.Fields.other = 0
                msg.Fields.pluginHangs = 0

                if type(num_crashes) == "number" then
                    for i=1,num_crashes do
                        inject_message(msg, cnt)
                        cnt = cnt + 1
                    end
                end
            else
                -- It's expected to be in the overlap of FHR and UT
                msg.Fields.reason                      = "SKIP ME"
            end
        end
    end

    return 0, tostring(cnt)
end
