# ComfyUI helper.
comfy() {
  local comfy_dir
  comfy_dir="$(dot_repo_dir ComfyUI)" || {
    echo "Repo not found: ComfyUI"
    return 1
  }

  local comfy_venv="$comfy_dir/venv/bin/activate"
  local comfy_port="${COMFY_PORT:-8188}"
  local comfy_host="${COMFY_HOST:-0.0.0.0}"
  local comfy_pidfile="$comfy_dir/.comfy.pid"
  local comfy_log="$comfy_dir/user/comfy-launch.log"
  local cmd="${1:-restart}"

  _comfy_find_pids() {
    pgrep -af "main.py --listen .* --port $comfy_port" | awk '$0 !~ /pgrep -af/ {print $1}'
  }

  _comfy_stop() {
    if [[ -f "$comfy_pidfile" ]]; then
      local pid
      pid="$(cat "$comfy_pidfile" 2>/dev/null)"
      if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null
        sleep 1
      fi
      rm -f "$comfy_pidfile"
    fi

    local pids
    pids="$(_comfy_find_pids)"
    if [[ -n "$pids" ]]; then
      echo "$pids" | xargs -r kill 2>/dev/null || true
      sleep 1
      pids="$(_comfy_find_pids)"
      if [[ -n "$pids" ]]; then
        echo "$pids" | xargs -r kill -9 2>/dev/null || true
      fi
    fi
  }

  case "$cmd" in
    start|restart)
      _comfy_stop
      (
        cd "$comfy_dir" || exit 1
        source "$comfy_venv"
        nohup python main.py --listen "$comfy_host" --port "$comfy_port" >"$comfy_log" 2>&1 &
        echo $! >"$comfy_pidfile"
      )
      echo "ComfyUI ${cmd}ed on http://$comfy_host:$comfy_port"
      echo "Log: $comfy_log"
      ;;
    stop)
      _comfy_stop
      echo "ComfyUI stopped"
      ;;
    status)
      if [[ -f "$comfy_pidfile" ]] && kill -0 "$(cat "$comfy_pidfile" 2>/dev/null)" 2>/dev/null; then
        echo "ComfyUI running (pid $(cat "$comfy_pidfile")) on http://$comfy_host:$comfy_port"
      elif [[ -n "$(_comfy_find_pids)" ]]; then
        echo "ComfyUI running on port $comfy_port (orphan pid(s): $(_comfy_find_pids | tr '\n' ' '))"
      else
        echo "ComfyUI is not running"
      fi
      ;;
    logs)
      tail -n 80 "$comfy_log"
      ;;
    *)
      echo "Usage: comfy {start|restart|stop|status|logs}"
      return 1
      ;;
  esac
}

aim() {
  local repo
  repo="$(dot_repo_dir CENTRAL)" || {
    echo "Repo not found: CENTRAL"
    return 1
  }
  "$repo/scripts/aim_control.py" "$@"
}

dispatcher() {
  local repo
  repo="$(dot_repo_dir CENTRAL)" || {
    echo "Repo not found: CENTRAL"
    return 1
  }
  "$repo/scripts/dispatcher_control.py" "$@"
}

i2v_legacy() {
  local comfy_dir
  comfy_dir="$(dot_repo_dir ComfyUI)" || {
    echo "Repo not found: ComfyUI"
    return 1
  }

  "$comfy_dir/script_examples/batch_i2v_from_folder.py" \
    --randomize-seed \
    --wait \
    --profile medium \
    --template-api "$comfy_dir/user/workflows/wan22_enhancedH_q5L_2stage_gguf_vertical_ctxwindow2.api.json" \
    "$@"
}

i2v_single_legacy() {
  local comfy_dir
  comfy_dir="$(dot_repo_dir ComfyUI)" || {
    echo "Repo not found: ComfyUI"
    return 1
  }

  "$comfy_dir/script_examples/batch_i2v_from_folder.py" \
    --randomize-seed \
    --wait \
    --profile medium \
    --template-api "$comfy_dir/user/workflows/wan22_enhancedH_q5L_2stage_gguf_vertical.medium.api.json" \
    "$@"
}

