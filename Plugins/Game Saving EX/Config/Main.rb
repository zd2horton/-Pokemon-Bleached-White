module SaveSettings
  # Allow the game to autosave on certain occasions, based on the configuration
  # of the constants in module AutosaveSettings in Config_Autosave.rb
  # (This will also disable autosaving by manually calling pbCueAutosave)
  ENABLE_AUTOSAVE        = true

  # Key to press to quicksave in the overworld (Default: W)
  # Set this to nil to disable Quicksaving.
  QUICKSAVE_KEY          = :AUX2

  # The Maximum amounts of Save Slots a player can have. Set this to nil
  # for infinite save slots.
  MAX_SAVE_SLOTS         = nil

  # Allow the Player to save to any slot, or just the slot the Player
  # has currently loaded into.
  ALLOW_SAVE_TO_ANY_SLOT = true

  # Show a quick warning screen about the autosave feature when starting the
  # game.
  SHOW_AUTOSAVE_WARNING  = ENABLE_AUTOSAVE && !$DEBUG

  # Save File Location. By default this is one of the following folders:
  # Windows: %APPDATA%
  # Linux: $HOME/.local/share
  # macOS (unsandboxed): $HOME/Library/Application Support
  SAVE_DATA_FILENAME     = System.game_title

  # The path for the Icon shown in the bottom left corner when Autosaving or
  # Quicksaving. Its recommended that this is a GIF file.
  SAVING_ICON_PATH       = "Graphics/UI/icon_save"

  # The Position at which the save icon should be displayed. The provided
  # options are:
  #  * :TopLeft    :Top        :TopRight
  #  * :Left       :Center     :Right
  #  * :BottomLeft :Bottom     :BottomRight
  SAVING_ICON_POSITION   = :BottomLeft

  # Allow the Autosave slot to be deleted by the player manually from the load
  # screen
  ALOW_AUTOSAVE_DELETE   = false
end
