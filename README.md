
# Automated Server Setup Script

This script (`setup.sh`) is designed to automate the setup of a server environment for deploying web applications using Docker, Docker Compose, and GitLab Runner. It handles tasks like creating users, generating SSH keys, cloning project repositories, setting up Docker, and configuring GitLab Runner.

## Features

- Creates a deploy user if not already created.
- Generates SSH keys for the deploy user and root (if needed).
- Clones multiple project repositories into specified directories.
- Installs Docker and Docker Compose.
- Configures GitLab Runner for CI/CD pipelines.
- Changes the SSH port to 23232 for increased security.
- Automatically starts Docker Compose to run the applications.

## Prerequisites

- A Linux-based server with sudo privileges.
- Access to GitLab repositories (SSH keys will be generated for authentication).
- Docker and Docker Compose should be installed (the script handles this if not already installed).
- GitLab Runner registration token (required during script execution).

## Directory Structure

Once the script is run, it will set up the following directory structure under `/home/deployer/automated-server-setup-front/`:

```
/home/deployer/automated-server-setup-front
└── src
    ├── onomis-react
    ├── onomis-vue
    ├── onomis-landing
    └── emeax-landing
```

Each of the above folders corresponds to a specific project (React, Vue, and HTML landing pages).

## Usage

1. **Download and Run the Script**

   To run the script, use the following command:

   ```bash
   bash <(curl -Ls https://raw.githubusercontent.com/afsh7n/automated-server-setup-front/main/setup.sh)
   ```

2. **Enter Deployment Details**

   The script will prompt you for the following information:
   - Deploy username (default: `deployer`).
   - GitLab repository URLs for the projects (React, Vue, HTML landing pages).
   - GitLab Runner registration token (required to configure CI/CD).

3. **Accessing Applications**

   After the script completes, you can access the applications using the following routes:
   - **Onomis React**: `http://your-domain/preview/onomis-react`
   - **Onomis Vue**: `http://your-domain/preview/onomis-vue`
   - **Onomis Landing**: `http://your-domain/onomis`
   - **Emeax Landing**: `http://your-domain/`

## Steps Executed by the Script

1. **User Creation**: Creates a deploy user (`deployer`) and adds them to the sudo group.
2. **SSH Key Generation**: Generates SSH keys for secure GitLab access.
3. **Repository Cloning**: Clones the following projects into `/home/deployer/automated-server-setup-front/src/`:
   - `onomis-react`
   - `onomis-vue`
   - `onomis-landing`
   - `emeax-landing`
4. **Docker Installation**: Installs Docker and Docker Compose (if not already installed).
5. **GitLab Runner Configuration**: Installs GitLab Runner, registers it using the provided token, and sets it up as a service.
6. **SSH Port Change**: Changes the SSH port from the default (22) to 23232 for enhanced security.
7. **Docker Compose Execution**: Starts all services using Docker Compose (`docker-compose up -d --build`).

## Notes

- **SSH Keys**: After running the script, you will need to add the generated SSH key to your GitLab account to allow the script to clone private repositories.
- **Firewall**: Ensure that the firewall rules allow traffic on the SSH port (23232) and HTTP/HTTPS ports (80/443).

## Troubleshooting

- If you encounter a 404 error when accessing the applications, make sure the Nginx configuration and the file structure inside the `src` folder are correct.
- Use the command `docker logs <nginx-container-id>` to view logs and troubleshoot any issues with Nginx or Docker.
- If the GitLab Runner fails to start, check the registration token and ensure the service is running using `sudo systemctl status gitlab-runner`.

## License

This script is open-source and available under the MIT License.
