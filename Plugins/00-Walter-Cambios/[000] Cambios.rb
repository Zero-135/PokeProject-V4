#POKEDEX
class PokemonPokedexInfo_Scene
    #Permite ver Shinies en la Pokédex
    def pbScene
        @available = pbGetAvailableForms(false)
        @available_shiny = pbGetAvailableForms(true)
        Pokemon.play_cry(@species, @form)
        loop do
            Graphics.update
            Input.update
            pbUpdate
            dorefresh = false
            if Input.trigger?(Input::ACTION)
                pbSEStop
                Pokemon.play_cry(@species, @form) if @page == 1
            elsif Input.trigger?(Input::BACK)
                pbPlayCloseMenuSE
                break
            elsif Input.trigger?(Input::USE)
                ret = pbPageCustomUse(@page_id)
                if !ret
                    case @page_id
                        when :page_info
                            pbPlayDecisionSE
                            @show_battled_count = !@show_battled_count
                            dorefresh = true
                        when :page_forms
                            if @available.length + @available_shiny.length > 1
                                pbPlayDecisionSE
                                pbChooseForm
                                dorefresh = true
                            end
                        end
                    else
                    dorefresh = true
                end
            elsif Input.repeat?(Input::UP)
                oldindex = @index
                pbGoToPrevious
                if @index != oldindex
                    pbUpdateDummyPokemon
                    @available = pbGetAvailableForms(false)
                    @available_shiny = pbGetAvailableForms(true)
                    pbSEStop
                    (@page == 1) ? Pokemon.play_cry(@species, @form) : pbPlayCursorSE
                    dorefresh = true
                end
            elsif Input.repeat?(Input::DOWN)
                oldindex = @index
                pbGoToNext
                if @index != oldindex
                    pbUpdateDummyPokemon
                    @available = pbGetAvailableForms(false)
                    @available_shiny = pbGetAvailableForms(true)
                    pbSEStop
                    (@page == 1) ? Pokemon.play_cry(@species, @form) : pbPlayCursorSE
                    dorefresh = true
                end
            elsif Input.repeat?(Input::LEFT)
                oldpage = @page
                numpages = @page_list.length
                @page -= 1
                @page = numpages if @page < 1
                @page = 1 if @page > numpages 
                if @page != oldpage
                    pbPlayCursorSE
                    dorefresh = true
                end
            elsif Input.repeat?(Input::RIGHT)
                oldpage = @page
                numpages = @page_list.length
                @page += 1
                @page = numpages if @page < 1
                @page = 1 if @page > numpages
                if @page != oldpage
                    pbPlayCursorSE
                    dorefresh = true
                end
            end
            drawPage(@page) if dorefresh
        end
        return @index
    end

    #Revisa si se ha visualizado la forma shiny  #Doble
    def pbGetAvailableForms(shiny = nil)
        ret = []
        multiple_forms = false
        GameData::Species.each do |sp|
            next if sp.species != @species
            next if sp.form != 0 && (!sp.real_form_name || sp.real_form_name.empty?)
            next if sp.pokedex_form != sp.form
            multiple_forms = true if sp.form > 0
            if sp.single_gendered?
                real_gender = (sp.gender_ratio == :AlwaysFemale) ? 1 : 0
                next if !$player.pokedex.seen_form?(@species, real_gender, sp.form, shiny) && !Settings::DEX_SHOWS_ALL_FORMS
                real_gender = 2 if sp.gender_ratio == :Genderless
                ret.push([sp.form_name, real_gender, sp.form])
            elsif !gender_difference?(sp.form)
                2.times do |real_gndr|
                    next if !$player.pokedex.seen_form?(@species, real_gndr, sp.form, shiny) && !Settings::DEX_SHOWS_ALL_FORMS
                    ret.push([sp.form_name || _INTL("Forma Normal"), 0, sp.form])
                    break
                end
            elsif sp.form_name == _INTL("Macho") || sp.form_name == _INTL("Hembra")
                next if !$player.pokedex.seen_form?(@species, sp.form, sp.form, shiny) && !Settings::DEX_SHOWS_ALL_FORMS
                ret.push([sp.form_name, sp.form, sp.form])
            else
                g = [_INTL("Macho"), _INTL("Hembra")]
                2.times do |real_gndr|
                    next if !$player.pokedex.seen_form?(@species, real_gndr, sp.form, shiny) && !Settings::DEX_SHOWS_ALL_FORMS
                    form_name = (sp.form_name) ? sp.form_name + " " + g[real_gndr] : g[real_gndr]
                    ret.push([form_name, real_gndr, sp.form]) 
                end
            end
        end
        ret.sort! { |a, b| (a[2] == b[2]) ? a[1] <=> b[1] : a[2] <=> b[2] }
        ret.each do |entry|
            if entry[0]
                entry[0] = "" if !multiple_forms && !gender_difference?(entry[2])
            else
                case entry[1]
                    when 0 then entry[0] = _INTL("Macho")
                    when 1 then entry[0] = _INTL("Hembra")
                else
                    entry[0] = (multiple_forms) ? _INTL("Forma Normal") : _INTL("Sin Género")
                end
            end
            entry[1] = 0 if entry[1] == 2
        end
        return ret
    end

    #Flechas en Formas del Poke en Pokedex
    def pbChooseForm
        index = 0
        @availablePokedex = @available.length > 0 ? @available : @available_shiny

        @availablePokedex.length.times do |i|
            if @availablePokedex[i][1] == @gender && @availablePokedex[i][2] == @form
                index = i
                break
            end
        end
        oldindex = -1
        shiny = @shiny
        old_shiny = !shiny

        @sprites["leftarrow"] = AnimatedSprite.new("Graphics/UI/left_arrow", 8, 40, 28, 2, @viewport)
        @sprites["leftarrow"].x = 172
        @sprites["leftarrow"].y = 308
        @sprites["leftarrow"].play
        @sprites["leftarrow"].visible = false
        @sprites["rightarrow"] = AnimatedSprite.new("Graphics/UI/right_arrow", 8, 40, 28, 2, @viewport)
        @sprites["rightarrow"].x = 312
        @sprites["rightarrow"].y = 308
        @sprites["rightarrow"].play
        @sprites["rightarrow"].visible = false
        loop do
            @availablePokedex = shiny ? @available_shiny : @available
            if oldindex != index || old_shiny != shiny
                $player.pokedex.set_last_form_seen(@species, @availablePokedex[index][1], @availablePokedex[index][2], shiny)
                pbUpdateDummyPokemon
                drawPage(@page)
                @sprites["uparrow"].visible   = (index > 0)
                @sprites["downarrow"].visible = (index < @availablePokedex.length - 1)
                @sprites["rightarrow"].visible = !shiny && (@available_shiny.length > 0)
                @sprites["leftarrow"].visible = shiny && (@available.length > 0)
                oldindex = index
                old_shiny = shiny
            end
            Graphics.update
            Input.update
            pbUpdate
            if Input.trigger?(Input::UP)
                pbPlayCursorSE
                index = (index != 0) ? index - 1 : 0
            elsif Input.trigger?(Input::DOWN)
                pbPlayCursorSE
                index = (index != @availablePokedex.length - 1) ? index + 1 : @availablePokedex.length - 1
            elsif Input.trigger?(Input::RIGHT)
                pbPlayCursorSE
                if @available_shiny.length > 0
                    shiny = true
                    index = (index < @available_shiny.length) ? index : @available_shiny.length - 1
                end
            elsif Input.trigger?(Input::LEFT)
                pbPlayCursorSE
                if @available.length > 0
                    shiny = false
                    index = (index < @available.length) ? index : @available.length - 1
                end
            elsif Input.trigger?(Input::BACK)
                pbPlayCancelSE
                break
            elsif Input.trigger?(Input::USE)
                pbPlayDecisionSE
                break
            end
        end
        @sprites["uparrow"].visible   = false
        @sprites["downarrow"].visible = false
        @sprites["rightarrow"].visible = false
        @sprites["leftarrow"].visible = false
        #$player.pokedex.set_last_form_seen(@species, 0, 0, false)
    end

    #Imagen Pokedex Back y Shiny
    alias walter_pbUpdateDummyPokemon pbUpdateDummyPokemon
    def pbUpdateDummyPokemon
        walter_pbUpdateDummyPokemon
        @species = @dexlist[@index][:species]
        @gender, @form, @shiny = $player.pokedex.last_form_seen(@species)
        @sprites["infosprite"].setSpeciesBitmap(@species, @gender, @form, @shiny)
        @sprites["formfront"]&.setSpeciesBitmap(@species, @gender, @form, @shiny)
        if @sprites["formback"]
            @sprites["formback"].setSpeciesBitmap(@species, @gender, @form, @shiny, false, true)
        end
        @sprites["formicon"]&.pbSetParams(@species, @gender, @form, @shiny)
    end

    #Muestra el genero del Pokemon Shiny
    def drawPageForms
        #Nuevo
        @sprites["formfront"].visible     = true
        @sprites["formback"].visible      = true
        @sprites["formicon"].visible      = true

        #Antiguo
        coords = PAGE_FORMS_COORDS
        @sprites["background"].setBitmap(_INTL("Graphics/UI/Pokedex/bg_forms"))
        overlay = @sprites["overlay"].bitmap
        base   = Color.new(88, 88, 80)
        shadow = Color.new(168, 184, 184)
        # Write species and form name
        formname = ""
        if @shiny
            @available_shiny.each do |i|
                if i[1] == @gender && i[2] == @form
                    formname = i[0]
                    break
                end
            end
        else
            @available.each do |i|
                if i[1] == @gender && i[2] == @form
                    formname = i[0]
                    break
                end
            end
        end
        textpos = [
            [GameData::Species.get(@species).name, Graphics.width / 2, Graphics.height + coords[:species_name_y_offset], :center, base, shadow],
            [formname, Graphics.width / 2, Graphics.height + coords[:form_name_y_offset], :center, base, shadow]
        ]
        # Draw all text
        pbDrawTextPositions(overlay, textpos)
    end
