"=============================================================================
" File: sky_color_clock.vim
" Author: mopp
" Created: 2018-01-18
"=============================================================================

scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim



function! s:default_color_stops(timestamp) abort
    let sunset_time_from_noon = s:get_sunset_time_from_noon(a:timestamp)
    let sunrise = 12 - sunset_time_from_noon
    let sunset = 12 + sunset_time_from_noon
    return [
                \ [sunrise - 2.0,          "#111111"],
                \ [sunrise - 1.5,          "#4d548a"],
                \ [sunrise - 1.0,          "#c486b1"],
                \ [sunrise - 0.5,          "#ee88a0"],
                \ [sunrise,                "#ff7d75"],
                \ [sunrise + 0.5,          "#f4eeef"],
                \ [(sunset + sunrise) / 2, "#5dc9f1"],
                \ [sunset - 1.5,           "#9eefe0"],
                \ [sunset - 1.0,           "#f1e17c"],
                \ [sunset - 0.5,           "#f86b10"],
                \ [sunset,                 "#100028"],
                \ [sunset + 0.5,           "#111111"],
                \ ]
endfunction


" degrees = radian * 180 / pi.
function! s:rad_to_deg(r) abort
    return a:r * 180.0 / s:pi
endfunction


" radian = degrees * pi / 180.
function! s:deg_to_rad(d) abort
    return a:d * s:pi / 180.0
endfunction


function! s:get_sunset_time_from_noon(timestamp) abort
    let current_year   = str2nr(strftime('%Y', a:timestamp))
    let leap_count     = count(map(range(1970, current_year - 1), 'v:val % 400 == 0 || (v:val % 4 == 0 && v:val % 100 != 0)'), 1)
    let day_of_year    = float2nr(a:timestamp / (24 * 60 * 60)) % 365 - leap_count - 1

    let latitude = g:sky_color_clock#latitude
    let sun_declination = s:deg_to_rad(-23.44 * (cos(s:deg_to_rad((360 / 365.0) * (day_of_year + 10)))))
    let sunset_hour_angle = acos(-1 * tan(s:deg_to_rad(latitude) * tan(sun_declination)))
    return 24.0 * (s:rad_to_deg(sunset_hour_angle) / 360.0)
endfunction


" https://github.com/Qix-/color-convert/blob/427cbb70540bb9e5b3e94aa3bb9f97957ee5fbc0/conversions.js#L555-L580
" [float] -> number.
function! s:to_ansi256_color(rgb) abort
    let r = float2nr(255.0 * a:rgb[0])
    let g = float2nr(255.0 * a:rgb[1])
    let b = float2nr(255.0 * a:rgb[2])

    if (r == g) && (g == b)
        if (r < 8)
            return 16
        elseif (248 < r)
            return 231
        else
            return float2nr(round(((r - 8.0) / 247.0) * 24.0) + 232.0)
        endif
    endif

    " 16 + 36 × r + 6 × g + b (0 ≤ r, g, b ≤ 5)
    " https://stackoverflow.com/a/39277954
    let ansi256 = 16 +
                \ 36 * (round(r / 255.0 * 5)) +
                \  6 * (round(g / 255.0 * 5)) +
                \       round(b / 255.0 * 5)

    return float2nr(ansi256)
endfunction


" https://stackoverflow.com/questions/2353211/hsl-to-rgb-color-conversion
" [float] -> [float].
function! s:rgb_to_hsl(rgb) abort
    let max = 0.0
    let min = 1.0
    for c in a:rgb
        if max < c
            let max = c
        endif
        if c < min
            let min = c
        endif
    endfor

    let l = (max + min) / 2.0
    let delta = max - min

    if abs(delta) <= 1.0e-10
        return [0.0, 0.0, l]
    endif

    let s = (l <= 0.5) ? (delta / (max + min)) : (delta / (2.0 - max - min))

    let [r, g, b] = a:rgb
    let rc = (max - r) / delta
    let gc = (max - g) / delta
    let bc = (max - b) / delta

    if max == r
        let h = bc - gc
    elseif max == g
        let h = 2.0 + rc - bc
    else
        let h = 4.0 + gc - rc
    endif

    let h = fmod(h / 6.0, 1.0)

    if h < 0.0
        let h = 1.0 + h
    endif

    return [h, s, l]
