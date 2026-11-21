fish_add_path -Up ~/.local/bin

if status is-interactive
    set -gx EDITOR /usr/bin/vim
    set -gx VISUAL /usr/bin/vim

    set -gx fish_greeting "
┏━┛┏━┃┏┏ ┏━┛━┏┛
┃  ┃ ┃┃┃┃┏━┛ ┃ 
━━┛━━┛┛┛┛━━┛ ┛"

    alias cp="cp -i"
    alias df="df -h"
    alias free="free -m"
    alias lb="lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINT"
    alias ls='eza -al --color=always --group-directories-first --icons'
    alias la='eza -a --color=always --group-directories-first --icons'
    alias ll='eza -l --color=always --group-directories-first --icons'
    alias lt='eza -aT --color=always --group-directories-first --icons'

    alias lg='lazygit'
    alias gad="git add"
    alias gbr="git branch"
    alias gch="git checkout"
    alias gco="git commit -v"
    alias gdf="git diff"
    alias gfh="git fetch --prune"
    alias glg="git log --oneline -n 20"
    alias gmr="git merge"
    alias gph="git push"
    alias gpl="git pull"
    alias gsk="git stash --keep-index"
    alias gst="git status -bs"

    set -gx MANROFFOPT -c
    set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
    set -gx LESS_TERMCAP_mb (printf '\e[01;32m')
    set -gx LESS_TERMCAP_md (printf '\e[01;32m')
    set -gx LESS_TERMCAP_me (printf '\e[0m')
    set -gx LESS_TERMCAP_se (printf '\e[0m')
    set -gx LESS_TERMCAP_so (printf '\e[01;47;34m')
    set -gx LESS_TERMCAP_ue (printf '\e[0m')
    set -gx LESS_TERMCAP_us (printf '\e[01;36m')
    set -gx LESS -r

    if type -q tv
        tv init fish | source
    end

    if type -q zoxide
        zoxide init fish | source
    end

    bind \e\[A history-search-backward
    bind \e\[B history-search-forward
    if functions -q tv_shell_history
        bind \cr tv_shell_history
    end

    if test -f ~/.config/fish/secrets.fish
        source ~/.config/fish/secrets.fish
    end

    if type -q starship
        starship init fish | source
    end
end