end


#Adiciones Personalizadas Walter
module GameData
    class Species
        #Imagenes
        def self.check_graphic_file(path, species, form = 0, gender = 0, shiny = false, shadow = false, subfolder = "")
            try_subfolder = sprintf("%s/", subfolder)
            try_species = species
            try_form    = (form > 0) ? sprintf("_%d", form) : ""
            try_gender  = (gender == 1) ? "Female/" : ""
            try_shadow  = (shadow) ? "_shadow" : ""
            factors = []
            if shiny == 2
                factors.push([4, sprintf("%s super shiny/", subfolder), try_subfolder])
            elsif shiny
                factors.push([4, sprintf("%s shiny/", subfolder), try_subfolder])
            end
            factors.push([3, try_shadow, ""]) if shadow
            factors.push([2, try_gender, ""]) if gender == 1
            factors.push([1, try_form, ""]) if form > 0
            factors.push([0, try_species, "0000"])
            # Go through each combination of parameters in turn to find an existing sprite
            (2**factors.length).times do |i|
                # Set try_ parameters for this combination
                factors.each_with_index do |factor, index|
                    value = ((i / (2**index)).even?) ? factor[1] : factor[2]
                    case factor[0]
                        when 0 then try_species   = value
                        when 1 then try_form      = value
                        when 2 then try_gender    = value
                        when 3 then try_shadow    = value
                        when 4 then try_subfolder = value   # Shininess
                    end
                end
                # Look for a graphic matching this combination's parameters
                try_species_text = try_species
                ret = pbResolveBitmap(sprintf("%s%s%s%s%s%s", path, try_subfolder,
                                            try_gender, try_species_text, try_form, try_shadow))
                return ret if ret
            end
            return nil
        end

        #Tutores
        def get_tutor_moves
            case @id
                when :PIKACHU     then moves = [:VOLTTACKLE]
                when :PIKACHU_2   then moves = [:THUNDERSHOCK]
                when :PIKACHU_3   then moves = [:ICICLECRASH]
                when :PIKACHU_4   then moves = [:FLYINGPRESS]
                when :PIKACHU_5   then moves = [:ELECTRICTERRAIN]
                when :PIKACHU_6   then moves = [:DRAININGKISS]
                when :PIKACHU_7   then moves = [:METEORMASH]
                when :ROTOM_1     then moves = [:OVERHEAT]
                when :ROTOM_2     then moves = [:HYDROPUMP]
                when :ROTOM_3     then moves = [:BLIZZARD]
                when :ROTOM_4     then moves = [:AIRSLASH]
                when :ROTOM_5     then moves = [:LEAFSTORM]
                when :KYUREM_1    then moves = [:ICEBURN, :FUSIONFLARE]
                when :KYUREM_2    then moves = [:FREEZESHOCK, :FUSIONBOLT]
                when :NECROZMA_1  then moves = [:SUNSTEELSTRIKE]
                when :NECROZMA_2  then moves = [:MOONGEISTBEAM]
                when :ZACIAN_1    then moves = [:BEHEMOTHBLADE]
                when :ZAMAZENTA_1 then moves = [:BEHEMOTHBASH]
                when :CALYREX_1   then moves = [:GLACIALLANCE]
                when :CALYREX_2   then moves = [:ASTRALBARRAGE]
            end
            return self.tutor_moves.sort unless moves
            return (self.tutor_moves + moves).sort
        end
    end
