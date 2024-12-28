class Game_Temp
  attr_accessor :cue_autosave
  attr_accessor :in_debug
  attr_accessor :executing_script
  attr_accessor :last_warped
  attr_accessor :encounter_battle
  attr_accessor :exiting_cave

  def last_warped
    @last_warped = Graphics.frame_count if !@last_warped
    return @last_warped
  end
end

class PokemonSystem
  attr_accessor :autosave

  def autosave
    @autosave = 0 if !@autosave
    return @autosave
  end
end

class PokemonGlobalMetadata
  attr_accessor :allow_autosave

  def allow_autosave
    @allow_autosave = true if @allow_autosave.nil?
    return @allow_autosave
  end
end

if SaveSettings::ENABLE_AUTOSAVE
  MenuHandlers.add(:options_menu, :autosave, {
    "name"        => _INTL("Autosave"),
    "order"       => 197,
    "type"        => EnumOption,
    "parameters"  => [_INTL("On"), _INTL("Off")],
    "description" => _INTL("Let the game automatically save after certain points?"),
    "get_proc"    => proc { next $PokemonSystem.autosave },
    "set_proc"    => proc { |value, scene| $PokemonSystem.autosave = value }
  })
end

def pbCueAutosave(duration = 0.2)
  return false if !SaveSettings::ENABLE_AUTOSAVE
  return if !$PokemonGlobal || !$PokemonGlobal.allow_autosave ||
   !$PokemonSystem || $PokemonSystem.autosave != 0 ||
   !$game_temp || $game_temp.in_debug
  $game_temp.save_buffer = [duration, 0.1].max
  $game_temp.save_sprite.opacity = 0
  $game_temp.save_sprite.bitmap.goto_and_play(0) if $game_temp.save_sprite.bitmap.animated?
  $game_temp.save_sprite.update
  $game_temp.cue_autosave = true
end

def pbToggleAutosave(force = nil)
  $PokemonGlobal.allow_autosave = force.nil? ? !$PokemonGlobal.allow_autosave : force
end

def pbAllowAutosave(force = nil)
  pbToggleAutosave(true)
end

def pbDisallowAutosave(force = nil)
  pbToggleAutosave(false)
end

alias __saving__pbSetPokemonCenter pbSetPokemonCenter unless defined?(__saving__pbSetPokemonCenter)
def pbSetPokemonCenter(*args)
  __saving__pbSetPokemonCenter(*args)
  pbCueAutosave if AutosaveSettings::ON_POKECENTER_HEAL
end

alias __saving__pbPokeCenterPC pbPokeCenterPC unless defined?(__saving__pbPokeCenterPC)
def pbPokeCenterPC(*args)
  __saving__pbPokeCenterPC(*args)
  pbCueAutosave if AutosaveSettings::ON_PC_ACCESS
end

alias __saving__pbDebugMenu pbDebugMenu unless defined?(__saving__pbDebugMenu)
def pbDebugMenu(*args)
  $game_temp.in_debug = true
  __saving__pbDebugMenu(*args)
  $game_temp.in_debug = false
end

alias __saving__pbPokemonMart pbPokemonMart unless defined?(__saving__pbPokemonMart)
def pbPokemonMart(*args)
  __saving__pbPokemonMart(*args)
  pbCueAutosave if AutosaveSettings::ON_MART_ACCESS
end

alias __saving__pbEraseEscapePoint pbEraseEscapePoint unless defined?(__saving__pbEraseEscapePoint)
def pbEraseEscapePoint(*args)
  __saving__pbEraseEscapePoint(*args)
  pbCueAutosave(0.1) if AutosaveSettings::ON_HM_WARP && !$game_switches[Settings::STARTING_OVER_SWITCH] && !$game_temp.exiting_cave
end

alias __saving__pbCaveExit pbCaveExit unless defined?(__saving__pbCaveExit)
def pbCaveExit(*args)
  $game_temp.exiting_cave = true
  __saving__pbCaveExit(*args)
  $game_temp.exiting_cave = false
end

alias __saving__pbSmashEvent pbSmashEvent unless defined?(__saving__pbSmashEvent)
def pbSmashEvent(*args)
  __saving__pbSmashEvent(*args)
  pbCueAutosave if AutosaveSettings::ON_HM_EVENT_DELETE
end

alias __saving__pbStartOver pbStartOver unless defined?(__saving__pbStartOver)
def pbStartOver(*args)
  __saving__pbStartOver(*args)
  pbCueAutosave if AutosaveSettings::ON_BLACK_OUT
end

class Scene_Map
  alias __saving__call_menu call_menu unless method_defined?(:__saving__call_menu)
  def call_menu(*args)
    __saving__call_menu(*args)
    pbCueAutosave if AutosaveSettings::ON_MENU_ACCESS
  end
end

class Scene_Credits
  alias __saving__main main unless method_defined?(:__saving__main)
  def main(*args)
    pbCueAutosave if AutosaveSettings::ON_PLAY_CREDITS
    __saving__main(*args)
  end
end

class PokemonMapFactory
  alias __saving__setMapChanged setMapChanged unless method_defined?(:__saving__setMapChanged)
  def setMapChanged(*args)
    __saving__setMapChanged(*args)
    pbCueAutosave if !$PokemonGlobal.visitedMaps[$game_map.map_id] &&
                      (AutosaveSettings::ON_FIRST_MAP_VISIT ||
                       (AutosaveSettings::ON_FIRST_OUTDOOR_MAP_VISIT &&
                        GameData::MapMetadata.exists?($game_map.map_id) &&
                        GameData::MapMetadata.get($game_map.map_id).outdoor_map))
  end

  alias __saving__setSceneStarted setSceneStarted unless method_defined?(:__saving__setSceneStarted)
  def setSceneStarted(*args)
    __saving__setSceneStarted(*args)
    return if !@mapChanged
    if AutosaveSettings::ON_EVERY_MAP_VISIT && (System.uptime - $game_temp.last_warped) >= 300.0
      $game_temp.last_warped = System.uptime
      pbCueAutosave
    end
  end