endfunction


function! s:hue_to_rgb(p, q, t) abort
    let t = a:t
    if 1.0 < a:t
        let t = a:t - 1.0
    elseif a:t < 0.0
        let t = a:t + 1.0
    endi

    if (t < 1.0 / 6.0) | return a:p + (a:q - a:p) * 6.0 * t | endif
    if (t < 1.0 / 2.0) | return a:q | endif
    if (t < 2.0 / 3.0) | return a:p + (a:q - a:p) * (2.0 / 3.0 - t) * 6.0 | endif

    return a:p
endfunction


function! s:hsl_to_rgb(hsl) abort
    let [h, s, l] = a:hsl

    let q = l <= 0.5 ? l * (1.0 + s) : l + s - l * s
    let p = 2.0 * l - q
    let r = s:hue_to_rgb(p, q, h + 1.0 / 3.0)
    let g = s:hue_to_rgb(p, q, h)
    let b = s:hue_to_rgb(p, q, h - 1.0 / 3.0)

    return [r, g, b]
endfunction


" https://hail2u.net/blog/software/convert-hex-color-to-functional-color-with-vim.html
" (string) -> [float].
function! s:parse_rgb(rgb) abort
    let rgb = matchlist(a:rgb, '\([0-9A-F]\{2\}\)\([0-9A-F]\{2\}\)\([0-9A-F]\{2\}\)')[1:3]
    return map(rgb, 'str2nr(v:val, 16) / 255.0')
endfunction


" (float, float, float) -> string.
function! s:to_rgb_string(rgb) abort
    let [r, g, b] = a:rgb
    let r = float2nr(ceil(r * 255.0))
    let g = float2nr(ceil(g * 255.0))
    let b = float2nr(ceil(b * 255.0))
    return printf('#%02x%02x%02x', r, g, b)
endfunction


" (string, string, float) -> string.
function! s:blend_color(base_color, mix_color, fraction) abort
    let x = a:fraction == 0.0 ? 0.5 : a:fraction
    let y = 1.0 - x

    let [r1, g1, b1] = s:parse_rgb(a:base_color)
    let [r2, g2, b2] = s:parse_rgb(a:mix_color)

    let r = (r1 * y) + (r2 * x)
    let g = (g1 * y) + (g2 * x)
    let b = (b1 * y) + (b2 * x)

    return s:to_rgb_string([r, g, b])
endfunction


function! s:make_gradient(color_stops, time) abort
    let [sec, min, hour] = split(strftime('%S,%M,%H', a:time), ',')
    let m = sec / 60.0
    let h = (m + min) / 60.0
    let x = h + hour

    let first_color = a:color_stops[0]
    if x <= first_color[0]
        return first_color[1]
    endif

    let last_color = a:color_stops[0]
    for next_color in a:color_stops
        if x <= next_color[0]
            let fraction = ((x - last_color[0]) / (next_color[0] - last_color[0]))
            return s:blend_color(last_color[1], next_color[1], fraction)
        endif
        let last_color = next_color
    endfor

    return a:color_stops[-1][1]
endfunction


