#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ffmpeg_wrap.sh last-frame <input_video> [output_image]
  ffmpeg_wrap.sh stitch <clip1> <clip2> [output_video]

Commands:
  last-frame   Extract the exact final frame from a video.
               Default output: <input_basename>_lastframe.png

  stitch       Concatenate two clips in order.
               Default output: stitched_<clip1>_<clip2>.mp4
               Uses stream copy first; falls back to H.264/AAC re-encode if needed.
EOF
}

require_ffmpeg() {
  if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "Error: ffmpeg not found in PATH." >&2
    exit 1
  fi
  if ! command -v ffprobe >/dev/null 2>&1; then
    echo "Error: ffprobe not found in PATH." >&2
    exit 1
  fi
}

require_file() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "Error: file not found: $f" >&2
    exit 1
  fi
}

default_last_frame_name() {
  local input="$1"
  local base
  base="$(basename "$input")"
  base="${base%.*}"
  echo "${base}_lastframe.png"
}

default_stitch_name() {
  local a="$1"
  local b="$2"
  local a_base b_base
  a_base="$(basename "${a%.*}")"
  b_base="$(basename "${b%.*}")"
  echo "stitched_${a_base}_${b_base}.mp4"
}

extract_last_frame() {
  local input="$1"
  local output="${2:-$(default_last_frame_name "$input")}"
  require_file "$input"

  rm -f "$output"

  # Precise path: count frames, then extract exact last frame index (n = total-1).
  local total_frames
  total_frames="$(ffprobe -v error -select_streams v:0 -count_frames \
    -show_entries stream=nb_read_frames -of default=nokey=1:noprint_wrappers=1 "$input" \
    | tr -d '\r' | tail -n 1)"

  if [[ "$total_frames" =~ ^[0-9]+$ ]] && [[ "$total_frames" -gt 0 ]]; then
    local last_index=$((total_frames - 1))
    ffmpeg -hide_banner -loglevel error -y \
      -i "$input" \
      -vf "select=eq(n\\,$last_index)" \
      -vsync vfr \
      -frames:v 1 \
      "$output" || true
  fi

  # Fallback 1: seek near end (fast, but not always exact).
  if [[ ! -s "$output" ]]; then
    ffmpeg -hide_banner -loglevel error -y \
      -sseof -1 \
      -i "$input" \
      -frames:v 1 \
      "$output" || true
  fi

  # Fallback 2: reverse stream and grab first frame (slow but reliable).
  if [[ ! -s "$output" ]]; then
    ffmpeg -hide_banner -loglevel error -y \
      -i "$input" \
      -vf reverse \
      -frames:v 1 \
      "$output"
  fi

  if [[ ! -s "$output" ]]; then
    echo "Error: failed to extract last frame from: $input" >&2
    exit 1
  fi

  echo "Saved last frame: $output"
}

stitch_two() {
  local clip1="$1"
  local clip2="$2"
  local output="${3:-$(default_stitch_name "$clip1" "$clip2")}"
  require_file "$clip1"
  require_file "$clip2"

  local list_file
  list_file="$(mktemp)"
  trap "rm -f '$list_file'" EXIT

  # Absolute paths are safest for ffmpeg concat demuxer.
  printf "file '%s'\nfile '%s'\n" "$(realpath "$clip1")" "$(realpath "$clip2")" >"$list_file"

  if ffmpeg -hide_banner -loglevel error -y \
      -f concat -safe 0 -i "$list_file" -c copy "$output"; then
    echo "Stitched (stream copy): $output"
    return
  fi

  echo "Stream-copy failed, re-encoding..." >&2
  ffmpeg -hide_banner -loglevel error -y \
    -f concat -safe 0 -i "$list_file" \
    -c:v libx264 -preset slow -crf 18 \
    -c:a aac -b:a 192k \
    "$output"
  echo "Stitched (re-encoded): $output"
}

main() {
  if [[ $# -lt 1 ]]; then
    usage
    exit 1
  fi

  local cmd="$1"
  shift

  case "$cmd" in
    last-frame)
      if [[ $# -lt 1 || $# -gt 2 ]]; then
        usage
        exit 1
      fi
      require_ffmpeg
      extract_last_frame "$@"
      ;;
    stitch)
      if [[ $# -lt 2 || $# -gt 3 ]]; then
        usage
        exit 1
      fi
      require_ffmpeg
      stitch_two "$@"
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      echo "Error: unknown command: $cmd" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
