# Get current directory.
# Ref: http://unix.stackexchange.com/questions/76505/portable-way-to-get-scripts-absolute-path
XP_DIR="$(dirname $0:A)"

# Import commands
source "${XP_DIR}/activate.sh"

# Import completion
source "${XP_DIR}/completion.zsh"
