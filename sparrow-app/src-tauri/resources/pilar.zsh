# --- pilar prompt menu (iTerm2 / zsh) --------------------------------
# Runs once per tab/window. Uses fzf for arrow-key UI if available.
[[ -o interactive ]] || return

if [[ -z "${pilar_MENU_SHOWN:-}" ]]; then
  export pilar_MENU_SHOWN=1

  # Paths (adjust ONLY if your folder names differ)
  HOME_DIR="$HOME"

  PROJECTS_DIR="$HOME/Projects"
  PERSONAL_ANDROID_DIR="$HOME/AndroidStudioProjects"

  PILAR_PROJECTS_FILE="$HOME/.config/sparrow/pilar-projects.tsv"

  RAP_DIR="$HOME/RobotsAndPencils"
  RAP_ANDROID_DIR="$RAP_DIR/AndroidStudioProjects"

  autoload -Uz add-zsh-hook

  _exists() { command -v "$1" >/dev/null 2>&1; }

  _cd_or_warn() {
    local target="$1"
    if [[ -d "$target" ]]; then
      cd "$target" || return 1
      return 0
    else
      echo "Missing directory: $target"
      return 1
    fi
  }

  _git_hint() {
    if _exists git && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      local branch
      branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)"
      if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
        echo "git: $branch (dirty)"
      else
        echo "git: $branch (clean)"
      fi
    fi
  }

  _auto_activate_venv() {
    local venv=""
    [[ -f ".venv/bin/activate" ]] && venv=".venv"
    [[ -z "$venv" && -f "venv/bin/activate" ]] && venv="venv"
    [[ -z "$venv" && -f "env/bin/activate" ]] && venv="env"

    if [[ -n "$venv" ]]; then
      if [[ -z "${VIRTUAL_ENV:-}" || "$VIRTUAL_ENV" != "$(pwd)/$venv" ]]; then
        source "$venv/bin/activate"
        echo "venv: activated $venv"
      fi
    fi
  }

  _open_editor_menu() {
    echo ""

    # If fzf exists, use it (arrow keys + type-to-filter)
    if _exists fzf; then
      local pick
      pick="$(printf "%s\n" \
        "1) No" \
        "2) VS Code (code .)" \
        "3) Android Studio (open -a \"Android Studio\" .)" \
        "4) Sublime Text (open -a \"Sublime Text\" .)" \
        | fzf --prompt="Editor> " --height=10 --border --reverse)"

      # If they hit ESC, fzf returns empty. Treat that as "No".
      [[ -z "$pick" ]] && return 0

      case "${pick%%)*}" in
        1) return 0 ;;
        2)
          if _exists code; then
            code .
          else
            echo "VS Code CLI not found (but you already fixed this, so this should be rare)."
          fi
          ;;
        3)
          open -a "Android Studio" . >/dev/null 2>&1 || echo "Couldn't open Android Studio."
          ;;
        4)
          open -a "Sublime Text" . >/dev/null 2>&1 || echo "Couldn't open Sublime Text."
          ;;
      esac
      return 0
    fi

    # Fallback (no fzf): numbered prompt
    echo "Open in editor?"
    echo "  1) No"
    echo "  2) VS Code (code .)"
    echo "  3) Android Studio (open -a \"Android Studio\" .)"
    echo "  4) Sublime Text (open -a \"Sublime Text\" .)"
    echo ""

    local e
    read "e?Choose [1-4] (Enter = 1): "
    e="${e:-1}"

    case "$e" in
      1) ;;
      2)
        if _exists code; then
          code .
        else
          echo "VS Code CLI not found."
        fi
        ;;
      3)
        open -a "Android Studio" . >/dev/null 2>&1 || echo "Couldn't open Android Studio."
        ;;
      4)
        open -a "Sublime Text" . >/dev/null 2>&1 || echo "Couldn't open Sublime Text."
        ;;
      *) ;;
    esac
  }


  _after_cd() {
    _update_sparrow_current_project

    _git_hint
    _auto_activate_venv
    _open_editor_menu
  }

  _update_sparrow_current_project() {
    mkdir -p "$HOME/.config/sparrow"
    pwd > "$HOME/.config/sparrow/current-project"
  }

  add-zsh-hook chpwd _update_sparrow_current_project

  _pick_with_fzf_or_fallback() {
    # args: prompt, newline-separated options on stdin
    local prompt="$1"
    if _exists fzf; then
      fzf --prompt="$prompt " --height=12 --border --reverse
    else
      # no fzf: just echo back (caller will do numbered menu)
      cat
    fi
  }

  _open_pilar_project_group() {
    local group_name="$1"
    local prompt_name="$2"

    local sub_choice=""
    local -a project_names
    local -a project_paths
    local -a project_options

    project_names=()
    project_paths=()
    project_options=()

    if [[ -f "$PILAR_PROJECTS_FILE" ]]; then
      local saved_group=""
      local saved_name=""
      local saved_path=""

      while IFS=$'\t' read -r saved_group saved_name saved_path; do
        [[ "$saved_group" == "$group_name" ]] || continue
        [[ -n "$saved_name" && -n "$saved_path" ]] || continue

        local already_exists=0
        local existing_path

        for existing_path in "${project_paths[@]}"; do
          if [[ "$existing_path" == "$saved_path" ]]; then
            already_exists=1
            break
          fi
        done

        if (( ! already_exists )); then
          project_names+=("$saved_name")
          project_paths+=("$saved_path")
        fi
      done < "$PILAR_PROJECTS_FILE"
    fi

    if (( ${#project_names[@]} == 0 )); then
      echo ""
      echo "No projects saved in $group_name."
      echo ""
      return 0
    fi

    local i
    local marker=""

    for (( i = 1; i <= ${#project_names[@]}; i++ )); do
      local project_name="${project_names[$i]}"
      local project_path="${project_paths[$i]}"
      local marker="🪹"

      if [[ -f "$project_path/sparrow.toml" ]]; then
        marker="🪺"
      fi

      project_options+=(
        "$i|$marker   $project_name ($project_path)"
      )
    done

    if _exists fzf; then
      sub_choice="$(
        printf "%s\n" "${project_options[@]}" |
          fzf \
            --prompt="$prompt_name> " \
            --height=12 \
            --border \
            --reverse \
            --delimiter='|' \
            --with-nth=2 \
            --color='bg+:-1,fg+:-1,hl+:bold'
      )"

      [[ -z "$sub_choice" ]] && return 0

      sub_choice="${sub_choice%%|*}"
  
    else
      echo ""
      echo "$group_name:"

      printf "  %s\n" "${project_options[@]}"

      echo ""
      read "sub_choice?Choose [1-${#project_names[@]}]: "
    fi

    if [[ "$sub_choice" == <-> ]] &&
       (( sub_choice >= 1 && sub_choice <= ${#project_paths[@]} )); then
      _cd_or_warn "${project_paths[$sub_choice]}" && _after_cd
    fi
  }

  function _pilar_menu_prompt() {
    add-zsh-hook -d precmd _pilar_menu_prompt

    # ---------------- Main pilar selection ----------------
    local main_choice=""
    if _exists fzf; then
      main_choice="$(printf "%s\n" \
        "1) Home directory (no project)" \
        "2) Personal Projects" \
        "3) Calypso Projects" \
        "4) Robots & Pencils Projects" \
        | _pick_with_fzf_or_fallback "pilar>")"
      # Extract leading number if present
      main_choice="${main_choice%%)*}"
    else
      echo ""
      echo "Which pilar are we working on?"
      echo "  1) Home directory (no project)"
      echo "  2) Personal Projects"
      echo "  3) Calypso Projects"
      echo "  4) Robots & Pencils Projects"
      echo ""
      read "main_choice?Choose [1-4] (Enter = 1): "
      main_choice="${main_choice:-1}"
    fi

    case "$main_choice" in
      1)
        _cd_or_warn "$HOME_DIR" && _after_cd
        ;;

      2)
        _open_pilar_project_group \
          "Personal Projects" \
          "Personal"
        ;;

      3)
        _open_pilar_project_group \
          "Calypso Projects" \
          "Calypso"
        ;;

      4)
        _open_pilar_project_group \
          "Robots & Pencils Projects" \
          "R&P"
        ;;
    esac
  }

  add-zsh-hook precmd _pilar_menu_prompt
fi
# ----------------------------------------------------------------------
# Reset to main menu
alias pilar='unset pilar_MENU_SHOWN; exec zsh'
alias zshconfig='open -a "Sublime Text" ~/.zshrc'


source "$HOME/.cargo/env"
export PS2='dquote> '
export TERM=xterm-256color
