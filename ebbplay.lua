-- euclidean drummer
-- @tehn
--
-- E1 select
-- E2 density
-- E3 length
-- K2 reset phase
-- K3 start/stop
--
-- K1 = ALT
-- ALT-E1 = bpm
--
-- add samples via param menu

er = require 'er'
engine.name = 'Ack'

local g = grid.connect()

local ack = require 'ack'
local BeatClock = require 'beatclock'

local intervals = {1, 16/15, 9/8, 6/5, 5/4, 4/3, 45/32, 3/2, 8/5, 5/3, 9/5, 15/8}
local bpm_glob = 120
-- local clk = BeatClock.new()
-- local clk2 = BeatClock.new() 
-- local clk_midi = midi.connect()
-- clk_midi.event = clk.process_midi

local reset = false
local alt = false
local running = true
local track_edit = 1
local current_pattern = 0
local current_pset = 0

local track = {}
for i=1,4 do
  track[i] = {
    k = 0,
    n = 9 - i,
    pos = 1,
    s = {}
  }
end

local clocks = {}
for i=1,4 do
  clocks[i] = BeatClock.new()
end

local pattern = {}
for i=1,112 do
  pattern[i] = {
    data = 0,
    k = {},
    n = {}
  }
  for x=1,4 do
    pattern[i].k[x] = 0
    pattern[i].n[x] = 0
  end
end

local function reer(i)
  if track[i].k == 0 then
    for n=1,32 do track[i].s[n] = false end
  else
    track[i].s = er.gen(track[i].k,track[i].n)
  end
end

local function trig()
  for i=1,4 do
    if track[i].s[track[i].pos] then
      engine.trig(i-1)
    end
  end
end

function init()
  for i=1,4 do reer(i) end

  screen.line_width(1)
  for i=1,4 do
    if i == 1 then 
      clocks[i].on_step = step1
      params:add{type="number",id="intrvl1",name="intrvl1",
      min=1,max=12,default=1,
      action=function(n) 
        intrvl1=n
        clocks[i].bpm = bpm_glob * intervals[intrvl1]
        
        end}
    elseif i == 2 then
      clocks[i].on_step = step2
      params:add{type="number",id="intrvl2",name="intrvl2",
      min=1,max=12,default=1,
      action=function(n) 
        intrvl2=n
        clocks[i].bpm = bpm_glob * intervals[intrvl2]
        
        end}
    elseif i == 3 then
      clocks[i].on_step = step3
      params:add{type="number",id="intrvl3",name="intrvl3",
      min=1,max=12,default=1,
      action=function(n) 
        intrvl3=n
        clocks[i].bpm = bpm_glob * intervals[intrvl3]
        
        end}
    else 
      clocks[i].on_step = step4
      params:add{type="number",id="intrvl4",name="intrvl4",
      min=1,max=12,default=1,
      action=function(n) 
        intrvl4=n
        clocks[i].bpm = bpm_glob * intervals[intrvl4]
        end}
    end
    clocks[i].on_select_internal = function() clocks[i]:start() end
    clocks[i].on_select_external = reset_pattern
    
  end
  
  for channel=1,4 do
    ack.add_channel_params(channel)
  end
  ack.add_effects_params()

  params:read("playfair.pset")
  params:bang()

  playfair_load()
  for i=1,4 do
    clocks[i]:start()
  end
end

function reset_pattern()
  reset = true
  for i=1,4 do
    clocks[i]:reset()
  end
end

function step1()
  step_logic(1)
end
function step2()
  step_logic(2)
end
function step3()
  step_logic(3)
end
function step4()
  step_logic(4)
end

function step_logic(ind)
  if reset then
    for i=1,4 do track[i].pos = 1 end
    reset = false
  else
    track[ind].pos = (track[ind].pos % track[ind].n) + 1
  end
  trig()
  redraw()
end

function key(n,z)
  if n==1 then alt = z
  elseif n==2 and z==1 then reset_pattern()
  elseif n==3 and z==1 then
    if running then
      for i=1,4 do
        clocks[i]:stop()
      end
      running = false
    else
      for i=1,4 do
        clocks[i]:start()
      end
      running = true
    end
  end
  redraw()
end

function enc(n,d)
  if n==1 then
    if alt==1 then
      params:delta("bpm", d)
    else
      track_edit = util.clamp(track_edit+d,1,4)
    end
  elseif n == 2 then
    track[track_edit].k = util.clamp(track[track_edit].k+d,0,track[track_edit].n)
  elseif n==3 then
    track[track_edit].n = util.clamp(track[track_edit].n+d,1,32)
    track[track_edit].k = util.clamp(track[track_edit].k,0,track[track_edit].n)
  end
  reer(track_edit)
  redraw()
end

function redraw()
  screen.aa(0)
  screen.clear()
  screen.move(0,10)
  screen.level(4)
  screen.fill()
  for i=1,4 do
    screen.level((i == track_edit) and 15 or 4)
    screen.move(5, i*10 + 10)
    screen.text_center(track[i].k)
    screen.move(20,i*10 + 10)
    screen.text_center(track[i].n)

    for x=1,track[i].n do
      screen.level((track[i].pos==x and not reset) and 15 or 2)
      screen.move(x*3 + 30, i*10 + 10)
      if track[i].s[x] then
        screen.line_rel(0,-8)
      else
        screen.line_rel(0,-2)
      end
      screen.stroke()
    end
  end
  screen.update()
end


local keytimer = 0

function g.event(x,y,z)
  local id = x + (y-1)*16
  if z==1 then
    if id > 16 then
      keytimer = util.time()
    elseif id < 17 then
      params:read("tehn/playfair-" .. string.format("%02d",id) .. ".pset")
      params:bang()
      current_pset = id
    end
  else
    if id > 16 then
      id = id - 16
      local elapsed = util.time() - keytimer
      if elapsed < 0.5 and pattern[id].data == 1 then
        -- recall pattern
        current_pattern = id
        for i=1,4 do
          track[i].n = pattern[id].n[i]
          track[i].k = pattern[id].k[i]
          reer(i)
        end
        --reset_pattern()
      elseif elapsed > 0.5 then
        -- store pattern
        current_pattern = id
        for i=1,4 do
          pattern[id].n[i] = track[i].n
          pattern[id].k[i] = track[i].k
          pattern[id].data = 1
        end
      end
    end
    gridredraw()
  end
end

function gridredraw()
  g.all(0)
  if current_pset > 0 and current_pset < 17 then
    g.led(current_pset,1,9)
  end
  for x=1,16 do
    for y=2,8 do
      local id = x + (y-2)*16
      if pattern[id].data == 1 then
        g.led(x,y,id == current_pattern and 15 or 4)
      end
    end
  end
  g:refresh()
end


function playfair_save()
  local fd=io.open(data_dir .. "ok/playfair.data","w+")
  io.output(fd)
  for i=1,112 do
    io.write(pattern[i].data .. "\n")
    for x=1,4 do
      io.write(pattern[i].k[x] .. "\n")
      io.write(pattern[i].n[x] .. "\n")
    end
  end
  io.close(fd)
end

function playfair_load()
  local fd=io.open(data_dir .. "tehn/playfair.data","r")
  if fd then
    print("found datafile")
    io.input(fd)
    for i=1,112 do
      pattern[i].data = tonumber(io.read())
      for x=1,4 do
        pattern[i].k[x] = tonumber(io.read())
        pattern[i].n[x] = tonumber(io.read())
      end
    end
    io.close(fd)
  end
end

cleanup = function()
  playfair_save()
end
