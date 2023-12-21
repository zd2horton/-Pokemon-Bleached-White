#-------------------------------------------------------------------------------
# Edits to databox to add stat stages
#-------------------------------------------------------------------------------
class Battle::Scene::PokemonDataBox

  alias __databox__initializeOtherGraphics initializeOtherGraphics unless method_defined?(:__databox__initializeOtherGraphics)  
  def initializeOtherGraphics(*args)
    @base_path = pbResolveBitmap("Graphics/Pictures/Battle/icon_mega") ? "Graphics/Pictures/" : "Graphics/UI/"

    @types_bitmap = AnimatedBitmap.new(@base_path + "Battle/icon_types")
    @types_sprite = Sprite.new(viewport)
    height = @types_bitmap.height / GameData::Type.count
    @types_y = -height
    @types_x = (@battler.opposes?(0)) ? 24 : 40
    @types_sprite.bitmap = Bitmap.new(@databoxBitmap.width - @types_x, height)
    @sprites["types_sprite"] = @types_sprite

    @stat_base = Sprite.new(viewport)
    @stat_base.bitmap = RPG::Cache.load_bitmap(@base_path + "Battle/", "overlay_stat_base")
    @stat_overlay = Sprite.new(viewport)
    @stat_overlay.bitmap = Bitmap.new(@stat_base.width, @stat_base.height)
    @stats_x = (@battler.opposes?(0)) ? 232 : -23
    @stats_y = (@databoxBitmap.height - @stat_base.height) / 2
    @sprites["stat_base"] = @stat_base
    @sprites["stat_overlay"] = @stat_overlay

    __databox__initializeOtherGraphics(*args)
  end

  alias __databox__dispose dispose unless method_defined?(:__databox__dispose)  
  def dispose(*args)
    __databox__dispose(*args)
    @types_bitmap.dispose
  end

  alias __databox__set_x x= unless method_defined?(:__databox__set_x)
  def x=(value)
    __databox__set_x(value)
    @types_sprite.x = value + @types_x
    @stat_base.x = @stat_overlay.x = value + @stats_x
  end

  alias __databox__set_y y= unless method_defined?(:__databox__set_y)
  def y=(value)
    __databox__set_y(value)
    @types_sprite.y = value + @types_y
    @stat_base.y = @stat_overlay.y = value + @stats_y
  end

  alias __databox__set_z z= unless method_defined?(:__databox__set_z)
  def z=(value)
    __databox__set_z(value)
    @types_sprite.z = value + 1
    @stat_base.z = value + 1
    @stat_overlay.z = value + 2
  end

  alias __databox__refresh refresh unless method_defined?(:__databox__refresh)
  def refresh
    __databox__refresh
    return if !@battler.pokemon
    draw_type_icons
    draw_stats
  end

  def draw_type_icons
    # Draw Pokémon's types
    @types_sprite.bitmap.clear
    width  = @types_bitmap.width
    height = @types_bitmap.height / GameData::Type.count
    @battler.types.each_with_index do |type, i|
      type_number = GameData::Type.get(type).icon_position
      type_rect = Rect.new(0, type_number * height, width, height) 
      @types_sprite.bitmap.blt((width + 2) * i, 0, @types_bitmap.bitmap, type_rect)
    end
  end

  def draw_stats
    @stat_overlay.bitmap.clear
    stat_coords = {
      :ATTACK => [9, 31, 4],
      :DEFENSE => [39, 30, 4],
      :SPECIAL_ATTACK => [9, 57, 4],
      :SPECIAL_DEFENSE => [39, 57, 4],
      :SPEED => [24, 3, 4]
    }
    stat_coords.each do |stat, coords|
      value = @battler.stages[stat]
      next if value == 0
      stat_file = "overlay_stat"
      stat_file += value < 0 ? "_down" : "_up"
      added = false
      value.abs.times do |v|
        if v > 2 && !added
          stat_file += "_2" 
          added = true
        end
        stat_bmp = RPG::Cache.load_bitmap(@base_path + "Battle/", stat_file)
        y = coords[1] + ((2 - (v % 3)) * (stat_bmp.height + coords[2]))
        @stat_overlay.bitmap.blt(coords[0], y, stat_bmp, Rect.new(0, 0, stat_bmp.width, stat_bmp.height))
        stat_bmp.dispose
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Update databox to reflect stat changes
#-------------------------------------------------------------------------------
class Battle::Battler

  def refresh_stat_databox
    sprite = @battle.scene.sprites["dataBox_#{index}"]
    return if !sprite.respond_to?(:draw_stats)
    sprite.draw_stats
  end

  def statsRaisedThisRound=(value)
    @statsLoweredThisRound = value
    refresh_stat_databox
  end

  def statsLoweredThisRound=(value)
    @statsLoweredThisRound = value
    refresh_stat_databox
  end

  alias __databox__pbRaiseStatStageBasic pbRaiseStatStageBasic unless method_defined?(:__databox__pbRaiseStatStageBasic)
  def pbRaiseStatStageBasic(*args)
    ret = __databox__pbRaiseStatStageBasic(*args)
    refresh_stat_databox
    return ret
  end

  alias __databox__pbLowerStatStageBasic pbLowerStatStageBasic unless method_defined?(:__databox__pbLowerStatStageBasic)
  def pbLowerStatStageBasic(*args)
    ret = __databox__pbLowerStatStageBasic(*args)
    refresh_stat_databox
    return ret
  end
end
