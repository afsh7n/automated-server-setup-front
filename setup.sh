#!/bin/bash

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Step 1: Clone the project structure into /home/deployer/
project_structure_url="https://github.com/afsh7n/automated-server-setup-front.git"
project_directory="/home/deployer/automated-server-setup-front"

echo -e "${BLUE}Cloning project structure into $project_directory...${NC}"
if [ -d "$project_directory" ]; then
    echo -e "${GREEN}Project structure already exists. Pulling the latest changes.${NC}"
    cd $project_directory && sudo -u $deploy_user git pull
else
    git clone $project_structure_url $project_directory
    cd $project_directory
fi

# Step 2: Create a new user (if needed)
read -p "Please enter the username for the deploy user (default: deployer): " deploy_user
deploy_user=${deploy_user:-deployer}

if id "$deploy_user" &>/dev/null; then
    echo -e "${GREEN}User '$deploy_user' already exists. Skipping user creation.${NC}"
else
    echo -e "${BLUE}Creating user '$deploy_user'...${NC}"
    sudo adduser --disabled-password --gecos "" $deploy_user
    sudo usermod -aG sudo $deploy_user
    echo -e "${GREEN}User '$deploy_user' created and added to sudo group.${NC}"
fi

# Step 3: Generate SSH key for deploy_user and root (if needed)
if [ -f "/home/$deploy_user/.ssh/id_rsa.pub" ]; then
    echo -e "${GREEN}SSH key for '$deploy_user' already exists. Skipping SSH key generation.${NC}"
else
    echo -e "${BLUE}Generating SSH key for $deploy_user...${NC}"
    sudo mkdir -p /home/$deploy_user/.ssh
    sudo chown -R $deploy_user:$deploy_user /home/$deploy_user
    sudo chmod 700 /home/$deploy_user/.ssh

    sudo -u $deploy_user ssh-keygen -t rsa -b 4096 -C "exp@exp.com" -N "" -f /home/$deploy_user/.ssh/id_rsa

    sudo chmod 600 /home/$deploy_user/.ssh/id_rsa
    sudo chmod 644 /home/$deploy_user/.ssh/id_rsa.pub

    echo -e "${BLUE}Here is the SSH public key. Please add it to your GitLab account:${NC}"
    cat /home/$deploy_user/.ssh/id_rsa.pub
fi

echo -e "${BLUE}Starting SSH agent and adding the key...${NC}"
eval $(ssh-agent -s)
ssh-add /home/$deploy_user/.ssh/id_rsa

read -p "Press enter after you've added the SSH key to GitLab..."

# Step 4: Clone repositories into respective folders
declare -A project_folders=(
    ["onomis-react"]="onomis-react"
    ["onomis-vue"]="onomis-vue"
    ["onomis-landing"]="onomis"
    ["emeax-landing"]="emeax"
    ["onomis-docs"]="onomis-docs"
)

declare -A project_urls  # This array will hold the URLs for each project

src_directory="/home/$deploy_user/automated-server-setup-front/src"

# Ensure the src directory exists
if [ ! -d "$src_directory" ]; then
    echo -e "${BLUE}Creating src directory...${NC}"
    mkdir -p $src_directory
fi

# Add GitLab to known_hosts to avoid manual confirmation
echo -e "${BLUE}Adding GitLab to known_hosts...${NC}"
ssh-keyscan gitlab.com >> /home/$deploy_user/.ssh/known_hosts
sudo chown $deploy_user:$deploy_user /home/$deploy_user/.ssh/known_hosts

for project_name in "${!project_folders[@]}"; do
    folder_name=${project_folders[$project_name]}
    folder_path="$src_directory/$folder_name"

    # Ask for the GitLab repository URL only once
    read -p "Please enter your GitLab repository URL for $project_name: " repo_url
    project_urls[$project_name]=$repo_url  # Store the repo URL in the array

    # Check if the folder already exists and is not empty
    if [ -d "$folder_path" ]; then
        echo -e "${RED}$project_name already exists. Removing it...${NC}"
        sudo rm -rf $folder_path  # Remove the existing folder
        echo -e "${GREEN}Removed existing folder $folder_path.${NC}"
    fi

    # Clone the repository
    echo -e "${BLUE}Cloning $project_name into $folder_path...${NC}"
    git clone $repo_url $folder_path
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}$project_name cloned successfully to $folder_path.${NC}"
    else
        echo -e "${RED}Failed to clone $project_name. Please check the URL and SSH key.${NC}"
        exit 1
    fi
done

# Step 5: Install Docker (if needed)
if command -v docker &>/dev/null; then
    echo -e "${GREEN}Docker is already installed. Skipping Docker installation.${NC}"
else
    echo -e "${BLUE}Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh ./get-docker.sh
    sudo usermod -aG docker $deploy_user
    echo -e "${GREEN}Docker installed successfully.${NC}"
fi

# Step 6: Install Docker Compose (if needed)
if command -v docker-compose &>/dev/null; then
    echo -e "${GREEN}Docker Compose is already installed. Skipping Docker Compose installation.${NC}"
