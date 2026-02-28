# Technical Test - Skeleton Project

Base project for technical tests with Rails API backend, React frontend, MySQL database, and Nginx reverse proxy. All running with Docker Compose.

## Technologies

- Ruby 3.2.0
- Rails 7
- React 18 (Vite)
- MySQL 8
- Nginx (reverse proxy)
- Docker & Docker Compose
- Bootstrap 5
- RSpec (testing)

## Architecture

```
┌──────────────┐     ┌──────────────┐
│   Frontend   │     │   Backend    │
│  React/Vite  │     │  Rails API   │
│  port: 5173  │     │  port: 3001  │
└──────┬───────┘     └──────┬───────┘
       │                    │
       └────────┬───────────┘
                │
         ┌──────┴───────┐
         │    Nginx     │
         │  port: 8000  │
         └──────────────┘
                │
         ┌──────┴───────┐
         │   MySQL 8    │
         │  port: 3307  │
         └──────────────┘
```

## Getting Started

### Prerequisites

- Docker & Docker Compose
- Create the external network (first time only):

```bash
docker network create networks_default
```

### Run the project

```bash
docker compose build
docker compose up -d
```

### Access

| Service  | URL                     |
|----------|-------------------------|
| Frontend | http://localhost:5173    |
| Backend  | http://localhost:3001    |
| Nginx    | http://localhost:8000    |
| MySQL    | localhost:3307           |

### Useful commands

```bash
# Enter the Rails container
docker compose exec app bash

# Rails console
docker compose exec app rails console

# Create database
docker compose exec app rails db:create

# Run migrations
docker compose exec app rails db:migrate

# Run tests
docker compose exec app bundle exec rspec

# Enter the frontend container
docker compose exec frontend sh
```

## Project Structure

```
.
├── backend/          # Rails API application
├── frontend/         # React (Vite) application
├── nginx/            # Nginx reverse proxy config
├── docker-compose.yml
└── README.md
```
