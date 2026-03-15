#Correcciones Personalizadas Walter

#Correccion RecheckForm
class Pokemon
    def initialize(species, level, owner = $player, withMoves = true, recheck_form = true)
        species_data = GameData::Species.get(species)
        @species          = species_data.species
        @form             = species_data.base_form
        @forced_form      = nil
        @time_form_set    = nil
        self.level        = level
        @steps_to_hatch   = 0
        heal_status
        @gender           = nil
        @shiny            = nil
        @ability_index    = nil
        @ability          = nil
        @nature           = nil
        @nature_for_stats = nil
        @item             = nil
        @mail             = nil
        @moves            = []
        reset_moves if withMoves
        @first_moves      = []
        @ribbons          = []
        @cool             = 0
        @beauty           = 0
        @cute             = 0
        @smart            = 0
        @tough            = 0
        @sheen            = 0
        @pokerus          = 0
        @name             = nil
        @happiness        = species_data.happiness
        @poke_ball        = :POKEBALL
        @markings         = []
        @iv               = {}
        @ivMaxed          = {}
        @ev               = {}
        GameData::Stat.each_main do |s|
            @iv[s.id]       = rand(IV_STAT_LIMIT + 1)
            @ev[s.id]       = 0
        end
        case owner
        when Owner
            @owner = owner
        when Player, NPCTrainer
            @owner = Owner.new_from_trainer(owner)
        else
            @owner = Owner.new(0, "", 2, 2)
        end
        @obtain_method    = 0   # Met
        @obtain_method    = 4 if $game_switches && $game_switches[Settings::FATEFUL_ENCOUNTER_SWITCH]
        @obtain_map       = ($game_map) ? $game_map.map_id : 0
        @obtain_text      = nil
        @obtain_level     = level
        @hatched_map      = 0
        @timeReceived     = Time.now.to_i
        @timeEggHatched   = nil
        @fused            = nil
        @personalID       = rand(2**16) | (rand(2**16) << 16)
        @hp               = 1
        @totalhp          = 1
        calc_stats
        if @form == 0 && recheck_form
            f = MultipleForms.call("getFormOnCreation", self)
            if f
                self.form = f
                reset_moves if withMoves
            end
        end
    end
end

if Settings::USE_NEW_EXP_SHARE
    #Queremos que viaje la forma al momento de la creacion del poke
	class Pokemon
		attr_accessor(:expshare)    # Repartir experiencia
		alias initialize_old initialize
		def initialize(species, level, player = $player, withMoves = true, recheck_form = true)
			initialize_old(species, level, player, withMoves, recheck_form)
			$PokemonSystem.expshareon ||= 0
			@expshare = expshare_enabled? && $PokemonSystem.expshareon == 0
		end 
	end
end

