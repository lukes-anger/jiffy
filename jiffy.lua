-- Jiffy
-- 1.1 @molotov
-- llllllll.co/t/jiffy
--
-- >>------>
--
-- 16 Sec Looper
--
-- >>------>
--
-- K2      : Record // Loop
-- K3      : Play // Stop
-- K1 + K3 : Delete
--
-- >>------>
--
-- E1      : Wonk
-- E2      : Speed
-- E3      : Dub Level


local alt = false
local recording = false
local playing = false
local start_time = nil
local current_position = 0
local rec = 0.5
local rate = 1.0
local slew = 0.5
local buffclear = true
local loopclear = false
local pre = 0.9
local UI = require 'ui'

function stereo()
  -- set softcut to stereo inputs
  softcut.level_input_cut(1, 1, 1)
  softcut.level_input_cut(2, 1, 0)
  softcut.level_input_cut(1, 2, 0)
  softcut.level_input_cut(2, 2, 1)
end


function mono()
  --set softcut to mono input
  softcut.level_input_cut(1, 1, 1)
  softcut.level_input_cut(2, 1, 0)
  softcut.level_input_cut(1, 2, 1)
  softcut.level_input_cut(2, 2, 0)
end

function set_input(n)
  if n == 1 then
    stereo()
  else
    mono()
  end
end

local function reset_loop()
  -- empties buffers and resets loop length to 16 secs
  for i = 1,2 do
    softcut.buffer_clear(i)
    params:set(i .. "loop_start", 0)
    params:set(i .. "loop_end",16.0)
    softcut.position(i, 0)
  end
  current_position = 0
end

local function set_loop_start(v)
  for i = 1,2 do
    v = util.clamp(v, 0, params:get(i .. "loop_end") - .01)
    params:set(i .. "loop_start", v)
    softcut.loop_start(i, v)
  end
end

local function set_loop_end(v)
  for i = 1,2 do
    v = util.clamp(v, params:get(i .. "loop_start") + .01, 16.0)
    params:set(i .. "loop_end", v)
    softcut.loop_end(i, v)
  end
end


local function update_positions(voice,position)
  current_position = position
end

local function pbicon(x,y,s,v)
  screen.aa(1)
  pbi = UI.PlaybackIcon.new(x, y, s, v)
  pbi:redraw()
end   

local function dialx(x,y,v)
  screen.aa(1)
  d1 = UI.Dial.new (x, y, 20, 0, 0.0, 1.0, 0.01, 0.0, nothing, 0.0, "slew")
  d1:set_value_delta(v)
  d1:redraw()
end

local function dialy(x,y,v)
  screen.aa(1)
  d1 = UI.Dial.new (x, y, 20, 0, 0.0, 1.0, 0.01, 0.0, nothing, 0.0, "dub")
  d1:set_value_delta(v)
  d1:redraw()
end

local function dialz(x,y,v)
  screen.aa(1)
  markers = {-1,0,1}
  d1 = UI.Dial.new (x, y, 20, 0, -2.0, 2.0, 0.01, 1.0, markers, 0.0, "speed")
  d1:set_value_delta(v)
  d1:redraw()
end

local function dialtime(i,x,y,v)
  screen.aa(1)
  markers = {params:get(i .. "loop_end")}
  d1 = UI.Dial.new (x, y, 40, 0, 0.0, 16.0, 0.01, 0.0, markers, 0.0, "")
  d1:set_value(v)
  d1:redraw()
end

function init()
  audio.level_cut(1)
  audio.level_adc_cut(1)
  audio.level_eng_cut(1)
  softcut.level_input_cut(1, 1, 1)
  softcut.level_input_cut(2, 1, 0)
  softcut.level_input_cut(1, 2, 0)
  softcut.level_input_cut(2, 2, 1)  
  softcut.pan(1,-1)
  softcut.pan(2,1)
  for i = 1, 2 do
    softcut.level(i,1)
    softcut.level_slew_time(i,0.1)
    softcut.play(i, 0)
    softcut.rate(i, rate)
    softcut.rate_slew_time(i,0.5)
    softcut.loop_start(i, 0)
    softcut.loop_end(i, 16)
    softcut.loop(i, 1)
    softcut.fade_time(i, 0.1)
    softcut.rec(i, 0)
    softcut.rec_level(i,rec)
    softcut.pre_level(i, pre)
    softcut.position(i, 0)
    softcut.buffer(i,i)
    softcut.enable(i, 1)
    softcut.filter_dry(i, 1)


    -- sample start controls
    params:add_control(i .. "loop_start", i .. "loop start", controlspec.new(0.0, 15.99, "lin", .01, 0, "secs"))
    params:set_action(i .. "loop_start", function(x) set_loop_start(x) end)
    -- sample end controls
    params:add_control(i .. "loop_end", i .. "loop end", controlspec.new(.01, 16, "lin", .01, 350, "secs"))
    params:set_action(i .. "loop_end", function(x) set_loop_end(x) end)
  end
  
  -- input
  params:add_option("input", "input", {"stereo", "mono (L)"}, 1)
  params:set_action("input", function(x) set_input(x) end)  
  
  -- screen metro
  local screen_timer = metro.init()
  screen_timer.time = 1/15
  screen_timer.event = function() redraw() end
  screen_timer:start()

  -- softcut phase poll
  softcut.phase_quant(1, .01)
  softcut.event_phase(update_positions)
  softcut.poll_start_phase()
