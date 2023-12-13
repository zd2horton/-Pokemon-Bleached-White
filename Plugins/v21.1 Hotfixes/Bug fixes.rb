#===============================================================================
# "v21.1 Hotfixes" plugin
# This file contains fixes for bugs in Essentials v21.1.
# These bug fixes are also in the master branch of the GitHub version of
# Essentials:
# https://github.com/Maruno17/pokemon-essentials
#===============================================================================

Essentials::ERROR_TEXT += "[v21.1 Hotfixes 1.0.1]\r\n"

#===============================================================================
# Fixed Pokédex not showing male/female options for species with gender
# differences, and showing them for species without.
#===============================================================================
class PokemonPokedexInfo_Scene
  def pbGetAvailableForms
    ret = []
    multiple_forms = false
    gender_differences = (GameData::Species.front_sprite_filename(@species, 0) != GameData::Species.front_sprite_filename(@species, 0, 1))
    # Find all genders/forms of @species that have been seen
    GameData::Species.each do |sp|
      next if sp.species != @species
      next if sp.form != 0 && (!sp.real_form_name || sp.real_form_name.empty?)
      next if sp.pokedex_form != sp.form
      multiple_forms = true if sp.form > 0
      if sp.single_gendered?
        real_gender = (sp.gender_ratio == :AlwaysFemale) ? 1 : 0
        next if !$player.pokedex.seen_form?(@species, real_gender, sp.form) && !Settings::DEX_SHOWS_ALL_FORMS
        real_gender = 2 if sp.gender_ratio == :Genderless
        ret.push([sp.form_name, real_gender, sp.form])
      elsif sp.form == 0 && !gender_differences
        2.times do |real_gndr|
          next if !$player.pokedex.seen_form?(@species, real_gndr, sp.form) && !Settings::DEX_SHOWS_ALL_FORMS
          ret.push([sp.form_name || _INTL("One Form"), 0, sp.form])
          break
        end
      else   # Both male and female
        2.times do |real_gndr|
          next if !$player.pokedex.seen_form?(@species, real_gndr, sp.form) && !Settings::DEX_SHOWS_ALL_FORMS
          ret.push([sp.form_name, real_gndr, sp.form])
          break if sp.form_name && !sp.form_name.empty?   # Only show 1 entry for each non-0 form
        end
      end
    end
    # Sort all entries
    ret.sort! { |a, b| (a[2] == b[2]) ? a[1] <=> b[1] : a[2] <=> b[2] }
    # Create form names for entries if they don't already exist
    ret.each do |entry|
      if entry[0]   # Alternate forms, and form 0 if no gender differences
        entry[0] = "" if !multiple_forms && !gender_differences
      else   # Necessarily applies only to form 0
        case entry[1]
        when 0 then entry[0] = _INTL("Male")
        when 1 then entry[0] = _INTL("Female")
        else
          entry[0] = (multiple_forms) ? _INTL("One Form") : _INTL("Genderless")
        end
      end
      entry[1] = 0 if entry[1] == 2   # Genderless entries are treated as male
    end
    return ret
  end
end

#===============================================================================
# Fixed AI always switching Pokémon due to unusable moves if the Pokémon is
# asleep or frozen.
#===============================================================================
class Battle::AI
  def pbChooseMove(choices)
    user_battler = @user.battler
    # If no moves can be chosen, auto-choose a move or Struggle
    if choices.length == 0
      @battle.pbAutoChooseMove(user_battler.index)
      PBDebug.log_ai("#{@user.name} will auto-use a move or Struggle")
      return
    end
    # Figure out useful information about the choices
    max_score = 0
    choices.each { |c| max_score = c[1] if max_score < c[1] }
    # Decide whether all choices are bad, and if so, try switching instead
    if @trainer.high_skill? && @user.can_switch_lax?
      badMoves = false
      if max_score <= MOVE_USELESS_SCORE
        badMoves = user_battler.can_attack?
        badMoves = true if !badMoves && pbAIRandom(100) < 25
      elsif max_score < MOVE_BASE_SCORE * move_score_threshold && user_battler.turnCount > 2
        badMoves = true if pbAIRandom(100) < 80
      end
      if badMoves
        PBDebug.log_ai("#{@user.name} wants to switch due to terrible moves")
        if pbChooseToSwitchOut(true)
          @battle.pbUnregisterMegaEvolution(@user.index)
          return
        end
        PBDebug.log_ai("#{@user.name} won't switch after all")
      end
    end
    # Calculate a minimum score threshold and reduce all move scores by it
    threshold = (max_score * move_score_threshold.to_f).floor
    choices.each { |c| c[3] = [c[1] - threshold, 0].max }
    total_score = choices.sum { |c| c[3] }
    # Log the available choices
    if $INTERNAL
      PBDebug.log_ai("Move choices for #{@user.name}:")
      choices.each_with_index do |c, i|
        chance = sprintf("%5.1f", (c[3] > 0) ? 100.0 * c[3] / total_score : 0)
        log_msg = "   * #{chance}% to use #{user_battler.moves[c[0]].name}"
        log_msg += " (target #{c[2]})" if c[2] >= 0
        log_msg += ": score #{c[1]}"
        PBDebug.log(log_msg)
      end
    end
    # Pick a move randomly from choices weighted by their scores
    randNum = pbAIRandom(total_score)
    choices.each do |c|
      randNum -= c[3]
      next if randNum >= 0
      @battle.pbRegisterMove(user_battler.index, c[0], false)
      @battle.pbRegisterTarget(user_battler.index, c[2]) if c[2] >= 0
      break
    end
    # Log the result
    if @battle.choices[user_battler.index][2]
      move_name = @battle.choices[user_battler.index][2].name
      if @battle.choices[user_battler.index][3] >= 0
        PBDebug.log("   => will use #{move_name} (target #{@battle.choices[user_battler.index][3]})")
      else
        PBDebug.log("   => will use #{move_name}")
      end
    end
  end
