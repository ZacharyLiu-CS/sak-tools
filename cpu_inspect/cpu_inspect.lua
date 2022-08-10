#!/bin/lua
require("lfs")

local monitor_config  = {
  binary_name = "ycsbc",
  frequency = 400,    -- 400 times in a second
  time_duration = 60, -- 60 seconds
  process_id = -1,
}

local flamegraph_path = "./FlameGraph"
local flamegraph_remote_url = "git@github.com:brendangregg/FlameGraph.git"

local is_binary_executing = false

function isemptydir(directory,nospecial)
  for filename in require('lfs').dir(directory) do
    if filename ~= '.' and filename ~= '..' then
      return false
    end
  end
  return true
end

function capture(cmd, raw)
  local f = assert(io.popen(cmd, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  if raw then return s end
  s = string.gsub(s, '^%s+', '')
  s = string.gsub(s, '%s+$', '')
  s = string.gsub(s, '[\n\r]+', ' ')
  return s
end



-- git clone the flamegraph to the targeted path
local attr = lfs.attributes(flamegraph_path)
if (attr == nil) then
  lfs.mkdir(flamegraph_path)
end

if ( isemptydir(flamegraph_path) ) then
  os.execute("git clone ".. flamegraph_remote_url)
end

-- get the binary process's pid
if (monitor_config.process_id == -1) then
  local ps_command = "ps -aux |grep " .. monitor_config.binary_name .. " |grep -v grep |awk '{print$2}' | head -n 1"
  local pid = capture(ps_command, true)
  if ( pid ~= "" ) then
    is_binary_executing = true
    monitor_config.process_id = pid
    print(monitor_config.binary_name .. " process id :" .. monitor_config.process_id)
   else
	print(monitor_config.binary_name .. " not running!")
  end

end

-- execute the perf command
if ( is_binary_executing) then
local perf_command = "sudo perf record -F " .. monitor_config.frequency .. " -p " .. monitor_config.process_id .. " -g -- sleep " .. monitor_config.time_duration
local output_name = monitor_config.binary_name .. "_" .. os.time() ..  ".svg"
local draw_command = "sudo perf script | ".. flamegraph_path.. "/stackcollapse-perf.pl ".. flamegraph_path.. "/flamegraph.pl" .. " > "  ..output_name
os.execute(perf_command)
os.execute(draw_command)
end
