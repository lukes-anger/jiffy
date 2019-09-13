-- Jiffy
-- 1.0.0 @molotov
-- llllllll.co
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
-- E1      : Slew
-- E2      : Speed
-- E3      : Dub Level
local alt = false
local recording = false
local playing = false
local save_time = 2
local start_time = nil
local current_position = 0
local rec = 0.5
local rate = 1.0
local slew = 0.5
local buffclear = true
local loopclear = false
local pre = 0.9
local UI = require 'ui'

local function reset_loop()
  softcut.buffer_clear(1)
  params:set("loop_start", 0)
  params:set("loop_end",16.0)
  softcut.position(1, 0)
  current_position = 0
end

local function set_loop_start(v)
  v = util.clamp(v, 0, params:get("loop_end") - .01)
  params:set("loop_start", v)
  softcut.loop_start(1, v)
end

local function set_loop_end(v)
  v = util.clamp(v, params:get("loop_start") + .01, 16.0)
  params:set("loop_end", v)
  softcut.loop_end(1, v)
end

local function update_positions(voice,position)
  current_position = position
end

local function pbicon(x,y,s,v)
  screen.aa(1)
  hello = UI.PlaybackIcon.new(x, y, s, v)
  hello:redraw()
end   

local function dialx(x,y,v)
  screen.aa(1)
  d1 = UI.Dial.new (x, y, 20, .5, 0, 5.0, 0.01, 1.0, nothing, 0.0, "slew")
  d1:set_value_delta(v)
  d1:redraw()
end

local function dialy(x,y,v)
  screen.aa(1)
  --markers = {0,1}
  d1 = UI.Dial.new (x, y, 20, 0, 0.0, 1.0, 0.01, 1.0, nothing, 0.0, "level")
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

local function dialtime(x,y,v)
  screen.aa(1)
  markers = {params:get("loop_end")}
  d1 = UI.Dial.new (x, y, 30, 0, 0.0, 16.0, 0.01, 0.0, markers, 0.0, "")
  d1:set_value(v)
  d1:redraw()
end

function init()
  audio.level_cut(1)
  audio.level_adc_cut(1)
  audio.level_eng_cut(1)
  softcut.level(1,1)
  softcut.level_slew_time(1,0.1)
  softcut.level_input_cut(1, 1, 1.0)
  softcut.level_input_cut(2, 1, 1.0)
  softcut.pan(1, 0.5)
  softcut.play(1, 0)
  softcut.rate(1, rate)
  softcut.rate_slew_time(1,0.5)
  softcut.loop_start(1, 0)
  softcut.loop_end(1, 16)
  softcut.loop(1, 1)
  softcut.fade_time(1, 0.1)
  softcut.rec(1, 0)
  softcut.rec_level(1,rec)
  softcut.pre_level(1, pre)
  softcut.position(1, 0)
  softcut.buffer(1,1)
  softcut.enable(1, 1)
  softcut.filter_dry(1, 1)

  -- sample start controls
  params:add_control("loop_start", "loop start", controlspec.new(0.0, 15.99, "lin", .01, 0, "secs"))
  params:set_action("loop_start", function(x) set_loop_start(x) end)
  -- sample end controls
  params:add_control("loop_end", "loop end", controlspec.new(.01, 16, "lin", .01, 350, "secs"))
  params:set_action("loop_end", function(x) set_loop_end(x) end)

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
  if n == 2 and z == 1 then
    if recording == false then
      softcut.rec(1, 1)
      recording = true
      start_time = util.time()
      loopclear = false
    else
      softcut.rec(1, 0)
      recording = false
      playing = true
      softcut.play(1, 1)
      while buffclear == true do
        params:set("loop_end", current_position)
      buffclear = false
      end
    end
  elseif n == 3 and z == 1 then
    if alt then
      reset_loop()
      buffclear = true
      softcut.play(1, 0)
      softcut.rec(1, 0)
      playing = false
      recording = false
      loopclear = true
    else
      if playing == true then
        softcut.play(1, 0)
        softcut.rec(1, 0)
        playing = false
        recording = false
      elseif recording == true then
        softcut.play(1, 0)
        softcut.rec(1, 0)
        playing = false
        recording = false
        while params:get("loop_end") == 16.00 do
          params:set("loop_end", current_position)
        buffclear = false
        end
      else  
        softcut.position(1, 0)
        softcut.play(1, 1)
        softcut.rec(1, 0)
        playing = true
        recording = false
      end
    end
  end
end

function enc(n,d)
  if n==1 then
    slew = util.clamp(slew+d/5,0.1,5)
    softcut.rate_slew_time(1,slew)
  elseif n==2 then
    rate = util.clamp(rate+d/4,-2,2)
    softcut.rate(1,rate)
  elseif n==3 then
    pre = util.clamp(pre+d/100,0,1)
    softcut.pre_level(1,pre)
  end
  redraw()
end

function redraw()
  screen.aa(1)
  screen.clear()
  if recording then
    screen.circle(66,49,5)
    screen.fill()
  elseif playing and rate > 0 then
    pbicon(61,44,10,1)
  elseif playing and rate < 0 then
    pbicon(61,44,10,2)
  elseif playing and rate == 0 then  
    pbicon(61,44,10,0)
  elseif not playing and not recording then
    pbicon(61,44,10,0)  
  end
  screen.move(5, 60)
  screen.level(5)
  if loopclear then
    --screen.text("X")
  end
  screen.move(59,22)
  a = dialz(56,5,rate)
  a = dialx(5,5,slew)
  a = dialtime(51,35,current_position)
  screen.move(100, 60)
  screen.font_face(4)
  screen.font_size(10)   
  if recording or playing then
    screen.text(string.format("%.2f", current_position))
  else
    screen.text(string.format("%.2f", params:get("loop_end")))
  end
  screen.level(15)
  screen.move(108,20)
  b = dialy(105,5,pre)
  screen.update()
end
