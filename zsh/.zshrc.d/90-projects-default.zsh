if [[ -o interactive && -d "$PROJECTS_DIR" && "$PWD" == "$HOME" ]]; then
  cd "$PROJECTS_DIR"
fi
