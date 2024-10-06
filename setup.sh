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
git config --global --add safe.directory /home/deployer/automated-server-setup-front

read -p "Press enter after you've added the SSH key to GitLab..."

# Step 4: Clone repositories into respective folders
declare -A project_folders=(
    ["onomis-react"]="onomis-react"
    ["onomis-vue"]="onomis-vue"
    ["onomis"]="onomis"
    ["emeax"]="emeax"
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

    read -p "Please enter your GitLab repository URL for $project_name (leave empty if you don't want to set this project): " repo_url
    if [[ -z "$repo_url" ]]; then
        echo -e "${YELLOW}Skipping setup for $project_name as no URL was provided.${NC}"
        continue
    fi

    project_urls[$project_name]=$repo_url  # Store the repo URL in the array

    if [ -d "$folder_path" ]; then
        read -p "Folder already exists for $project_name. Do you want to remove and re-clone it? (y/n): " remove_folder
        if [[ "$remove_folder" == "y" || "$remove_folder" == "Y" ]]; then
            echo -e "${RED}Removing $project_name...${NC}"
            sudo rm -rf "$folder_path"
            echo -e "${GREEN}Removed existing folder $folder_path.${NC}"
        else
            echo -e "${YELLOW}Skipping re-clone for $project_name.${NC}"
            continue
        fi
    fi

    echo -e "${BLUE}Cloning $project_name into $folder_path...${NC}"
    git clone $repo_url $folder_path
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}$project_name cloned successfully to $folder_path.${NC}"
    else
        echo -e "${RED}Failed to clone $project_name. Please check the URL and SSH key.${NC}"
        exit 1
    fi
done


# Step 5: Add base configuration to vite.config.js for onomis-react and onomis-vue
for project_name in "onomis-react" "onomis-vue"; do
    folder_path="$src_directory/$project_name"
    vite_config_path="$folder_path/vite.config.js"

    if [ -f "$vite_config_path" ]; then
        echo -e "${BLUE}Adding base configuration to $vite_config_path for $project_name...${NC}"
        # Determine the correct base URL based on the project name
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

# Step 8: Change SSH port to 23232 and configure UFW

# Check if ufw is installed and install it if necessary
if command -v ufw &>/dev/null; then
    echo -e "${GREEN}UFW is already installed. Skipping installation.${NC}"
else
    echo -e "${BLUE}Installing UFW (Uncomplicated Firewall)...${NC}"
    sudo apt-get update && sudo apt-get install -y ufw
    echo -e "${GREEN}UFW installed successfully.${NC}"
fi

# Enable UFW if it is not enabled already
if sudo ufw status | grep -q "inactive"; then
    echo -e "${BLUE}Enabling UFW...${NC}"
    sudo ufw enable
    echo -e "${GREEN}UFW enabled.${NC}"
else
    echo -e "${GREEN}UFW is already active.${NC}"
fi

# Change SSH port to 23232 if not already set
if grep -q "Port 23232" /etc/ssh/sshd_config; then
    echo -e "${GREEN}SSH port is already set to 23232. Skipping this step.${NC}"
else
    echo -e "${BLUE}Changing SSH port to 23232...${NC}"
    sudo sed -i 's/#Port 22/Port 23232/' /etc/ssh/sshd_config
    sudo systemctl restart ssh
    echo -e "${GREEN}SSH port changed to 23232 and service restarted.${NC}"
fi

# Configure UFW to allow port 23232 for SSH and deny port 22
echo -e "${BLUE}Configuring UFW to allow SSH on port 23232 and deny port 22...${NC}"
sudo ufw allow 23232/tcp
sudo ufw deny 22/tcp
sudo ufw reload
echo -e "${GREEN}UFW configured: port 23232 allowed, port 22 denied.${NC}"



echo -e "${BLUE}Starting Docker Compose based on existing projects...${NC}"
# List of services to check and potentially run
services=("onomis-react" "onomis-vue" "onomis-docs" "emeax" "onomis")

echo -e "${BLUE}Checking and starting active services...${NC}"

# Step 1: Always start Nginx
echo -e "${BLUE}Starting Nginx...${NC}"
docker-compose up -d nginx

# Step 2: Check each service and start if available
for service in "${services[@]}"; do
    # Directory where the project is located
    project_dir="/home/deployer/automated-server-setup-front/src/$service"

    # Check if the directory exists and is not empty
    if [ -d "$project_dir" ] && [ "$(ls -A $project_dir)" ]; then
        echo -e "${GREEN}Service $service found. Starting...${NC}"
        # Start the specific service
        docker-compose up -d --build $service
    else
        echo -e "${RED}Service $service not found or directory is empty. Skipping...${NC}"
    fi
