#!/usr/bin/env bash
set -euo pipefail
HOST="${1:-*}"      # hosts/<HOST>/* 아래를 대상으로
KEEP="${2:-30}"     # 보존 개수
TYPE="${3:-full}"   # full | lite | all
DRY="${DRY:-0}"
base="hosts/${HOST}"
shopt -s nullglob
candidates=()
for d in ${base}/* ; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  case "$TYPE" in
    full) [[ "$name" == *-FULL* ]] || continue ;;
    lite) [[ "$name" == *-FULL* ]] && continue ;;
    all)  : ;;
    *) echo "TYPE must be: full | lite | all" >&2; exit 2 ;;
  esac
  candidates+=("$d")
done
IFS=$'\n' read -r -d '' -a sorted < <(printf '%s\n' "${candidates[@]}" | sort && printf '\0')
count="${#sorted[@]}"
[ "$count" -le "$KEEP" ] && { echo "[prune-old] nothing to delete (count=$count <= keep=$KEEP)"; exit 0; }
let del_count="count-KEEP"
to_delete=("${sorted[@]:0:del_count}")
echo "[prune-old] host=${HOST} type=${TYPE} keep=${KEEP} total=${count} delete=${#to_delete[@]}"
printf ' - %s\n' "${to_delete[@]}"
[ "$DRY" = "1" ] && { echo "[prune-old] DRY RUN (no deletion)"; exit 0; }
for d in "${to_delete[@]}"; do rm -rf -- "$d"; done
echo "[prune-old] done"
