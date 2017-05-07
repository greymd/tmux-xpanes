# Get current directory.
# Ref: http://unix.stackexchange.com/questions/76505/portable-way-to-get-scripts-absolute-path
__XPANES_DIR="$(dirname $0:A)"

# Import commands
source "${__XPANES_DIR}/activate.sh"

# Import completion
source "${__XPANES_DIR}/completion.zsh"