class Battle::Move
    #Correccion de habilidades
    def pbCalcDamageMultipliersGlobalAbilities(user, target, numTargets, type, baseDmg, multipliers)
        all_abilities = @battle.pbAllActiveAbilities
        if (all_abilities.include?(:DARKAURA) && type == :DARK) ||
            (all_abilities.include?(:FAIRYAURA) && type == :FAIRY)
            if all_abilities.include?(:AURABREAK)
                multipliers[:power_multiplier] *= 3 / 4.0
            else
                multipliers[:power_multiplier] *= 4 / 3.0
            end
        end
        if all_abilities.include?(:TABLETSOFRUIN) && user.ability_id != :TABLETSOFRUIN
            multipliers[:power_multiplier] *= 3 / 4.0 if physicalMove?
        end
        if all_abilities.include?(:VESSELOFRUIN) && user.ability_id != :VESSELOFRUIN
            multipliers[:power_multiplier] *= 3 / 4.0 if specialMove?
        end
        if all_abilities.include?(:SWORDOFRUIN) && target.ability_id != :SWORDOFRUIN
            if @battle.field.effects[PBEffects::WonderRoom] > 0
                multipliers[:defense_multiplier] *= 3 / 4.0 if specialMove?
            else
                multipliers[:defense_multiplier] *= 3 / 4.0 if physicalMove?
            end
        end
        if all_abilities.include?(:BEADSOFRUIN) && target.ability_id != :BEADSOFRUIN
            if @battle.field.effects[PBEffects::WonderRoom] > 0
                multipliers[:defense_multiplier] *= 3 / 4.0 if physicalMove?
            else
                multipliers[:defense_multiplier] *= 3 / 4.0 if specialMove?
            end
        end
    end

    #Correccion Function IncreasePowerInSun
    def pbCalcDamageMultipliersLingeringEffects(user, target, numTargets, type, baseDmg, multipliers)
        # Parental Bond's second attack
        if user.effects[PBEffects::ParentalBond] == 1
            multipliers[:power_multiplier] /= (Settings::MECHANICS_GENERATION >= 7) ? 4 : 2
        end
        # Other
        if user.effects[PBEffects::MeFirst]
            multipliers[:power_multiplier] *= 1.5
        end
        if user.effects[PBEffects::HelpingHand]
            multipliers[:power_multiplier] *= 1.5
        end
        if user.effects[PBEffects::Charge] > 0 && type == :ELECTRIC
            multipliers[:power_multiplier] *= 2
        end
        if target.effects[PBEffects::Vulnerable]
            multipliers[:final_damage_multiplier] *= 2
        end
        # Mud Sport
        if type == :ELECTRIC
            if @battle.allBattlers.any? { |b| b.effects[PBEffects::MudSport] }
                multipliers[:power_multiplier] /= 3
            end
            if @battle.field.effects[PBEffects::MudSportField] > 0
                multipliers[:power_multiplier] /= 3
            end
        end
        # Water Sport
        if type == :FIRE
            if @battle.allBattlers.any? { |b| b.effects[PBEffects::WaterSport] }
                multipliers[:power_multiplier] /= 3
            end
            if @battle.field.effects[PBEffects::WaterSportField] > 0
                multipliers[:power_multiplier] /= 3
            end
        end
        # Terrain moves
        terrain_multiplier = (Settings::MECHANICS_GENERATION >= 8) ? 1.3 : 1.5
        case @battle.field.terrain
        when :Electric
            multipliers[:power_multiplier] *= terrain_multiplier if type == :ELECTRIC && user.affectedByTerrain?
        when :Grassy
            multipliers[:power_multiplier] *= terrain_multiplier if type == :GRASS && user.affectedByTerrain?
        when :Psychic
            multipliers[:power_multiplier] *= terrain_multiplier if type == :PSYCHIC && user.affectedByTerrain?
        when :Misty
            multipliers[:power_multiplier] /= 2 if type == :DRAGON && target.affectedByTerrain?
        end
        # Weather
        case target.effectiveWeather
        when :Sun, :HarshSun
            case type
            when :FIRE
                multipliers[:final_damage_multiplier] *= 1.5
            when :WATER
                if @function_code == "IncreasePowerInSun" && [:Sun, :HarshSun].include?(user.effectiveWeather)
                    multipliers[:final_damage_multiplier] *= 1.5
                else
                    multipliers[:final_damage_multiplier] /= 2
                end
            else
                if @function_code == "IncreasePowerInSun" && [:Sun, :HarshSun].include?(user.effectiveWeather)
                    multipliers[:final_damage_multiplier] *= 1.5
                end
            end
        when :Rain, :HeavyRain
            case type
            when :FIRE
                multipliers[:final_damage_multiplier] /= 2
            when :WATER
                multipliers[:final_damage_multiplier] *= 1.5
            end
        when :Sandstorm
            if target.pbHasType?(:ROCK) && specialMove? && @function_code != "UseTargetDefenseInsteadOfTargetSpDef"
                multipliers[:defense_multiplier] *= 1.5
            end
        when :ShadowSky
            multipliers[:final_damage_multiplier] *= 1.5 if type == :SHADOW
        when :Snowstorm
            if target.pbHasType?(:ICE) && 
                (physicalMove? || @function_code == "UseTargetDefenseInsteadOfTargetSpDef")
                multipliers[:defense_multiplier] *= 1.5
            end
        end
        # Aurora Veil, Reflect, Light Screen
        if !ignoresReflect? && !target.damageState.critical &&
            !user.hasActiveAbility?(:INFILTRATOR)
            if target.pbOwnSide.effects[PBEffects::AuroraVeil] > 0
                if @battle.pbSideBattlerCount(target) > 1
                    multipliers[:final_damage_multiplier] *= 2 / 3.0
                else
                    multipliers[:final_damage_multiplier] /= 2
                end
            elsif target.pbOwnSide.effects[PBEffects::Reflect] > 0 && physicalMove?
                if @battle.pbSideBattlerCount(target) > 1
                    multipliers[:final_damage_multiplier] *= 2 / 3.0
                else
                    multipliers[:final_damage_multiplier] /= 2
                end
            elsif target.pbOwnSide.effects[PBEffects::LightScreen] > 0 && specialMove?
                if @battle.pbSideBattlerCount(target) > 1
                    multipliers[:final_damage_multiplier] *= 2 / 3.0
                else
                    multipliers[:final_damage_multiplier] /= 2
                end
            end
        end
    end
end

#Coreccion IncreasePowerInElectricTerrain
class Battle::Move::IncreasePowerInElectricTerrain < Battle::Move
  def pbBasePower(base_power, user, target)
    base_power = (base_power * 1.5).floor if @battle.field.terrain == :Electric
    return base_power
  end
end

