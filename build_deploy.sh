#!/bin/bash

# Jitsi Meet Build and Deploy Script
# This script builds the Jitsi Meet web application from source and deploys it

set -e  # Exit on any error

echo "🚀 Starting Jitsi Meet build and deploy process..."

# Source NVM at the beginning
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Check if we're in the correct directory
if [ ! -f "package.json" ]; then
    echo "❌ Error: package.json not found. Please run this script from the jitsi-meet directory."
    exit 1
fi

# Check if NVM is available
if ! command -v nvm &> /dev/null; then
    echo "❌ Error: NVM is not available. Please install NVM first:"
    echo "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
    exit 1
fi

# Use Node.js 22
echo "📦 Using Node.js 22..."
nvm use 22

# Check Node.js and npm versions
echo "🔍 Node.js version: $(node --version)"
echo "🔍 npm version: $(npm --version)"

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
else
    echo "📦 Dependencies already installed, skipping..."
fi

# Build the application
echo "🔨 Building Jitsi Meet web application..."
make

# Check if build was successful
if [ ! -f "libs/app.bundle.min.js" ]; then
    echo "❌ Error: Build failed. app.bundle.min.js not found."
    exit 1
fi

echo "✅ Build completed successfully!"

# Deploy to Jitsi Meet installation
echo "🚀 Deploying to Jitsi Meet installation..."

# Create backup of current installation
echo "📦 Creating backup of current installation..."
sudo cp -r /usr/share/jitsi-meet /usr/share/jitsi-meet.backup.$(date +%Y%m%d_%H%M%S)

# Clean target directory completely
echo "🧹 Cleaning target directory..."
sudo rm -rf /usr/share/jitsi-meet/*

# Deploy all files fresh
echo "📤 Copying all files..."
sudo cp -r libs /usr/share/jitsi-meet/
sudo cp -r css /usr/share/jitsi-meet/
sudo cp -r images /usr/share/jitsi-meet/
sudo cp -r fonts /usr/share/jitsi-meet/
sudo cp -r lang /usr/share/jitsi-meet/
sudo cp -r sounds /usr/share/jitsi-meet/
sudo cp -r static /usr/share/jitsi-meet/
[ -d "scripts" ] && sudo cp -r scripts /usr/share/jitsi-meet/
[ -d "prosody-plugins" ] && sudo cp -r prosody-plugins /usr/share/jitsi-meet/
sudo cp *.html /usr/share/jitsi-meet/ 2>/dev/null || true
sudo cp *.js /usr/share/jitsi-meet/ 2>/dev/null || true
sudo cp *.json /usr/share/jitsi-meet/ 2>/dev/null || true
sudo cp *.txt /usr/share/jitsi-meet/ 2>/dev/null || true

# Set proper permissions
echo "🔐 Setting permissions..."
sudo chown -R www-data:www-data /usr/share/jitsi-meet/

# Reload nginx
echo "🔄 Reloading nginx..."
sudo systemctl reload nginx

# Ensure deep-linking is disabled server-wide (idempotent)
CFG="/etc/jitsi/meet/meet2.bookaderma.com-config.js"
echo "🛠  Enforcing disableDeepLinking on server config..."
sudo cp "$CFG" "$CFG.bak.$(date +%s)"
# Enable legacy flag if present and commented, or inject if missing
sudo sed -i -E "s#^\s*//\s*disableDeepLinking:\s*true,#    disableDeepLinking: true,#" "$CFG" || true
if ! grep -q "^[[:space:]]*disableDeepLinking:\s*true" "$CFG"; then
  sudo sed -i "/var config = {/a\\    disableDeepLinking: true," "$CFG"
fi
# Enable new deeplinking.disabled config (inject if missing)
if ! grep -q "deeplinking:\s*{[[:space:]]*disabled:\s*true" "$CFG"; then
  sudo sed -i "/var config = {/a\\    deeplinking: { disabled: true }," "$CFG"
fi

# Verify deployment
echo "🔍 Verifying deployment..."
if [ -f "/usr/share/jitsi-meet/libs/app.bundle.min.js" ]; then
    echo "✅ Deployment successful!"
    echo "📊 File sizes:"
    ls -lh /usr/share/jitsi-meet/libs/app.bundle.min.js
    ls -lh /usr/share/jitsi-meet/css/all.css
else
    echo "❌ Error: Deployment failed. app.bundle.min.js not found in target directory."
    exit 1
fi

echo ""
echo "🎉 Jitsi Meet web application has been successfully built and deployed!"
echo "🌐 Your custom web interface is now available at: https://meet2.bookaderma.com"
echo ""
echo "📝 To make changes:"
echo "   1. Edit files in the current directory"
echo "   2. Run this script again: ./build_deploy.sh"
echo ""
echo "📋 Build completed at: $(date)"
