# Load tracked zsh fragments in lexical order.
if [[ -d "$HOME/.zshrc.d" ]]; then
  for file in "$HOME"/.zshrc.d/*.zsh; do
    [[ -r "$file" ]] && source "$file"
  done
fi

# Load machine-specific overrides last.
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