end

#Movimiento Combate
class Battle
    def pbRegisterMove(idxBattler, idxMove, showMessages = true)
        battler = @battlers[idxBattler]
        move = battler.moves[idxMove]
        return false if !pbCanChooseMove?(idxBattler, idxMove, showMessages)

        if move.id == :STRUGGLE
            @choices[idxBattler][0] = :UseMove    # "Use move"
            @choices[idxBattler][1] = -1          # Index of move to be used
            @choices[idxBattler][2] = @struggle   # Struggle Battle::Move object
            @choices[idxBattler][3] = -1          # No target chosen yet
        else
            @choices[idxBattler][0] = :UseMove   # "Use move"
            @choices[idxBattler][1] = idxMove    # Index of move to be used
            @choices[idxBattler][2] = move       # Battle::Move object
            @choices[idxBattler][3] = -1         # No target chosen yet
        end

        return true
    end
end

#Actualizacion de las formas de los pokes legendarios
MultipleForms.register(:RESHIRAM, {
    "getFormOnBattle" => proc { |pkmn|
        if pkmn.ability == :TURBOBLAZE && pkmn.form == 0
            next 1
        end
    },
    "getFormOnLeavingBattle" => proc { |pkmn, battle, usedInBattle, endBattle|
        next 0 if pkmn.form >= 1
    }
})