else
    echo -e "${BLUE}Installing Docker Compose...${NC}"
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}Docker Compose installed successfully.${NC}"
fi

# Step 7: Clean up .bash_logout file (if needed)
if [ -f "/home/$deploy_user/.bash_logout" ]; then
    echo -e "${BLUE}Removing .bash_logout to prevent environment preparation issues...${NC}"
    sudo rm /home/$deploy_user/.bash_logout
    echo -e "${GREEN}.bash_logout file has been removed successfully.${NC}"
fi

# Step 8: Change SSH port to 23232
if grep -q "Port 23232" /etc/ssh/sshd_config; then
    echo -e "${GREEN}SSH port is already set to 23232. Skipping this step.${NC}"
else
    echo -e "${BLUE}Changing SSH port to 23232...${NC}"
    sudo sed -i 's/#Port 22/Port 23232/' /etc/ssh/sshd_config
    sudo systemctl restart ssh
    echo -e "${GREEN}SSH port changed to 23232 and service restarted.${NC}"
fi


# Step 9: Start Docker Compose
echo -e "${BLUE}Starting Docker Compose...${NC}"
cd /home/$deploy_user/automated-server-setup-front
docker-compose up -d --build
echo -e "${GREEN}Docker Compose started successfully.${NC}"


# Step 10: Clone repositories into respective folders
# Install GitLab Runner (if needed)
if command -v gitlab-runner &>/dev/null; then
    echo -e "${GREEN}GitLab Runner is already installed. Skipping installation.${NC}"
else
    echo -e "${BLUE}Installing GitLab Runner...${NC}"
    curl -L --output /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64
    sudo chmod +x /usr/local/bin/gitlab-runner
    echo -e "${GREEN}GitLab Runner installed successfully.${NC}"
fi

# Step 1: Define the deploy user
read -p "Please enter the username for the deploy user (default: deployer): " deploy_user
deploy_user=${deploy_user:-deployer}

# Step 2: Install and configure GitLab Runner as a service
echo -e "${BLUE}Installing GitLab Runner service for user $deploy_user...${NC}"
sudo gitlab-runner install --user=$deploy_user
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to install GitLab Runner as a service.${NC}"
    exit 1
fi

# Step 3: Start the GitLab Runner service
echo -e "${BLUE}Starting GitLab Runner service...${NC}"
sudo gitlab-runner start
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to start GitLab Runner.${NC}"
    exit 1
fi


# Step 11: Register the GitLab Runner for each project using the URLs from earlier
for project_name in "${!project_urls[@]}"; do
    echo -e "${BLUE}Please register the GitLab Runner for $project_name.${NC}"
    echo -e "Follow this link to generate the registration token:"
    echo -e "${GREEN}${project_urls[$project_name]}/-/settings/ci_cd${NC}"

    read -p "Enter the GitLab Runner registration token for $project_name: " runner_token

    sudo gitlab-runner register --non-interactive \
        --url "https://gitlab.com/" \
        --registration-token "$runner_token" \
        --executor "shell" \
        --docker-image "alpine:latest" \
        --description "$project_name runner" \
        --tag-list "$project_name" \
        --run-untagged="false" \
        --locked="true"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}GitLab Runner registered successfully for $project_name.${NC}"
    else
        echo -e "${RED}Failed to register GitLab Runner for $project_name. Please check the token and try again.${NC}"
        exit 1
    fi
done

echo -e "${GREEN}Setup complete!${NC}"



# Step 11: Summary and Final Steps
echo -e "${BLUE}========================= Summary =========================${NC}"
echo -e "${GREEN}1. Project structure has been cloned successfully.${NC}"
echo -e "${GREEN}2. SSH keys have been generated and configured.${NC}"
echo -e "${GREEN}3. Repositories have been cloned and base paths have been configured.${NC}"
echo -e "${GREEN}4. Dependencies have been installed for each project.${NC}"
echo -e "${GREEN}5. Docker and Docker Compose have been installed (if needed).${NC}"
echo -e "${GREEN}6. Docker Compose is up and running.${NC}"
echo -e "${GREEN}7. GitLab Runners have been registered for each project.${NC}"

echo -e "${BLUE}======================== Next Steps =======================${NC}"
echo -e "${GREEN}- You can now access your projects via their respective URLs.${NC}"
echo -e "${GREEN}- If there are any issues with Docker Compose, you can check logs using:${NC}"
echo -e "${GREEN}  docker-compose logs${NC}"

echo -e "${BLUE}======================= Useful Links ======================${NC}"
echo -e "${GREEN}To manage GitLab CI/CD for your project, visit the CI/CD settings page here:${NC}"
echo -e "${GREEN}  ${RED}https://gitlab.com/your-project/-/settings/ci_cd${NC}"
echo -e "${GREEN}- Replace 'your-project' with the actual project path you are working on.${NC}"

echo -e "${GREEN}Setup complete! All services should be running smoothly.${NC}"

# Step 12: Exit script
exit 0