function! s:pick_bg_color(timestamp) abort
    return s:make_gradient(g:sky_color_clock#color_stops, a:timestamp)
endfunction


function! s:pick_fg_color(bg_color) abort
    let [h, s, l] = s:rgb_to_hsl(s:parse_rgb(a:bg_color))
    let new_l = l + (0.5 < l ? -0.55 : 0.55)
    let new_l = (new_l < 0.0) ? 0.0 : new_l
    let new_l = (1.0 < new_l) ? 1.0 : new_l

    return s:to_rgb_string(s:hsl_to_rgb([h, s, new_l]))
endfunction


function! s:get_emoji_moonphase(timestamp) abort
    let time_in_days = a:timestamp / (24.0 * 60.0 * 60.0)
    let current_phase = fmod(time_in_days - s:new_moon_base_timestamp, s:moonphase_cycle)

    for [phase, emoji] in s:moonphase_emojis
        if current_phase <= phase
            return emoji
        endif
    endfor

    return s:moonphase_emojis[-1][1]
endfunction


function! s:get_sky_colors(timestamp) abort
    let bg = s:pick_bg_color(a:timestamp)
    let fg = s:pick_fg_color(bg)

    " Convert the RGB string into ANSI 256 color.
    let bg_t = s:to_ansi256_color(s:parse_rgb(bg))
    let fg_t = s:to_ansi256_color(s:parse_rgb(fg))

    return [fg, bg, fg_t, bg_t]
endfunction


function! sky_color_clock#statusline() abort
    let now = get(g:, 'sky_color_clock#timestamp_force_override', localtime())

    let [fg, bg, fg_t, bg_t] = s:get_sky_colors(now)

    " Update highlight.
    execute printf('hi SkyColorClock guifg=%s guibg=%s ctermfg=%d ctermbg=%d ', fg, bg, fg_t, bg_t)

    let str = strftime(g:sky_color_clock#datetime_format, now)

    if g:sky_color_clock#enable_emoji_icon != 0
        let str = printf("%s %s", s:get_emoji_moonphase(now), str)
    endif

    return str
endfunction


function! sky_color_clock#preview() abort
    let now = localtime()
    let base_timestamp = (now - (now % (24 * 60 * 60))) - (9 * 60 * 60)

    tabnew
    syntax clear

    let cnt = 0
    let last_colors = s:get_sky_colors(base_timestamp)
    for h in range(0, 23)
        for m in range(0, 55, 5)
            let t = base_timestamp + (h * 60 * 60) + (m * 60)

            let colors = s:get_sky_colors(t)

            if last_colors == colors
                continue
            endif

            let last_colors = colors
            let [fg, bg, fg_t, bg_t] = colors
            let str = strftime(g:sky_color_clock#datetime_format, t)

            call append(cnt, str)

            let group_name = printf('SkyColorClockPreview%d', cnt)
            execute printf('hi %s guifg=%s guibg=%s ctermfg=%d ctermbg=%d', group_name, fg, bg, fg_t, bg_t)
            execute printf('syntax keyword %s %s', group_name, escape(str, ' '))
            execute printf('syntax match %s /%s/', group_name, escape(str, ' '))

            let cnt += 1
        endfor
    endfor
endfunction


" Local immutable variables.
let s:pi = 3.14159265359
let s:moonphase_cycle = 29.5306 " Eclipse (synodic month) cycle in days.
let s:new_moon_base_timestamp = 6.8576 " A new moon (1970/01/08 05:35) in days since the epoch.
let s:moonphase_emojis = [
            \ [ 1.84, '🌑'],
            \ [ 5.53, '🌒'],
            \ [ 9.22, '🌓'],
            \ [12.91, '🌔'],
            \ [16.61, '🌕'],
            \ [20.30, '🌖'],
            \ [23.99, '🌗'],
            \ [27.68, '🌘'],
            \ ]

let g:sky_color_clock#latitude          = get(g:, 'sky_color_clock#latitude', 35)
let g:sky_color_clock#color_stops       = get(g:, 'sky_color_clock#color_stops', s:default_color_stops(localtime()))
let g:sky_color_clock#datetime_format   = get(g:, 'sky_color_clock#datetime_format', '%d %H:%M')
let g:sky_color_clock#enable_emoji_icon = get(g:, 'sky_color_clock#enable_emoji_icon', has('mac'))


let s:enable_test = 0
if s:enable_test
    call assert_equal('#000000', s:to_rgb_string(s:hsl_to_rgb([0.0, 0.0, 0.0])))
    call assert_equal('#ffffff', s:to_rgb_string(s:hsl_to_rgb([0.0, 0.0, 1.0])))
    call assert_equal('#ff0000', s:to_rgb_string(s:hsl_to_rgb([0.0, 1.0, 0.5])))
    call assert_equal('#00ff00', s:to_rgb_string(s:hsl_to_rgb([120.0 / 360.0, 1.0, 0.5])))
    call assert_equal('#0000ff', s:to_rgb_string(s:hsl_to_rgb([240.0 / 360.0, 1.0, 0.5])))
    call assert_equal('#ffff00', s:to_rgb_string(s:hsl_to_rgb([60.0 / 360.0, 1.0, 0.5])))
    call assert_equal('#00ffff', s:to_rgb_string(s:hsl_to_rgb([180.0 / 360.0, 1.0, 0.5])))
    call assert_equal('#ff00ff', s:to_rgb_string(s:hsl_to_rgb([300.0 / 360.0, 1.0, 0.5])))
    call assert_equal('#c0c0c0', s:to_rgb_string(s:hsl_to_rgb([0.0, 0.0, 0.75])))
    call assert_equal('#808080', s:to_rgb_string(s:hsl_to_rgb([0.0, 0.0, 0.50])))
    call assert_equal('#800000', s:to_rgb_string(s:hsl_to_rgb([0.0, 1.0, 0.25])))
    call assert_equal('#808000', s:to_rgb_string(s:hsl_to_rgb([60.0 / 360.0, 1.0, 0.25])))
    call assert_equal('#008000', s:to_rgb_string(s:hsl_to_rgb([120.0 / 360.0, 1.0, 0.25])))
    call assert_equal('#800080', s:to_rgb_string(s:hsl_to_rgb([300.0 / 360.0, 1.0, 0.25])))
    call assert_equal('#008080', s:to_rgb_string(s:hsl_to_rgb([180.0 / 360.0, 1.0, 0.25])))
    call assert_equal('#000080', s:to_rgb_string(s:hsl_to_rgb([240.0 / 360.0, 1.0, 0.25])))

    " call assert_equal([0.0,           0.0, 0.00], s:rgb_to_hsl(s:parse_rgb('#000000')))
    " call assert_equal([0.0,           0.0, 1.00], s:rgb_to_hsl(s:parse_rgb('#ffffff')))
    " call assert_equal([0.0,           1.0, 0.50], s:rgb_to_hsl(s:parse_rgb('#ff0000')))
    " call assert_equal([120.0 / 360.0, 1.0, 0.50], s:rgb_to_hsl(s:parse_rgb('#00ff00')))
    " call assert_equal([240.0 / 360.0, 1.0, 0.50], s:rgb_to_hsl(s:parse_rgb('#0000ff')))
    " call assert_equal([60.0 / 360.0,  1.0, 0.50], s:rgb_to_hsl(s:parse_rgb('#ffff00')))
    " call assert_equal([180.0 / 360.0, 1.0, 0.50], s:rgb_to_hsl(s:parse_rgb('#00ffff')))
    " call assert_equal([300.0 / 360.0, 1.0, 0.50], s:rgb_to_hsl(s:parse_rgb('#ff00ff')))
    " call assert_equal([0.0,           0.0, 0.75], s:rgb_to_hsl(s:parse_rgb('#c0c0c0')))
    " call assert_equal([0.0,           0.0, 0.50], s:rgb_to_hsl(s:parse_rgb('#808080')))
    " call assert_equal([0.0,           1.0, 0.25], s:rgb_to_hsl(s:parse_rgb('#800000')))
    " call assert_equal([60.0 / 360.0,  1.0, 0.25], s:rgb_to_hsl(s:parse_rgb('#808000')))
    " call assert_equal([120.0 / 360.0, 1.0, 0.25], s:rgb_to_hsl(s:parse_rgb('#008000')))
    " call assert_equal([300.0 / 360.0, 1.0, 0.25], s:rgb_to_hsl(s:parse_rgb('#800080')))
    " call assert_equal([180.0 / 360.0, 1.0, 0.25], s:rgb_to_hsl(s:parse_rgb('#008080')))
    " call assert_equal([240.0 / 360.0, 1.0, 0.25], s:rgb_to_hsl(s:parse_rgb('#000080')))

    call assert_equal('🌑', s:get_emoji_moonphase(592500))
    call assert_equal('🌑', s:get_emoji_moonphase(1516155430))
    call assert_equal('🌓', s:get_emoji_moonphase(1516846630))

    if !empty(v:errors)
        for err in v:errors
            echoerr string(err)
        endfor
    endif
endif


let &cpo = s:save_cpo
unlet s:save_cpo
