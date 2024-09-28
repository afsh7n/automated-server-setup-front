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

    read -p "Please enter your GitLab repository URL for $project_name: " repo_url

    # Remove folder if it already exists (no confirmation needed)
    if [ -d "$folder_path" ]; then
        echo -e "${BLUE}Removing existing folder $folder_path...${NC}"
        sudo rm -rf $folder_path
        echo -e "${GREEN}Folder removed successfully.${NC}"
    fi

    # Clone the repository
    echo -e "${BLUE}Cloning $project_name into $folder_path...${NC}"
    git clone $repo_url $folder_path
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}$project_name cloned successfully to $folder_path.${NC}"

        # Check if vite.config.js exists, and add base configuration
        vite_config_path="$folder_path/vite.config.js"
        if [ -f "$vite_config_path" ]; then
            echo -e "${BLUE}Adding base configuration to $vite_config_path...${NC}"
            # Add the base line dynamically based on the project name
            if [[ "$project_name" == "onomis-react" ]]; then
                base_line="base: '/preview/onomis-react/',"
            elif [[ "$project_name" == "onomis-vue" ]]; then
                base_line="base: '/preview/onomis-vue/',"
            fi

            # Insert the base line after 'defineConfig({'
            sed -i "/defineConfig({/a \  $base_line" "$vite_config_path"

            echo -e "${GREEN}Base configuration added successfully to $vite_config_path.${NC}"
        else
            echo -e "${RED}vite.config.js not found for $project_name. Skipping base configuration.${NC}"
        fi

        # Check if package.json exists, and ensure dependencies are installed
        package_json_path="$folder_path/package.json"
        if [ -f "$package_json_path" ]; then
            echo -e "${BLUE}Installing dependencies for $project_name...${NC}"
            sudo -u $deploy_user npm install --prefix $folder_path
            echo -e "${GREEN}Dependencies installed successfully for $project_name.${NC}"
        else
            echo -e "${RED}package.json not found for $project_name. Skipping dependency installation.${NC}"
        fi
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

echo -e "${GREEN}Setup complete!${NC}"