class Battle::AI::AIMove
    #Correccion Function IncreasePowerInSun
    def rough_damage_modifiers_lingering_effects(user, target, calc_type, base_dmg, multipliers, is_critical)
        # Parental Bond
        if user.has_active_ability?(:PARENTALBOND)
            multipliers[:power_multiplier] *= (Settings::MECHANICS_GENERATION >= 7) ? 1.25 : 1.5
        end
        # Me First - n/a because can't predict the move Me First will use
        # Helping Hand - n/a
        # Charge
        if @ai.trainer.medium_skill? &&
            user.effects[PBEffects::Charge] > 0 && calc_type == :ELECTRIC
            multipliers[:power_multiplier] *= 2
        end
        # Glaive Rush
        if target.effects[PBEffects::Vulnerable]
            multipliers[:final_damage_multiplier] *= 2
        end
        # Mud Sport
        if @ai.trainer.medium_skill? && calc_type == :ELECTRIC
            if @ai.battle.allBattlers.any? { |b| b.effects[PBEffects::MudSport] }
                multipliers[:power_multiplier] /= 3
            end
            if @ai.battle.field.effects[PBEffects::MudSportField] > 0
                multipliers[:power_multiplier] /= 3
            end
        end
        # Water Sport
        if @ai.trainer.medium_skill? && calc_type == :FIRE
            if @ai.battle.allBattlers.any? { |b| b.effects[PBEffects::WaterSport] }
                multipliers[:power_multiplier] /= 3
            end
            if @ai.battle.field.effects[PBEffects::WaterSportField] > 0
                multipliers[:power_multiplier] /= 3
            end
        end
        # Terrain moves
        if @ai.trainer.medium_skill?
            terrain_multiplier = (Settings::MECHANICS_GENERATION >= 8) ? 1.3 : 1.5
            case @ai.battle.field.terrain
            when :Electric
                multipliers[:power_multiplier] *= terrain_multiplier if calc_type == :ELECTRIC && user.battler.affectedByTerrain?
            when :Grassy
                multipliers[:power_multiplier] *= terrain_multiplier if calc_type == :GRASS && user.battler.affectedByTerrain?
            when :Psychic
                multipliers[:power_multiplier] *= terrain_multiplier if calc_type == :PSYCHIC && user.battler.affectedByTerrain?
            when :Misty
                multipliers[:power_multiplier] /= 2 if calc_type == :DRAGON && target.battler.affectedByTerrain?
            end
        end
        # Weather
        if @ai.trainer.medium_skill?
            case target.battler.effectiveWeather
            when :Sun, :HarshSun
                case calc_type
                when :FIRE
                    multipliers[:final_damage_multiplier] *= 1.5
                when :WATER
                    if function_code == "IncreasePowerInSun" && [:Sun, :HarshSun].include?(user.battler.effectiveWeather)
                        multipliers[:final_damage_multiplier] *= 1.5
                    else
                        multipliers[:final_damage_multiplier] /= 2
                    end
                else
                    if function_code == "IncreasePowerInSun" && [:Sun, :HarshSun].include?(user.battler.effectiveWeather)
                        multipliers[:final_damage_multiplier] *= 1.5
                    end
                end
            when :Rain, :HeavyRain
                case calc_type
                when :FIRE
                    multipliers[:final_damage_multiplier] /= 2
                when :WATER
                    multipliers[:final_damage_multiplier] *= 1.5
                end
            when :Sandstorm
                if target.has_type?(:ROCK) && specialMove?(calc_type) &&
                    function_code != "UseTargetDefenseInsteadOfTargetSpDef"   # Psyshock
                    multipliers[:defense_multiplier] *= 1.5
                end
            when :ShadowSky
                multipliers[:final_damage_multiplier] *= 1.5 if calc_type == :SHADOW
            when :Snowstorm
                if target.pbHasType?(:ICE) &&
                    (physicalMove?(calc_type) || function_code == "UseTargetDefenseInsteadOfTargetSpDef")
                    multipliers[:defense_multiplier] *= 1.5
                end
            end
        end
        # Aurora Veil, Reflect, Light Screen
        if @ai.trainer.medium_skill? && !@move.ignoresReflect? && !is_critical &&
            !user.has_active_ability?(:INFILTRATOR)
            if target.pbOwnSide.effects[PBEffects::AuroraVeil] > 0
                if @ai.battle.pbSideBattlerCount(target.battler) > 1
                    multipliers[:final_damage_multiplier] *= 2 / 3.0
                else
                    multipliers[:final_damage_multiplier] /= 2
                end
            elsif target.pbOwnSide.effects[PBEffects::Reflect] > 0 && physicalMove?(calc_type)
                if @ai.battle.pbSideBattlerCount(target.battler) > 1
                    multipliers[:final_damage_multiplier] *= 2 / 3.0
                else
                    multipliers[:final_damage_multiplier] /= 2
                end
            elsif target.pbOwnSide.effects[PBEffects::LightScreen] > 0 && specialMove?(calc_type)
                if @ai.battle.pbSideBattlerCount(target.battler) > 1
                    multipliers[:final_damage_multiplier] *= 2 / 3.0
                else
                    multipliers[:final_damage_multiplier] /= 2
                end
            end
        end
    end
end





#Victini
Settings::DEXES_WITH_OFFSETS  = [4]
#Formas en la Pokedex
Settings::DEX_SHOWS_ALL_FORMS = false


#Copiar los atributos de Quilava a Cyndaquil
if Settings::REGIONAL_FORMS_DEPEND_ON_MAP_REGION
    MultipleForms.copy(:QUILAVA, :CYNDAQUIL)
end

#Correccion de Fecha y hora de cambio de forma
MultipleForms.register(:FURFROU, {
    "getForm" => proc { |pkmn|
        if !pkmn.time_form_set ||
            pbGetTimeNow.to_i > pkmn.time_form_set.to_i + (60 * 60 * 24 * 5)   # 5 days
            next 0
        end
    },
    "onSetForm" => proc { |pkmn, form, oldForm|
        pkmn.time_form_set = pbGetTimeNow.to_i
    }
})

