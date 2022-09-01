vim9script

import './stargates.vim' as sg
import './galaxies.vim'
import './messages.vim' as msg
import './workstation.vim' as ws

var start_mode: string
var in_visual_mode: bool
var is_hlsearch: bool
const match_paren_enabled = exists(':DoMatchParen') == 2 ? true : false


# `mode` can be positive number or string
# when it is number search for that much consequitive input chars
# when `mode` is string it is regex to search for
export def OkVIM(mode: any)
    try
        Greetings()
        var destinations: dict<any>
        if type(mode) == v:t_number
            g:stargate_mode = true
            destinations = ChooseDestinations(mode)
        else
            g:stargate_mode = false
            [destinations, _] = sg.GetDestinations(mode)
        endif
        if !empty(destinations)
            normal! m'
            if len(destinations) == 1
                msg.BlankMessage()
                cursor(destinations.jump.orbit, destinations.jump.degree)
            else
                UseStargate(destinations)
            endif
        endif
    catch /.*/
        redraw
        execute 'echoerr "' .. v:exception .. '"'
    finally
        Goodbye()
    endtry
enddef


def HideLabels(stargates: dict<any>)
    for v in values(stargates)
        popup_hide(v.id)
    endfor
enddef


def Saturate()
    prop_remove({ type: 'sg_desaturate' }, g:stargate_near, g:stargate_distant)
enddef


def Greetings()
    start_mode = mode()
    in_visual_mode = start_mode != 'n'
    if in_visual_mode
        execute "normal! \<C-c>"
    endif

    [g:stargate_near, g:stargate_distant] = ws.ReachableOrbits()

    is_hlsearch = false
    if v:hlsearch
        is_hlsearch = true
        setwinvar(0, '&hlsearch', 0)
    endif

    if match_paren_enabled
        silent! call matchdelete(3)
    endif

    g:stargate_conceallevel = &conceallevel
    ws.SetScreen()
    msg.StandardMessage(g:stargate_name .. ', choose a destination.')
enddef


def Goodbye()
    for v in values(g:stargate_popups)
        popup_hide(v)
    endfor
    prop_remove({ type: 'sg_error' }, g:stargate_near, g:stargate_distant)
    Saturate()
    ws.ClearScreen()

    # rehighlight matched paren
    doautocmd CursorMoved

    if is_hlsearch
        setwinvar(0, '&hlsearch', 1)
    endif

    if in_visual_mode
        execute 'normal! ' .. start_mode .. '`<o'
    endif
enddef


def ShowFiltered(stargates: dict<any>)
    for [label, stargate] in items(stargates)
        const id = g:stargate_popups[label]
        const scr_pos = screenpos(0, stargate.orbit, stargate.degree)
        popup_move(id, { line: scr_pos.row, col: scr_pos.col })
        popup_setoptions(id, { highlight: stargate.color, zindex: stargate.zindex })
        popup_show(id)
        stargates[label].id = id
    endfor
enddef


def UseStargate(destinations: dict<any>)
    var stargates = copy(destinations)
    msg.StandardMessage('Select a stargate for a jump.')
    while true
        var filtered = {}
        const [nr: number, err: bool] = ws.SafeGetChar()

        if err || nr == 27  # 27 is <Esc>
            msg.BlankMessage()
            return
        endif

        const char = nr2char(nr)
        for [label, stargate] in items(stargates)
            if match(label, char) == 0
                const new_label = strcharpart(label, 1)
                filtered[new_label] = stargate
            endif
        endfor

        if empty(filtered)
            msg.Error('Wrong stargate, ' .. g:stargate_name .. '. Choose another one.')
        elseif len(filtered) == 1
            msg.BlankMessage()
            cursor(filtered[''].orbit, filtered[''].degree)
            return
        else
            HideLabels(stargates)
            ShowFiltered(filtered)
            stargates = copy(filtered)
            msg.StandardMessage('Select a stargate for a jump.')
        endif
    endwhile
enddef


def ChooseDestinations(mode: number): dict<any>
    var to_galaxy = false
    var destinations = {}
    while true
        var nrs = []
        for _ in range(mode)
            const [nr: number, err: bool] = ws.SafeGetChar()

            if err || nr == 27  # 27 is <Esc>
                msg.BlankMessage()
                return {}
            endif

            if nr == 23  # 23 is <C-w>
                to_galaxy = true
                break
            endif

            nrs->add(nr)
        endfor

        if to_galaxy
            to_galaxy = false
            if in_visual_mode || ws.InOperatorPendingMode()
                msg.Error('It is impossible to do now, ' .. g:stargate_name .. '.')
            elseif !galaxies.ChangeGalaxy(false)
                return {}
            endif
            # if current window after the jump is in terminal or insert modes - quit stargate
            if match(mode(), '[ti]') == 0
                msg.InfoMessage("stargate: can't work in terminal or insert mode.")
                return {}
            endif
            continue
        endif

        var error: bool
        [destinations, error] = sg.GetDestinations(nrs
                                                    ->mapnew((_, v) => nr2char(v))
                                                    ->join(''))
        if !error && empty(destinations)
            msg.Error("We can't reach there, " .. g:stargate_name .. '.')
            continue
        endif
        break
    endwhile

    return destinations
enddef

# vim: sw=4
