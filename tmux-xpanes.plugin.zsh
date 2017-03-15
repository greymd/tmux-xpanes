# Get current directory.
# Ref: http://unix.stackexchange.com/questions/76505/portable-way-to-get-scripts-absolute-path
_XP_DIR="$(dirname $0:A)"

# Import commands
source "${_XP_DIR}/activate.sh"

# Import completion
source "${_XP_DIR}/completion.zsh"
