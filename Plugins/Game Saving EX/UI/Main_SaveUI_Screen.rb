class SaveSlotSelection_Scene

  attr_reader :single_screen

  def initialize(saved_data, show_new_game)
    @saved_data    = saved_data
    @show_new_game = show_new_game
    @viewport      = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z    = 99999
    @sprites       = {}
    @autosave_slot = @saved_data.any? { |data| data.is_a?(Hash) && data[:autosave_slot] == 1 } && !@show_new_game
    @index         = ($PokemonSystem&.current_save_slot || 1) - (@show_new_game || (@autosave_slot ^ $game_temp.in_load_screen) ? 1 : 0)
    @index         = 0 if @index < 0
    @cmd_index     = 0
    @single_screen = @saved_data.length <= 1 && (!@show_new_game || @saved_data[0][:temp])
    @index         = 0 if @single_screen
    @sprites["background"] = Sprite.new(@viewport)
    @sprites["background"].bitmap = Bitmap.new("Graphics/UI/Load Screen/bg")
    @sprites["leftarrow"]     = AnimatedSprite.new("Graphics/UI/Load Screen/leftarrow", 8, 40, 28, 2, @viewport)
    @sprites["leftarrow"].y   = (Graphics.height / 2) - 14
    @sprites["leftarrow"].ox  = @sprites["leftarrow"].bitmap.width
    @sprites["rightarrow"]    = AnimatedSprite.new("Graphics/UI/Load Screen/rightarrow", 8, 40, 28, 2, @viewport)
    @sprites["rightarrow"].y  = (Graphics.height / 2) - 14
    draw_save_panels
    @sprites["leftarrow"].visible  = false
    @sprites["rightarrow"].visible = (@saved_data.length > 1)
    @sprites["button_use"] = Sprite.new(@viewport)
    @sprites["button_use"].bitmap = Bitmap.new("Graphics/UI/Load Screen/button_use")
    @sprites["button_use"].oy = @sprites["button_use"].bitmap.height
    @sprites["button_use"].x  = 8
    @sprites["button_use"].y  = Graphics.height - 8
    @sprites["button_delete"] = Sprite.new(@viewport)
    @sprites["button_delete"].bitmap = Bitmap.new("Graphics/UI/Load Screen/button_delete")
    @sprites["button_delete"].ox = @sprites["button_delete"].bitmap.width/2
    @sprites["button_delete"].oy = @sprites["button_delete"].bitmap.height
    @sprites["button_delete"].x = Graphics.width/2
    @sprites["button_delete"].y = Graphics.height - 8
    @sprites["button_back"] = Sprite.new(@viewport)
    @sprites["button_back"].bitmap = Bitmap.new("Graphics/UI/Load Screen/button_back")
    @sprites["button_back"].ox = @sprites["button_back"].bitmap.width
    @sprites["button_back"].oy = @sprites["button_back"].bitmap.height
    @sprites["button_back"].x = Graphics.width - 8
    @sprites["button_back"].y = Graphics.height - 8
    @sprites["info"]         = Sprite.new(@viewport)
    @sprites["info"].bitmap  = Bitmap.new("Graphics/UI/Load Screen/overlay_title")
    pbSetSystemFont(@sprites["info"].bitmap)
    pbDrawTextPositions(@sprites["info"].bitmap,
       [[_INTL("Select a file:"), 34, 16, 0, Color.new(248, 248, 248), Color.new(136, 136, 136)]])
    refresh_screen
    if @single_screen
      @sprites["panel0"].title = @show_new_game ? _INTL("Saving...") : _INTL("Continue...")
      @sprites["panel1"].visible = false if @sprites["panel1"]
      @sprites["panel0"].refresh
      @sprites.each do |key, sprite|
        next if !key.include?("panel")
        offset = (Graphics.width - sprite.bgbitmap.width) / 2
        x = sprite.bgbitmap.width + (offset * 1.5)
        sprite.x += (x * @index)
      end
    end
    offset = (Graphics.width - @sprites["panel0"].bgbitmap.width) / 2
    @sprites["leftarrow"].x  = offset + 10
    @sprites["rightarrow"].x = Graphics.width - offset - 10
    @sprites["leftarrow"].play
    @sprites["rightarrow"].play
    @sprites["sel"] = SelectorSprite.new(@viewport, 4)
    @sprites["sel"].filename = "Graphics/UI/Load Screen/overlay_select"
    @sprites["sel"].visible = true
    @sprites["sel"].target(@sprites["panel0"], 20)
    @sprites["sel"].update
    @sprites.each_value { |sprite| sprite.opacity = 0 }
    refresh_cursor
  end

  def update
    pbUpdateSpriteHash(@sprites)
  end

  def choose_slot
    dur = 0.25
	t_start = System.uptime
    loop do
	  timer = System.uptime - t_start
	  timer = dur if timer >= dur
	  factor = timer / dur.to_f
      update
      @sprites.each_value { |sprite| sprite.opacity = 255 * factor }
	  break if timer >= dur
    end
    Graphics.update
    update
    if @show_new_game
      ret = main_new_game
    else
      ret = main_load_screen
    end
    return ret
  end

  def draw_save_panels(no_opac = false)
    @sprites.each do |key, sprite|
      next if !key.include?("panel")
      sprite.dispose if sprite
    end
    @sprites.delete_if { |_, sprite| !sprite || sprite.disposed? }
    @sprites["sel"]&.target(nil)
    if no_opac
      @saved_data.clear
      @saved_data = get_saved_data(!@show_new_game)
      @sprites["leftarrow"].visible = false
      @sprites["rightarrow"].visible = false
      @sprites["sel"].visible        = false
    end
    @autosave_slot = @saved_data.any? { |data| data.is_a?(Hash) && data[:autosave_slot] == 1 } && !@show_new_game
    @saved_data.each_with_index do |data, i|
      disp_idx = i + (@autosave_slot ? 0 : 1)
      @sprites["panel#{i}"] = PokemonSaveSlotPanel.new(i, disp_idx, data, @viewport)
      offset = (Graphics.width - @sprites["panel#{i}"].bgbitmap.width) / 2
      @sprites["panel#{i}"].x = offset + ((@sprites["panel#{i}"].bgbitmap.width + (offset/2)) * i)
      @sprites["panel#{i}"].y = Graphics.height / 2 - @sprites["panel#{i}"].bgbitmap.height / 4
      @sprites["panel#{i}"].refresh
      @sprites["panel#{i}"].opacity = 0 if !no_opac
    end
    if @show_new_game && !@single_screen
      i = @saved_data.length
      @sprites["panel#{i}"] = PokemonSaveSlotPanel.new(i, i, -1, @viewport)
      offset = (Graphics.width - @sprites["panel#{i}"].bgbitmap.width) / 2
      @sprites["panel#{i}"].x = offset + ((@sprites["panel#{i}"].bgbitmap.width + (offset / 2)) * i)
      @sprites["panel#{i}"].y = Graphics.height/2 - @sprites["panel#{i}"].bgbitmap.height / 4
      @sprites["panel#{i}"].refresh
      @sprites["panel#{i}"].opacity = 0
    end
    @sprites.each do |key, sprite|
      next if !key.include?("panel")
      offset = (Graphics.width - sprite.bgbitmap.width) / 2
      x = sprite.bgbitmap.width + (offset / 2)
      sprite.x -= x * @index
    end
    @sprites["sel"]&.target(@sprites["panel#{@index}"], 20) if @cmd_index == 0 && !no_opac
    @sprites["sel"]&.target(nil, 0) if @sprites["sel"]&.anchor&.disposed?
    pbUpdateSpriteHash(@sprites)
  end

  def delete_save_file(index)
    real_idx = (@autosave_slot ? (index == 0 ? 0 : index) : index + 1)
    SaveData.delete_file(real_idx)
    @saved_data.clear
    @saved_data = get_saved_data(!@show_new_game)
    pbMessage(_INTL("File successfully deleted.") + "\\me[GUI save game]\\wtnp[30]") { update }
    $PokemonSystem.current_save_slot = 1 if $PokemonSystem.current_save_slot == real_idx && !@saved_data.empty?
    return true
  end

  def move_right
    start_x = {}
    @sprites.each do |key, sprite|
      next if !key.include?("panel")
      start_x[key] = sprite.x
    end
    frac = 4 + @saved_data.length / 6
    @sprites["leftarrow"].visible  = false
    @sprites["rightarrow"].visible = false
    dur = 1.to_f / frac
    t_start = System.uptime
    loop do
	  timer = System.uptime - t_start
	  timer = dur if timer >= dur
	  factor = timer / dur.to_f
      update
      @sprites.each do |key, sprite|
        next if !key.include?("panel")
        offset = (Graphics.width - sprite.bgbitmap.width) / 2
        x = sprite.bgbitmap.width + (offset / 2)
        sprite.x = start_x[key] - (x * factor)
      end
	  break if timer >= dur
    end
    refresh_screen
  end

  def move_left
    start_x = {}
    @sprites.each do |key, sprite|
      next if !key.include?("panel")
      start_x[key] = sprite.x
    end
    @sprites["leftarrow"].visible  = false
    @sprites["rightarrow"].visible = false
    frac = 4 + @saved_data.length / 6
    dur = 1.to_f / frac
	t_start = System.uptime
    loop do
	  timer = System.uptime - t_start
	  timer = dur if timer >= dur
	  factor = timer / dur.to_f
      update
      @sprites.each do |key, sprite|
        next if !key.include?("panel")
        offset = (Graphics.width - sprite.bgbitmap.width) / 2
        x = sprite.bgbitmap.width + (offset / 2)
        sprite.x = start_x[key] + (x * factor)
      end
	  break if timer >= dur
    end
    refresh_screen
  end

  def move_cursor_left
    old_cmd = @cmd_index
    opt = ["use", "delete", "back"]
    loop do
      @cmd_index -= 1
      @cmd_index = 1 if @cmd_index < 1
      str = opt[@cmd_index - 1]
      break if @sprites["button_#{str}"]&.visible
      @cmd_index = 4 if @cmd_index == 1
      next if @cmd_index != old_cmd
      @cmd_index = 3
      break
    end
    refresh_cursor if @cmd_index != old_cmd
  end

  def move_cursor_right
    old_cmd = @cmd_index
    opt = ["use", "delete", "back"]
    loop do
      @cmd_index += 1
      @cmd_index = 3 if @cmd_index > 3
      str = opt[@cmd_index - 1]
      break if @sprites["button_#{str}"]&.visible
      @cmd_index = 0 if @cmd_index == 3
      next if @cmd_index != old_cmd
      @cmd_index = 3
      break
    end
    refresh_cursor if @cmd_index != old_cmd
  end

  def refresh_cursor
    return if !@sprites["sel"]
    if @cmd_index == 0
      @sprites["sel"].target(@sprites["panel#{@index}"], 20)
    else
      opt = ["use", "delete", "back"]
      str = opt[@cmd_index - 1]
      @sprites["sel"].target(@sprites["button_#{str}"], 20)
    end
    @sprites["sel"].update
  end

  def refresh_screen(change_arrows = true)
    ng = @saved_data.length - (@autosave_slot || !@show_new_game ? 1 : 0)
    ng = 0 if @single_screen
    if change_arrows
      @sprites["leftarrow"].visible  = (@index != 0)
      @sprites["rightarrow"].visible = (@index != ng)
    else
      @sprites["leftarrow"].visible  = false
      @sprites["rightarrow"].visible = false
    end
    @sprites["button_use"].visible    = true
    @sprites["button_back"].visible   = true
    @sprites["button_delete"].visible = true
    if !@saved_data[@index].is_a?(Hash)
      @sprites["button_delete"].visible = false
      @sprites["button_use"].visible    = @show_new_game
    elsif @saved_data[@index][:autosave_slot] == 1 && !SaveSettings::ALOW_AUTOSAVE_DELETE
      @sprites["button_delete"].visible = false
    elsif @single_screen && @saved_data[@index][:temp]
      @sprites["button_delete"].visible = false
    end
    @sprites.each do |key, sprite|
      next if !key.include?("panel")
      sprite.selected = sprite.index == @index
    end
    refresh_cursor
  end

  def main_load_screen
    loop do
      Graphics.update
      Input.update
      update
      if Input.trigger?(Input::USE)
        case @cmd_index
        when 0, 1
          if !@saved_data[@index]
            pbPlayBuzzerSE
            next
          end
          pbSEPlay("GUI save choice")
          return (@index + (@autosave_slot ? 0 : 1)), @saved_data[@index], nil, false
        when 2
          if pbConfirmMessage(_INTL("Would you like to delete this file?")) { update }
            ret = delete_save_file(@index)
            return -1, nil, nil, @saved_data.all? { |s| s.nil? }
          end
        when 3
          pbPlayCancelSE
          return -1, nil, nil, false
        end
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        return -1, nil, nil, false
      elsif Input.trigger?(Input::ACTION) && @saved_data[@index] && (SaveSettings::ALOW_AUTOSAVE_DELETE || @saved_data[@index][:autosave_slot] != 1)
        if pbConfirmMessage(_INTL("Would you like to delete this file?")) { update }
          ret = delete_save_file(@index)
          return -1, nil, nil, @saved_data.all? { |s| s.nil? }
        end
      elsif Input.press?(Input::LEFT) && @cmd_index == 0 && @index > 0 && !@single_screen
        pbPlayCursorSE
        @index -= 1
        move_left
      elsif Input.trigger?(Input::LEFT) && @cmd_index != 0
        old_cmd = @cmd_index
        move_cursor_left
        pbPlayCursorSE if @cmd_index != old_cmd
      elsif Input.press?(Input::RIGHT) && @cmd_index == 0 && @index < (@saved_data.length - 1) && !@single_screen
        pbPlayCursorSE
        @index += 1
        move_right
      elsif Input.trigger?(Input::RIGHT) && @cmd_index != 0
        old_cmd = @cmd_index
        move_cursor_right
        pbPlayCursorSE if @cmd_index != old_cmd
      elsif Input.trigger?(Input::UP) && @cmd_index != 0
        @cmd_index = 0
        pbPlayCursorSE
        refresh_cursor
      elsif Input.trigger?(Input::DOWN) && @cmd_index == 0
        @cmd_index = 1
        pbPlayCursorSE
        refresh_cursor
      end
    end
  end

  def main_new_game
    loop do
      Graphics.update
      Input.update
      update
      if Input.trigger?(Input::USE)
        case @cmd_index
        when 0, 1
          if @saved_data[@index] &&
             (!$player || $player.id != @saved_data[@index][:player].id)
            pbMessage(_INTL("There is a different game file that is already saved in this slot.")) { update }
            message = if $player
                        _INTL("Would you like to overwrite this save file?")
                      else
                        _INTL("Would you like to continue in this save file?")
                      end
            next if !pbConfirmMessage(message) { update }
          else
            pbSEPlay("GUI save choice")
          end
          return (@index + (@autosave_slot ? 0 : 1)), @saved_data[@index], nil, false
        when 3
          pbPlayCancelSE
          return -1, nil
        when 2
          if pbConfirmMessage(_INTL("Would you like to delete this file?")) { update }
            ret = delete_save_file(@index)
            return -1, nil, nil, @saved_data.all? { |s| s.nil? }
          end
        end
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        return -1, nil
      elsif Input.trigger?(Input::ACTION) && @saved_data[@index]
        if pbConfirmMessage(_INTL("Would you like to delete this file?")) { update }
          ret = delete_save_file(@index)
          return -1, nil, nil, @saved_data.all? { |s| s.nil? }
        end
      elsif Input.press?(Input::LEFT) && @cmd_index == 0 && @index > 0 && !@single_screen
        pbPlayCursorSE
        @index -= 1
        move_left
      elsif Input.trigger?(Input::LEFT) && @cmd_index != 0
        old_cmd = @cmd_index
        move_cursor_left
        pbPlayCursorSE if @cmd_index != old_cmd
      elsif Input.press?(Input::RIGHT) && @cmd_index == 0 && @index <= (@saved_data.length - 1) && !@single_screen
        pbPlayCursorSE
        @index += 1
        move_right
      elsif Input.trigger?(Input::RIGHT) && @cmd_index != 0
        old_cmd = @cmd_index
        move_cursor_right
        pbPlayCursorSE if @cmd_index != old_cmd
      elsif Input.trigger?(Input::UP) && @cmd_index != 0
        @cmd_index = 0
        pbPlayCursorSE
        refresh_cursor
      elsif Input.trigger?(Input::DOWN) && @cmd_index == 0
        @cmd_index = (@sprites["button_use"].visible ? 1 : @sprites["button_delete"].visible ? 2 : 3)
        pbPlayCursorSE
        refresh_cursor
      end
    end
  end

  def dispose(black = false)
    if black
      dur = 0.4
	  t_start = System.uptime
      loop do
	    timer = System.uptime - t_start
	    timer = dur if timer >= dur
	    factor = timer / dur.to_f
        update
        @sprites.each_value { |sprite| sprite.color.alpha = 255 * factor }
		break if timer >= dur
      end
    else
      dur = 0.25
	  t_start = System.uptime
      loop do
	    timer = System.uptime - t_start
	    timer = dur if timer >= dur
	    factor = timer / dur.to_f
        update
        @sprites.each_value do |sprite|
          next if sprite.opacity == 0
          sprite.opacity = 255 * (1 - factor)
        end
		break if timer >= dur
      end
    end
    Graphics.update
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

