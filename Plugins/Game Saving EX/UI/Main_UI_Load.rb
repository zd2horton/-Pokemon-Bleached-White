class PokemonLoadScreen
  def initialize(scene)
    @scene = scene
  end

  def show_continue?
    save_files = []
    Dir.foreach(SaveSettings.save_data_location) do |f|
      next if f == "." || f == ".."
      next if File.directory?(File.join(SaveSettings.save_data_location, "#{f}"))
      next if !f[/Game_(\d+).rxdata/i]
      save_files << File.join(SaveSettings.save_data_location, "#{f}")
    end
    return false if save_files.empty?
    save_files.each do |f|
      if !test_file(f) || f.end_with?("bak")
        new_name = f.end_with?("bak") ? f : f + ".bak"
        next unless File.file?(new_name) && test_file(new_name)
        File.move(new_name, (new_name.gsub(".bak", ""))) if f.end_with?("bak")
      end
      return true
    end
    return false
  end

  def test_file(file_path)
    save_data = if file_path.end_with?("bak")
                  SaveData.read_from_file(file_path)
                else
                  SaveData.read_and_convert_from_file(file_path)
                end
    return SaveData.valid_slot?(save_data)
  end

  def delete_save_data
    return false
  end

  def prompt_save_deletion
    return false
  end

  def pbStartDeleteScreen
    pbStartLoadScreen
  end

  def create_load_commands
    @commands = []
    @cmd_continue     = -1
    @cmd_new_game     = -1
    @cmd_options      = -1
    @cmd_debug        = -1
    @cmd_quit         = -1
    @commands[@cmd_continue = @commands.length]  = _INTL("Load Game") if show_continue?
    @commands[@cmd_new_game = @commands.length]  = _INTL("New Game")
    @commands[@cmd_options = @commands.length]   = _INTL("Options")
    @commands[@cmd_debug = @commands.length]     = _INTL("Debug") if $DEBUG
    @commands[@cmd_quit = @commands.length]      = _INTL("Quit Game")
  end

  def handle_loaded_data(data, new_game = false)
    if data[0] == -1 && (!new_game || data[1].nil?)
      if data[3]
        @scene.pbCloseScene
        create_load_commands
        @scene.pbStartScene(@commands, false, nil, nil, 0)
        @scene.pbStartScene2
      end
      data[2].dispose if data[2]
      return true
    end
    $PokemonSystem.current_save_slot = data[0] if data[0] >= 1
    if data[2]
      @scene.pbCloseScene
      data[2].dispose(true)
    else
      @scene.pbEndScene
    end
  end

  def pbStartLoadScreen
    create_load_commands
    @scene.pbStartScene(@commands, false, nil, nil, 0)
    @scene.pbStartScene2
    loop do
      command = @scene.pbChoose(@commands)
      pbPlayDecisionSE if command != @cmd_quit
      case command
      when @cmd_continue
        data = pbLoadSaveSlot
        next if handle_loaded_data(data)
        Game.load(data[1])
        if Settings::LANGUAGES.length >= 2
          MessageTypes.load_message_files(Settings::LANGUAGES[$PokemonSystem.language][1])
        end
        return
      when @cmd_new_game
        data = pbChooseSaveSlot
        next if handle_loaded_data(data, true)
        Game.start_new
        if Settings::LANGUAGES.length >= 2
          $PokemonSystem.language = pbChooseLanguage
          MessageTypes.load_message_files(Settings::LANGUAGES[$PokemonSystem.language][1])
        end
        return
      when @cmd_options
        pbFadeOutIn do
          scene = PokemonOption_Scene.new
          screen = PokemonOptionScreen.new(scene)
          screen.pbStartScreen(true)
        end
      when @cmd_debug
        pbFadeOutIn { pbDebugMenu(false) }
      when @cmd_quit
        pbPlayCloseMenuSE
        @scene.pbEndScene
        $scene = nil
        return
      else
        pbPlayBuzzerSE
      end
    end
  end

  alias __load__pbStartLoadScreen pbStartLoadScreen unless method_defined?(:__load__pbStartLoadScreen)
  def pbStartLoadScreen(*args)
    $game_temp&.in_load_screen = true
    __load__pbStartLoadScreen(*args)
    $game_temp&.in_load_screen = false
  end
end

#===============================================================================
#
#===============================================================================
class Game_Temp
  attr_accessor :in_load_screen
end
