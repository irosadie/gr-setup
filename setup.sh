#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
echo "=================================================="
echo "    Docker Compose Setup for FBBot"
echo "=================================================="
echo -e "${NC}"

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        echo -e "${YELLOW}Warning: Running as root. Consider using a non-root user.${NC}"
        sleep 2
    fi
}

# Function to install Docker if not present
install_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker not found. Installing Docker...${NC}"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
        echo -e "${GREEN}Docker installed successfully!${NC}"
        echo -e "${YELLOW}Please logout and login again to use Docker without sudo.${NC}"
    fi
}

# Function to install Docker Compose if not present
install_docker_compose() {
    echo -e "${BLUE}Checking Docker Compose...${NC}"
    
    # Check if docker compose (plugin) is available
    if docker compose version &> /dev/null; then
        echo -e "${GREEN}Docker Compose (plugin) is already installed${NC}"
        docker compose version
        return 0
    fi
    
    # Check if docker-compose (standalone) is available
    if command -v docker-compose &> /dev/null; then
        echo -e "${GREEN}Docker Compose (standalone) is already installed${NC}"
        docker-compose --version
        return 0
    fi
    
    echo -e "${YELLOW}Docker Compose not found. Installing Docker Compose plugin...${NC}"
    
    # Install Docker Compose plugin (recommended method)
    if command -v apt &> /dev/null; then
        sudo apt update
        sudo apt install -y docker-compose-plugin
    elif command -v yum &> /dev/null; then
        sudo yum install -y docker-compose-plugin
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y docker-compose-plugin
    else
        echo -e "${YELLOW}Package manager not supported. Installing via direct download...${NC}"
        # Fallback: install standalone docker-compose
        DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
        sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
    
    # Wait a moment for plugin to load
    sleep 2
    
    # Verify installation
    if docker compose version &> /dev/null; then
        echo -e "${GREEN}Docker Compose (plugin) installed successfully!${NC}"
        docker compose version
    elif command -v docker-compose &> /dev/null; then
        echo -e "${GREEN}Docker Compose (standalone) installed successfully!${NC}"
        docker-compose --version
    else
        echo -e "${YELLOW}Docker Compose plugin installed but may require Docker restart${NC}"
        echo -e "${YELLOW}Try: sudo systemctl restart docker${NC}"
        echo -e "${YELLOW}Or logout and login again${NC}"
    fi
}

# Function to detect Docker Compose command
detect_docker_compose_cmd() {
    if docker compose version &> /dev/null; then
        echo "docker compose"
    elif command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        echo "docker compose"  # Default fallback
    fi
}

# Function to install required tools
install_required_tools() {
    echo -e "${BLUE}Checking required tools...${NC}"
    
    # Check and install net-tools for netstat
    if ! command -v netstat &> /dev/null && ! command -v ss &> /dev/null; then
        echo -e "${YELLOW}Installing net-tools for port checking...${NC}"
        if command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y net-tools
        elif command -v yum &> /dev/null; then
            sudo yum install -y net-tools
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y net-tools
        else
            echo -e "${YELLOW}Could not install net-tools. Port checking may be limited.${NC}"
        fi
    fi
}

# Function to open firewall port
open_firewall_port() {
    local port=$1
    echo -e "${BLUE}Opening firewall port $port...${NC}"
    
    # Check if ufw is available and active
    if command -v ufw &> /dev/null; then
        sudo ufw allow $port/tcp
        echo -e "${GREEN}Port $port opened via UFW${NC}"
    elif command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --permanent --add-port=$port/tcp
        sudo firewall-cmd --reload
        echo -e "${GREEN}Port $port opened via firewalld${NC}"
    elif command -v iptables &> /dev/null; then
        sudo iptables -A INPUT -p tcp --dport $port -j ACCEPT
        echo -e "${GREEN}Port $port opened via iptables${NC}"
        echo -e "${YELLOW}Note: iptables rules may not persist after reboot${NC}"
    else
        echo -e "${YELLOW}No firewall management tool found. Please open port $port manually.${NC}"
    fi
}

