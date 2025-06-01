set -e

project_folder_full_name="$(find . -mindepth 1 -maxdepth 1 -type d)"
project_folder_name=$(basename "$project_folder_full_name")
cd "$project_folder_name"

echo
echo -n "Running as: "
cat ~/.claude.json | jq '.oauthAccount.emailAddress' | tr -d '"'
echo
trap 'exit 0' INT
read -r -p "Press any key to continue, CTRL+C or CTRL+D to quit..."

claude config set -g autoUpdaterStatus disabled

if [[ "$CLAUDE_HELP" == "true" ]]; then
    exec claude --help
elif [[ "$CLAUDE_RESUME" == "true" ]]; then
    exec claude --resume
else
    exec claude
fi
