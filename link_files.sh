#!/usr/bin/env bash
set -u

DOTFILE_DIR=/home/max/Projects/dotfiles
HOME_DIR=$(eval echo ~$USER)

if [ ! -d "$DOTFILE_DIR" ]; then
    echo "Cannot locate dotfiles repo"
    exit 1
fi


# Link SSH config.
if [ -d ${HOME_DIR}/.ssh ]; then
    echo "Linking SSH config..."
    ln -sf ${DOTFILE_DIR}/.ssh/config ${HOME_DIR}/.ssh/config
else
    echo "Skipping SSH config..."
fi

# Link bash configs.
if [ -f ${DOTFILE_DIR}/.bash_aliases ]; then
    echo "Linking bash aliases..."
    ln -sf ${DOTFILE_DIR}/.bash_aliases ${HOME_DIR}/.bash_aliases
else
    echo "Skipping bash aliases..."
fi

if [ -f ${DOTFILE_DIR}/.bash_profile ]; then
    echo "Linking bash profile..."
    ln -sf ${DOTFILE_DIR}/.bash_profile ${HOME_DIR}/.bash_profile
else
    echo "Skipping bash profile..."
fi

if [ -f ${DOTFILE_DIR}/.bashrc ]; then
    echo "Linking bashrc..."
    ln -sf ${DOTFILE_DIR}/.bashrc ${HOME_DIR}/.bashrc
else
    echo "Skipping bashrc..."
fi

# Link zsh configs.
if [ -f ${DOTFILE_DIR}/.zprofile ]; then
    echo "Linking zprofile..."
    ln -sf ${DOTFILE_DIR}/.zprofile ${HOME_DIR}/.zprofile
else
    echo "Skipping zprofile..."
fi

if [ -f ${DOTFILE_DIR}/.zshrc ]; then
    echo "Linking zshrc..."
    ln -sf ${DOTFILE_DIR}/.zshrc ${HOME_DIR}/.zshrc
else
    echo "Skipping zshrc..."
fi

# Link git configs.
if [ -d ${HOME_DIR}/.git ]; then
    echo "Linking git configs..."
    ln -sf ${DOTFILE_DIR}/.gitconfig ${HOME_DIR}/.gitconfig
    ln -sf ${DOTFILE_DIR}/.gitignore ${HOME_DIR}/.gitignore
else
    echo "Skipping git configs..."
fi

# Link Vim configs.
if [ -d ${HOME_DIR}/.vim ]; then
    echo "Linking vim configs..."
    ln -sf ${DOTFILE_DIR}/.vimrc ${HOME_DIR}/.vim/.vimrc
else 
    echo "Skipping vim configs..."
fi

# Link input config.
if [ -f ${DOTFILE_DIR}/.inputrc ]; then
    echo "Linking input configs..."
    ln -sf ${DOTFILE_DIR}/.inputrc ${HOME_DIR}/.inputrc
else 
    echo "Skipping input configs..."
fi