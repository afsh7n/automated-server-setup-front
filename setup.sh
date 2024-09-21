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
    cd $project_directory && git pull
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
    echo -e "${GREEN}User '$deploy_user' created and added to sudo group.${NC}."
fi

# Step 3: Generate SSH key for deploy_user and root (if needed)
if [ -f "/home/$deploy_user/.ssh/id_rsa.pub" ]; then
    echo -e "${GREEN}SSH key for '$deploy_user' already exists. Skipping SSH key generation.${NC}"
else
    # Ensure the .ssh directory exists and has the correct permissions
    echo -e "${BLUE}Creating .ssh directory for $deploy_user...${NC}"
    sudo mkdir -p /home/$deploy_user/.ssh
    sudo chown $deploy_user:$deploy_user /home/$deploy_user/.ssh
    sudo chmod 700 /home/$deploy_user/.ssh

    # Generate SSH key for the deploy user
    echo -e "${BLUE}Generating SSH key for $deploy_user...${NC}"
    sudo -u $deploy_user ssh-keygen -t rsa -b 4096 -C "exp@exp.com" -N "" -f /home/$deploy_user/.ssh/id_rsa

    # Ensure the permissions for the keys are correct
    sudo chmod 600 /home/$deploy_user/.ssh/id_rsa
    sudo chmod 644 /home/$deploy_user/.ssh/id_rsa.pub
    sudo chown $deploy_user:$deploy_user /home/$deploy_user/.ssh/id_rsa
    sudo chown $deploy_user:$deploy_user /home/$deploy_user/.ssh/id_rsa.pub

    echo -e "${BLUE}Here is the SSH public key. Please add it to your GitLab account:${NC}"
    cat /home/$deploy_user/.ssh/id_rsa.pub
fi

read -p "Press enter after you've added the SSH key to GitLab..."

# Step 4: Clone repositories into respective folders
declare -A project_folders=(
    ["onomis-react"]="onomis-react"
    ["onomis-vue"]="onomis-vue"
    ["onomis-landing"]="onomis"
    ["emeax-landing"]="emeax"
)

src_directory="/home/$deploy_user/automated-server-setup-front/src"

# Ensure the src directory exists
if [ ! -d "$src_directory" ]; then
    echo -e "${BLUE}Creating src directory...${NC}"
    mkdir -p $src_directory
fi

for project_name in "${!project_folders[@]}"; do
    folder_name=${project_folders[$project_name]}
    folder_path="$src_directory/$folder_name"

    read -p "Please enter your GitLab repository URL for $project_name: " repo_url

    # Check if the folder already exists; if not, create it
    if [ ! -d "$folder_path" ]; then
        echo -e "${BLUE}Creating folder $folder_name...${NC}"
        mkdir -p $folder_path
    fi

    # Check if the repository already exists
    if [ -d "$folder_path/.git" ]; then
        echo -e "${GREEN}Repository already exists in $folder_path. Pulling latest changes...${NC}"
        cd $folder_path && git pull
    else
        echo -e "${BLUE}Cloning $project_name into $folder_path...${NC}"
        git clone $repo_url $folder_path
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}$project_name cloned successfully to $folder_path.${NC}"
        else
            echo -e "${RED}Failed to clone $project_name. Please check the URL and SSH key.${NC}"
            exit 1
        fi
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

# Step 9: Install and configure GitLab Runner (if needed)
if command -v gitlab-runner >/dev/null 2>&1; then
    echo -e "${GREEN}GitLab Runner is already installed. Skipping installation.${NC}"
else
    echo -e "${BLUE}Installing GitLab Runner...${NC}"
    curl -L --output /tmp/gitlab-runner-linux-amd64 "https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64"
    sudo mv /tmp/gitlab-runner-linux-amd64 /usr/local/bin/gitlab-runner
    sudo chmod +x /usr/local/bin/gitlab-runner
    echo -e "${GREEN}GitLab Runner installed successfully.${NC}"
fi

if sudo systemctl is-active --quiet gitlab-runner; then
    echo -e "${GREEN}GitLab Runner is already running. Skipping this step.${NC}"
else
    echo -e "${BLUE}Installing and starting GitLab Runner as a service...${NC}"
    sudo gitlab-runner install --user=$deploy_user --working-directory=/home/$deploy_user
    sudo gitlab-runner start

    echo -e "${BLUE}Please enter your GitLab Runner registration token:${NC}"
    read registration_token

    sudo gitlab-runner register --non-interactive \
      --url "https://gitlab.com/" \
      --registration-token "$registration_token" \
      --executor "shell" \
      --description "My Server Runner" \
      --tag-list "server" \
      --run-untagged="true" \
      --locked="false"

    sudo systemctl restart gitlab-runner
    if sudo systemctl is-active --quiet gitlab-runner; then
        echo -e "${GREEN}GitLab Runner is running and ready to accept jobs.${NC}"
    else
        echo -e "${RED}GitLab Runner failed to start after registration. Please check the logs for more details.${NC}"
        exit 1
    fi
fi

# Step 10: Start Docker Compose
echo -e "${BLUE}Starting Docker Compose...${NC}"
cd /home/$deploy_user/automated-server-setup-front
docker-compose up -d --build
echo -e "${GREEN}Docker Compose started successfully.${NC}"

echo -e "${GREEN}Setup complete!${NC}"
