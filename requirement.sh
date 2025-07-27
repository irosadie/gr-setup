#!/bin/bash

# Setup script untuk Docker, Docker Compose, dan Makefile
# Author: Assistant
# Description: Script untuk setup environment Docker dengan Makefile

set -e  # Exit jika ada error

echo "=== Docker & Docker Compose Setup Script ==="
echo

# Fungsi untuk cek apakah command tersedia
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Fungsi untuk install Docker
install_docker() {
    echo "🐳 Installing Docker..."
    
    # Remove old versions jika ada
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install dependencies
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package index
    sudo apt-get update
    
    # Install Docker Engine
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    echo "✅ Docker installed successfully!"
}

# Fungsi untuk install Docker Compose
install_docker_compose() {
    echo "🔧 Installing Docker Compose..."
    
    # Install Docker Compose plugin (recommended method)
    sudo apt-get install -y docker-compose-plugin
    
    # Verifikasi instalasi
    if command_exists "docker compose"; then
        echo "✅ Docker Compose installed successfully!"
        docker compose version
    else
        echo "❌ Docker Compose installation failed"
        exit 1
    fi
}

# Fungsi untuk install make
install_make() {
    echo "🛠️  Installing Make..."
    sudo apt-get install -y build-essential
    echo "✅ Make installed successfully!"
}

# Fungsi untuk membuat Makefile
create_makefile() {
    echo "📄 Creating Makefile..."
    
    cat > Makefile << 'EOF'
# Makefile untuk Docker Compose commands
# Usage: make <command>

.PHONY: help up down logs ps restart prune-all clean

# Default target
help: ## Tampilkan help message
	@echo "Available commands:"
	@echo "  make up          - Start containers (docker-compose up -d)"
	@echo "  make down        - Stop containers (docker-compose down)"
	@echo "  make logs        - Show logs (docker-compose logs -f)"
	@echo "  make ps          - Show running containers"
	@echo "  make restart     - Restart containers"
	@echo "  make prune-all   - Stop containers and remove images"
	@echo "  make clean       - Clean up everything (containers, images, volumes)"

up: ## Start containers in detached mode
	@echo "🚀 Starting containers..."
	docker-compose up -d
	@echo "✅ Containers started!"

down: ## Stop and remove containers
	@echo "🛑 Stopping containers..."
	docker-compose down
	@echo "✅ Containers stopped!"

logs: ## Show logs from all containers
	@echo "📋 Showing logs..."
	docker-compose logs -f

ps: ## Show running containers
	@echo "📊 Running containers:"
	docker-compose ps

restart: ## Restart containers
	@echo "🔄 Restarting containers..."
	docker-compose restart
	@echo "✅ Containers restarted!"

prune-all: ## Stop containers and remove all images
	@echo "🧹 Stopping containers and removing images..."
	docker-compose down --rmi all
	@echo "✅ Cleanup completed!"

clean: ## Clean up everything (containers, images, volumes, networks)
	@echo "🗑️  Cleaning up everything..."
	docker-compose down -v --rmi all --remove-orphans
	docker system prune -f
	@echo "✅ Complete cleanup done!"

# Aliases untuk kemudahan
start: up
stop: down
EOF

    echo "✅ Makefile created successfully!"
    echo
    echo "Available make commands:"
    echo "  make up          - Start containers"
    echo "  make down        - Stop containers" 
    echo "  make prune-all   - Stop containers and remove images"
    echo "  make logs        - Show logs"
    echo "  make ps          - Show running containers"
    echo "  make clean       - Complete cleanup"
}

# Main script execution
main() {
    echo "🔍 Checking system requirements..."
    
    # Update package list
    echo "📦 Updating package list..."
    sudo apt-get update
    
    # Cek dan install Docker jika belum ada
    if ! command_exists docker; then
        echo "❌ Docker not found"
        install_docker
    else
        echo "✅ Docker already installed"
        docker --version
    fi
    
    # Cek dan install Docker Compose jika belum ada
    if ! command_exists "docker compose" && ! command_exists "docker-compose"; then
        echo "❌ Docker Compose not found"
        install_docker_compose
    else
        echo "✅ Docker Compose already installed"
        if command_exists "docker compose"; then
            docker compose version
        else
            docker-compose --version
        fi
    fi
    
    # Cek dan install Make jika belum ada
    if ! command_exists make; then
        echo "❌ Make not found"
        install_make
    else
        echo "✅ Make already installed"
        make --version | head -1
    fi
    
    # Buat Makefile jika belum ada
    if [ ! -f "Makefile" ]; then
        echo "❌ Makefile not found"
        create_makefile
    else
        echo "✅ Makefile already exists"
        echo "⚠️  If you want to recreate Makefile, delete the existing one first"
    fi
    
    echo
    echo "🎉 Setup completed successfully!"
    echo
    echo "📝 Next steps:"
    echo "1. Logout and login again (or run: newgrp docker) to apply Docker group changes"
    echo "2. Create your docker-compose.yml file"
    echo "3. Run 'make up' to start your containers"
    echo
    echo "💡 Run 'make help' to see all available commands"
}

# Jalankan main function
main "$@"