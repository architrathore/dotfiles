# profiler.zsh -- Lightweight zshrc startup profiler
#
# Usage:
#   1. Set PROFILE_ZSHRC=1 before sourcing this file
#   2. Wrap sections of your zshrc with tick / tock:
#        tick
#        source $ZSH/oh-my-zsh.sh
#        tock "zshrc/oh-my-zsh"
#   3. Call profiler_report at the end of your zshrc
#
# Labels use "group/item" notation. Entries sharing the same group
# prefix are collapsed under a group header in the output table.
# Entries without a "/" go into an "(other)" group.
#
# Configurable thresholds (set before sourcing):
#   PROFILER_WARN_MS  -- yellow highlight (default: 100)
#   PROFILER_SLOW_MS  -- red highlight    (default: 500)

# ── Thresholds (overridable) ────────────────────────────────────────

: ${PROFILER_WARN_MS:=100}
: ${PROFILER_SLOW_MS:=500}

# ── Guard: no-op when profiling is disabled ─────────────────────────

if (( ! PROFILE_ZSHRC )); then
  tick()  { : }
  tock()  { : }
  profiler_report() { : }
  return 0
fi

# ── Initialization ──────────────────────────────────────────────────

zmodload zsh/datetime

typeset -a  _profiler_names _profiler_times
typeset -F  _profiler_start

# ── Public API ──────────────────────────────────────────────────────

tick() {
  _profiler_start=$EPOCHREALTIME
}

tock() {
  _profiler_names+=("$1")
  _profiler_times+=($(( (EPOCHREALTIME - _profiler_start) * 1000 )))
}

# ── Color helpers ───────────────────────────────────────────────────

typeset -A _profiler_colors=(
  [cyan]=$'\e[36m'
  [green]=$'\e[32m'
  [yellow]=$'\e[33m'
  [red]=$'\e[31m'
  [bold]=$'\e[1m'
  [dim]=$'\e[2m'
  [reset]=$'\e[0m'
)

_profiler_color_for_time() {
  local ms_int=${1%.*}
  if (( ms_int > PROFILER_SLOW_MS )); then
    print -n "${_profiler_colors[red]}"
  elif (( ms_int > PROFILER_WARN_MS )); then
    print -n "${_profiler_colors[yellow]}"
  else
    print -n "${_profiler_colors[green]}"
  fi
}

# ── Grouping ────────────────────────────────────────────────────────
# Parses "group/item" labels into parallel arrays for grouped display.
# Entries without "/" are placed in the "(other)" group.

