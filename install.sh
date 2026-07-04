#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { printf "${CYAN}%s${NC}\n" "$*"; }
ok()    { printf "${GREEN}✓ %s${NC}\n" "$*"; }
err()   { printf "${RED}✗ %s${NC}\n" "$*"; }

if [[ "$(uname -m)" != "x86_64" ]]; then
  err "This config is designed for x86_64"
  exit 1
fi

if [[ -z "$(command -v pacman)" ]]; then
  err "This script only supports Arch Linux"
  exit 1
fi

if [[ "$EUID" -eq 0 ]]; then
  err "Do not run as root"
  exit 1
fi

DOTFILES=(
  .bash_logout
  .bash_profile
  .bashrc
  .git-credentials
  .mbsyncrc
  .msmtprc
  .notmuch-config
  .smbcredentials
  .tmux.conf
  .zshrc
)

link_dotfiles() {
  info "Symlinking dotfiles to \$HOME..."

  for f in "${DOTFILES[@]}"; do
    target="$HOME/$f"
    source="$REPO_DIR/$f"

    if [[ ! -e "$source" ]]; then
      err "$f not found in repo, skipping"
      continue
    fi

    if [[ -L "$target" ]]; then
      current="$(readlink "$target")"
      if [[ "$current" == "$source" ]]; then
        ok "$f already linked correctly"
        continue
      fi
      info "Replacing existing symlink for $f"
      rm "$target"
    elif [[ -e "$target" ]]; then
      info "Backing up existing $f to ${f}.bak"
      mv "$target" "${target}.bak"
    fi

    ln -s "$source" "$target"
    ok "Linked $f"
  done
}

install_pacman() {
  info "Installing core packages..."

  local packages=(
    aerc
    alacritty
    bluetui
    brightnessctl
    btop
    cmake
    dconf
    dolphin
    eza
    fastfetch
    ffmpegthumbnailer
    firefox
    fzf
    git
    gnome-calendar
    gnome-control-center
    gtk3
    gtk4
    highlight
    hyprland
    imagemagick
    isync
    kitty
    libsecret
    lua
    lua-language-server
    mediainfo
    mpv
    neovim
    networkmanager
    niri
    nm-connection-editor
    notmuch
    npm
    nvidia-dkms
    nvidia-utils
    odt2txt
    openrgb
    pamixer
    perl
    php
    playerctl
    poppler
    python
    python-pip
    qalculate-gtk
    ranger
    rclone
    ruby
    starship
    swayidle
    swaylock
    systemd
    tmux
    transmission-cli
    trash-cli
    tree-sitter
    ttf-maple-mono
    ttf-nerd-fonts-symbols
    udiskie
    w3m
    waybar
    wireplumber
    wol
    xdg-user-dirs
    xdg-utils
    ydotool
    zoxide
    zsh
    zsh-autosuggestions
    zsh-syntax-highlighting
  )

  sudo pacman -S --needed --noconfirm "${packages[@]}"
  ok "Core packages installed"
}

install_aur() {
  info "Installing AUR packages..."

  run_yay() {
    if command -v yay &>/dev/null; then
      yay -S --needed --noconfirm "$@"
    else
      err "yay not installed. Install it first:"
      err "  git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si"
      return 1
    fi
  }

  run_yay walker
  run_yay wiremix
  run_yay localsend
  run_yay hyprwhspr-bin
  run_yay youtube-webapp-bin
  run_yay tpack

  ok "AUR packages installed"
}

install_cargo() {
  if ! command -v cargo &>/dev/null; then
    info "Installing Rust..."
    sudo pacman -S --needed --noconfirm rustup
    rustup default stable
  fi

  local cargo_pkgs=(nokkvi)
  for pkg in "${cargo_pkgs[@]}"; do
    if ! command -v "$pkg" &>/dev/null; then
      info "Installing $pkg via cargo..."
      cargo install "$pkg"
    else
      ok "$pkg already installed"
    fi
  done
}

install_npm_global() {
  info "Installing global npm packages..."

  if ! command -v opencode &>/dev/null; then
    npm install -g @opencode-ai/plugin
    ok "opencode installed"
  else
    ok "opencode already installed"
  fi

  if ! command -v prettier &>/dev/null; then
    npm install -g prettier
    ok "prettier installed"
  else
    ok "prettier already installed"
  fi
}

setup_tmux() {
  info "Setting up tmux plugins via tpack..."

  if command -v tpack &>/dev/null; then
    tmux new-session -d -s __tpack_install 2>/dev/null || true
    tpack install 2>/dev/null && ok "Tmux plugins installed" || info "Run 'tpack install' inside tmux to install plugins"
    tmux kill-session -t __tpack_install 2>/dev/null || true
  else
    info "tpack not found. Install it with the AUR step above."
  fi
}

setup_neovim() {
  info "Setting up Neovim plugins..."

  nvim --headless "+Lazy! sync" +qa 2>/dev/null && ok "Neovim plugins installed" || info "Run nvim manually to complete plugin setup"

  if command -v mason &>/dev/null; then
    nvim --headless -c 'MasonInstall lua-language-server clangd codelldb debugpy' +qa 2>/dev/null || true
  fi
}

setup_systemd() {
  info "Enabling systemd user services..."

  local services=(
    elephant.service
    mbsync.timer
  )

  for s in "${services[@]}"; do
    if [[ -f "$REPO_DIR/systemd/user/$s" ]]; then
      systemctl --user enable "$s" 2>/dev/null && ok "Enabled $s" || info "Skipped $s (maybe not available)"
    fi
  done

  systemctl --user daemon-reload 2>/dev/null || true
}

change_shell() {
  if [[ "$SHELL" != "/usr/bin/zsh" ]]; then
    info "Changing default shell to zsh..."
    if chsh -s /usr/bin/zsh; then
      ok "Default shell changed to zsh (logout to apply)"
    else
      err "Failed to change shell. Try: chsh -s /usr/bin/zsh"
    fi
  else
    ok "zsh is already the default shell"
  fi
}

install_python_tools() {
  info "Installing Python tools..."
  pip install --user --break-system-packages pygments pynvim 2>/dev/null || \
    pip install --user pygments pynvim
  ok "Python tools installed"
}

main() {
  echo "══════════════════════════════════════════"
  echo "  DotFiles Installer"
  echo "══════════════════════════════════════════"
  echo

  install_pacman
  install_aur
  install_cargo
  install_npm_global
  install_python_tools
  setup_tmux
  setup_neovim
  setup_systemd
  link_dotfiles
  change_shell

  echo
  echo "══════════════════════════════════════════"
  echo "  Done! Restart your shell or log out."
  echo "══════════════════════════════════════════"
}

main "$@"
