# Path to your oh-my-zsh installation.
export ZSH=/Users/rodmachen/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
# ZSH_THEME="risto"
# risto theme with blue and green swapped
ZSH_THEME="rodsto"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git z)

# User configuration

export PATH="$HOME/.local/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

source $ZSH/oh-my-zsh.sh

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.

# Example aliases
alias zs="source ~/.zshrc"
alias sz="code ~/.zshrc"
alias c.="code ."
alias gs="git status"
alias glp="git log --pretty=format:'%h %ad | %s%d [%an]' --graph --date=short"
alias gmm="git merge master"
alias gcm="git commit -m"
alias gcom="git checkout master"
alias type="git cat-file -t"
alias dump="git cat-file -p"
alias gpum="git pull upstream master"
#alias gps="git push --set-upstream origin"
#alias gprm="git pull --rebase upstream master"
#alias gpom="git push origin master"
#alias vim="/Applications/MacVim.app/Contents/MacOS/Vim"
#alias vg="valgrind --tool=memcheck --leak-check=yes --show-reachable=yes --num-callers=20 --track-fds=yes"
alias gfi="git-fixit"
alias nrg="npm run generate"
alias nrst="npm run start:dev"
alias nrsp="npm run stop:dev"
alias rake='noglob rake'
alias mci="mvn clean install -DskipTests"
alias mcit="mvn clean install"
alias mct="mvn clean test"
alias audio="sudo kextunload /System/Library/Extensions/AppleHDA.kext;sudo kextload /System/Library/Extensions/AppleHDA.kext"
alias mcis='mci && ./start.sh'
alias mcic='mvn test jacoco:report'
alias chmd='chmod +x'

stty -ixon


function code {
    if [[ $# = 0 ]]
    then
        open -a "Visual Studio Code"
    else
        local argPath="$1"
        [[ $1 = /* ]] && argPath="$1" || argPath="$PWD/${1#./}"
        open -a "Visual Studio Code" "$argPath"
    fi
}