_profiler_group_entries() {
  local other_label="(other)"
  local i name time_ms group item

  # Associative arrays for group aggregation
  typeset -gA _pg_group_times _pg_group_counts
  typeset -ga _pg_group_order _pg_item_groups _pg_item_names _pg_item_times

  _pg_group_times=()
  _pg_group_counts=()
  _pg_group_order=()
  _pg_item_groups=()
  _pg_item_names=()
  _pg_item_times=()

  for i in {1..${#_profiler_names[@]}}; do
    name=${_profiler_names[i]}
    time_ms=${_profiler_times[i]}

    if [[ $name == */* ]]; then
      group=${name%%/*}
      item=${name#*/}
    else
      group=$other_label
      item=$name
    fi

    # First time seeing this group? Register it.
    if [[ -z ${_pg_group_times[$group]} ]]; then
      _pg_group_order+=($group)
      _pg_group_times[$group]=0
      _pg_group_counts[$group]=0
    fi

    (( _pg_group_times[$group] += time_ms ))
    (( _pg_group_counts[$group]++ ))

    _pg_item_groups+=($group)
    _pg_item_names+=($item)
    _pg_item_times+=($time_ms)
  done

  # Sort: push "(other)" to the end
  typeset -ga _pg_sorted_groups=()
  local g
  for g in $_pg_group_order; do
    [[ $g != $other_label ]] && _pg_sorted_groups+=($g)
  done
  [[ -n ${_pg_group_times[$other_label]} ]] && _pg_sorted_groups+=($other_label)
}

# ── Column width calculation ────────────────────────────────────────

_profiler_compute_column_widths() {
  local indent="    "
  _pf_name_width=5
  _pf_time_width=14

  local i g
  for i in {1..${#_pg_item_names[@]}}; do
    local padded_len=$(( ${#indent} + ${#_pg_item_names[i]} ))
    (( padded_len > _pf_name_width )) && _pf_name_width=$padded_len
  done
  for g in $_pg_sorted_groups; do
    # Account for group header: "^ group (count)"
    local header_len=$(( ${#g} + ${#_pg_group_counts[$g]} + 5 ))
    (( header_len > _pf_name_width )) && _pf_name_width=$header_len
  done
}

# ── Table rendering ─────────────────────────────────────────────────

_profiler_hline() {
  local left=$1 mid=$2 right=$3
  local bdr=${_profiler_colors[cyan]} bold=${_profiler_colors[bold]} rst=${_profiler_colors[reset]}
  print "${bdr}${bold}${left}${(l:_pf_name_width+2::─:)}${mid}${(l:_pf_time_width+2::─:)}${right}${rst}"
}

# Draws a full-width title row:  │   <centered text>   │
_profiler_title_row() {
  local text=$1
  local bdr=${_profiler_colors[cyan]} bold=${_profiler_colors[bold]} rst=${_profiler_colors[reset]}
  local inner=$(( _pf_name_width + _pf_time_width + 3 ))
  local pad_l=$(( (inner - ${#text}) / 2 ))
  local pad_r=$(( inner - ${#text} - pad_l ))

  printf "%s│%s %s%*s%s%*s%s %s│%s\n" \
    "$bdr" "$rst" \
    "$bold" $pad_l "" "$text" $pad_r "" \
    "$rst" "$bdr" "$rst"
}

# Draws one table row:  │ <name> │ <value> │
# Arguments: <name> <name_style> <value> <value_style>
_profiler_row() {
  local name=$1 name_style=$2 value=$3 value_style=$4
  local bdr=${_profiler_colors[cyan]} rst=${_profiler_colors[reset]}

  printf "%s│%s %s%-*s%s %s│%s %s%*s%s %s│%s\n" \
    "$bdr" "$rst" \
    "$name_style" $_pf_name_width "$name" "$rst" \
    "$bdr" "$rst" \
    "$value_style" $_pf_time_width "$value" "$rst" \
    "$bdr" "$rst"
}

# Formats milliseconds as a right-aligned string: "  123.45 ms"
_profiler_fmt_time() {
  printf "%*.2f ms" $((_pf_time_width - 3)) "$1"
}

_profiler_render_table() {
  local bold=${_profiler_colors[bold]}
  local dim=${_profiler_colors[dim]}

  # Compute total
  local total=0 t
  for t in $_profiler_times; do (( total += t )); done

  # Title
  local title="ZSHRC PROFILING RESULTS"

  print
  _profiler_hline "┌" "─" "┐"
  _profiler_title_row "$title"
  _profiler_hline "├" "┬" "┤"
  _profiler_row "Block" "$bold" "Time (ms)" "$bold"
  _profiler_hline "├" "┼" "┤"

  # Data rows
  local g i tc
  for g in $_pg_sorted_groups; do
    tc=$(_profiler_color_for_time "${_pg_group_times[$g]}")

    _profiler_row \
      "^ ${g} (${_pg_group_counts[$g]})" "${bold}${tc}" \
      "$(_profiler_fmt_time "${_pg_group_times[$g]}")" "${bold}${tc}"

    for i in {1..${#_pg_item_groups[@]}}; do
      if [[ ${_pg_item_groups[i]} == $g ]]; then
        tc=$(_profiler_color_for_time "${_pg_item_times[i]}")

        _profiler_row \
          "    ${_pg_item_names[i]}" "$dim" \
          "$(_profiler_fmt_time "${_pg_item_times[i]}")" "$tc"
      fi
    done
  done

  # Footer
  _profiler_hline "├" "┼" "┤"
  _profiler_row "TOTAL" "$bold" "$(_profiler_fmt_time "$total")" "$bold"
  _profiler_hline "└" "┴" "┘"
  print
}

# ── Main entry point ────────────────────────────────────────────────

profiler_report() {
  _profiler_group_entries
  _profiler_compute_column_widths
  _profiler_render_table
}
