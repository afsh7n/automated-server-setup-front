
# Multi-Project Setup with Docker (HTML, React, Vue)

This repository contains a setup for managing multiple front-end projects (HTML, React, and Vue) using Docker. Each project is stored in a separate directory under the `src/` folder and served through Nginx with Docker Compose.

## Project Structure

```
project-root/
│
├── src/
│   ├── landing-page-html/
│   │   └── index.html
│   ├── main-page-html/
│   │   └── index.html
│   ├── react-app/
│   │   └── # React project files
│   └── vue-app/
│       └── # Vue project files
├── docker-compose.yml
└── nginx.conf
```

- **landing-page-html**: Contains the HTML landing page.
- **main-page-html**: Contains the main HTML page.
- **react-app**: Contains the React project.
- **vue-app**: Contains the Vue project.

## What It Does

This setup uses Docker and Docker Compose to serve multiple projects:
- Two static HTML pages served via Nginx.
- A React project served on `/react`.
- A Vue project served on `/vue`.

Nginx acts as a reverse proxy, routing traffic to each project based on the URL path.

## How to Set Up

1. Clone the repository:
   ```bash
   git clone <your-repo-url>
   cd <your-repo-folder>
   ```

2. Build and start the Docker containers:
   ```bash
   docker-compose up -d --build
   ```

3. Access the applications:
   - HTML Landing Page: `http://localhost/landing-page`
   - HTML Main Page: `http://localhost/main-page`
   - React Project: `http://localhost/react`
   - Vue Project: `http://localhost/vue`

## Troubleshooting

### React Project: Blank Page Issue
If the React project shows a blank page, ensure that the `homepage` property in the `package.json` is set to `/react`:
```json
"homepage": "/react"
```

### Vue Project: 502 Bad Gateway or Invalid Host Header
For the Vue project, if you encounter an `Invalid Host Header` or `502 Bad Gateway`, ensure the following settings in `vue.config.js`:

```javascript
module.exports = {
  publicPath: '/vue/',  // Set the base path for the Vue app
  devServer: {
    host: '0.0.0.0',
    port: 8080,
    allowedHosts: 'all',
    client: {
      webSocketURL: 'auto://0.0.0.0:8080/ws',
    },
    headers: {
      'Access-Control-Allow-Origin': '*',
    }
  }
}
```

Ensure that Nginx is correctly configured to proxy requests to the Vue container in `nginx.conf`:

```nginx
location /vue/ {
  proxy_pass http://vue-app-container:8080;
  proxy_set_header Host $host;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto $scheme;
}
```

## Conclusion

This setup provides a clean and simple way to manage multiple front-end projects using Docker. With Nginx as a reverse proxy and Docker Compose to manage the services, you can easily scale and maintain the projects.

Feel free to contribute or report any issues!
