#!/usr/bin/env bash


GIT_ROOT=$(git rev-parse --show-toplevel)

if [ -z "$GITLAB_TOKEN" ]; then
    echo "GitLab access token is required."
    exit 1
fi

# Use curl to get the current user from GitLab API
GITLAB_USER=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "https://gitlab.com/api/v4/user" | jq -r '.username')

echo $GITLAB_USER

# Retrieve the current Git repository URL
REPO_URL=$(git config --get remote.origin.url)
if [ -z "$REPO_URL" ]; then
    echo "Failed to retrieve Git repository URL."
    exit 1
fi

# Extract the GitLab project path from the URL
PROJECT_PATH=$(echo $REPO_URL | sed -e 's/.*gitlab.com.//' -e 's/\.git$//')

echo $PROJECT_PATH

# Ensure that the project path is extracted
if [ -z "$PROJECT_PATH" ]; then
    echo "Failed to extract project path from repository URL."
    exit 1
fi

# Use curl to get the project ID from GitLab API
PROJECT_DATA=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "https://gitlab.com/api/v4/projects/${PROJECT_PATH//\//%2F}")
PROJECT_ID=$(echo $PROJECT_DATA | jq -r '.id')


# Ensure that the project ID is retrieved
if [ -z "$PROJECT_ID" ]; then
    echo "Failed to retrieve project ID from GitLab."
    exit 1
fi

# export TF_ADDRESS="https://gitlab.com/api/v4/projects/$PROJECT_ID/terraform/state/foundation"
# export TF_HTTP_USERNAME="$GITLAB_USER"
# export TF_HTTP_PASSWORD="$GITLAB_TOKEN"

# Three terraform projects are foundation, extensions and cluster
# Run terraform init for each project
for project in foundation extensions cluster; do
    echo "Initializing $project..."
    # Run terraform init with the derived values
    cd "$GIT_ROOT/terragrunt/$project"
    terragrunt init \
        -reconfigure \
        -backend-config="address=https://gitlab.com/api/v4/projects/$PROJECT_ID/terraform/state/$project" \
        -backend-config="lock_address=https://gitlab.com/api/v4/projects/$PROJECT_ID/terraform/state/$project/lock" \
        -backend-config="unlock_address=https://gitlab.com/api/v4/projects/$PROJECT_ID/terraform/state/$project/lock" \
        -backend-config="username=$GITLAB_USER" \
        -backend-config="password=$GITLAB_TOKEN" \
        -backend-config="lock_method=POST" \
        -backend-config="unlock_method=DELETE" \
        -backend-config="retry_wait_min=5"
done
