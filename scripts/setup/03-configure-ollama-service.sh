#!/bin/bash
set -euo pipefail

# 03-configure-ollama-service.sh - Configure Ollama as a system service
# This script sets up Ollama to run automatically on Mac Studio

echo "=== Configuring Ollama Service ==="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check if Ollama is installed
if ! command -v ollama &> /dev/null; then
    print_error "Ollama is not installed. Please run 02-install-ollama.sh first"
    exit 1
fi

# Create LaunchAgents directory if it doesn't exist
mkdir -p ~/Library/LaunchAgents

# Create the plist file for launchd
print_status "Creating Ollama service configuration..."
cat > ~/Library/LaunchAgents/com.ollama.server.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ollama.server</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(which ollama)</string>
        <string>serve</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
        <key>Crashed</key>
        <true/>
    </dict>
    <key>ThrottleInterval</key>
    <integer>60</integer>
    <key>EnvironmentVariables</key>
    <dict>
        <key>OLLAMA_HOST</key>
        <string>0.0.0.0:11434</string>
        <key>OLLAMA_MODELS</key>
        <string>$HOME/ollama-models</string>
        <key>OLLAMA_KEEP_ALIVE</key>
        <string>10m</string>
        <key>OLLAMA_NUM_PARALLEL</key>
        <string>4</string>
        <key>OLLAMA_MAX_LOADED_MODELS</key>
        <string>2</string>
        <key>OLLAMA_FLASH_ATTENTION</key>
        <string>true</string>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin</string>
    </dict>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/ollama.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/ollama.error.log</string>
</dict>
</plist>
EOF

# Create logs directory
mkdir -p ~/Library/Logs

# Unload existing service if it exists
if launchctl list | grep -q "com.ollama.server"; then
    print_status "Unloading existing Ollama service..."
    launchctl unload ~/Library/LaunchAgents/com.ollama.server.plist 2>/dev/null || true
fi

# Load the new service
print_status "Loading Ollama service..."
launchctl load ~/Library/LaunchAgents/com.ollama.server.plist

# Wait for service to start
sleep 3

# Check if service is running
if launchctl list | grep -q "com.ollama.server"; then
    print_status "Ollama service loaded successfully"
    
    # Test API endpoint
    if curl -s http://localhost:11434/api/version > /dev/null 2>&1; then
        print_status "Ollama API is accessible at http://localhost:11434"
        
        # Get version info
        version_info=$(curl -s http://localhost:11434/api/version | jq -r '.version' 2>/dev/null || echo "unknown")
        print_status "Ollama version: $version_info"
    else
        print_warning "Ollama service is loaded but API is not responding"
        print_warning "Check logs at: ~/Library/Logs/ollama.error.log"
    fi
else
    print_error "Failed to load Ollama service"
    exit 1
fi

# Create helper script for service management
print_status "Creating service management helper..."
cat > ~/bin/ollama-service << 'EOF'
#!/bin/bash
# Ollama service management helper

case "$1" in
    start)
        launchctl load ~/Library/LaunchAgents/com.ollama.server.plist 2>/dev/null
        echo "Ollama service started"
        ;;
    stop)
        launchctl unload ~/Library/LaunchAgents/com.ollama.server.plist 2>/dev/null
        echo "Ollama service stopped"
        ;;
    restart)
        launchctl unload ~/Library/LaunchAgents/com.ollama.server.plist 2>/dev/null
        sleep 2
        launchctl load ~/Library/LaunchAgents/com.ollama.server.plist
        echo "Ollama service restarted"
        ;;
    status)
        if launchctl list | grep -q "com.ollama.server"; then
            echo "Ollama service is running"
            curl -s http://localhost:11434/api/version | jq '.' 2>/dev/null || echo "API not responding"
        else
            echo "Ollama service is not running"
        fi
        ;;
    logs)
        tail -f ~/Library/Logs/ollama.log
        ;;
    errors)
        tail -f ~/Library/Logs/ollama.error.log
        ;;
    *)
        echo "Usage: ollama-service {start|stop|restart|status|logs|errors}"
        exit 1
        ;;
esac
EOF

chmod +x ~/bin/ollama-service

print_status "Ollama service configuration complete!"
print_status "Service management commands:"
print_status "  ollama-service start   - Start the service"
print_status "  ollama-service stop    - Stop the service"
print_status "  ollama-service restart - Restart the service"
print_status "  ollama-service status  - Check service status"
print_status "  ollama-service logs    - View service logs"
print_status "  ollama-service errors  - View error logs"