#===============================================================================
#
#===============================================================================
class PokemonSaveSlotPanel < Sprite

  attr_reader   :index
  attr_accessor :title
  attr_reader   :full
  attr_reader   :bgbitmap

  def initialize(index, display_index, data, viewport)
    super(viewport)
    @index         = index
    @data          = data
    @selected      = false
    @refreshBitmap = true
    if data.nil?
      @title = _INTL("Empty Save File")
      init_empty_panel
    elsif @data == -1
      @title = _INTL("New Game")
      init_new_panel
    else
      if @data[:autosave_slot] == 1
        @title = _INTL("Autosave")
      else
        @title = _INTL("Slot {1}", display_index)
      end
      init_load_panel
    end
    refresh
  end

  def update
    super
    return if !@icon_bitmaps || @icon_bitmaps.empty?
    if @trainer.party
      @trainer.party.each_with_index do |pkmn, i|
        next if !@icon_bitmaps["pokemon#{i}"]
        @icon_bitmaps["pokemon#{i}"].x       = self.x + 254 + (66 * (i % 2))
        @icon_bitmaps["pokemon#{i}"].y       = self.y + 48 + (50 * (i / 2))
        @icon_bitmaps["pokemon#{i}"].color   = self.color
        @icon_bitmaps["pokemon#{i}"].tone    = self.tone
        @icon_bitmaps["pokemon#{i}"].opacity = self.opacity
      end
    end
    @icon_bitmaps["player"].ox      = @icon_bitmaps["player"].bitmap.width / 8
    @icon_bitmaps["player"].oy      = @icon_bitmaps["player"].bitmap.height / 4
    @icon_bitmaps["player"].x       = self.x + @icon_bitmaps["player"].bitmap.height / 8 + 36
    @icon_bitmaps["player"].y       = self.y + @icon_bitmaps["player"].bitmap.height / 4 + 48
    @icon_bitmaps["player"].tone    = self.tone
    @icon_bitmaps["player"].color   = self.color
    @icon_bitmaps["player"].opacity = self.opacity
    pbUpdateSpriteHash(@icon_bitmaps)
  end

  def init_load_panel
    @trainer  = @data[:player]
    @totalsec = @data[:stats]&.play_time.to_i || 0
    @mapid    = @data[:map_factory].map.map_id
    @bgbitmap = AnimatedBitmap.new("Graphics/UI/Load Screen/panel_load")
    @icon_bitmaps = {}
    if @trainer.party
      @trainer.party.each_with_index do |pkmn, i|
        next if !pkmn
        @icon_bitmaps["pokemon#{i}"] = PokemonIconSprite.new(@trainer.party[i], viewport)
      end
    end
    if @trainer
      meta = GameData::PlayerMetadata.get(@trainer.character_ID || 1)
      if meta
        filename = pbGetPlayerCharset(meta.walk_charset, @trainer, true)
        @icon_bitmaps["player"] = TrainerWalkingCharSprite.new(filename, viewport)
        if @icon_bitmaps["player"].respond_to?(:trainer)
          @icon_bitmaps["player"].trainer = @trainer
          @icon_bitmaps["player"].charset = filename
        end
        @icon_bitmaps["player"].bitmap = Bitmap.new(128, 192) if !@icon_bitmaps["player"].bitmap
        charwidth  = @icon_bitmaps["player"].bitmap.width
        charheight = @icon_bitmaps["player"].bitmap.height
      end
    end
    @base_color   = Color.new(248, 248, 248)
    @shadow_color = Color.new(136, 136, 136)
  end

  def init_new_panel
    @bgbitmap     = AnimatedBitmap.new("Graphics/UI/Load Screen/panel_new")
    @base_color   = Color.new(248, 248, 248)
    @shadow_color = Color.new(136, 136, 136)
  end

  def init_empty_panel
    @bgbitmap = AnimatedBitmap.new("Graphics/UI/Load Screen/panel_empty")
    @base_color   = Color.new(248, 248, 248)
    @shadow_color = Color.new(136, 136, 136)
  end

  def dispose
    @bgbitmap.dispose
    pbDisposeSpriteHash(@icon_bitmaps) if @icon_bitmaps
    self.bitmap.dispose
    super
  end

  def selected=(value)
    return if @selected == value
    @selected = value
    refresh
  end

  def refresh
    return if disposed?
    if !self.bitmap || self.bitmap.disposed?
      self.bitmap = BitmapWrapper.new(@bgbitmap.width, @bgbitmap.height / 2)
      pbSetSystemFont(self.bitmap)
    end
    self.bitmap.clear if self.bitmap
    self.bitmap.blt(0, 0, @bgbitmap.bitmap, Rect.new(0, (@selected) ? @bgbitmap.height / 2 : 0, @bgbitmap.width, @bgbitmap.height / 2))
    if @data.nil?
      refresh_empty
    elsif @data == -1
      refresh_new
    else
      refresh_load
    end
    self.update
  end

  def refresh_load
    textpos = []
    textpos.push([@title, 32, 14, 0, @base_color, @shadow_color])
    textpos.push([_INTL("Leaders Beat:"), 32, 116, 0, @base_color, @shadow_color])
    textpos.push([@trainer.badge_count.to_s, 206, 116, 1, @base_color, @shadow_color])
    textpos.push([_INTL("Kreatures Seen:"), 32, 148, 0, @base_color, @shadow_color])
    textpos.push([@trainer.pokedex.seen_count.to_s, 240, 148, 1, @base_color, @shadow_color])
    textpos.push([_INTL("Time:"), 32, 178, 0, @base_color, @shadow_color])
    hour = @totalsec / 60 / 60
    min  = @totalsec / 60 % 60
    if hour > 0
      textpos.push([_INTL("{1}h {2}m", hour, min), 206, 178, 1, @base_color, @shadow_color])
    else
      textpos.push([_INTL("{1}m", min), 206, 178, 1, @base_color, @shadow_color])
    end
    if @trainer.male?
      textpos.push([@trainer.name, 114, 72, 0, Color.new(56, 160, 248), Color.new(56, 104, 168)])
    elsif @trainer.female?
      textpos.push([@trainer.name, 114, 72, 0, Color.new(240, 72, 88), Color.new(160, 64, 64)])
    else
      textpos.push([@trainer.name, 114, 72, 0, @base_color, @shadow_color])
    end
    mapname = pbGetMapNameFromId(@mapid)
    mapname.gsub!(/\\PN/, @trainer.name)
    textpos.push([mapname, 386, 40, 1, @base_color, @shadow_color])
    pbDrawTextPositions(self.bitmap, textpos)
  end

  def refresh_new
    textpos = []
    textpos.push([@title, 204, 12, 2, @base_color, @shadow_color])
    pbDrawTextPositions(self.bitmap, textpos)
  end

  def refresh_empty
    textpos = []
    textpos.push([@title, 204, 12, 2, @base_color, @shadow_color])
    pbDrawTextPositions(self.bitmap, textpos)
  end
end