MultipleForms.register(:ZEKROM, {
    "getFormOnBattle" => proc { |pkmn|
        if pkmn.ability == :TERAVOLT && pkmn.form == 0
            next 1
        end
    },
    "getFormOnLeavingBattle" => proc { |pkmn, battle, usedInBattle, endBattle|
        next 0 if pkmn.form >= 1
    }
})

MultipleForms.register(:KYUREM, {
    "getFormOnBattle" => proc { |pkmn|
        next pkmn.form + 2 if pkmn.form == 1 || pkmn.form == 2
    },
    "getFormOnLeavingBattle" => proc { |pkmn, battle, usedInBattle, endBattle|
        next pkmn.form - 2 if pkmn.form >= 3   # Fused forms stop glowing
    },
    "onSetForm" => proc { |pkmn, form, oldForm|
        case form
        when 0   # Normal
            pkmn.moves.each_with_index do |move, i|
            case move.id
            when :ICEBURN, :FREEZESHOCK
                next if !GameData::Move.exists?(:GLACIATE)
                if pkmn.hasMove?(:GLACIATE)
                    pkmn.moves[i] = nil
                else
                    move.id = :GLACIATE
                end
            when :FUSIONFLARE, :FUSIONBOLT
                next if !GameData::Move.exists?(:SCARYFACE)
                if pkmn.hasMove?(:SCARYFACE)
                    pkmn.moves[i] = nil
                else
                    move.id = :SCARYFACE
                end
            end
            pkmn.moves.compact!
        end
        when 1   # White
            pkmn.moves.each do |move|
            case move.id
            when :GLACIATE
                next if !GameData::Move.exists?(:ICEBURN) || pkmn.hasMove?(:ICEBURN)
                move.id = :ICEBURN
            when :SCARYFACE
                next if !GameData::Move.exists?(:FUSIONFLARE) || pkmn.hasMove?(:FUSIONFLARE)
                move.id = :FUSIONFLARE
            end
        end
        when 2   # Black
            pkmn.moves.each do |move|
            case move.id
            when :GLACIATE
                next if !GameData::Move.exists?(:FREEZESHOCK) || pkmn.hasMove?(:FREEZESHOCK)
                move.id = :FREEZESHOCK
            when :SCARYFACE
                next if !GameData::Move.exists?(:FUSIONBOLT) || pkmn.hasMove?(:FUSIONBOLT)
                move.id = :FUSIONBOLT
            end
        end
    end
  }
})

MultipleForms.register(:XERNEAS, {
    "getFormOnBattle" => proc { |pkmn|
        if pkmn.ability == :FAIRYAURA && pkmn.form == 0
            next 1
        end
    },
    "getFormOnLeavingBattle" => proc { |pkmn, battle, usedInBattle, endBattle|
        next 0 if endBattle
    }
})

MultipleForms.register(:ZACIAN, {
    "getFormOnBattle" => proc { |pkmn|
        if pkmn.form == 0 && pkmn.hasItem?(:RUSTEDSWORD)
            next 1
        end
    },
    "changePokemonOnStartingBattle" => proc { |pkmn, battle|
        if GameData::Move.exists?(:BEHEMOTHBLADE) && pkmn.hasItem?(:RUSTEDSWORD)
            pkmn.moves.each { |move| move.id = :BEHEMOTHBLADE if move.id == :IRONHEAD }
        end
    },
    "getFormOnLeavingBattle" => proc { |pkmn, battle, usedInBattle, endBattle|
        next 0 if endBattle
    },
    "changePokemonOnLeavingBattle" => proc { |pkmn, battle, usedInBattle, endBattle|
        if endBattle
            pkmn.moves.each { |move| move.id = :IRONHEAD if move.id == :BEHEMOTHBLADE }
        end
    },
    "getFormOnAttack" => proc { |pkmn, move|
        if pkmn.form == 1 && move == :BEHEMOTHBLADE
            next 2
        end
    }
})

