# Correcciones Gen 9  

#[000] Pokemon

#Correccion de Fecha y hora de cambio de forma
MultipleForms.register(:HOOPA, {
    "getForm" => proc { |pkmn|
        if Settings::MECHANICS_GENERATION < 9 && (!pkmn.time_form_set ||
            pbGetTimeNow.to_i > pkmn.time_form_set.to_i + (60 * 60 * 24 * 3))   # 3 days
            next 0
        end
    },
    "onSetForm" => proc { |pkmn, form, oldForm|
        pkmn.time_form_set = pbGetTimeNow.to_i if Settings::MECHANICS_GENERATION < 9
        # Move Change
        form_moves = [
        :HYPERSPACEHOLE,    # Confined form
        :HYPERSPACEFURY,    # Unbound form
        ]
        # Find a known move that should be forgotten
        old_move_index = -1
        pkmn.moves.each_with_index do |move, i|
            next if !form_moves.include?(move.id)
            old_move_index = i
            break
        end
        # Determine which new move to learn (if any)
        new_move_id = form_moves[form]
        new_move_id = nil if !GameData::Move.exists?(new_move_id)
        new_move_id = nil if pkmn.hasMove?(new_move_id)
        # Forget a known move (if relevant) and learn a new move (if relevant)
        if old_move_index >= 0
            old_move_name = pkmn.moves[old_move_index].name
            if new_move_id.nil?
                # Just forget the old move
                pkmn.forget_move_at_index(old_move_index)
            else
                # Replace the old move with the new move (keeps the same index)
                pkmn.moves[old_move_index].id = new_move_id
                new_move_name = pkmn.moves[old_move_index].name
                pbMessage("\\se[]" + _INTL("{1} aprendió {2}!", pkmn.name, new_move_name) + "\\se[Pkmn move learnt]")
            end
        end
    }
})

#Adicion Zygarde changePokemonOnMegaEvolve
MultipleForms.register(:ZYGARDE, {
    "changePokemonOnMegaEvolve" => proc { |battler, battle|
        if GameData::Move.exists?(:NIHILLIGHT)
            if [4, 5].include?(battler.form)
                battler.eachMoveWithIndex do |m, i|
                    next if m.id != :COREENFORCER
                    pokemon_move = battler.pokemon.moves[i]
                    pokemon_move.id = :NIHILLIGHT
                    battler_move = Battle::Move.from_pokemon_move(battle, pokemon_move)
                    battler.moves[i] = battler_move
                    if battle.choices[battler.index][1] == i
                        battle.choices[battler.index][2] = battler_move 
                        battle.pbDisplay(_INTL("{2} de {1} se transformó en {3}!", battler.pbThis,
                                        GameData::Move.get(:COREENFORCER).name, 
                                        GameData::Move.get(:NIHILLIGHT).name
                                        ))
                        break
                    end
                end
            end
        end
    },
    "getMegaMoves" => proc { |pkmn|
        next { :COREENFORCER => :NIHILLIGHT }
    },
    "changePokemonOnLeavingBattle" => proc { |pkmn, battle, usedInBattle, endBattle|
        if pkmn.fainted? || endBattle
            pkmn.moves.each { |move| move.id = :COREENFORCER if move.id == :NIHILLIGHT }
        end
    },
    "getFormOnLeavingBattle" => proc { |pkmn, battle, usedInBattle, endBattle|
        next pkmn.form - 2 if pkmn.form >= 2 && (pkmn.fainted? || endBattle)
    }
})

#Correcciones Formas OnCreation
MultipleForms.register(:TANDEMAUS, {
    "getFormOnCreation" => proc { |pkmn|
        next (pkmn.personalID % 100 == 0) ? 1 : 0
    },
    "getForm" => proc { |pkmn|
        next (pkmn.personalID % 100 == 0) ? 1 : 0
    }
})

MultipleForms.copy(:TANDEMAUS, :MAUSHOLD)

MultipleForms.register(:DUNSPARCE, {
    "getFormOnCreation" => proc { |pkmn|
        next (pkmn.personalID % 100 == 0) ? 1 : 0
    },
    "getForm" => proc { |pkmn|
        next (pkmn.personalID % 100 == 0) ? 1 : 0
    }
})

