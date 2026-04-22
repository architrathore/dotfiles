#!/bin/bash
input=$(cat)
model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // empty')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')

ESC=$'\033'
BOLD="${ESC}[1m"
DIM="${ESC}[2m"
ITALIC="${ESC}[3m"
RESET="${ESC}[0m"

c256() { printf '%s[38;5;%dm' "$ESC" "$1"; }

PURPLE=$(c256 141)
CYAN=$(c256 87)
WHITE=$(c256 255)
BLUE=$(c256 75)
GREEN=$(c256 114)
ORANGE=$(c256 215)
PINK=$(c256 213)
GOLD=$(c256 220)

gradient_color() {
  local pos=$1 total=$2
  local pct=$(( pos * 100 / total ))
  if [ "$pct" -lt 20 ]; then c256 46
  elif [ "$pct" -lt 35 ]; then c256 48
  elif [ "$pct" -lt 50 ]; then c256 50
  elif [ "$pct" -lt 60 ]; then c256 86
  elif [ "$pct" -lt 70 ]; then c256 226
  elif [ "$pct" -lt 80 ]; then c256 214
  elif [ "$pct" -lt 90 ]; then c256 202
  else c256 196
  fi
}

pct_color() {
  local p=$1
  if [ "$p" -lt 30 ]; then c256 48
  elif [ "$p" -lt 60 ]; then c256 86
  elif [ "$p" -lt 80 ]; then c256 226
  elif [ "$p" -lt 90 ]; then c256 214
  else c256 196
  fi
}

fmt_tokens() {
  local val="$1"
  if [ -z "$val" ] || [ "$val" = "null" ] || [ "$val" = "0" ]; then return; fi
  if [ "$val" -ge 1000000 ] 2>/dev/null; then
    awk "BEGIN{printf \"%.1fM\", $val/1000000}"
  elif [ "$val" -ge 1000 ] 2>/dev/null; then
    awk "BEGIN{v=$val/1000; if(v==int(v)) printf \"%dk\",v; else printf \"%.1fk\",v}"
  else
    echo "$val"
  fi
}

fmt_cost() {
  local val="$1"
  if [ -z "$val" ] || [ "$val" = "null" ]; then return; fi
  awk "BEGIN{v=$val; if(v<0.01) printf \"<1c\"; else if(v<1) printf \"%.0fc\",v*100; else printf \"\$%.2f\",v}"
}

model_icon() {
  case "$1" in
    *Opus*)   printf "👑" ;;
    *Sonnet*) printf "🎵" ;;
    *Haiku*)  printf "🌸" ;;
    *)        printf "🤖" ;;
  esac
}

if [ -n "$used" ]; then
  used_int=$(printf '%.0f' "$used")
  bar_width=30
  filled=$(( used_int * bar_width / 100 ))
  empty=$(( bar_width - filled ))

  icon=$(model_icon "$model")

  bar_filled=""
  i=0
  while [ $i -lt $filled ]; do
    col=$(gradient_color $i $bar_width)
    bar_filled="${bar_filled}${col}━"
    i=$(( i + 1 ))
  done

  bar_tip=""
  if [ "$filled" -gt 0 ] && [ "$filled" -lt "$bar_width" ]; then
    tip_col=$(gradient_color $filled $bar_width)
    bar_tip="${tip_col}╸${RESET}"
    empty=$(( empty - 1 ))
  fi

  bar_empty=""
  i=0
  while [ $i -lt $empty ]; do
    bar_empty="${bar_empty}╌"
    i=$(( i + 1 ))
  done

  pc=$(pct_color "$used_int")

  in_fmt=$(fmt_tokens "$total_in")
  out_fmt=$(fmt_tokens "$total_out")
  cr_fmt=$(fmt_tokens "$cache_read")
  cost_fmt=$(fmt_cost "$cost")

  token_parts=""
  if [ -n "$in_fmt" ]; then
    token_parts="${BLUE}↓${RESET}${DIM}${in_fmt}${RESET}"
  fi
  if [ -n "$out_fmt" ]; then
    token_parts="${token_parts} ${GREEN}↑${RESET}${DIM}${out_fmt}${RESET}"
  fi
  if [ -n "$cr_fmt" ]; then
    token_parts="${token_parts} ${PINK}♻${RESET}${DIM}${cr_fmt}${RESET}"
  fi
  if [ -n "$cost_fmt" ]; then
    token_parts="${token_parts}  ${GOLD}💰${RESET}${DIM}${cost_fmt}${RESET}"
  fi

  total_fmt=$(fmt_tokens "$ctx_size")

  printf '%s %s%s%s  %s%s%s%s%s%s%s%s%s%s%s%s  %s%s%d%%%s  %s  %sctx:%s%s%s\n' \
    "$icon" "$BOLD" "$PURPLE" "$model" \
    "$RESET" "$DIM" "$WHITE" "⟨" "$RESET" "$bar_filled" "$bar_tip" "$DIM" "$bar_empty" \
    "$DIM" "$WHITE" "⟩" \
    "$BOLD" "$pc" "$used_int" "$RESET" \
    "$token_parts" "$DIM" "$CYAN" "$total_fmt" "$RESET"
else
  icon=$(model_icon "$model")
  printf '%s %s%s%s%s  %s%sready%s\n' \
    "$icon" "$BOLD" "$PURPLE" "$model" "$RESET" "$DIM" "$ITALIC" "$RESET"
fi
