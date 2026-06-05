eval "$(starship init zsh)"
eval "$(zoxide init zsh)"

j() {
  local arg="$1"
  local result

  # --- 0. cd compatibility ---
  if [[ -z "$arg" ]]; then
    cd ~ || return
    return
  fi

  if [[ "$arg" == "-" ]]; then
    cd - || return
    return
  fi

  # --- 1. explicit path → behave like cd ---
  if [[ "$arg" == /* || "$arg" == .* || "$arg" == */* ]]; then
    cd "$arg" || return
    return
  fi

  # --- 2. choose search base ---
  local base=()
  if [[ "$PWD" == "$HOME" ]]; then
    base=("$HOME/dev" "$HOME/Documents")
  else
    base=(".")
  fi

  # --- 3. fast find ---
  result=$(find "${base[@]}" -maxdepth 4 \
    \( -path "*/.git" -o -path "*/build" -o -path "*/.*" \) -prune -o \
    -type d -iname "*${arg}*" -print \
    2>/dev/null | head -n 1)

  # --- 4. handle result ---
  if [[ -z "$result" ]]; then
    echo "no match"
    return 1
  fi

  cd "$result" || return
}

gcm() {
  git add .

  diff=$(git diff --staged)

  [ -z "$diff" ] && {
    echo "Nothing staged."
    return 1
  }

  msg=$(printf "%s" "$diff" | opencode run "Write a precise conventional commit message. Give a short title (max 72 chars) and a body explaining why. Only describe the provided diff.")

  echo "-----"
  echo "$msg"
  echo "-----"

  git commit -m "$msg"
}

cr() {
  diff=$(git diff --staged)

  [ -z "$diff" ] && {
    echo "Nothing staged to review."
    return 1
  }

  tmp=$(mktemp)

  (
    echo "## Diff"
    printf "%s\n" "$diff"

    echo
    echo "## Files"
    git diff --staged --name-only
  ) | opencode run "
Create a concise code review.

Focus only on:
- bugs
- design flaws
- performance issues

Ignore formatting and minor issues.

STRICT OUTPUT:
- Return ONLY raw HTML BODY CONTENT
- No <html>, <head>, <style>
- No markdown, no code fences

STRUCTURE:
- Summary (short)
- Critical Issues
- Warnings

Each issue:
- title
- short explanation
" \
  | sed '/^```/d' \
  > "$tmp"

  # Inject into fixed template (consistent design)
  cat > codeReview.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Code Review</title>
<style>
body {
  background: #0d1117;
  color: #c9d1d9;
  font-family: system-ui, sans-serif;
  margin: 0;
}
.container {
  max-width: 900px;
  margin: 40px auto;
  padding: 20px;
}
h1, h2 {
  color: #e6edf3;
}
.section {
  margin-top: 30px;
}
.card {
  border: 1px solid #30363d;
  border-left: 4px solid #58a6ff;
  padding: 12px 16px;
  margin: 12px 0;
  border-radius: 6px;
  background: #161b22;
}
.card.critical {
  border-left-color: #f85149;
}
.card.warning {
  border-left-color: #d29922;
}
</style>
</head>
<body>
<div class="container">
<h1>Code Review</h1>

$(cat "$tmp")

</div>
</body>
</html>
EOF

  rm "$tmp"

  echo "Wrote codeReview.html"

  # optional auto-open (linux)
  command -v xdg-open >/dev/null && xdg-open codeReview.html >/dev/null 2>&1 &
}

alias n='nvim'
alias ls='eza -lh'
alias sync-pwd='~/.local/bin/keepass-sync.sh'
alias yay='yay --noconfirm'
alias cd='z'
alias stopSleep='sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target'
alias startSleep='sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target'
alias open='xdg-open'
alias Hwol='wol d8:43:ae:c8:bd:e4'

HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000

setopt APPEND_HISTORY
setopt SHARE_HISTORY

autoload -Uz compinit
compinit

zstyle ':completion:*' menu select
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _ignored _approximate
zstyle ':completion:*' match-original both

zstyle ':completion:*' matcher-list \
  'm:{a-z}={A-Za-z}' \
  'r:|[._-]=* r:|=*'

autoload -Uz colors && colors
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

zstyle ':completion:*' group-name ''
zstyle ':completion:*' format '%F{yellow}%d%f'
zstyle ':completion:*' list-prompt '%SAt %p: Hit TAB for more, or type to filter%s'

zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

source /usr/share/fzf/key-bindings.zsh
source /usr/share/fzf/completion.zsh

export EDITOR=nvim
export VISUAL=nvim

fastfetch
