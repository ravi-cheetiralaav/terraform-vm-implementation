# Simple Setup Script for Windows Server
# Parameters from Terraform template
$Server = "${ServerParam}"
$Tags = "${TagsParam}"

# Echo the parameters
echo "Server Parameter: $Server"
echo "Tags Parameter: $Tags"
echo "Script executed successfully as admin user"

# Exit with success
exit 0