MultipleForms.copy(:DUNSPARCE, :DUDUNSPARCE)




#[001] Summary
#Correccion del BackSprite
class PokemonSummary_Scene
    def pbScene
        @pokemon.play_cry
        loop do
            Graphics.update
            Input.update
            pbUpdate
            dorefresh = false
            if Input.trigger?(Input::ACTION)
                pbSEStop
                @pokemon.play_cry
                @show_back = !@show_back
                if PluginManager.installed?("[DBK] Animated Pokémon System")
                    @sprites["pokemon"].display_values = [UI_POKEMON_SPRITE_X, UI_POKEMON_SPRITE_Y, UI_SPRITE_CONSTRICT_W, UI_SPRITE_CONSTRICT_H]
                    @sprites["pokemon"].setSummaryBitmap(@pokemon, @show_back)
                else
                    @sprites["pokemon"].setPokemonBitmap(@pokemon, @show_back)
                end
                if @show_back
                    @sprites["pokemon"].zoom_x = 2 / 3.0
                    @sprites["pokemon"].zoom_y = 2 / 3.0
                end
            elsif Input.trigger?(Input::BACK)
                pbPlayCloseMenuSE
                break
            elsif Input.trigger?(Input::SPECIAL) && @page_id == :page_skills
                pbPlayDecisionSE
                showAbilityDescription(@pokemon)
            elsif Input.trigger?(Input::SPECIAL) && @page_id == :page_info && @pokemon.shadowPokemon?
                pbPlayDecisionSE
                showShadowDescription(@pokemon)
            elsif Input.trigger?(Input::USE)
                dorefresh = pbPageCustomUse(@page_id)
                if !dorefresh
                    case @page_id
                    when :page_moves
                        pbPlayDecisionSE
                        dorefresh = pbOptions
                    when :page_ribbons
                        pbPlayDecisionSE
                        pbRibbonSelection
                        dorefresh = true
                    else
                        if !@inbattle
                            pbPlayDecisionSE
                            dorefresh = pbOptions
                        end
                    end
                end
            elsif Input.repeat?(Input::UP)
                oldindex = @partyindex
                pbGoToPrevious
                if @partyindex != oldindex
                    pbChangePokemon
                    @ribbonOffset = 0
                    dorefresh = true
                end
            elsif Input.repeat?(Input::DOWN)
                oldindex = @partyindex
                pbGoToNext
                if @partyindex != oldindex
                    pbChangePokemon
                    @ribbonOffset = 0
                    dorefresh = true
                end
            elsif Input.trigger?(Input::JUMPUP) && !@party.is_a?(PokemonBox)
                oldindex = @partyindex
                @partyindex = 0
                if @partyindex != oldindex
                    pbChangePokemon
                    @ribbonOffset = 0
                    dorefresh = true
                end
            elsif Input.trigger?(Input::JUMPDOWN) && !@party.is_a?(PokemonBox)
                oldindex = @partyindex
                @partyindex = @party.length - 1
                if @partyindex != oldindex
                    pbChangePokemon
                    @ribbonOffset = 0
                    dorefresh = true
                end
            elsif Input.repeat?(Input::LEFT)
                oldpage = @page
                numpages = @page_list.length
                @page -= 1
                @page = numpages if @page < 1
                @page = 1 if @page > numpages
                if @page != oldpage
                    pbSEPlay("GUI summary change page")
                    @ribbonOffset = 0
                    dorefresh = true
                end
            elsif Input.repeat?(Input::RIGHT)
                oldpage = @page
                numpages = @page_list.length
                @page += 1
                @page = numpages if @page < 1
                @page = 1 if @page > numpages
                if @page != oldpage
                    pbSEPlay("GUI summary change page")
                    @ribbonOffset = 0
                    dorefresh = true
                end
            end
            @show_back = false if dorefresh
            if !@show_back
                @sprites["pokemon"].zoom_x = 1.0
                @sprites["pokemon"].zoom_y = 1.0
            end
            drawPage(@page) if dorefresh
        end
        return @partyindex
    end
end