#Correcciones Formas OnCreation
if Settings::LINEA_DE_SPEWPA_POR_ID
    MultipleForms.register(:SCATTERBUG, {
        "getFormOnCreation" => proc { |pkmn|
            next $player.secret_ID % 18
        },
        "getForm" => proc { |pkmn|
            next $player.secret_ID % 18
        }
    })

    MultipleForms.copy(:SCATTERBUG, :SPEWPA, :VIVILLON)
end

MultipleForms.register(:TOXEL, {
    "getFormOnCreation" => proc { |pkmn|
        next 1 if [:LONELY, :BOLD, :RELAXED, :TIMID, :SERIOUS, :MODEST, :MILD,
                    :QUIET, :BASHFUL, :CALM, :GENTLE, :CAREFUL].include?(pkmn.nature_id)
        next 0
    },
    "getForm" => proc { |pkmn|
        next 1 if [:LONELY, :BOLD, :RELAXED, :TIMID, :SERIOUS, :MODEST, :MILD,
                    :QUIET, :BASHFUL, :CALM, :GENTLE, :CAREFUL].include?(pkmn.nature_id)
        next 0
    }
})

MultipleForms.copy(:TOXEL, :TOXTRICITY)

module GameData
    class Species
        #Correccion Genero Pikachu Cosplay
        Species.singleton_class.alias_method :walter_schema, :schema
        def self.schema(compiling_forms = false)
            ret = self.walter_schema(compiling_forms)
            if compiling_forms
                ret["GenderRatio"]    = [:gender_ratio,       "e", :GenderRatio]
                ret["GrowthRate"]     = [:growth_rate,        "e", :GrowthRate]
            end
            return ret
        end
    end
end

#Orden Pokedex Specie
def pbChooseFromGameDataList(game_data, default = nil)
    if !GameData.const_defined?(game_data.to_sym)
        raise _INTL("No se encuentra la clase {1} en el módulo GameData.", game_data.to_s)
    end
    game_data_module = GameData.const_get(game_data.to_sym)
    commands = []
    game_data_module.each do |data|
        name = data.real_name
        name = yield(data) if block_given?
        next if !name
        commands.push([commands.length + 1, name, data.id])
    end
    num_sort = game_data == :Species ? -1 : 1
    return pbChooseList(commands, default, nil, num_sort)
end

#Pregunta si se añade el poke al equipo
def pbAddPokemon(pkmn, level = 1, see_form = true)
  return false if !pkmn
  if pbBoxesFull?
    pbMessage(_INTL("¡No hay espacio para más Pokémon!") + "\1")
    pbMessage(_INTL("¡Las Cajas del PC están llenas y no tienen más espacio!"))
    return false
  end
  pkmn = Pokemon.new(pkmn, level, $player, true, false) if !pkmn.is_a?(Pokemon)
  species_name = pkmn.speciesName
  pbMessage(_INTL("¡{1} obtuvo un {2}!", $player.name, species_name) + "\\me[Pkmn get]\\wtnp[80]")
  was_owned = $player.owned?(pkmn.species)
  $player.pokedex.set_seen(pkmn.species)
  $player.pokedex.set_owned(pkmn.species)
  $player.pokedex.register(pkmn) if see_form
  # Show Pokédex entry for new species if it hasn't been owned before
  if Settings::SHOW_NEW_SPECIES_POKEDEX_ENTRY_MORE_OFTEN && see_form && !was_owned &&
    $player.has_pokedex && $player.pokedex.species_in_unlocked_dex?(pkmn.species)
    pbMessage(_INTL("Los datos de {1} se han añadido a la Pokédex.", species_name))
    $player.pokedex.register_last_seen(pkmn)
    pbFadeOutIn do
        scene = PokemonPokedexInfo_Scene.new
        screen = PokemonPokedexInfoScreen.new(scene)
        screen.pbDexEntry(pkmn.species)
    end
  end
  # Nickname and add the Pokémon
  pbNicknameAndStore(pkmn)
  return true
end