done

# Step 3: Final message after processing all services
echo -e "${GREEN}All available services have been started successfully.${NC}"

# مسیر فایل Nginx در سیستم میزبان
nginx_config_host="/home/deployer/automated-server-setup-front/docker/nginx.conf"

# گرفتن مقدار SERVER_NAME از محیط
server_name="${SERVER_NAME}"

# محتوای بیسیک کانفیگ Nginx
base_config="events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;  # شامل شدن MIME types استاندارد
    default_type  application/octet-stream;

    server {
        listen 80;
        server_name ${server_name};

    "

# نوشتن محتوای بیسیک در فایل nginx.conf
echo "$base_config" > "$nginx_config_host"

# بررسی و اضافه کردن پراکسی‌ها به داخل بلاک server
if docker ps --format '{{.Names}}' | grep -q "onomis-react"; then
    echo "Adding onomis-react to nginx config"
    cat <<EOT >> "$nginx_config_host"
        # Proxy برای Onomis React
        location /preview/onomis-react/ {
            proxy_pass http://onomis-react:3000/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
EOT
fi

if docker ps --format '{{.Names}}' | grep -q "onomis-vue"; then
    echo "Adding onomis-vue to nginx config"
    cat <<EOT >> "$nginx_config_host"
        # Proxy برای Onomis Vue
        location /preview/onomis-vue/ {
            proxy_pass http://onomis-vue:3001/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
EOT
fi

if docker ps --format '{{.Names}}' | grep -q "onomis-docs"; then
    echo "Adding onomis-docs to nginx config"
    cat <<EOT >> "$nginx_config_host"
        # Proxy برای Onomis Docs
        location /preview/onomis-docs/ {
            proxy_pass http://onomis-docs:3002/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
EOT
fi

if docker ps --format '{{.Names}}' | grep -q "emeax"; then
    echo "Adding emeax to nginx config"
    cat <<EOT >> "$nginx_config_host"
        # Proxy برای emeax
        location / {
            proxy_pass http://emeax:3003/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
EOT
fi

if docker ps --format '{{.Names}}' | grep -q "onomis"; then
    echo "Adding onomis to nginx config"
    cat <<EOT >> "$nginx_config_host"
        # Proxy برای Onomis
        location /onomis/ {
            proxy_pass http://onomis:3004/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
EOT
fi

# بستن بلاک server
echo "   } }" >> "$nginx_config_host"

# ری‌استارت کردن کانتینر Nginx برای اعمال تغییرات
echo "Restarting Nginx container..."
docker restart nginx

echo "Nginx configuration updated and reloaded successfully."




# Install GitLab Runner (if needed)
if command -v gitlab-runner &>/dev/null; then
    echo -e "${GREEN}GitLab Runner is already installed. Skipping installation.${NC}"
else
    echo -e "${BLUE}Installing GitLab Runner...${NC}"
    curl -L --output /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64
    sudo chmod +x /usr/local/bin/gitlab-runner
    echo -e "${GREEN}GitLab Runner installed successfully.${NC}"
fi


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
    if [[ -z "${project_urls[$project_name]}" ]]; then
        echo -e "${YELLOW}Skipping GitLab Runner setup for $project_name as it was not set up.${NC}"
        continue
    fi

    # Check if we need to remove an existing GitLab Runner
    runner_exists=$(sudo gitlab-runner list | grep -c "$project_name")
    if [ $runner_exists -ne 0 ]; then
        read -p "A runner already exists for $project_name. Do you want to remove it and re-register? (y/n): " remove_runner
        if [[ "$remove_runner" == "y" || "$remove_runner" == "Y" ]]; then
            sudo gitlab-runner unregister --name "$project_name runner"
            echo -e "${GREEN}Removed existing runner for $project_name.${NC}"
        else
            echo -e "${YELLOW}Skipping GitLab Runner registration for $project_name.${NC}"
            continue
        fi
    fi

    # Register the runner
    echo -e "${BLUE}Registering GitLab Runner for $project_name...${NC}"
    read -p "Enter the GitLab Runner registration token for $project_name: " runner_token

    sudo gitlab-runner register --non-interactive \
        --url "https://gitlab.com/" \
        --registration-token "$runner_token" \
        --executor "shell" \
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
