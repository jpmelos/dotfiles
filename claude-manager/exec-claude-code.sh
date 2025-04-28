set -e

project_folder_full_name="$(find . -mindepth 1 -maxdepth 1 -type d)"
project_folder_name=$(basename "$project_folder_full_name")
cd "$project_folder_name"

echo
echo -n "Running as: "
cat ~/.claude.json | jq '.oauthAccount.emailAddress' | tr -d '"'
echo
read -r -p "Press Enter to continue, CTRL+D to quit..."

exec claude
