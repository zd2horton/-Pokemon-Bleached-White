class Scene_Map
  alias __saving__update update unless method_defined?(:__saving__update)
  def update(*args)
    __saving__update(*args)
    return update_save_sprite if !is_save_possible?(recalc: true)
    if defined?(SaveSettings::QUICKSAVE_KEY) && SaveSettings::QUICKSAVE_KEY &&
       ((Input.const_defined?(SaveSettings::QUICKSAVE_KEY) &&
        Input.trigger?(Input.const_get(SaveSettings::QUICKSAVE_KEY))) ||
        Input.triggerex?(SaveSettings::QUICKSAVE_KEY))
       $game_temp.save_timer <= 0 && $game_temp.save_buffer <= 0 &&
       $game_system && !$game_system.save_disabled &&
       !$game_temp.cue_autosave && !$game_player.moving?
      $game_temp.save_buffer = System.uptime
      $game_temp.save_sprite.opacity = 0
    end
    if $game_temp.save_buffer > 0 && (System.uptime - $game_temp.save_buffer) > 0.1 && !$game_player.moving?
      if $game_temp.cue_autosave
        $autosave_slot = 1
        old_slot = $PokemonSystem.current_save_slot
        Game.save(slot: 0)
        $PokemonSystem.current_save_slot = old_slot
      else
        Game.save(slot: $PokemonSystem.current_save_slot)
      end
      $autosave_slot = 0
      $game_temp.save_timer   = System.uptime
      $game_temp.save_buffer  = 0
      $game_temp.cue_autosave = false
    end
    update_save_sprite
  end

  SAVE_ICON_FADE_DURATION   = 0.5
  SAVE_ICON_LINGER_DURATION = 3.0

  def update_save_sprite
    return if $game_temp.save_timer <= 0
    timer = System.uptime - $game_temp.save_timer
    if timer > (SAVE_ICON_FADE_DURATION + SAVE_ICON_LINGER_DURATION)
      $game_temp.save_sprite.opacity = lerp(255, 0, SAVE_ICON_FADE_DURATION, timer - (SAVE_ICON_FADE_DURATION + SAVE_ICON_LINGER_DURATION))
    elsif timer > SAVE_ICON_FADE_DURATION
      $game_temp.save_sprite.opacity = 255
    else 
      $game_temp.save_sprite.opacity = lerp(0, 255, SAVE_ICON_FADE_DURATION, timer)
    end
    $game_temp.save_sprite.update
    $game_temp.save_timer = 0 if timer > (SAVE_ICON_FADE_DURATION * 2) + SAVE_ICON_LINGER_DURATION
  end

  alias __saving__miniupdate miniupdate unless method_defined?(:__saving__miniupdate)
  def miniupdate(*args)
    __saving__miniupdate(*args)
    update_save_sprite if !is_save_possible?(recalc: true)
  end
end

class Game_Temp
  attr_accessor :save_vp
  attr_accessor :save_sprite
  attr_accessor :save_timer
  attr_accessor :save_buffer

  def save_vp
    if !@save_vp || @save_vp.disposed?
      x = 0; y = Graphics.height/2
      case SaveSettings::SAVING_ICON_POSITION
      when :Top, :Center, :Bottom then x = Graphics.width / 2 - Graphics.width / 4
      when :TopRight, :Right, :BottomRight then x = Graphics.width/2
      end
      case SaveSettings::SAVING_ICON_POSITION
      when :TopLeft, :Top, :TopRight then y = 0
      when :Left, :Center, :Right then y = Graphics.height / 2 - Graphics.height / 4
      end
      @save_vp   = Viewport.new(x, y, Graphics.width / 2, Graphics.height / 2)
      @save_vp.z = 99999
    end
    return @save_vp
  end

  def save_sprite
    if !@save_sprite || @save_sprite.disposed?
      @save_sprite = Sprite.new(self.save_vp)
      refresh_save_sprite
    end
    return @save_sprite
  end

  def refresh_save_sprite
    @save_sprite.bitmap = RPG::Cache.load_bitmap("", "#{SaveSettings::SAVING_ICON_PATH}")
    @save_sprite.bitmap.play if @save_sprite.bitmap.animated?
    x = 8; y = @save_vp.rect.height - 8; ox = 0; oy = @save_sprite.bitmap.height
    case SaveSettings::SAVING_ICON_POSITION
    when :Top, :Center, :Bottom
      x  = @save_vp.rect.width / 2
      ox = @save_sprite.bitmap.width / 2
    when :TopRight, :Right, :BottomRight
      x  = @save_vp.rect.width - 8
      ox = @save_sprite.bitmap.width
    end
    case SaveSettings::SAVING_ICON_POSITION
    when :TopLeft, :Top, :TopRight
      y  = 8
      oy = 0
    when :Left, :Center, :Right
      y  = @save_vp.rect.height / 2
      oy = @save_sprite.bitmap.height / 2
    end
    @save_sprite.x       = x
    @save_sprite.y       = y
    @save_sprite.ox      = ox
    @save_sprite.oy      = oy
    @save_sprite.opacity = 0
  end

  def save_timer
    @save_timer = 0 if !@save_timer
    return @save_timer
  end

  def save_buffer
    @save_buffer = 0 if !@save_buffer
    return @save_buffer
  end
end

def is_save_possible?(key = :base, recalc: false)
  return false if !$game_temp
  return $game_temp.save_possible[key] if !recalc
  ret   = true
  ret_i = true
  ret_m = true
  ret = false if $game_temp.in_menu || $game_temp.in_battle
  ret = false if $game_temp.message_window_showing
  ret = false if !$game_system || $game_system.save_disabled
  ret_m = false if pbMapInterpreterRunning?
  ret_m = false if pbMapInterpreter && pbMapInterpreter.move_route_waiting
  ret_m = false if pbMapInterpreter && pbMapInterpreter.wait_count > 0
  ret_i = false if !$game_map || $game_map.events.values.any? { |e| e.wait_count > 0 }
  ret = false if !$game_temp || $game_temp.executing_script
  ret = false if pbInBugContest?
  ret = false if pbInSafari?
  $game_temp.save_possible[:base]       = ret && ret_i && ret_m
  $game_temp.save_possible[:interp]     = ret_i && ret
  $game_temp.save_possible[:move_route] = ret_m && ret
  return $game_temp.save_possible[key]
end

class Game_Temp
  attr_accessor :save_possible

  def save_possible
    @save_possible = {} if !@save_possible
    return @save_possible
  end
end

class Interpreter
  attr_reader :move_route_waiting
  attr_reader :wait_count

  alias __saving__execute_script execute_script unless method_defined?(:__saving__execute_script)
  def execute_script(*args)
    $game_temp.executing_script = true
    ret = __saving__execute_script(*args)
    $game_temp.executing_script = false
    return ret
  end

  alias __saving__command_201 command_201 unless method_defined?(:__saving__command_201)
  def command_201(*args)
    $game_temp.save_sprite.opacity = 0
    $game_temp.save_timer = 0
    $game_temp.save_sprite.update
    Graphics.update
    ret = __saving__command_201(*args)
    return ret
  end
end

class Game_Event
  attr_reader :wait_count
end