gallery() {
  local wall_repo
  wall_repo="$(dot_repo_dir video_wall)" || {
    echo "Repo not found: video_wall"
    return 1
  }

  local comfy_dir
  comfy_dir="$(dot_repo_dir ComfyUI)" || comfy_dir="$HOME/ComfyUI"

  local port="8000"
  local -a video_roots=(
    "$HOME/output/amazing/best"
    "$comfy_dir/output/upscaled_best"
    "$comfy_dir/output/video/auto_batch"
  )
  local preview_seconds="${GALLERY_PREVIEW_SECONDS:-3.2}"
  local preview_fps="${GALLERY_PREVIEW_FPS:-16}"
  local preview_width="${GALLERY_PREVIEW_WIDTH:-280}"
  local preview_quality="${GALLERY_PREVIEW_QUALITY:-58}"
  local preview_time="${GALLERY_PREVIEW_TIME:-00:00:00.30}"

  if [[ -n "$VIDEO_WALL_ROOTS" ]]; then
    video_roots=("${(@s:,:)VIDEO_WALL_ROOTS}")
  elif [[ -n "$VIDEO_WALL_ROOT" ]]; then
    video_roots=("$VIDEO_WALL_ROOT")
  fi

  if [[ "$1" =~ ^[0-9]+$ ]]; then
    port="$1"
    shift
  fi

  if [[ "$#" -gt 0 ]]; then
    video_roots=("$@")
  fi

  local root
  for root in "${video_roots[@]}"; do
    if [[ ! -d "$root" ]]; then
      echo "Gallery root does not exist: $root"
      return 1
    fi
  done

  "$wall_repo/build_gallery.py" \
    --url-mode http \
    --roots "${video_roots[@]}" \
    --preview-seconds "$preview_seconds" \
    --preview-fps "$preview_fps" \
    --preview-width "$preview_width" \
    --preview-quality "$preview_quality" \
    --preview-time "$preview_time" || return $?

  local server_root="${wall_repo:h}"
  local relative_url="${wall_repo:t}/gallery.html"
  local ip
  ip="$(dot_primary_ip)"

  echo "Serving gallery..."
  echo "Video roots:"
  for root in "${video_roots[@]}"; do
    echo "  - $root"
  done
  echo "Preview profile:    ${preview_seconds}s @ ${preview_fps}fps, ${preview_width}px, q${preview_quality}"
  echo "Primary URL:        http://${ip}:${port}/${relative_url}"
  echo "Local URL:          http://127.0.0.1:${port}/${relative_url}"

  dot_open_url "http://${ip}:${port}/${relative_url}" || true

  local -a existing_pids
  existing_pids=("${(@f)$(pgrep -f "python3 -m http.server ${port} --bind 0.0.0.0" 2>/dev/null)}")
  if (( ${#existing_pids[@]} )); then
    echo "Restarting existing gallery server on port ${port}..."
    kill "${existing_pids[@]}" 2>/dev/null || true
    sleep 0.4
  else
    echo "Starting gallery server on port ${port}..."
  fi

  echo "Press Ctrl+C to stop."
  (cd "$server_root" && python3 -m http.server "$port" --bind 0.0.0.0)
}

gallery_http() {
  gallery "$@"
}

gallery_file() {
  [[ "$MY_PLATFORM" == "wsl" ]] || {
    echo "gallery_file is only supported on WSL."
    return 1
  }

  local wall_repo
  wall_repo="$(dot_repo_dir video_wall)" || {
    echo "Repo not found: video_wall"
    return 1
  }

  local comfy_dir
  comfy_dir="$(dot_repo_dir ComfyUI)" || comfy_dir="$HOME/ComfyUI"

  local -a video_roots=(
    "$HOME/output/amazing/best"
    "$comfy_dir/output/upscaled_best"
    "$comfy_dir/output/video/auto_batch"
  )
  local preview_seconds="${GALLERY_PREVIEW_SECONDS:-3.2}"
  local preview_fps="${GALLERY_PREVIEW_FPS:-10}"
  local preview_width="${GALLERY_PREVIEW_WIDTH:-280}"
  local preview_quality="${GALLERY_PREVIEW_QUALITY:-58}"
  local preview_time="${GALLERY_PREVIEW_TIME:-00:00:00.30}"

  if [[ -n "$VIDEO_WALL_ROOTS" ]]; then
    video_roots=("${(@s:,:)VIDEO_WALL_ROOTS}")
  elif [[ -n "$VIDEO_WALL_ROOT" ]]; then
    video_roots=("$VIDEO_WALL_ROOT")
  fi

  if [[ "$#" -gt 0 ]]; then
    video_roots=("$@")
  fi

  local root
  for root in "${video_roots[@]}"; do
    if [[ ! -d "$root" ]]; then
      echo "Gallery root does not exist: $root"
      return 1
    fi
  done

  "$wall_repo/build_gallery.py" \
    --url-mode wsl \
    --roots "${video_roots[@]}" \
    --preview-seconds "$preview_seconds" \
    --preview-fps "$preview_fps" \
    --preview-width "$preview_width" \
    --preview-quality "$preview_quality" \
    --preview-time "$preview_time" || return $?

  local distro="${WSL_DISTRO_NAME:-Ubuntu}"
  local url="file://wsl.localhost/${distro}${wall_repo}/gallery.html"

  echo "Gallery: $url"
  echo "Video roots:"
  for root in "${video_roots[@]}"; do
    echo "  - $root"
  done
  echo "Preview profile: ${preview_seconds}s @ ${preview_fps}fps, ${preview_width}px, q${preview_quality}"
  dot_open_url "$url" || true
}

comfy-run() {
  local repo
  repo="$(dot_repo_dir video_queue)" || {
    echo "Repo not found: video_queue"
    return 1
  }
  "$repo/venv/bin/python" "$repo/cli.py" "$@"
}

alias queue-status="comfy-run status"
alias queue-cancel="comfy-run cancel"
alias queue-retry="comfy-run retry"
alias i2v="comfy-run submit --workflow wan-context-2stage"
alias i2v-lite="comfy-run submit --workflow wan-context-lite-2stage"

queue() {
  local root
  root="$(dot_repo_dir video_queue)" || {
    echo "Repo not found: video_queue"
    return 1
  }

  local port="${1:-8585}"
  local host="0.0.0.0"
  local url="http://127.0.0.1:${port}"

  (
    cd "$root" || exit 1
    pkill -f "uvicorn app:app --host ${host} --port ${port}" >/dev/null 2>&1 || true
    pkill -f "$root/run.sh" >/dev/null 2>&1 || true
    if command -v setsid >/dev/null 2>&1; then
      setsid -f env PORT="$port" ./run.sh >/tmp/video_queue.log 2>&1 < /dev/null
    else
      PORT="$port" nohup ./run.sh >/tmp/video_queue.log 2>&1 < /dev/null &!
    fi
  )

  local ok=0
  local i
  for i in {1..20}; do
    if curl -fsS "${url}/api/health" >/tmp/video_queue_health.json 2>/dev/null; then
      ok=1
      break
    fi
    sleep 0.3
  done

  echo "Queue UI: ${url}"
  if (( ok )); then
    curl -fsS -X POST "${url}/api/reload/workflows" >/tmp/video_queue_reload_workflows.json 2>/dev/null || true
    curl -fsS -X POST "${url}/api/reload/loras" >/tmp/video_queue_reload_loras.json 2>/dev/null || true
    local proc
    proc="$(ps -eo pid,lstart,cmd | grep -m1 -E "uvicorn app:app --host ${host} --port ${port}" || true)"
    if [[ -n "$proc" ]]; then
      echo "Process: $proc"
    fi
    echo -n "Health: "
    cat /tmp/video_queue_health.json
    echo
  else
    echo "Health: unavailable (check /tmp/video_queue.log)"
  fi

  dot_open_url "${url}" || true
}

queue_restart() {
  local root
  root="$(dot_repo_dir video_queue)" || {
    echo "Repo not found: video_queue"
    return 1
  }

  local port="${1:-8585}"
  pkill -f "$root/run.sh" >/dev/null 2>&1 || true
  pkill -f "uvicorn app:app --host 0.0.0.0 --port ${port}" >/dev/null 2>&1 || true
  sleep 1
  queue "${port}"
}

alias queue-restart="queue_restart"

upscale() {
  local comfy_dir
  comfy_dir="$(dot_repo_dir ComfyUI)" || {
    echo "Repo not found: ComfyUI"
    return 1
  }
  "$comfy_dir/script_examples/upscale" "$@"
}

vapp() {
  local repo
  repo="$(dot_repo_dir unified_video_app)" || {
    echo "Repo not found: unified_video_app"
    return 1
  }

  cd "$repo" || return 1

  if [[ -f ".venv/bin/activate" ]]; then
    source .venv/bin/activate
  fi

  echo "Starting Unified Video App..."
  echo "Frontend: http://127.0.0.1:5173"
  echo "Backend API: http://127.0.0.1:8080"

  ./run.sh
}

vapp-open() {
  dot_open_url "http://127.0.0.1:5173" || true
  dot_open_url "http://127.0.0.1:8080" || true
}

genflow() {
  local repo
  repo="$(dot_repo_dir photo_auto_tagging)" || {
    echo "Repo not found: photo_auto_tagging"
    return 1
  }

  local venv_activate="$repo/.venv/bin/activate"
  local python_cmd="$repo/.venv/bin/python"

  if [[ ! -x "$python_cmd" ]]; then
    echo "Python not found at: $python_cmd"
    echo "Expected virtualenv at: $repo/.venv"
    return 1
  fi

  (
    cd "$repo" || exit 1
    source "$venv_activate" || exit 1
    if [[ $# -eq 0 ]]; then
      "$python_cmd" -m genflow.cli ui --port 8888
      return
    fi
    if [[ "$1" =~ ^[0-9]+$ ]]; then
      "$python_cmd" -m genflow.cli ui --port "$1"
      return
    fi
    "$python_cmd" -m genflow.cli "$@"
  )
}

pq() {
  local repo
  repo="$(dot_repo_dir photo_auto_tagging)" || {
    echo "Repo not found: photo_auto_tagging"
    return 1
  }

  local pq_bin="$repo/.venv/bin/pq"
  local port_default="10024"

  if [[ ! -x "$pq_bin" ]]; then
    echo "pq binary not found at: $pq_bin"
    return 1
  fi

  _pq_find_ui_pids() {
    pgrep -af "(/\\.venv/bin/pq ui|photoquery\\.cli\\.main ui)" | awk '$0 !~ /pgrep -af/ {print $1}'
  }

  _pq_stop_ui() {
    local pids
    pids="$(_pq_find_ui_pids)"
    if [[ -n "$pids" ]]; then
      echo "$pids" | xargs -r kill 2>/dev/null || true
      sleep 1
      pids="$(_pq_find_ui_pids)"
      if [[ -n "$pids" ]]; then
        echo "$pids" | xargs -r kill -9 2>/dev/null || true
      fi
    fi
  }

  if [[ "$1" == "stop" ]]; then
    _pq_stop_ui
    rm -f /tmp/pq_ui.pid
    echo "PhotoQuery UI stopped"
    return 0
  fi

  if [[ $# -eq 0 || "$1" =~ ^[0-9]+$ ]]; then
    local port="${1:-$port_default}"
    local log="/tmp/pq_ui_${port}.log"
    local ready_url="http://127.0.0.1:${port}/api/status"

    _pq_stop_ui
    cd "$repo" || return 1
    PHOTOQUERY_HF_ALLOW_DOWNLOAD=0 PHOTOQUERY_UI_PREWARM=0 HF_HUB_OFFLINE=1 TRANSFORMERS_OFFLINE=1 \
      nohup "$pq_bin" ui --port "$port" >"$log" 2>&1 < /dev/null &!

    local pid
    sleep 0.3
    pid="$(pgrep -n -f "/\\.venv/bin/pq ui --port ${port}")"
    if [[ -n "$pid" ]]; then
      echo "$pid" >/tmp/pq_ui.pid
    fi

    local ok=0
    local i
    for i in {1..240}; do
      if curl -fsS "$ready_url" >/dev/null 2>&1; then
        ok=1
        break
      fi
      sleep 0.25
    done

    if (( ok )); then
      echo "PhotoQuery UI restarted on http://127.0.0.1:${port}"
      echo "V2: http://127.0.0.1:${port}/v2/"
      echo "Log: $log"
      return 0
    fi

    echo "PhotoQuery UI did not become ready on port ${port} within 60s"
    echo "Log: $log"
    tail -n 80 "$log" 2>/dev/null || true
    return 1
  fi

  (
    cd "$repo" || exit 1
    "$pq_bin" "$@"
  )
}

queue_v2() {
  local root
  root="$(dot_repo_dir video_queue)" || {
    echo "Repo not found: video_queue"
    return 1
  }

  local cli_py="$root/cli.py"
  local python_bin="$root/venv/bin/python"
  local port_default="8585"

  if [[ ! -x "$python_bin" ]]; then
    echo "python not found at: $python_bin"
    return 1
  fi
  if [[ ! -f "$cli_py" ]]; then
    echo "queue cli not found at: $cli_py"
    return 1
  fi

  _queue_v2_find_ui_pids() {
    pgrep -af "($root/run\\.sh|uvicorn app:app --host 0\\.0\\.0\\.0 --port )" | awk '$0 !~ /pgrep -af/ {print $1}'
  }

  _queue_v2_stop_ui() {
    local pids
    pids="$(_queue_v2_find_ui_pids)"
    if [[ -n "$pids" ]]; then
      echo "$pids" | xargs -r kill 2>/dev/null || true
      sleep 1
      pids="$(_queue_v2_find_ui_pids)"
      if [[ -n "$pids" ]]; then
        echo "$pids" | xargs -r kill -9 2>/dev/null || true
      fi
    fi
  }

  if [[ "$1" == "stop" ]]; then
    _queue_v2_stop_ui
    rm -f /tmp/queue_v2_ui.pid
    echo "Video Queue UI stopped"
    return 0
  fi

  if [[ $# -eq 0 || "$1" =~ ^[0-9]+$ ]]; then
    local port="${1:-$port_default}"
    local log="/tmp/queue_v2_ui_${port}.log"
    local ready_url="http://127.0.0.1:${port}/api/health"
    local open_url="http://127.0.0.1:${port}/v2"

    _queue_v2_stop_ui
    (
      cd "$root" || exit 1
      if command -v setsid >/dev/null 2>&1; then
        setsid -f env PORT="$port" ./run.sh >"$log" 2>&1 < /dev/null
      else
        PORT="$port" nohup ./run.sh >"$log" 2>&1 < /dev/null &!
      fi
    )

    local pid
    sleep 0.3
    pid="$(pgrep -n -f "uvicorn app:app --host 0.0.0.0 --port ${port}")"
    if [[ -n "$pid" ]]; then
      echo "$pid" >/tmp/queue_v2_ui.pid
    fi

    local ok=0
    local i
    for i in {1..80}; do
      if curl -fsS "$ready_url" >/dev/null 2>&1; then
        ok=1
        break
      fi
      sleep 0.25
    done

    if (( ok )); then
      echo "Video Queue UI restarted on http://127.0.0.1:${port}"
      echo "V2: http://127.0.0.1:${port}/v2"
      echo "Legacy: http://127.0.0.1:${port}/"
      echo "Log: $log"
      dot_open_url "$open_url" || true
      return 0
    fi

    echo "Video Queue UI did not become ready on port ${port} within 20s"
    echo "Log: $log"
    tail -n 80 "$log" 2>/dev/null || true
    return 1
  fi

  (
    cd "$root" || exit 1
    "$python_bin" "$cli_py" "$@"
  )
}