MultipleForms.register(:ZAMAZENTA, {
    "getFormOnBattle" => proc { |pkmn|
        if pkmn.form == 0 && pkmn.hasItem?(:RUSTEDSHIELD)
            next 1
        end
    },
    "changePokemonOnStartingBattle" => proc { |pkmn, battle|
        if GameData::Move.exists?(:BEHEMOTHBASH) && pkmn.hasItem?(:RUSTEDSHIELD)
            pkmn.moves.each { |move| move.id = :BEHEMOTHBASH if move.id == :IRONHEAD }
        end
    },
    "getFormOnLeavingBattle" => proc { |pkmn, battle, usedInBattle, endBattle|
        next 0 if endBattle
    },
    "changePokemonOnLeavingBattle" => proc { |pkmn, battle, usedInBattle, endBattle|
        if endBattle
            pkmn.moves.each { |move| move.id = :IRONHEAD if move.id == :BEHEMOTHBASH }
        end
    },
    "getFormOnAttack" => proc { |pkmn, move|
        if pkmn.form == 1 && move == :BEHEMOTHBASH
            next 2
        end
    }
})

MultipleForms.register(:SOLGALEO, {
    "getFormOnAttack" => proc { |pkmn, move|
        if pkmn.form == 0 && (move == :SUNSTEELSTRIKE || move == :SEARINGSUNRAZESMASH)
            next 1
        end
    }
})

MultipleForms.register(:LUNALA, {
    "getFormOnAttack" => proc { |pkmn, move|
        if pkmn.form == 0 && (move == :MOONGEISTBEAM || move == :MENACINGMOONRAZEMAELSTROM)
            next 1
        end
    }
})

MultipleForms.register(:MARSHADOW, {
    "getFormOnAttack" => proc { |pkmn, move|
        if pkmn.form == 0 && move == :SOULSTEALING7STARSTRIKE
            next 1
        end
    }
})

class Battle::Battler
    #Modificaciones para las formas de Reshiram, Zekrom y Kyurem
    alias new_forms_pbCheckForm pbCheckForm
    def pbCheckForm(endOfRound = false)
        new_forms_pbCheckForm(endOfRound)
        return if fainted? || @effects[PBEffects::Transform]
        f = MultipleForms.call("getFormOnBattle", @pokemon)
        pbChangeForm(f, _INTL("")) if f
    end

    #Cambia Formas en Ataques
    def pbProcessTurn(choice, tryFlee = true)
        return false if fainted?
        # Wild roaming Pokémon always flee if possible
        if tryFlee && wild? && @battle.rules[:roamer_flees] && @battle.pbCanRun?(@index)
            pbBeginTurn(choice)
            wild_flee(_INTL("¡{1} ha huido del combate!", pbThis))
            return true
        end
        # Shift with the battler next to this one
        if choice[0] == :Shift
            idxOther = -1
            case @battle.pbSideSize(@index)
            when 2
                idxOther = (@index + 2) % 4
            when 3
                if @index != 2 && @index != 3   # If not in middle spot already
                    idxOther = (@index.even?) ? 2 : 3
                end
            end
            if idxOther >= 0
                @battle.pbSwapBattlers(@index, idxOther)
                case @battle.pbSideSize(@index)
                when 2
                    @battle.pbDisplay(_INTL("¡{1} se ha desplazado!", pbThis))
                when 3
                    @battle.pbDisplay(_INTL("¡{1} se movió al centro!", pbThis))
                end
            end
            pbBeginTurn(choice)
            pbCancelMoves(false)
            @lastRoundMoved = @battle.turnCount   # Done something this round
            return true
        end
        # If this battler's action for this round wasn't "use a move"
        if choice[0] != :UseMove
            # Clean up effects that end at battler's turn
            pbBeginTurn(choice)
            pbEndTurn(choice)
            return false
        end
        
        f = MultipleForms.call("getFormOnAttack", @pokemon, choice[2].id)
        pbChangeForm(f, _INTL("")) if f
        # Use the move
        PBDebug.log("[Use move] #{pbThis} (#{@index}) usó #{choice[2].name}")
        @battle.clearStagesChangeRecords
        PBDebug.logonerr { pbUseMove(choice, choice[2] == @battle.struggle) }
        pbChangeForm(f - 1, _INTL("")) if f

        @battle.checkStatChangeResponses
        @battle.pbJudge
        # Update priority order
        @battle.pbCalculatePriority if Settings::RECALCULATE_TURN_ORDER_AFTER_SPEED_CHANGES
        return true
    end
end