end

Battle::AI::Handlers::ShouldSwitch.add(:asleep,
  proc { |battler, reserves, ai, battle|
    # Asleep and won't wake up this round or next round
    next false if battler.status != :SLEEP || battler.statusCount <= 2
    # Doesn't want to be asleep (includes checking for moves usable while asleep)
    next false if battler.wants_status_problem?(:SLEEP)
    # Doesn't benefit from being asleep
    next false if battler.has_active_ability?(:MARVELSCALE)
    # Doesn't know Rest (if it does, sleep is expected, so don't apply this check)
    next false if battler.check_for_move { |m| m.function_code == "HealUserFullyAndFallAsleep" }
    # Not trapping another battler in battle
    if ai.trainer.high_skill?
      next false if ai.battlers.any? do |b|
        b.effects[PBEffects::JawLock] == battler.index ||
        b.effects[PBEffects::MeanLook] == battler.index ||
        b.effects[PBEffects::Octolock] == battler.index ||
        b.effects[PBEffects::TrappingUser] == battler.index
      end
      trapping = false
      ai.each_foe_battler(battler.side) do |b, i|
        next if b.ability_active? && Battle::AbilityEffects.triggerCertainSwitching(b.ability, b.battler, battle)
        next if b.item_active? && Battle::ItemEffects.triggerCertainSwitching(b.item, b.battler, battle)
        next if Settings::MORE_TYPE_EFFECTS && b.has_type?(:GHOST)
        next if b.battler.trappedInBattle?   # Relevant trapping effects are checked above
        if battler.ability_active?
          trapping = Battle::AbilityEffects.triggerTrappingByTarget(battler.ability, b.battler, battler.battler, battle)
          break if trapping
        end
        if battler.item_active?
          trapping = Battle::ItemEffects.triggerTrappingByTarget(battler.item, b.battler, battler.battler, battle)
          break if trapping
        end
      end
      next false if trapping
    end
    # Doesn't have sufficiently raised stats that would be lost by switching
    next false if battler.stages.any? { |key, val| val >= 2 }
    # A reserve Pokémon is awake and not frozen
    next false if reserves.none? { |pkmn| ![:SLEEP, :FROZEN].include?(pkmn.status) }
    # 60% chance to not bother
    next false if ai.pbAIRandom(100) < 60
    PBDebug.log_ai("#{battler.name} wants to switch because it is asleep and can't do anything")
    next true
  }
)

#===============================================================================
# Fixed class PngAnimatedBitmap animating slowly.
#===============================================================================
class PngAnimatedBitmap
  def initialize(dir, filename, hue = 0)
    @frames       = []
    @currentFrame = 0
    @timer_start  = System.uptime
    panorama = RPG::Cache.load_bitmap(dir, filename, hue)
    if filename[/^\[(\d+)(?:,(\d+))?\]/]   # Starts with 1 or 2 numbers in brackets
      # File has a frame count
      numFrames = $1.to_i
      duration  = $2.to_i   # In 1/20ths of a second
      duration  = 5 if duration == 0
      raise "Invalid frame count in #{filename}" if numFrames <= 0
      raise "Invalid frame duration in #{filename}" if duration <= 0
      if panorama.width % numFrames != 0
        raise "Bitmap's width (#{panorama.width}) is not divisible by frame count: #{filename}"
      end
      @frame_duration = duration / 20.0
      subWidth = panorama.width / numFrames
      numFrames.times do |i|
        subBitmap = Bitmap.new(subWidth, panorama.height)
        subBitmap.blt(0, 0, panorama, Rect.new(subWidth * i, 0, subWidth, panorama.height))
        @frames.push(subBitmap)
      end
      panorama.dispose
    else
      @frames = [panorama]
    end
  end

  def totalFrames
    return (@frame_duration * @frames.length * 20).to_i
  end
end

#===============================================================================
# Fixed being unable to replace a NamedEvent.
#===============================================================================
class NamedEvent
  def add(key, proc)
    @callbacks[key] = proc
  end
end

#===============================================================================
# Fixed Cramorant's form not reverting after coughing up its Gulp Missile.
#===============================================================================
class Battle::Battler
  alias __hotfixes__pbEffectsOnMakingHit pbEffectsOnMakingHit

  def pbEffectsOnMakingHit(move, user, target)
    if target.damageState.calcDamage > 0 && !target.damageState.substitute
      # Cramorant - Gulp Missile
      if target.isSpecies?(:CRAMORANT) && target.ability == :GULPMISSILE &&
         target.form > 0 && !target.effects[PBEffects::Transform]
        oldHP = user.hp
        # NOTE: Strictly speaking, an attack animation should be shown (the
        #       target Cramorant attacking the user) and the ability splash
        #       shouldn't be shown.
        @battle.pbShowAbilitySplash(target)
        target.pbChangeForm(0, nil)
        if user.takesIndirectDamage?(Battle::Scene::USE_ABILITY_SPLASH)
          @battle.scene.pbDamageAnimation(user)
          user.pbReduceHP(user.totalhp / 4, false)
        end
        case target.form
        when 1   # Gulping Form
          user.pbLowerStatStageByAbility(:DEFENSE, 1, target, false)
        when 2   # Gorging Form
          user.pbParalyze(target) if user.pbCanParalyze?(target, false)
        end
        @battle.pbHideAbilitySplash(target)
        user.pbItemHPHealCheck if user.hp < oldHP
      end
    end    
    __hotfixes__pbEffectsOnMakingHit(move, user, target)
  end
end