def pbPartyScreen(idxBattler, canCancel = false, mode = 0)
    # # Fade out and hide all sprites
    # visibleSprites = pbFadeOutAndHide(@sprites)
    # # Get player's party
    # partyPos = @battle.pbPartyOrder(idxBattler)
    # partyStart, _partyEnd = @battle.pbTeamIndexRangeFromBattlerIndex(idxBattler)
    # modParty = @battle.pbPlayerDisplayParty(idxBattler)
    
    # Get player's party
    partyPos =Array.new($player.party.length) { |i| i }
    partyStart = [0][idxBattler]
    modParty = $player.party
    
    # Start party screen
    scene = PokemonParty_Scene.new
    switchScreen = PokemonPartyScreen.new(scene, modParty)
    msg = _INTL("Elige un Pokémon.")
    msg = _INTL("¿Qué Pokémon enviar al PC?") if mode == 1
    #switchScreen.pbStartScene(msg, @battle.pbNumPositions(0, 0))
    switchScreen.pbStartScene(msg, 1)
    # Loop while in party screen
    loop do
      # Select a Pokémon
      scene.pbSetHelpText(msg)
      idxParty = switchScreen.pbChoosePokemon
      if idxParty < 0
        next if !canCancel
        break
      end
      # Choose a command for the selected Pokémon
      cmdSwitch  = -1
      cmdBoxes   = -1
      cmdSummary = -1
      cmdSelect  = -1
      commands = []
      commands[cmdSwitch  = commands.length] = _INTL("Cambiar") if mode == 0 && modParty[idxParty].able? &&
                                                                     (@battle.canSwitch || !canCancel)
      commands[cmdBoxes   = commands.length] = _INTL("Enviar al PC") if mode == 1
      commands[cmdSelect  = commands.length] = _INTL("Seleccionar") if mode == 2 && modParty[idxParty].fainted?
      commands[cmdSummary = commands.length] = _INTL("Datos")
      commands[commands.length]              = _INTL("Cancelar")
      command = scene.pbShowCommands(_INTL("¿Qué hacer con {1}?", modParty[idxParty].name), commands)
      if (cmdSwitch >= 0 && command == cmdSwitch) ||   # Switch In
         (cmdBoxes >= 0 && command == cmdBoxes)   ||   # Send to Boxes
         (cmdSelect >= 0 && command == cmdSelect)      # Select for Revival Blessing
        idxPartyRet = -1
        partyPos.each_with_index do |pos, i|
            next if pos != idxParty + partyStart
            idxPartyRet = i
            break
        end
        break if yield idxPartyRet, switchScreen
      elsif cmdSummary >= 0 && command == cmdSummary   # Summary
        scene.pbSummary(idxParty, true)
      end
    end
    # Close party screen
    switchScreen.pbEndScene
end

def pbNicknameAndStore(pkmn)
    if pbBoxesFull?
        pbMessage(_INTL("¡No hay espacio para más Pokémon!") + "\1")
        pbMessage(_INTL("¡Las Cajas del PC están llenas y no tienen más espacio!"))
        return
    end
    $player.pokedex.set_seen(pkmn.species)
    $player.pokedex.set_owned(pkmn.species)

    # Nickname the Pokémon (unless it's a Shadow Pokémon)
    if !pkmn.shadowPokemon?
        pbNickname(pkmn)
    end

    battleRules = $game_temp.battle_rules
    sendToBoxes = 1
    sendToBoxes = $PokemonSystem.sendtoboxes if Settings::NEW_CAPTURE_CAN_REPLACE_PARTY_MEMBER
    sendToBoxes = 2 if battleRules["forceCatchIntoParty"]

    scene = BattleCreationHelperMethods.create_battle_scene
    peer  = Battle::Peer.new

    # Store the Pokémon
    if $player.party_full? && (sendToBoxes == 0 || sendToBoxes == 2)   # Ask/must add to party
        cmds = [_INTL("Agregar al equipo"),
                _INTL("Enviar a una caja"),
                _INTL("Ver datos de {1}", pkmn.name),
                _INTL("Ver equipo")]
        cmds.delete_at(1) if sendToBoxes == 2   # Remove "Send to a Box" option
        loop do
            cmd = pbMessage(_INTL("¿A dónde quieres enviar a {1}?", pkmn.name), cmds, 99)
            next if cmd == 99 && sendToBoxes == 2   # Can't cancel if must add to party
            break if cmd == 99   # Cancelling = send to a Box
            cmd += 1 if cmd >= 1 && sendToBoxes == 2
            case cmd
                when 0   # Add to your party
                    pbMessage(_INTL("Elige a un Pokémon de tu equipo para enviar a las cajas."))
                    party_index = -1
                    pbPartyScreen(0, (sendToBoxes != 2), 1) do |idxParty, _partyScene|
                        party_index = idxParty
                        next true
                    end
                    next if party_index < 0   # Cancelled
                    party_size = $player.party.length
                    # Get chosen Pokémon and clear battle-related conditions
                    send_pkmn = $player.party[party_index]
                    
                    #peer.pbOnLeavingBattle(self, send_pkmn, @usedInBattle[0][party_index], true)
                    peer.pbOnLeavingBattle(self, send_pkmn, false, true)#revisar

                    send_pkmn.statusCount = 0 if send_pkmn.status == :POISON   # Bad poison becomes regular
                    send_pkmn.makeUnmega
                    send_pkmn.makeUnprimal
                    # Send chosen Pokémon to storage
                    stored_box = peer.pbStorePokemon($player, send_pkmn)
                    $player.party.delete_at(party_index)
                    box_name = peer.pbBoxName(stored_box)
                    pbMessage(_INTL("{1} fue enviado a la caja \"{2}\".", send_pkmn.name, box_name))
                    # Rearrange all remembered properties of party Pokémon          
                    # (party_index...party_size).each do |idx|
                    #   if idx < party_size - 1
                    #     @initialItems[0][idx] = @initialItems[0][idx + 1]
                    #     $game_temp.party_levels_before_battle[idx] = $game_temp.party_levels_before_battle[idx + 1]
                    #     $game_temp.party_critical_hits_dealt[idx] = $game_temp.party_critical_hits_dealt[idx + 1]
                    #     $game_temp.party_direct_damage_taken[idx] = $game_temp.party_direct_damage_taken[idx + 1]
                    #   else
                    #     @initialItems[0][idx] = nil
                    #     $game_temp.party_levels_before_battle[idx] = nil
                    #     $game_temp.party_critical_hits_dealt[idx] = nil
                    #     $game_temp.party_direct_damage_taken[idx] = nil
                    #   end
                    # end
                    break
                when 1   # Send to a Box
                    break
                when 2   # See X's summary
                    pbFadeOutIn do
                        summary_scene = PokemonSummary_Scene.new
                        summary_screen = PokemonSummaryScreen.new(summary_scene, true)
                        summary_screen.pbStartScreen([pkmn], 0)
                    end
                when 3   # Check party
                    pbPartyScreen(0, true, 2)
            end
        end
    end
    # Store as normal (add to party if there's space, or send to a Box if not)
    stored_box = peer.pbStorePokemon($player, pkmn)
    if stored_box < 0
        pbMessage(_INTL("Se agregó a {1} al equipo.", pkmn.name))
        #@initialItems[0][$player.party.length - 1] = pkmn.item_id if @initialItems
        return
    end
    # Messages saying the Pokémon was stored in a PC box
    box_name = peer.pbBoxName(stored_box)
    pbMessage(_INTL("Se envió {1} a la caja \"{2}\"!", pkmn.name, box_name))
