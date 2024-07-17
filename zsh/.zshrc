# path to oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# zsh plugins
plugins=(autojump zsh-syntax-highlighting zsh-autosuggestions)

# Spaceship theme + settings
ZSH_THEME="spaceship"
SPACESHIP_CHAR_SYMBOL='❯ '
SPACESHIP_VENV_PREFIX='('
SPACESHIP_VENV_SUFFIX=') '
SPACESHIP_PROMPT_FIRST_PREFIX_SHOW=true
SPACESHIP_DIR_PREFIX=''
SPACESHIP_DIR_TRUNC_REPO=false
SPACESHIP_PROMPT_ORDER=(venv time user dir host git hg package node bun deno ruby python elm elixir xcode swift golang perl php rust haskell scala kotlin java lua dart julia crystal docker docker_compose aws gcloud azure conda dotnet ocaml vlang zig purescript erlang kubectl ansible terraform pulumi ibmcloud nix_shell gnu_screen exec_time async line_sep battery jobs exit_code sudo char)

# init oh my zsh
source $ZSH/oh-my-zsh.sh

# virtualenvwrapper
export WORKON_HOME=$HOME/.virtualenvs
VIRTUALENVWRAPPER_PYTHON="/usr/bin/python3"
source /usr/local/bin/virtualenvwrapper.sh

# vi-mode terminal
set -o vi

# remove delay between switching terminal editing modes in terminal
export KEYTIMEOUT=1

# tmux quick set up
alias home="tmux new-session -A -s home"

# bindings for autosuggesiotns
bindkey '^h' autosuggest-accept
bindkey '^o' autosuggest-execute

# function to quickly make temp directory
function mtd() {
    local target_dir="/tmp/"
    local name=$1

    if [ -z "$name" ]; then
        # if no arg provided make dir with random chars
        name=$(openssl rand -hex 16)
    fi

    local dir_path="${target_dir}${name}"
    local postfix=2

    # get unique directory
    while [ -d "$dir_path" ]; do
        name="${1}${postfix}"
        dir_path="${target_dir}${name}"
        ((postfix++))
    done

    mkdir "$dir_path"
    cd "$dir_path"
}


# fzf history widget
source "/opt/homebrew/Cellar/fzf/0.48.1/shell/key-bindings.zsh"
bindkey ^F fzf-history-widget

# allow backwards history incremental in vi mode
bindkey -v && bindkey "^R" history-incremental-pattern-search-backward

# vim instead of nvim
alias vim="nvim"
alias vimdiff="nvim -d"

# don't record duplicate history
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS

# keep all history
export HISTFILESIZE=1000000000
export HISTSIZE=1000000000
setopt INC_APPEND_HISTORY
