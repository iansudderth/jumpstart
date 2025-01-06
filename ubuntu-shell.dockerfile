FROM ubuntu:24.10

# set this since it's not set by default
ENV HOME=/home/ubuntu 

# install curl, git and zsh
RUN apt-get update && apt-get install -y \
  curl \
  git \
  zsh \
  wget \
  nano \
  rsync \
  zoxide \
  fzf \
  eza \
  entr \
  micro \
  just \
  bat \
  build-essential \
  neovim \
  python3-dev \
  python3-pip \
  python3-setuptools \
  build-essential \
  libssl-dev \
  zlib1g-dev \
  libbz2-dev \
  libreadline-dev \
  libsqlite3-dev \
  libncursesw5-dev \
  xz-utils \
  tk-dev \
  libxml2-dev \
  libxmlsec1-dev \
  libffi-dev \
  liblzma-dev \
  pipx \
  unzip \
  kubernetes \
  ca-certificates 

RUN install -m 0755 -d /etc/apt/keyrings

RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc

RUN chmod a+r /etc/apt/keyrings/docker.asc

RUN echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# TODO: zellij

#on ubuntu bat gets installed as catbat to avoid name conflicts
RUN	mkdir -p ~/.local/bin
RUN	ln -s /usr/bin/batcat ~/.local/bin/bat

# ohmyzsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

#autocomplete plugin
RUN	git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# install startship
RUN curl -sS https://starship.rs/install.sh | sh -s -- -y

# install rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# need to set the environment
ENV  PATH="$HOME/.cargo/bin:${PATH}"

RUN rustup update

# install yazi
RUN cargo install --locked yazi-fm yazi-cli

RUN curl https://pyenv.run | bash


ENV PYENV_ROOT="$HOME/.pyenv"
ENV PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims/:$PATH"
RUN eval "$(pyenv init --path)"

RUN pyenv install -s 3.12
RUN pyenv install -s 3.11
RUN pyenv global 3.12 3.11


RUN eval "$(pyenv init --path)"

RUN pipx install thefuck --python python3.11

RUN	git clone https://github.com/iansudderth/dotfiles.git "/tmp/dotfiles"

RUN rsync -avh --progress "/tmp/dotfiles/" "$HOME/"

RUN	curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh

ENV VOLTA_HOME="$HOME/.volta"
ENV PATH="$VOLTA_HOME/bin:$PATH"

RUN curl https://get.volta.sh | bash

RUN volta install node@lts

RUN curl -fsSL https://deno.land/install.sh | sh

RUN curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

WORKDIR /home/ubuntu

ENTRYPOINT ["zsh"]