end

class Battle::Battler
    #Actualizacion Sprite Movimientos 2 Turnos
    def pbRestoreBattlerSprite(user)
        scene = @battle.scene
        return if !scene

        sprite = scene.sprites["pokemon_#{user.index}"]
        return if !sprite

        sprite.visible = true
        sprite.opacity = 255
        sprite.pbSetPosition
    end

    def pbProcessMoveHit(move, user, targets, hitNum, skipAccuracyCheck)
        return false if user.fainted?
        # For two-turn attacks being used in a single turn
        move.pbInitialEffect(user, targets, hitNum)
        numTargets = 0   # Number of targets that are affected by this hit
        # Count a hit for Parental Bond (if it applies)
        user.effects[PBEffects::ParentalBond] -= 1 if user.effects[PBEffects::ParentalBond] > 0
        # Accuracy check (accuracy/evasion calc)
        if hitNum == 0 || move.successCheckPerHit?
            targets.each do |b|
                b.damageState.missed = false
                next if b.damageState.unaffected
                if pbSuccessCheckPerHit(move, user, b, skipAccuracyCheck)
                    numTargets += 1
                else
                    b.damageState.missed     = true
                    b.damageState.unaffected = true
                end
            end
            # If failed against all targets
            if targets.length > 0 && numTargets == 0 && !move.worksWithNoTargets?
                targets.each do |b|
                    next if !b.damageState.missed || b.damageState.magicCoat
                    pbMissMessage(move, user, b)
                    if user.itemActive?
                        Battle::ItemEffects.triggerOnMissingTarget(user.item, user, b, move, hitNum, @battle)
                    end
                    break if move.pbRepeatHit?   # Dragon Darts only shows one failure message
                end
                move.pbCrashDamage(user)
                user.pbItemHPHealCheck
                pbCancelMoves
                
                if move.pbIsChargingTurn?(user)
                    pbRestoreBattlerSprite(user)
                end
                
                return false
            end
        end
        # If we get here, this hit will happen and do something
        all_targets = targets
        targets = move.pbDesignateTargetsForHit(targets, hitNum)   # For Dragon Darts
        targets.each { |b| b.damageState.resetPerHit }
        #---------------------------------------------------------------------------
        # Trigger abilities before the hit (they can alter b.damageState.typeMod)
        targets.each do |b|
            next if !b.abilityActive?
            Battle::AbilityEffects.triggerOnTargetedForHit(b.ability, user, b, move, hitNum, @battle)
        end
        # Calculate damage to deal
        if move.pbDamagingMove?
            targets.each do |b|
                next if b.damageState.unaffected
                # Check whether Substitute/Disguise will absorb the damage
                move.pbCheckDamageAbsorption(user, b)
                # Calculate the damage against b
                # pbCalcDamage shows the "eat berry" animation for SE-weakening
                # berries, although the message about it comes after the additional
                # effect below
                move.pbCalcDamage(user, b, targets.length)   # Stored in damageState.calcDamage
                # Lessen damage dealt because of False Swipe/Endure/etc.
                move.pbReduceDamage(user, b)   # Stored in damageState.hpLost
                @battle.hitsTakenCounts[b.idxOwnSide][b.pokemonIndex] += 1 if !b.damageState.substitute
            end
        end
        # Show move animation (for this hit)
        move.pbShowAnimation(move.id, user, targets, hitNum)
        # Type-boosting Gem consume animation/message
        if user.effects[PBEffects::GemConsumed] && hitNum == 0
            # NOTE: The consume animation and message for Gems are shown now, but the
            #       actual removal of the item happens in def pbEffectsAfterMove.
            @battle.pbCommonAnimation("UseItem", user)
            @battle.pbDisplay(_INTL("¡{1} refuerza el poder de {2}!",
                                    GameData::Item.get(user.effects[PBEffects::GemConsumed]).name, move.name))
        end
        # Messages about missed target(s) (relevant for multi-target moves only)
        if !move.pbRepeatHit?
            targets.each do |b|
                next if !b.damageState.missed
                pbMissMessage(move, user, b)
                if user.itemActive?
                    Battle::ItemEffects.triggerOnMissingTarget(user.item, user, b, move, hitNum, @battle)
                end
            end
        end
        # Deal the damage (to all allies first simultaneously, then all foes
        # simultaneously)
        if move.pbDamagingMove?
            # This just changes the HP amounts and does nothing else
            targets.each { |b| move.pbInflictHPDamage(b) if !b.damageState.unaffected }
            # Animate the hit flashing and HP bar changes
            move.pbAnimateHitAndHPLost(user, targets)
        end
        # Self-Destruct/Explosion's damaging and fainting of user
        move.pbSelfKO(user) if hitNum == 0
        user.pbFaint if user.fainted?
        if move.pbDamagingMove?
            targets.each do |b|
                next if b.damageState.unaffected
                # NOTE: This method is also used for the OHKO special message.
                move.pbHitEffectivenessMessages(user, b, targets.length)
                # Record data about the hit for various effects' purposes
                move.pbRecordDamageLost(user, b)
            end
            # Close Combat/Superpower's stat-lowering, Flame Burst's splash damage,
            # and Incinerate's berry destruction
            targets.each do |b|
                next if b.damageState.unaffected
                move.pbEffectWhenDealingDamage(user, b)
            end
            # Ability/item effects such as Static/Rocky Helmet, and Grudge, etc.
            targets.each do |b|
                next if b.damageState.unaffected
                pbEffectsOnMakingHit(move, user, b)
            end
            # Disguise/Endure/Sturdy/Focus Sash/Focus Band messages
            targets.each do |b|
                next if b.damageState.unaffected
                move.pbEndureKOMessage(b)
            end
            # HP-healing held items (checks all battlers rather than just targets
            # because Flame Burst's splash damage affects non-targets)
            @battle.pbPriority(true).each do |b|
                next if move.preventsBattlerConsumingHealingBerry?(b, targets)
                b.pbItemHPHealCheck
            end
            # Animate battlers fainting (checks all battlers rather than just targets
            # because Flame Burst's splash damage affects non-targets)
            @battle.pbPriority(true).each { |b| b.pbFaint if b&.fainted? }
        end
        @battle.pbJudgeCheckpoint(user, move)
        # Main effect (recoil/drain, etc.)
        targets.each do |b|
            next if b.damageState.unaffected
            move.pbEffectAgainstTarget(user, b)
        end
        move.pbEffectGeneral(user)
        targets.each do |b|
            next if !b&.fainted?
            b.pbFaint
            if user.pokemon.isSpecies?(:BISHARP) && b.isSpecies?(:BISHARP) && b.item == :LEADERSCREST
                user.pokemon.evolution_counter += 1
            end
        end
        user.pbFaint if user.fainted?
        # Additional effect
        if !user.hasActiveAbility?(:SHEERFORCE)
            targets.each do |b|
                next if b.damageState.calcDamage == 0
                chance = move.pbAdditionalEffectChance(user, b)
                next if chance <= 0
                move.pbAdditionalEffect(user, b) if @battle.pbRandom(100) < chance
            end
        end
        # Make the target flinch (because of an item/ability)
        targets.each do |b|
            next if b.fainted?
            next if b.damageState.calcDamage == 0 || b.damageState.substitute
            chance = move.pbFlinchChance(user, b)
            next if chance <= 0
            if @battle.pbRandom(100) < chance
                PBDebug.log("[Item/ability triggered] #{user.pbThis}'s King's Rock/Razor Fang or Stench")
                b.pbFlinch(user)
            end
        end
        # Message for and consuming of type-weakening berries
        # NOTE: The "consume held item" animation for type-weakening berries occurs
        #       during pbCalcDamage above (before the move's animation), but the
        #       message about it only shows here.
        targets.each do |b|
            next if b.damageState.unaffected
            next if !b.damageState.berryWeakened
            b.damageState.berryWeakened = false   # Weakening only applies for one hit
            @battle.pbDisplay(_INTL("¡{1} redujo el daño de {2}!", b.itemName, b.pbThis(true)))
            b.pbConsumeItem
        end
        # Steam Engine (goes here because it should be after stat changes caused by
        # the move)
        if [:FIRE, :WATER].include?(move.calcType)
            targets.each do |b|
                next if b.damageState.unaffected
                next if b.damageState.calcDamage == 0 || b.damageState.substitute
                next if !b.hasActiveAbility?(:STEAMENGINE)
                b.pbRaiseStatStageByAbility(:SPEED, 6, b) if b.pbCanRaiseStatStage?(:SPEED, b)
            end
        end
        # Fainting
        targets.each { |b| b.pbFaint if b&.fainted? }
        user.pbFaint if user.fainted?
        # Dragon Darts' second half of attack
        if move.pbRepeatHit? && hitNum == 0 &&
            targets.any? { |b| !b.fainted? && !b.damageState.unaffected }
            pbProcessMoveHit(move, user, all_targets, 1, skipAccuracyCheck)
        end
        return true
    end
