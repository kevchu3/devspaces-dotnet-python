HISTFILE=/home/user/.zsh_history
HISTSIZE=1000
SAVEHIST=1000
if [ -f /workspace.rc ]
then
  . /workspace.rc
fi

autoload -Uz compinit
compinit
if [ $commands[oc] ]; then
  source <(oc completion zsh)
  compdef _oc oc
fi
