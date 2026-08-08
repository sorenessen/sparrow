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
    _git_hint
    _auto_activate_venv
    _open_editor_menu
  }

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
        local sub_choice=""
        if _exists fzf; then
          sub_choice="$(printf "%s\n" \
            "1) Projects root ($PROJECTS_DIR)" \
            "2) AndroidProjects ($PERSONAL_ANDROID_DIR)" \
            | _pick_with_fzf_or_fallback "Personal>")"
          sub_choice="${sub_choice%%)*}"
        else
          echo ""
          echo "Personal Projects:"
          echo "  1) Projects root ($PROJECTS_DIR)"
          echo "  2) AndroidProjects ($PERSONAL_ANDROID_DIR)"
          echo ""
          read "sub_choice?Choose [1-2] (Enter = 1): "
          sub_choice="${sub_choice:-1}"
        fi

        case "$sub_choice" in
          1) _cd_or_warn "$PROJECTS_DIR" && _after_cd ;;
          2) _cd_or_warn "$PERSONAL_ANDROID_DIR" && _after_cd ;;
          *) _cd_or_warn "$PROJECTS_DIR" && _after_cd ;;
        esac
        ;;

      3)
        local sub_choice=""
        local -a calypso_names
        local -a calypso_paths
        local -a calypso_options

        # Existing projects remain available.
        calypso_names=()
        calypso_paths=()

        # Add projects saved through Sparrow.
        if [[ -f "$PILAR_PROJECTS_FILE" ]]; then
          local saved_group=""
          local saved_name=""
          local saved_path=""

          while IFS=$'\t' read -r saved_group saved_name saved_path; do
            [[ "$saved_group" == "Calypso Projects" ]] || continue
            [[ -n "$saved_name" && -n "$saved_path" ]] || continue

            # Don't add the same path twice.
            local already_exists=0
            local existing_path

            for existing_path in "${calypso_paths[@]}"; do
              if [[ "$existing_path" == "$saved_path" ]]; then
                already_exists=1
                break
              fi
            done

            if (( ! already_exists )); then
              calypso_names+=("$saved_name")
              calypso_paths+=("$saved_path")
            fi
          done < "$PILAR_PROJECTS_FILE"
        fi

        # Build the numbered menu.
        local i
        for (( i = 1; i <= ${#calypso_names[@]}; i++ )); do
          calypso_options+=(
            "$i) ${calypso_names[$i]} (${calypso_paths[$i]})"
          )
        done

        if _exists fzf; then
          sub_choice="$(
            printf "%s\n" "${calypso_options[@]}" |
              _pick_with_fzf_or_fallback "Calypso>"
          )"

          sub_choice="${sub_choice%%)*}"
        else
          echo ""
          echo "Calypso Projects:"

          printf "  %s\n" "${calypso_options[@]}"

          echo ""
          read "sub_choice?Choose [1-${#calypso_names[@]}] (Enter = 1): "
          sub_choice="${sub_choice:-1}"
        fi

        if [[ "$sub_choice" == <-> ]] &&
           (( sub_choice >= 1 && sub_choice <= ${#calypso_paths[@]} )); then
          _cd_or_warn "${calypso_paths[$sub_choice]}" && _after_cd
        else
          _cd_or_warn "$CATE_DIR" && _after_cd
        fi
        ;;

      4)
        local sub_choice=""
        if _exists fzf; then
          sub_choice="$(printf "%s\n" \
            "1) AndroidProjects ($RAP_ANDROID_DIR)" \
            "2) R&P root ($RAP_DIR)" \
            | _pick_with_fzf_or_fallback "R&P>")"
          sub_choice="${sub_choice%%)*}"
        else
          echo ""
          echo "Robots & Pencils Projects:"
          echo "  1) AndroidProjects ($RAP_ANDROID_DIR)"
          echo "  2) R&P root ($RAP_DIR)"
          echo ""
          read "sub_choice?Choose [1-2] (Enter = 1): "
          sub_choice="${sub_choice:-1}"
        fi

        case "$sub_choice" in
          1) _cd_or_warn "$RAP_ANDROID_DIR" && _after_cd ;;
          2) _cd_or_warn "$RAP_DIR" && _after_cd ;;
          *) _cd_or_warn "$RAP_ANDROID_DIR" && _after_cd ;;
        esac
        ;;

      *)
        _cd_or_warn "$HOME_DIR" && _after_cd
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
