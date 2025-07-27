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
    
    # Tunggu sebentar untuk memastikan plugin ter-load
    sleep 2
    
    # Verifikasi instalasi dengan berbagai cara
    if docker compose version >/dev/null 2>&1; then
        echo "✅ Docker Compose installed successfully!"
        docker compose version
    elif docker-compose --version >/dev/null 2>&1; then
        echo "✅ Docker Compose (standalone) installed successfully!"
        docker-compose --version
    else
        echo "⚠️  Docker Compose plugin installed but may require Docker restart"
        echo "📋 Installed package info:"
        dpkg -l | grep docker-compose-plugin || echo "Package not found in dpkg"
        echo "🔄 Try restarting Docker service: sudo systemctl restart docker"
        echo "🔄 Or logout and login again to refresh your session"
        return 0  # Don't exit, continue with setup
    fi
}

# Fungsi untuk install make
install_make() {
    echo "🛠️  Installing Make..."
    sudo apt-get install -y build-essential
    echo "✅ Make installed successfully!"
}

# Fungsi untuk debugging Docker Compose
debug_docker_compose() {
    echo "🔍 Docker Compose Debug Information:"
    echo "----------------------------------------"
    echo "1. Checking docker compose plugin:"
    docker compose version 2>/dev/null || echo "   ❌ docker compose not available"
    
    echo "2. Checking docker-compose standalone:"
    docker-compose --version 2>/dev/null || echo "   ❌ docker-compose not available"
    
    echo "3. Checking installed Docker plugins:"
    docker plugin ls 2>/dev/null || echo "   ❌ Cannot list Docker plugins"
    
    echo "4. Checking Docker Compose plugin package:"
    dpkg -l | grep docker-compose 2>/dev/null || echo "   ❌ No docker-compose packages found"
    
    echo "5. Docker version:"
    docker version --format '{{.Server.Version}}' 2>/dev/null || echo "   ❌ Cannot get Docker version"
    
    echo "6. PATH check:"
    echo "   PATH: $PATH"
    
    echo "7. Which docker:"
    which docker 2>/dev/null || echo "   ❌ docker not found in PATH"
    echo "----------------------------------------"
}
detect_docker_compose() {
    # Cek docker compose (plugin version) terlebih dahulu
    if docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    # Cek docker-compose (standalone version)
    elif docker-compose --version >/dev/null 2>&1; then
        echo "docker-compose"
    # Fallback: cek dengan command_exists
    elif command_exists "docker compose"; then
        echo "docker compose"
    elif command_exists "docker-compose"; then
        echo "docker-compose"
    else
        echo "none"
    fi
}

# Fungsi untuk membuat Makefile
create_makefile() {
    echo "📄 Creating Makefile..."
    
    # Deteksi versi Docker Compose yang tersedia
    COMPOSE_CMD=$(detect_docker_compose)
    
    if [ "$COMPOSE_CMD" = "none" ]; then
        echo "⚠️  No Docker Compose detected, but creating Makefile with docker compose as default"
        echo "💡 You can manually edit the Makefile later if needed"
        COMPOSE_CMD="docker compose"
        
        # Tampilkan debug info
        debug_docker_compose
    fi
    
    echo "🔍 Detected Docker Compose command: $COMPOSE_CMD"
    
    cat > Makefile << EOF
# Makefile untuk Docker Compose commands
# Usage: make <command>
# Auto-detected Docker Compose command: $COMPOSE_CMD

.PHONY: help up down logs ps restart prune-all clean

# Docker Compose command (auto-detected)
COMPOSE_CMD = $COMPOSE_CMD

# Default target
help: ## Tampilkan help message
	@echo "Available commands:"
	@echo "  make up          - Start containers (\$(COMPOSE_CMD) up -d)"
	@echo "  make down        - Stop containers (\$(COMPOSE_CMD) down)"
	@echo "  make logs        - Show logs (\$(COMPOSE_CMD) logs -f)"
	@echo "  make ps          - Show running containers"
	@echo "  make restart     - Restart containers"
	@echo "  make prune-all   - Stop containers and remove images"
	@echo "  make clean       - Clean up everything (containers, images, volumes)"

up: ## Start containers in detached mode
	@echo "🚀 Starting containers..."
	\$(COMPOSE_CMD) up -d
	@echo "✅ Containers started!"

down: ## Stop and remove containers
	@echo "🛑 Stopping containers..."
	\$(COMPOSE_CMD) down
	@echo "✅ Containers stopped!"

logs: ## Show logs from all containers
	@echo "📋 Showing logs..."
	\$(COMPOSE_CMD) logs -f

ps: ## Show running containers
	@echo "📊 Running containers:"
	\$(COMPOSE_CMD) ps

restart: ## Restart containers
	@echo "🔄 Restarting containers..."
	\$(COMPOSE_CMD) restart
	@echo "✅ Containers restarted!"

prune-all: ## Stop containers and remove all images
	@echo "🧹 Stopping containers and removing images..."
	\$(COMPOSE_CMD) down --rmi all
	@echo "✅ Cleanup completed!"

clean: ## Clean up everything (containers, images, volumes, networks)
	@echo "🗑️  Cleaning up everything..."
	\$(COMPOSE_CMD) down -v --rmi all --remove-orphans
	docker system prune -f
	@echo "✅ Complete cleanup done!"

# Aliases untuk kemudahan
start: up
stop: down
EOF

    echo "✅ Makefile created successfully!"
    echo "🔍 Using Docker Compose command: $COMPOSE_CMD"
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
    echo "🔍 Checking Docker Compose availability..."
    COMPOSE_CMD_CHECK=$(detect_docker_compose)
    if [ "$COMPOSE_CMD_CHECK" = "none" ]; then
        echo "❌ Docker Compose not found"
        install_docker_compose
        # Re-check setelah instalasi
        COMPOSE_CMD_CHECK=$(detect_docker_compose)
        if [ "$COMPOSE_CMD_CHECK" = "none" ]; then
            echo "⚠️  Docker Compose may need manual verification"
            echo "💡 Try running: docker compose version"
        fi
    else
        echo "✅ Docker Compose already installed ($COMPOSE_CMD_CHECK)"
        if [ "$COMPOSE_CMD_CHECK" = "docker compose" ]; then
            docker compose version
        elif [ "$COMPOSE_CMD_CHECK" = "docker-compose" ]; then
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
    echo "🔍 Makefile will automatically use the detected Docker Compose command: $(detect_docker_compose)"
}

# Jalankan main function
main "$@"