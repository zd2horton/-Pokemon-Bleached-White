class PokemonSystem
  attr_accessor :current_save_slot

  def current_save_slot
    @current_save_slot = 1 if !@current_save_slot
    return @current_save_slot
  end
end

SaveData.register(:autosave_slot) do
  ensure_class :Integer
  save_value { $autosave_slot }
  load_value { |value| $autosave_slot = value }
  new_game_value { 0 }
end

SaveData.register_conversion(:v20_add_stats) do
  essentials_version 20.1
  display_title "Add Autosave Slot"
  to_all do |save_data|
    save_data[:autosave_slot] = 0 unless save_data.has_key?(:autosave_slot)
  end
end

module Game
  def self.set_up_system
    # SaveData.move_old_windows_save if System.platform[/Windows/]
    SaveData.convert_to_multiple_slots
    file_path = File.join(SaveSettings.save_data_location, "Settings.rxdata")
    save_data = if File.file?(file_path)
                  SaveData.read_from_file(file_path)
                else
                   {}
                end
    if save_data.empty? || !SaveData.valid_settings?(save_data)
      SaveData.initialize_bootup_values
    else
      SaveData.load_bootup_values(save_data)
    end
    # Set resize factor
    pbSetResizeFactor([$PokemonSystem.screensize, 4].min)
    # Set language (and choose language if there is no save file)
    if Settings::LANGUAGES.length >= 2 && (save_data.empty? || $PokemonSystem.language == -1)
      $PokemonSystem.language = pbChooseLanguage if save_data.empty?
      pbLoadMessages('Data/' + Settings::LANGUAGES[$PokemonSystem.language][1])
    end
    SaveData.save_settings_to_file(file_path) if !File.file?(file_path)
  end

  def self.save(save_file = SaveData::FILE_PATH, safe: false, slot: nil)
    real_slot = slot.is_a?(Numeric) ? slot : $PokemonSystem.current_save_slot
    save_file = File.join(SaveSettings.save_data_location, "Game_#{real_slot}.rxdata")
    validate save_file => String, safe => [TrueClass, FalseClass]
    $PokemonGlobal.safesave = safe
    $game_system.save_count += 1
    $game_system.magic_number = $data_system.magic_number
    $PokemonSystem.current_save_slot = real_slot if real_slot != 0
    begin
      SaveData.save_to_file(save_file)
      SaveData.save_settings_to_file(File.join(SaveSettings.save_data_location, "Settings.rxdata"))
      Graphics.frame_reset
    rescue IOError, SystemCallError
      $game_system.save_count -= 1
      return false
    end
    return true
  end
end

module SaveData
  def self.save_settings_to_file(file_path)
    validate file_path => String
    save_data = self.compile_settings_hash
    File.open(file_path, 'wb') { |file| Marshal.dump(save_data, file) }
  end

  def self.exists?(slot = -1)
    if slot > 0
      File.file?(File.join(SaveSettings.save_data_location, "Game_#{slot}.rxdata"))
    else
      File.file?(File.join(SaveSettings.save_data_location, "Settings.rxdata"))
    end
  end

  def self.convert_to_multiple_slots
    return if File.file?(File.join(SaveSettings.save_data_location, "Game_1.rxdata"))
    return if !File.file?(FILE_PATH)
    SaveData.read_and_convert_from_file(FILE_PATH)
    File.move(FILE_PATH, File.join(SaveSettings.save_data_location, "Game_1.rxdata"))
  end

  def self.compile_save_hash
    save_data = {}
    @values.each { |value| save_data[value.id] = value.save }
    return save_data
  end

  def self.compile_settings_hash
    save_data = {}
    @values.each { |value| save_data[value.id] = value.save if value.load_in_bootup? }
    return save_data
  end

  def self.delete_file(slot = $PokemonSystem.current_save_slot)
    if File.file?(FILE_PATH)
      File.delete(FILE_PATH)
      File.delete(FILE_PATH + '.bak') if File.file?(FILE_PATH + '.bak')
    end
    file_name = (slot >= 0) ? "Game_#{slot}.rxdata" : "Settings.rxdata"
    file_path = File.join(SaveSettings.save_data_location, file_name)
    File.delete(file_path) if File.file?(file_path)
    File.delete(file_path + ".bak") if File.file?(file_path + ".bak")
  end

  def self.read_and_convert_from_file(file_path)
    validate file_path => String
    save_data = get_data_from_file(file_path)
    save_data = to_hash_format(save_data) if save_data.is_a?(Array)
    if !save_data.empty? && run_conversions(save_data, file_path)
      File.open(file_path, 'wb') { |file| Marshal.dump(save_data, file) }
    end
    return save_data
  end

  def self.read_from_file(file_path)
    validate file_path => String
    save_data = get_data_from_file(file_path)
    return save_data
  end

  def self.valid_slot?(save_data)
    validate save_data => Hash
    values = @values.select { |value| !value.load_in_bootup? }
    return values.all? { |value| value.valid?(save_data[value.id]) }
  end

  def self.valid_settings?(save_data)
    validate save_data => Hash
    values = @values.select { |value| value.load_in_bootup? }
    return values.all? { |value| value.valid?(save_data[value.id]) }
  end

  def self.run_conversions(save_data, file_path)
    validate save_data => Hash
    conversions_to_run = self.get_conversions(save_data)
    return false if conversions_to_run.none?
    File.open(file_path + '.bak', 'wb') { |f| Marshal.dump(save_data, f) }
    echoln "Running #{conversions_to_run.length} conversions..."
    conversions_to_run.each do |conversion|
      echo "#{conversion.title}..."
      conversion.run(save_data)
      echoln ' done.'
    end
    echoln '' if conversions_to_run.length > 0
    save_data[:essentials_version] = Essentials::VERSION
    save_data[:game_version] = Settings::GAME_VERSION
    return true
  end
end

def pbEmergencySave
  oldscene = $scene
  $scene = nil
  pbMessage(_INTL("The script is taking too long. The game will restart."))
  return if !$player
  file_path = File.join(SaveSettings.save_data_location, "Game_#{$PokemonSystem.current_save_slot}.rxdata")
  if SaveData.exists?(file_path)
    File.open(file_path, 'rb') do |r|
      File.open(file_path + '.bak', 'wb') do |w|
        loop do
          s = r.read(4096)
          break if !s
          w.write(s)
        end
      end
    end
  end
  if Game.save
    pbMessage("\\se[]" + _INTL("The game was saved.") + "\\me[GUI save game]\\wtnp[30]")
    pbMessage("\\se[]" + _INTL("The previous save file has been backed up.") + "\\wtnp[30]")
  else
    pbMessage("\\se[]" + _INTL("Save failed.\\wtnp[30]"))
  end
  $scene = oldscene
end

class PokemonGlobalMetadata
  attr_accessor :language

  def language
    @language = $PokemonSystem.language || 0 if !@language
    return @language
  end
end