end 


-- looper logic
function key(n, z)
  
  -- set key1 as alt
  if n == 1 then
    alt = z == 1 and true or false
  end
  
  -- set key2 as record/overdub
    -- set key1 as alt
  if n == 1 then
    alt = z == 1 and true or false
  end
  
  -- set key2 as record/overdub
  if n == 2 and z == 1 then
    if recording == false and playing == true then
      for i = 1,2 do
        softcut.rec(i, 1)
        softcut.play(i, 1) 
      end  
      recording = true
      start_time = util.time()
      loopclear = false
    elseif recording == false and playing == false then
      for i = 1,2 do
        softcut.position(i, 0)
        softcut.rec(i, 1)
        softcut.play(i, 1) 
      end  
      recording = true
      start_time = util.time()
      loopclear = false
    else  
      for i = 1,2 do
        softcut.rec(i, 0)
        softcut.play(i, 1)        
      end  
      recording = false
      playing = true
      while buffclear == true do
        for i = 1,2 do
          params:set(i .. "loop_end", current_position)
        end  
      buffclear = false
      end
    end
  elseif n == 3 and z == 1 then
    if alt then
    for i = 1,2 do
        softcut.play(i, 0)
        softcut.rec(i, 0)
      end        
      reset_loop()
      buffclear = true
      playing = false
      recording = false
      loopclear = true
    else
      if playing == true then
        for i = 1,2 do
          softcut.play(i, 0)
          softcut.rec(i, 0)
        end  
        playing = false
        recording = false
      elseif recording == true then
        for i = 1,2 do
          softcut.play(i, 0)
          softcut.rec(i, 0)
          while params:get(i .. "loop_end") == 16.00 do
            params:set(i .. "loop_end", current_position) 
        end  
        playing = false
        recording = false
        buffclear = false
        end
      else  
        for i = 1,2 do
          softcut.position(i, 0)
          softcut.play(i, 1)
          softcut.rec(i, 0)
        end
        playing = true
        recording = false
      end
    end
  end
end


-- encoder settings
function enc(n,d)
  if n==1 then
    slew = util.clamp(slew+d/5,0.1,5)
    for i = 1,2 do
      softcut.rate_slew_time(i,slew)
    end
  elseif n==2 then
    rate = util.clamp(rate+d/4,-2,2)
    for i = 1,2 do
      softcut.rate(i,rate)
    end  
  elseif n==3 then
    pre = util.clamp(pre+d/100,0,1)
    for i = 1,2 do
      softcut.pre_level(i,pre)
    end  
  end
  redraw()
end

-- gui
function redraw()
  screen.aa(1)
  screen.clear()
  screen.font_size(10)
  if recording then
    screen.circle(66,25,5)
    screen.fill()
  elseif playing and rate > 0 then
    pbicon(61,20,10,1)
  elseif playing and rate < 0 then
    pbicon(61,20,10,2)
  elseif playing and rate == 0 then  
    pbicon(61,20,10,0)
  elseif not playing and not recording then
    pbicon(61,20,10,0)  
  end
  dialz(5,5,rate)
  dialx(5,35,slew)
  -- uses voice 1 as current position
  dialtime(1, 46,5,current_position)
  screen.move(90, 55)
  screen.font_face(4)
  screen.font_size(20)  
  if recording or playing then
    screen.text(string.format("%.1f", current_position))
  else
    -- uses voice 1 as loop_end indicator
    screen.text(string.format("%.1f",params:get(1 .. "loop_end")))
  end
  --screen.level(15)
  screen.move(106,20)
  screen.font_size(10)
  dialy(105,5,pre)
  screen.update()
end

