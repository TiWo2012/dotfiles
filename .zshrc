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

alias ls='eza -lh'
alias sync-pwd='~/.local/bin/keepass-sync.sh'
alias yay='yay --noconfirm'
alias cd='z'
alias stopSleep='sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target'
alias startSleep='sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target'

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
