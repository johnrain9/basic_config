[[ "$MY_PLATFORM" == "macos" ]] || return 0

# Common Homebrew locations.
dot_prepend_path "/opt/homebrew/bin"
dot_prepend_path "/opt/homebrew/sbin"
dot_prepend_path "/usr/local/bin"
dot_prepend_path "/usr/local/sbin"
