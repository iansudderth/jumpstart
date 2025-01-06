FROM archlinux/archlinux:base-devel


WORKDIR /home/root/
ENV HOME=/home/root

RUN pacman -Syu --needed --noconfirm \
  git \
  zsh \
  zsh-autosuggestions \
  zsh-completions \
  wget \
  curl \
  nano \
  rsync \
  zoxide \
  fzf \
  eza \
  entr \
  micro \
  just \
  bat \
  neovim \
  python \
  pyenv \
  go \
  rust \
  unzip \
  zoxide \
  yazi \
  docker \
  k9s \
  kubectl \
  minikube \
  helm \
  lazygit \
  thefuck \
  starship \
  atuin \
  deno \
  neofetch \
  ripgrep \
  zellij

# makepkg user and workdir
ARG user=makepkg
RUN useradd --system --create-home $user \
  && echo "$user ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/$user
USER $user
WORKDIR /home/$user
ENV HOME=/home/$user
# Install yay
RUN git clone https://aur.archlinux.org/yay.git \
  && cd yay \
  && makepkg -sri --needed --noconfirm \
  && cd \
  # Clean up
  && rm -rf .cache yay


# Install any yay packages here before we switch back to root
RUN yay -Syu --noconfirm aur/lazydocker aur/volta-bin


# Reset to root and do the rest
USER root
WORKDIR /home/root/
ENV HOME=/home/root

# ohmyzsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

#autocomplete plugin
RUN	git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# dotfiles
RUN	git clone https://github.com/iansudderth/dotfiles.git "/tmp/dotfiles"

RUN rsync -avh --progress "/tmp/dotfiles/" "$HOME/"

# setting up python
RUN pyenv install 3.12 && pyenv global 3.12

# setting up volta
RUN volta install node@lts

# change shell to zsh
RUN chsh -s $(which zsh)
ENV SHELL=zsh 

ENTRYPOINT [ "zsh" ]