#Pikachu Cosplay
form_data = {
    "onSetForm" => proc { |pkmn, form, oldForm|
        form_moves = [
        :ICICLECRASH,     # Pikachu Belle
        :FLYINGPRESS,     # Pikachu Libre
        :ELECTRICTERRAIN, # Pikachu, Ph.D.
        :DRAININGKISS,    # Pikachu Pop Star
        :METEORMASH       # Pikachu Rock Star
        ]

        # Buscar movimiento anterior de forma
        old_move_index = pkmn.moves.index { |m| form_moves.include?(m.id) } || -1

        # Determinar nuevo movimiento
        new_move_id = (form > 2 && form < 8) ? form_moves[form - 3] : nil
        new_move_id = nil unless GameData::Move.exists?(new_move_id)
        if new_move_id.nil? && old_move_index >= 0 && pkmn.numMoves == 1
            new_move_id = :THUNDERSHOCK
            raise _INTL("Pikachu está intentando olvidar su último movimiento, pero no tiene más movimientos con el que reemplazarlo.") unless GameData::Move.exists?(new_move_id)
        end
        new_move_id = nil if pkmn.hasMove?(new_move_id)
        if old_move_index >= 0
            old_move_name = pkmn.moves[old_move_index].name
            if new_move_id.nil?
                pkmn.forget_move_at_index(old_move_index)
                pbMessage(_INTL("{1} olvidó {2}...", pkmn.name, old_move_name))
            else
                pkmn.moves[old_move_index].id = new_move_id
                new_move_name = pkmn.moves[old_move_index].name
                pbMessage(_INTL("{1} olvidó {2}...", pkmn.name, old_move_name) + "\1")
                pbMessage("\\se[]" + _INTL("¡{1} aprendió {2}!", pkmn.name, new_move_name) + "\\se[Pkmn move learnt]")
            end
        elsif new_move_id
            pbLearnMove(pkmn, new_move_id, true)
        end
    }
}

# Agregar getForm solo si está activado
if Settings::REGIONAL_FORMS_DEPEND_ON_MAP_REGION
    form_data["getForm"] = proc { |pkmn|
        next if pkmn.form_simple >= 2
        if $game_map
            map_pos = $game_map.metadata&.town_map_position
            next 1 if map_pos && map_pos[0] == 1
        end
        next 0
    }
end

MultipleForms.register(:PIKACHU, form_data)

#Adicion de Objetos para cambiar Formas
ItemHandlers::UseOnPokemon.add(:PIKACHUCATALOG, proc { |item, qty, pkmn, scene|
    if !pkmn.isSpecies?(:PIKACHU) || pkmn.form < 2 || pkmn.form > 7
        scene.pbDisplay(_INTL("No tendría efecto."))
        next false
    elsif pkmn.fainted?
        scene.pbDisplay(_INTL("No se puede usar en Pokémon debilitados."))
        next false
    end
    choices = [
        _INTL("Cosplay Pikachu"),
        _INTL("Pikachu Belle"),
        _INTL("Pikachu Libre"),
        _INTL("Pikachu, Ph.D."),
        _INTL("Pikachu Pop Star"),
        _INTL("Pikachu Rock Star"),
        _INTL("Cancelar")
    ]
    new_form = scene.pbShowCommands(_INTL("¿Qué disfraz te gustaría ponerle?"), choices, pkmn.form-2)
    if new_form == pkmn.form - 2
        scene.pbDisplay(_INTL("No tendría ningún efecto."))
        next false
    elsif new_form >= 0 && new_form < choices.length - 1
        pkmn.setForm(new_form + 2) do
            scene.pbRefresh
            scene.pbDisplay(_INTL("¡{1} se disfrazó!", pkmn.name))
        end
        next true
    end
    next false
})

ItemHandlers::UseOnPokemon.add(:SCISSORS, proc { |item, qty, pkmn, scene|
    if !pkmn.isSpecies?(:FURFROU)
        scene.pbDisplay(_INTL("No tendría efecto."))
        next false
    elsif pkmn.fainted?
        scene.pbDisplay(_INTL("No se puede usar en Pokémon debilitados."))
        next false
    end
    choices = [
        _INTL("Natural Form"),
        _INTL("Heart Trim"),
        _INTL("Star Trim"),
        _INTL("Diamond Trim"),
        _INTL("Debutante Trim"),
        _INTL("Matron Trim"),
        _INTL("Dandy Trim"),
        _INTL("La Reine Trim"),
        _INTL("Kabuki Trim"),
        _INTL("Pharaoh Trim"),
        _INTL("Cancelar")
    ]
    new_form = scene.pbShowCommands(_INTL("¿Qué corte te gustaría hacerle?"), choices, pkmn.form)
    if new_form == pkmn.form
        scene.pbDisplay(_INTL("No tendría ningún efecto."))
        next false
    elsif new_form >= 0 && new_form < choices.length - 1
        pkmn.setForm(new_form) do
            scene.pbRefresh
            scene.pbDisplay(_INTL("¡{1} cambio de corte!", pkmn.name))
        end
        next true
    end
    next false
})

#Formas de Rotom
ItemHandlers::UseOnPokemon.add(:ROTOMCATALOG,
    proc { |item, qty, pkmn, scene|
        next RotomFormChange.choose_form(pkmn, scene)
    }
)

