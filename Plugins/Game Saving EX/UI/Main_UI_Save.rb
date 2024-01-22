module SaveSettings
  def self.save_data_location
    split = System.data_directory.split("\\")
    path = split[0...split.size - 1].join("/")
    path.gsub!("\\", "/")
    return path + "/" + SAVE_DATA_FILENAME
  end
end

class PokemonSaveScreen
  def pbSaveScreen
    ret = false
    data = pbChooseSaveSlot(SaveSettings::ALLOW_SAVE_TO_ANY_SLOT, true)
    saved_data = data[1]
    slot = data[0]
    if slot <= 0
      data[2].dispose
      return false
    end
    $game_temp.begun_new_game = false
    $autosave_slot = 0
    if Game.save(nil, safe: false, slot: slot)
      if data[2] && !data[2].single_screen
        data[2].draw_save_panels(true)
        data[2].refresh_screen(false)
      end
      pbMessage("\\se[]" + _INTL("{1} saved the game to Slot {2}.", $player.name, slot) + "\\me[GUI save game]\\wtnp[30]") { data[2].update if data[2] }
      ret = true
    else
      pbMessage("\\se[]" + _INTL("Save failed.") + "\\wtnp[30]")
      ret = false
    end
    data[2].dispose if data[2]
    return ret
  end
end

def get_saved_data(show_autosave_slot = true)
  saved_data  = []
  highest_num = 0
  counter     = 0
  lowest_num  = (show_autosave_slot && SaveSettings::ENABLE_AUTOSAVE ? 0 : 1)
  Dir.foreach(SaveSettings.save_data_location) do |f|
    next if f == "." || f == ".."
    next if File.directory?(File.join(SaveSettings.save_data_location, "#{f}"))
    next if !f[/Game_(\d+).rxdata/i]
    next if f.end_with?("bak")
    num = $1.to_i
    highest_num = num if num > highest_num
  end
  (lowest_num..highest_num).each do |i|
    if !File.file?(File.join(SaveSettings.save_data_location, "Game_#{i}.rxdata"))
      saved_data.push(nil) if lowest_num != 0 || i != 0
      next
    end
    save_data = SaveData.read_from_file(File.join(SaveSettings.save_data_location, "Game_#{i}.rxdata"))
    if !SaveData.valid_slot?(save_data)
      saved_data.push(nil)
      next
    end
    saved_data.push(save_data)
    break if SaveSettings::MAX_SAVE_SLOTS && counter >= SaveSettings::MAX_SAVE_SLOTS
    counter += 1 if save_data[:autosave_slot] != 1
  end
  return saved_data
end

def pbLoadSaveSlot
  saved_data = get_saved_data
  return -1, nil if saved_data.empty? || saved_data.all? { |s| s.nil? }
  scene = SaveSlotSelection_Scene.new(saved_data, false)
  ret = scene.choose_slot
  ret[2] = scene
  return ret
end

def pbChooseSaveSlot(single_screen = true, save_screen = false)
  saved_data = single_screen ? get_saved_data(false) : []
  if (saved_data.empty? || saved_data.all? { |s| s.nil? }) && $player
    hash = SaveData.compile_save_hash
    hash[:temp] = true
    saved_data[0] = hash
  end
  return 0, nil, nil, false if saved_data.empty? || saved_data.all? { |s| s.nil? }
  scene = SaveSlotSelection_Scene.new(saved_data, true)
  ret = scene.choose_slot
  ret[2] = scene
  return ret
end