end

class Pokemon
    def gendernil
        @gender = nil
    end

    alias __evo_species__= species=
    def species=(species_id)
        self.__evo_species__ = species_id
        @gender      = nil if singleGendered? || @gender == 2
        calc_stats
    end
end

#Orden en las Formas
MenuHandlers.add(:pokemon_debug_menu, :species_and_form, {
  "name"   => _INTL("Especie/forma..."),
  "parent" => :main,
  "effect" => proc { |pkmn, pkmnid, heldpoke, settingUpBattle, screen|
    cmd = 0
    loop do
        msg = [_INTL("Especie {1}, forma {2}.", pkmn.speciesName, pkmn.form),
                _INTL("Especie {1}, forma {2} (forzado).", pkmn.speciesName, pkmn.form)][(pkmn.forced_form.nil?) ? 0 : 1]
        cmd = screen.pbShowCommands(msg,
                                    [_INTL("Definir especie"),
                                    _INTL("Definir forma"),
                                    _INTL("Eliminar de anulados")], cmd)
        break if cmd < 0
        case cmd
            when 0   # Set species
                species = pbChooseSpeciesList(pkmn.species)
                if species && species != pkmn.species
                    pkmn.species = species
                    pkmn.calc_stats
                    $player.pokedex.register(pkmn) if !settingUpBattle && !pkmn.egg?
                    screen.pbRefreshSingle(pkmnid)
                end
            when 1   # Set form
                cmd2 = 0
                formcmds = [[], []]
                GameData::Species::DATA.values
                .sort_by { |sp| [sp.species.to_s, sp.form] }
                .each do |sp|
                    next if sp.species != pkmn.species
                    form_name = sp.form_name
                    form_name = _INTL("Forma sin nombre") if !form_name || form_name.empty?
                    form_name = sprintf("%d: %s", sp.form, form_name)
                    formcmds[0].push(sp.form)
                    formcmds[1].push(form_name)
                    cmd2 = formcmds[0].length - 1 if pkmn.form == sp.form
                end
                if formcmds[0].length <= 1
                    screen.pbDisplay(_INTL("La especie {1} solo tiene una forma.", pkmn.speciesName))
                    if pkmn.form != 0 && screen.pbConfirm(_INTL("¿Quieres reiniciar la forma a la 0?"))
                        pkmn.gendernil if pkmn.species == :PIKACHU
                        pkmn.form = 0
                        $player.pokedex.register(pkmn) if !settingUpBattle && !pkmn.egg?
                        screen.pbRefreshSingle(pkmnid)
                    end
                else
                    cmd2 = screen.pbShowCommands(_INTL("Define la forma del Pokémon."), formcmds[1], cmd2)
                    next if cmd2 < 0
                    f = formcmds[0][cmd2]
                    if f != pkmn.form
                        if MultipleForms.hasFunction?(pkmn, "getForm")
                            next if !screen.pbConfirm(_INTL("Esta especie decide su propia forma. ¿Sobrescribir?"))
                            pkmn.forced_form = f
                        end
                        pkmn.gendernil if pkmn.species == :PIKACHU
                        pkmn.form = f
                        $player.pokedex.register(pkmn) if !settingUpBattle && !pkmn.egg?
                        screen.pbRefreshSingle(pkmnid)
                    end
                end
            when 2   # Remove form override
                pkmn.forced_form = nil
                screen.pbRefreshSingle(pkmnid)
        end
    end
    next false
  }
})