module RotomFormChange

    ROTOMFORMS ={
        :NORMAL => _INTL("Bombilla"),
        :HEAT   => _INTL("Microondas"),
        :WASH   => _INTL("Lavadora"),
        :FROST  => _INTL("Nevera"),
        :FAN    => _INTL("Ventilador"),
        :MOW    => _INTL("Corta césped"),
    }

    # === MÉTODO BASE (el corazón de todo) ===
    def self.apply_form(pkmn, new_form, scene = nil)
        if pkmn.form == new_form
            scene&.pbDisplay(_INTL("No tendría ningún efecto."))
            return false
        end

        pkmn.setForm(new_form) do
            scene&.pbRefresh
            scene&.pbDisplay(_INTL("¡{1} se transformó!", pkmn.name))
        end
        return true
    end

    # === USO DESDE SCRIPT (lo que tú quieres) ===
    def self.change_form(form_symbol, pkmn = nil)
        new_form = ROTOMFORMS.keys.index(form_symbol)
        return false if new_form.nil?

        pkmn ||= $player.party.find { |p| p.isSpecies?(:ROTOM) && !p.fainted? }
        return false if !pkmn

        apply_form(pkmn, new_form)
    end

    # === USO CON MENÚ (ROTOM CATALOG) ===
    def self.choose_form(pkmn, scene)
        if !pkmn.isSpecies?(:ROTOM)
            scene&.pbDisplay(_INTL("No se puede usar en este pokemon."))
            return false
        end
        if pkmn.fainted?
            scene&.pbDisplay(_INTL("Esto no puede ser usado en un Pokémon debilitado."))
            return false
        end

        choices = ROTOMFORMS.values + [_INTL("Cancelar")]
        new_form = scene.pbShowCommands(
        _INTL("¿Qué electrodoméstico quieres pedir?"),
        choices,
        pkmn.form
        )
        return false if new_form < 0
        return false if new_form >= choices.length - 1

        apply_form(pkmn, new_form, scene)
    end
end

#Intercambios en Mapa
def pbChoosePokemonForTradeAnyPokemon(variableNumber, nameVarNumber)
    pbChooseTradablePokemon(variableNumber, nameVarNumber, proc { |pkmn|
        next true
    })
end

def pbStartTradeMySelf(pokemonIndex)
    $stats.trade_count += 1
    myPokemon = $player.party[pokemonIndex]
    yourPokemon = myPokemon
    resetmoves = false
    pbFadeOutInWithMusic do
        evo = PokemonTrade_Scene.new
        evo.pbStartScreen(myPokemon, yourPokemon, $player.name, $player.name)
        evo.pbTrade
        evo.pbEndScreen
    end
    $player.party[pokemonIndex] = yourPokemon
end

#Evolucion Shellmet y Karrablast
GameData::Evolution.register({
    :id            => :SPECIESLINKING,
    :parameter     => :Species,
    :use_item_proc => proc { |pkmn, parameter, item|
        next item == :LINKINGCORD && $player.has_species?(parameter)
    }
})


#Evoluciones en Batalla
class Battle
    alias battle_pbGainExpOne pbGainExpOne
    def pbGainExpOne(idxParty, defeatedBattler, numPartic, expShare, expAll, showMessages = true)
        pkmn = pbParty(0)[idxParty]
        old_level = pkmn.level
        battle_pbGainExpOne(idxParty, defeatedBattler, numPartic, expShare, expAll, showMessages)
        new_level = pkmn.level

        return if new_level <= old_level

        new_species = pkmn.check_evolution_on_level_up
        return if !new_species

        pbFadeOutInWithMusic do
            evo = PokemonEvolutionScene.new
            evo.pbStartScreen(pkmn, new_species)
            evo.pbEvolution
            evo.pbEndScreen
        end

        battler = @battlers.find { |b| b && b.pokemon.equal?(pkmn) }
        updateBattler(battler, @scene)
    end
    
    def pbPlayerDisplayParty(idxBattler = 0)
        partyOrders = pbPartyOrder(idxBattler)
        idxStart, _idxEnd = pbTeamIndexRangeFromBattlerIndex(idxBattler)
        ret = []
        (partyOrders.length...pbParty(idxBattler).length).each do |i|
            partyOrders << i
        end
        eachInTeamFromBattlerIndex(idxBattler) { |pkmn, i| ret[partyOrders[i] - idxStart] = pkmn }
        return ret
    end
end

#Metodo para actualizar el sprite luego de evolucionar
def updateBattler(battler, scene)
    if battler
        idxBattler = battler.index
        battler.pbUpdate(true)
        scene.pbChangePokemon(battler, battler.pokemon)
        scene.pbRefreshOne(idxBattler)
    end