end

class Player
  def has_pokegear=(value)
    pbCueAutosave if !@pokegear && value && AutosaveSettings::ON_RECEIVE_POKEGEAR
    @has_pokegear = value
  end

  def has_running_shoes=(value)
    pbCueAutosave if !@has_running_shoes && value && AutosaveSettings::ON_RECEIVE_RUNNING_SHOES
    @has_running_shoes = value
  end

  def has_pokedex=(value)
    pbCueAutosave if !@has_pokedex && value && AutosaveSettings::ON_RECEIVE_POKEDEX
    @has_pokedex = value
  end

  def badges
    pbCueAutosave if $game_temp.executing_script && AutosaveSettings::ON_RECEIVE_BADGE
    return @badges
  end
end

alias __saving__pbReceiveMysteryGift pbReceiveMysteryGift unless defined?(__saving__pbReceiveMysteryGift)
def pbReceiveMysteryGift(*args)
  ret = __saving__pbReceiveMysteryGift(*args)
  pbCueAutosave if ret && AutosaveSettings::ON_RECEIVE_MYSTERY_GIFT
  return ret
end

alias __saving__pbItemBall pbItemBall unless defined?(__saving__pbItemBall)
def pbItemBall(*args)
  ret = __saving__pbItemBall(*args)
  item = args[0]; item_data = GameData::Item.try_get(item)
  return ret if !item_data
  recieved = AutosaveSettings::ON_RECEIVE_ITEM ||
             (item_data.is_key_item? && AutosaveSettings::ON_RECEIVE_KEY_ITEM) ||
             (item_data.is_HM? && AutosaveSettings::ON_RECEIVE_HM)
  pbCueAutosave if ret && recieved
  return ret
end

alias __saving__pbReceiveItem pbReceiveItem unless defined?(__saving__pbReceiveItem)
def pbReceiveItem(*args)
  ret = __saving__pbReceiveItem(*args)
  item = args[0]; item_data = GameData::Item.try_get(item)
  return ret if !item_data
  recieved = AutosaveSettings::ON_RECEIVE_ITEM ||
             (item_data.is_key_item? && AutosaveSettings::ON_RECEIVE_KEY_ITEM) ||
             (item_data.is_HM? && AutosaveSettings::ON_RECEIVE_HM)
  pbCueAutosave if ret && recieved
  return ret
end

alias __saving__pbBattleOnStepTaken pbBattleOnStepTaken unless defined?(__saving__pbBattleOnStepTaken)
def pbBattleOnStepTaken(*args)
  $game_temp.encounter_battle = true
  __saving__pbBattleOnStepTaken(*args)
  $game_temp.encounter_battle = false
end

class Battle::Scene
  alias __saving__pbEndBattle pbEndBattle unless method_defined?(:__saving__pbEndBattle)
  def pbEndBattle(*args)
    return __saving__pbEndBattle(*args) if !@battle.respond_to?(:decision)
    if @battle.trainerBattle?
      pbCueAutosave if AutosaveSettings::ON_TRAINER_BATTLE_WIN && [1, 5].include?(@battle.decision)
      pbCueAutosave if AutosaveSettings::ON_TRAINER_BATTLE_LOSS && @battle.decision == 2
    elsif @battle.wildBattle? && $game_temp.encounter_battle
      pbCueAutosave if AutosaveSettings::ON_WILD_BATTLE_WIN && [1, 5].include?(@battle.decision)
      pbCueAutosave if AutosaveSettings::ON_WILD_BATTLE_LOSS && @battle.decision == 2
      pbCueAutosave if AutosaveSettings::ON_WILD_BATTLE_CAUGHT && @battle.decision == 4
    elsif @battle.wildBattle? && !$game_temp.encounter_battle
      pbCueAutosave if AutosaveSettings::ON_STATIC_BATTLE_WIN && [1, 5].include?(@battle.decision)
      pbCueAutosave if AutosaveSettings::ON_STATIC_BATTLE_LOSS && @battle.decision == 2
      pbCueAutosave if AutosaveSettings::ON_STATIC_BATTLE_CAUGHT && @battle.decision == 4
    end
    __saving__pbEndBattle(*args)
  end
end

if defined?(Player_Quests)
  alias __saving__activateQuest activateQuest unless defined?(__saving__activateQuest)
  def activateQuest(*args)
    __saving__activateQuest(*args)
    pbCueAutosave if AutosaveSettings::ON_QUEST_ACTIVATE
  end

  alias __saving__advanceQuestToStage advanceQuestToStage unless defined?(__saving__advanceQuestToStage)
  def advanceQuestToStage(*args)
    __saving__advanceQuestToStage(*args)
    pbCueAutosave if AutosaveSettings::ON_QUEST_ADVANCE
  end


  alias __saving__completeQuest completeQuest unless defined?(__saving__completeQuest)
  def completeQuest(*args)
    __saving__completeQuestt(*args)
    pbCueAutosave if AutosaveSettings::ON_QUEST_COMPLETE
  end

  alias __saving__failQuest failQuest unless defined?(__saving__failQuest)
  def failQuest(*args)
    __saving__failQuest(*args)
    pbCueAutosave if AutosaveSettings::ON_QUEST_FAIL
  end
end