# Function to check if port is in use
check_port_in_use() {
    local port=$1
    if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Function to validate port
validate_port() {
    local port=$1
    if [[ $port -ge 1024 && $port -le 65535 ]]; then
        if check_port_in_use $port; then
            echo -e "${RED}Port $port is already in use!${NC}"
            return 1
        else
            return 0
        fi
    else
        return 1
    fi
}

# Function to validate username
validate_username() {
    local username=$1
    if [[ ${#username} -ge 3 && $username =~ ^[a-zA-Z0-9_]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Main setup function
main() {
    echo -e "${BLUE}Starting interactive setup...${NC}\n"
    
    # Check prerequisites
    check_root
    install_required_tools
    install_docker
    install_docker_compose
    
    # Get Broker credentials
    echo -e "${BLUE}=== Broker Configuration ===${NC}"
    
    # Username input
    while true; do
        read -p "Enter Broker username (min 3 chars, alphanumeric): " rabbitmq_user
        if validate_username "$rabbitmq_user"; then
            break
        else
            echo -e "${RED}Invalid username. Use at least 3 characters (letters, numbers, underscore only).${NC}"
        fi
    done
    
    # Password input
    while true; do
        read -s -p "Enter Broker password (min 6 chars, no @ symbol): " rabbitmq_pass
        echo
        if [[ ${#rabbitmq_pass} -ge 6 ]]; then
            if [[ "$rabbitmq_pass" == *"@"* ]]; then
                echo -e "${RED}Password cannot contain '@' symbol. This can cause connection issues.${NC}"
                continue
            fi
            read -s -p "Confirm password: " rabbitmq_pass_confirm
            echo
            if [[ "$rabbitmq_pass" == "$rabbitmq_pass_confirm" ]]; then
                break
            else
                echo -e "${RED}Passwords don't match. Try again.${NC}"
            fi
        else
            echo -e "${RED}Password too short. Minimum 6 characters.${NC}"
        fi
    done
    
    # Port input
    while true; do
        read -p "Enter Broker port [5672]: " rabbitmq_port
        rabbitmq_port=${rabbitmq_port:-5672}
        if validate_port "$rabbitmq_port"; then
            echo -e "${GREEN}Port $rabbitmq_port is available!${NC}"
            break
        else
            if [[ $rabbitmq_port -lt 1024 || $rabbitmq_port -gt 65535 ]]; then
                echo -e "${RED}Invalid port range. Use port between 1024-65535.${NC}"
            fi
            suggest_ports $rabbitmq_port
            echo -e "${YELLOW}Please try another port.${NC}"
        fi
    done
    
    # Security keys
    echo -e "\n${BLUE}=== Security Configuration ===${NC}"
    read -p "Enter SECRET_KEY [auto-generate]: " secret_key
    if [[ -z "$secret_key" ]]; then
        secret_key=$(openssl rand -hex 32 2>/dev/null || date +%s | sha256sum | base64 | head -c 32)
    fi
    
    read -p "Enter API_KEY [auto-generate]: " api_key
    if [[ -z "$api_key" ]]; then
        api_key=$(openssl rand -hex 16 2>/dev/null || date +%s | sha256sum | base64 | head -c 16)
    fi
    
    # Generate docker-compose.yml
    echo -e "\n${BLUE}Generating docker-compose.yml...${NC}"
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  rabbitmq:
    image: rabbitmq:3-management
    container_name: fbbot-broker
    ports:
      - "${rabbitmq_port}:5672"
    environment:
      - RABBITMQ_DEFAULT_USER=\${RABBITMQ_USER}
      - RABBITMQ_DEFAULT_PASS=\${RABBITMQ_PASS}
      - RABBITMQ_DEFAULT_VHOST=/
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "ping"]
      interval: 30s
      timeout: 10s
      retries: 5
    networks:
      - fbbot-network
    restart: unless-stopped

  fbbot:
    image: ghcr.io/irosadie/grbot:latest
    container_name: fbbot-worker
    depends_on:
      rabbitmq:
        condition: service_healthy
    env_file:
      - .env
    volumes:
      - ./logs:/app/logs
      - ./sessions:/app/sessions  
      - ./data:/app/data
    networks:
      - fbbot-network
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G

networks:
  fbbot-network:
    driver: bridge

volumes:
  rabbitmq_data:
EOF

    # Generate .env file
    echo -e "${BLUE}Generating .env file...${NC}"
    cat > .env << EOF
# Broker Configuration
RABBITMQ_HOST=rabbitmq
RABBITMQ_PORT=5672
RABBITMQ_USER=${rabbitmq_user}
RABBITMQ_PASS=${rabbitmq_pass}
CELERY_BROKER_URL=pyamqp://${rabbitmq_user}:${rabbitmq_pass}@rabbitmq:5672//
CELERY_RESULT_BACKEND=rpc://

# Browser Settings
HEADLESS=true
VISIBLE_BROWSER=false
DEBUG=false
ENVIRONMENT=production
DISPLAY=:99
PLAYWRIGHT_BROWSERS_PATH=/usr/local/share/ms-playwright

# Application Settings
PYTHONUNBUFFERED=1
PYTHONPATH=/app
LOG_LEVEL=INFO

# Security
SECRET_KEY=${secret_key}
API_KEY=${api_key}
EOF

    # Create directories
    echo -e "${BLUE}Creating required directories...${NC}"
    mkdir -p logs sessions data
    
    # Open firewall port
    open_firewall_port $rabbitmq_port
    
    # Set file permissions
    chmod 600 .env
    chmod 644 docker-compose.yml
    
    # Summary
    echo -e "\n${GREEN}=================================================="
    echo "           Setup Complete! 🚀"
    echo "==================================================${NC}"
    echo -e "${YELLOW}Generated files:${NC}"
    echo "  ✓ docker-compose.yml"
    echo "  ✓ .env (secure permissions)"
    echo "  ✓ logs/, sessions/, data/ directories"
    echo ""
    echo -e "${YELLOW}Configuration:${NC}"
    echo "  ✓ Broker User: $rabbitmq_user"
    echo "  ✓ Broker Port: $rabbitmq_port"
    echo "  ✓ Firewall: Port $rabbitmq_port opened"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Run: ${BLUE}docker-compose up -d${NC}"
    echo "  2. Check logs: ${BLUE}docker-compose logs -f${NC}"
    echo "  3. Stop: ${BLUE}docker-compose down${NC}"
    echo ""
    echo -e "${GREEN}Happy coding! 🎉${NC}"
}

# Run main function
main "$@"