end

#Evoluciones por Piedra
ItemHandlers::BattleUseOnPokemon.addIf(:evolution_stones,
    proc { |item| GameData::Item.get(item).is_evolution_stone? },
    proc { |item, pokemon, battler, choices, scene|
    if pokemon.shadowPokemon?
        scene.pbDisplay(_INTL("No tendría ningún efecto."))
        next false
    end
    newspecies = pokemon.check_evolution_on_use_item(item)
    if newspecies
        pbFadeOutInWithMusic do
            evo = PokemonEvolutionScene.new
            evo.pbStartScreen(pokemon, newspecies)
            evo.pbEvolution(false)
            evo.pbEndScreen
            if scene.is_a?(PokemonPartyScreen)
                scene.pbRefreshAnnotations(proc { |p| !p.check_evolution_on_use_item(item).nil? })
                scene.pbRefresh
            end
        end
        updateBattler(battler, scene)
        next true
    end
    scene.pbDisplay(_INTL("No tendría ningún efecto."))
    next false
})

#Correccion "APTO" en Bolsa al momento de usar una Piedra Evolutiva
alias _oldpbBattleAnimation pbBattleAnimation
def pbBattleAnimation(*args, &block)
    _oldpbBattleAnimation(*args, &block)
    $PokemonBattle = nil
end

class Battle
  alias _store_battle initialize
  def initialize(*args)
    _store_battle(*args)
    $PokemonBattle = self
  end
end

class PokemonBag_Scene
    alias old_pbUpdateAnnotation pbUpdateAnnotation
    def pbUpdateAnnotation
        if $game_temp.in_battle
            itemwindow = @sprites["itemlist"]
            item       = itemwindow.item
            itm        = GameData::Item.get(item) if item

            orderBattle = $PokemonBattle.pbPartyOrder(0)
            new_party = []
            orderBattle.each do |i|
                pkmn = $player.party[i]
                new_party << pkmn if pkmn
            end
            
            if @bag.last_viewed_pocket == 1 && item #Items Pocket
                annotations = nil
                annotations = []
                color_annotations=[]
                if itm.is_evolution_stone?
                    for i in new_party
                        elig = i.check_evolution_on_use_item(itm)
                        annotations.push((elig) ? _INTL("APTO") : _INTL("NO APTO"))
                        color_annotations.push((elig) ? nil : true)
                    end
                else
                    for i in 0...Settings::MAX_PARTY_SIZE
                        @sprites["pokemon#{i}"].text = annotations[i] if  annotations
                        @sprites["pokemon#{i}"].text_color = color_annotations[i] if annotations
                    end
                end
                for i in 0...Settings::MAX_PARTY_SIZE
                    @sprites["pokemon#{i}"].text = annotations[i] if  annotations
                    @sprites["pokemon#{i}"].text_color = color_annotations[i] if annotations
                end
            else
                old_pbUpdateAnnotation
            end
        else
            old_pbUpdateAnnotation
        end
    end
end

#Evolucion por RareCandy
ItemHandlers::BattleUseOnPokemon.add(:RARECANDY, proc { |item, pokemon, battler, choices, scene|
    if pokemon.shadowPokemon?
        scene.pbDisplay(_INTL("No tendría ningún efecto."))
        next false
    end
    if pokemon.level >= GameData::GrowthRate.max_level
        new_species = pokemon.check_evolution_on_level_up
        if !Settings::RARE_CANDY_USABLE_AT_MAX_LEVEL || !new_species
            scene.pbDisplay(_INTL("No tendría ningún efecto."))
            next false
        end
        # Check for evolution
        pbFadeOutInWithMusic do
            evo = PokemonEvolutionScene.new
            evo.pbStartScreen(pokemon, new_species)
            evo.pbEvolution
            evo.pbEndScreen
            scene.pbRefresh if scene.is_a?(PokemonPartyScreen)
        end
        updateBattler(battler, scene)
        next true
    end
    # Level up
    pbSEPlay("Pokemon level up")
    pbChangeLevel(pokemon, pokemon.level + 1, scene)
    updateBattler(battler, scene)
    next true
})

#MultipleForms.copy(:ESPURR, :BASCULIN)

#Metodo para extraer los eventos de un mapa
def execScript
    $game_map.events.each do |id, ev|
        data = ev.instance_variable_get(:@event)
        next if !data
        puts "ID: #{id} - Nombre: #{data.name} - X: #{ev.x} Y: #{ev.y}"
    end
end



#Cambios Following Pokemon
class Battle
    alias following_pbEndOfBattle pbEndOfBattle
    def pbEndOfBattle
        ret = following_pbEndOfBattle
        FollowingPkmn.refresh(false) if defined?(FollowingPkmn)
        return ret
    end
end