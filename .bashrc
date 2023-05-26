# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

if [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
fi

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        # We have color support; assume it's compliant with Ecma-48
        # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
        # a case would tend to support setf rather than setaf.)
        color_prompt=yes
    else
        color_prompt=
    fi
fi

# old color prompt
# \[\e]0;\u@\h: \w\a\]\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$

if [ "$color_prompt" = yes ]; then
    PROMPT='%(?.%F{green}√.%F{red}X%?)%f %B%F{240}%~%f%b %# '
else
    PROMPT='%(?.√.X%?) %~ %# '
fi
unset color_prompt force_color_prompt

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -e ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# completion scripts
if [ -e ~/.bash_completion ]; then
    . ~/.bash_completion
fi

export VISUAL=vim
export EDITOR="$VISUAL"
export RANGER_LOAD_DEFAULT_RC=false

if [ -f /usr/bin/virtualenvwrapper.sh ]; then
    source /usr/bin/virtualenvwrapper.sh
fi

if [ `which javac` ]; then
    export CLASSPATH=~/.java_class/:.
fi

export PATH=$PATH:/usr/local/bin

# specific if go lang is installed
if ! type "go" > /dev/null; then
    export GOPATH=~/go/
    export PATH=$PATH:~/go/bin/
fi

# if scripts directory is there, add to path
if [ -d ~/scripts ]; then
    export PATH=$PATH:~/scripts/
fi

# if matlab is installed, then add to path
if [ -f ~/matlab/bin/matlab ]; then
    export PATH=$PATH:~/matlab/bin/
fi

if [ -d ~/.class_vars/ ]; then
    for f in ~/.class_vars/*; do
        . $f;
    done
fi

if [ -d /opt/android-sdk/ ]; then
    export ANDROID_HOME=/opt/android-sdk
    export PATH=$PATH:$ANDROID_HOME/tools
    export PATH=$PATH:$ANDROID_HOME/platform-tools
fi

export JAVA_HOME='/usr/lib/jvm/java-8-openjdk/jre/'
