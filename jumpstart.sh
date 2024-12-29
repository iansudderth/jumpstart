(
  main() {

    BASEDIR=${0:a:h}
    green "running from  $BASEDIR"

    # install the basics
    blue "installing shell basics"
    apt-install-if-not "curl"
    apt-install-if-not "wget"
    apt-install-if-not "git"
    apt-install-if-not "zsh"
    apt-install-if-not "nano"
    apt-install-if-not "rsync"

    # setup the zsh shell
    install-oh-my-zsh

    # shell utils
    apt-install-if-not "yazi"
    # TODO: add updated fzf for ubuntu since apt has an older version
    apt-install-if-not "fzf"
    apt-install-if-not "atuin"
    apt-install-if-not "zoxide"
    apt-install-if-not "starship"
    apt-install-if-not "eza"
    apt-install-if-not "entr"
    apt-install-if-not "micro"

    # these are funky cause the package name and bins are named different
    apt-install-if-not-alias "neovim" "nvim"
    apt-install-if-not-alias "bat" "batcat"

    # TODO: Python
    # both system level and pynv please
    # TODO: Poetry
    install-python

    # the fuck gets installed after python
    install-thefuck

    # TODO: Just
    # TODO: Go
    # TODO: Rust
    # TODO: JS - node, npm, yran, volta, deno
    #
    # TODO: Docker, kubernetes, k9s, lazydocker
    #
    # TODO: rest of the dotfiles

    # TODO: zellij - needs rust

    # setup-github
    #
    # TODO: Setup gitignore scripts
    #
    # TODO: next steps cmd?  Next step scripts?
    #
    # TODO: Break out zsh files into paths and funcs and aliases?
    # Would let us load them into the scripts easier...
    #
    # TODO: git-extras
    # TODO: Dasht & Zeal?
    # also the man-db thing and tldr and cache everything
    #
    # TODO: CSV, JSON, YAML, Argo etc
    #
    # TODO: Dust
    # TODO: aerc
    #
    # TODO: Add arch, fedora and mac versions
    # TODO: host in a repo with a readme and an autorun command that we can copy and paste

    # TODO: interactive options selection? How hard would this be to implement?  Needs option to skip
    # TODO: maybe there's some sort of parsing utility?
    setup-dotfiles
    source $HOME/.zshrc
  }

  setup-github() {
    blue "setting up github"
    # TODO: make this idempotic
    apt-install-if-not "gh"

    if gh auth status | grep -q "Logged in"; then
      green "github is logged in"
    else
      blue "logging into github"
      gh auth login
    fi
  }

  install-python() {
    # TODO: make these idempotic
    blue "installing global python packages"

    sudo apt update
    sudo apt install -y python3-dev python3-pip python3-setuptools

    if -d $HOME/.pyenv/; then
      green "pyenv installed"
    else
      blue "installing pyenv"
      curl https://pyenv.run | bash
    fi

    blue "installing pyenv dependencies"
    sudo apt update
    sudo apt install -y build-essential libssl-dev zlib1g-dev \
      libbz2-dev libreadline-dev libsqlite3-dev curl git \
      libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

    blue "activating pyenv environment"
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path)"

    blue "activating pyenv"
    # TODO: parameterize this
    pyenv install -s 3.12
    pyenv install -s 3.11
    pyenv global 3.12 3.11

    blue "installing pipx"
    apt-install-if-not "pipx"
  }

  install-thefuck() {
    blue "installing thefuck"
    blue "activating pyenv"
    eval "$(pyenv init --path)"
    pipx install thefuck --python python3.11
  }

  setup-bash-config() {

  }

  install-oh-my-zsh() {
    blue "installing oh-my-zsh"

    # yellow "deleting old .oh-my-zsh folder"
    # rm -rf $HOME/.oh-my-zsh/

    export RUNZSH=no
    export ZSH="$HOME/.oh-my-zsh/"
    # get the base                              r
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

    # add autocomplete
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

  }

  setup-dotfiles() {
    blue "setting up dotfiles"

    # TODO: global gitignore
    # TODO: global gitconfig
    temp_dir=$(mktemp -d)
    blue "temp dir is $temp_dir"

    blue "cloning dotfiles"
    git clone https://github.com/iansudderth/dotfiles.git "$temp_dir/dotfiles"

    blue "merging dotfiles"
    rsync -avh --progress "$temp_dir/dotfiles/" "$HOME/"

    # blue "copying .zshrc from $temp_dir/dotfiles/.zshrc to $HOME/.zshrc"
    # cp "$temp_dir/dotfiles/.zshrc" "$HOME/.zshrc"

    blue "cleaning up"
    rm -rf "$temp_dir"

    green "dotfile setup complete"
  }

  has-cmd() {
    command -v $1 2>&1 >/dev/null
  }

  needs_app() {
    blue "checking if need $1"
    if has-cmd $1; then
      green "$1 is already installed!"
      return 1
    else
      yellow "$1 is not installed, installing now...."
      return 0
    fi
  }

  apt-install-if-not() {
    needs_app "$1" && sudo apt install -y "$1"
  }

  apt-install-if-not-alias() {
    needs_app "$2" && sudo apt install -y "$1"
  }

  # Colors for pretty printing
  # a simple library for easily outputting colored text to the screen.
  NC='\033[0m' # No Color
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  # YELLOW='\E[0;33m'
  YELLOW='\033[0;33m'
  BLACK='\033[0;47m'
  BLUE='\033[0;34m'
  MAGENTA='\033[0;35m'
  CYAN='\033[0;36m'
  WHITE='\033[0;37m'

  color() {
    if (($# < 2)); then
      echo "need to call color() with a color and text"
    else
      echo -e "${2}$1${NC}"
    fi
  }

  green() {
    color "$1" "$GREEN"
  }

  red() {
    color "$1" "$RED"
  }

  yellow() {
    color "$1" "$YELLOW"
  }
  black() {
    color "$1" "$BLACK"
  }
  blue() {
    color "$1" "$BLUE"
  }
  magenta() {
    color "$1" "$MAGENTA"
  }
  cyan() {
    color "$1" "$CYAN"
  }
  white() {
    color "$1" "$WHITE"
  }

  main
  source "$HOME/.zshrc"
)
