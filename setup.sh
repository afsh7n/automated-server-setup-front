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
    git clone --single-branch --branch demo $project_structure_url $project_directory
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
    echo -e "------------------------------------------------------------------------------"
fi

echo -e "${BLUE}Starting SSH agent and adding the key...${NC}"
eval $(ssh-agent -s)
ssh-add /home/$deploy_user/.ssh/id_rsa
sudo -u $deploy_user bash -c 'eval "$(ssh-agent -s)" && ssh-add /home/'"$deploy_user"'/.ssh/id_rsa'
git config --global --add safe.directory /home/deployer/automated-server-setup-front

read -p "Press enter after you've added the SSH key to GitLab..."

# Step 4: Clone repositories into respective folders
declare -A project_folders=(
    ["onomis-react"]="onomis-react"
    ["onomis-vue"]="onomis-vue"
    ["onomis"]="onomis"
    ["emeax"]="emeax"
    ["onomis-docs"]="onomis-docs"
    ["admin"]="admin"
    ["admin-docs"]="admin-docs"
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

# Final Nginx Configuration
nginx_config_host="/home/deployer/automated-server-setup-front/docker/nginx.conf"

# محتوای بیسیک کانفیگ Nginx
base_config="events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    server {
        listen 80;
        server_name emeax.com;
"

echo "$base_config" > "$nginx_config_host"

# Function to add a location to the main server block
function add_nginx_location() {
    local service_name="$1"
    local port="$2"
    local location="$3"
    cat <<EOT >> "$nginx_config_host"
        location $location {
            proxy_pass http://$service_name:$port$location;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_redirect off;
        }
EOT
}

# سرویس‌های دامنه اصلی و اضافه کردن آنها به بلوک اصلی server
declare -A services_and_ports=(
    ["onomis-react"]="3000:/preview/onomis-react/"
    ["onomis-vue"]="3001:/preview/onomis-vue/"
    ["onomis-docs"]="3002:/onomis-docs"
    ["emeax"]="3003:/"
    ["onomis"]="3004:/onomis/"
)

# بررسی سرویس‌های اصلی و افزودن آنها به فایل Nginx
for service_name in "${!services_and_ports[@]}"; do
    port_and_location=(${services_and_ports[$service_name]//:/ })
    port="${port_and_location[0]}"
    location="${port_and_location[1]}"

    if docker ps --format '{{.Names}}' | grep -w "$service_name"; then
        if docker inspect -f '{{.State.Running}}' "$service_name" 2>/dev/null | grep -q "true"; then
            echo -e "${GREEN}Container $service_name is running.${NC}"
            echo -e "${GREEN}Adding $service_name to Nginx config...${NC}"
            add_nginx_location "$service_name" "$port" "$location"
        else
            echo -e "${RED}Container $service_name is not running, skipping...${NC}"
        fi
    else
        echo -e "${RED}Container $service_name is not running or does not exist, skipping...${NC}"
    fi
done

# بستن بلوک سرور اصلی
echo "    }" >> "$nginx_config_host"

# افزودن سرورهای جداگانه برای admin و admin-docs
declare -A subdomain_services=(
    ["admin"]="3005:admin.emeax.com"
    ["admin-docs"]="3006:admin-docs.emeax.com"
)

for service_name in "${!subdomain_services[@]}"; do
    port_and_domain=(${subdomain_services[$service_name]//:/ })
    port="${port_and_domain[0]}"
    domain="${port_and_domain[1]}"

    if docker ps --format '{{.Names}}' | grep -w "$service_name"; then
        if docker inspect -f '{{.State.Running}}' "$service_name" 2>/dev/null | grep -q "true"; then
            echo -e "${GREEN}Container $service_name is running.${NC}"
            echo -e "${GREEN}Adding independent server block for $service_name with domain $domain to Nginx config...${NC}"
            cat <<EOT >> "$nginx_config_host"
server {
    listen 80;
    server_name $domain;

    location / {
        proxy_pass http://$service_name:$port/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
    }
}
EOT
        else
            echo -e "${RED}Container $service_name is not running, skipping...${NC}"
        fi
    else
        echo -e "${RED}Container $service_name is not running or does not exist, skipping...${NC}"
    fi
done

echo "}" >> "$nginx_config_host"

# ری‌استارت کردن کانتینر Nginx برای اعمال تغییرات
echo -e "${GREEN}Restarting Nginx container...${NC}"
docker restart nginx
echo -e "${GREEN}Nginx configuration updated and reloaded successfully.${NC}"



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

chmod 777 -R /home/deployer/automated-server-setup-front/src

sudo systemctl restart ssh

sleep 5

sudo systemctl restart ssh

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