#Modificacion para leer "Rules" en Batallas
module BattleCreationHelperMethods
    module_function
    BattleCreationHelperMethods.singleton_class.alias_method :old_prepare_battle, :prepare_battle
    def prepare_battle(battle)
        BattleCreationHelperMethods.old_prepare_battle(battle)
        battle.rules = $game_temp.battle_rules.clone
        #battle.rules = battleRules.clone
    end
end

class Battle::Move::RevivePokemonToHalfHP < Battle::Move
    def pbEffectGeneral(user)
        pkmn = nil
        if !@battle.controlPlayer && @battle.pbOwnedByPlayer?(user.index)
            # Player chooses the Pokémon to revive
            @battle.scene.pbPartyScreen(user.index, false, 2) do |idxParty, party_screen|
                pkmn = @battle.pbParty(user.idxOwnSide)[idxParty]
                if pkmn.egg?
                    party_screen.show_message(_INTL("¡No se puede revivir un huevo!"))
                    next false
                elsif !pkmn.fainted?
                    party_screen.show_message(_INTL("¡Este Pokémon no puede ser revivido!"))
                    next false
                end
                next true
            end
        else
            # The AI chooses the Pokémon to revive
            pkmn = Battle::AI.choose_pokemon_to_revive(user)
        end
        pkmn.hp = (pkmn.totalhp / 2).floor
        pkmn.hp = 1 if pkmn.hp <= 0
        pkmn.heal_status
        @battle.pbDisplay(_INTL("¡{1} fue revivido y está listo para luchar de nuevo!", pkmn.name))
    end
end