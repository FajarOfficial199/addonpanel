#!/bin/bash

# Pterodactyl SA-MP Players Addon Uninstaller
# Author: Your Name
# Description: Removes the SA-MP Players List addon from Pterodactyl Panel

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variables
PANEL_PATH="/var/www/pterodactyl"
ADDON_PATH="${PANEL_PATH}/resources/scripts/components/server/players"
API_ROUTE_FILE="${PANEL_PATH}/routes/api-client.php"
ROUTES_FILE="${PANEL_PATH}/resources/scripts/routes/server/index.ts"
NAVIGATION_FILE="${PANEL_PATH}/resources/scripts/components/server/ServerNavigation.tsx"
API_WRAPPER_FILE="${PANEL_PATH}/resources/scripts/api/server/players/getServerPlayers.ts"
BACKUP_DIR="/tmp/pterodactyl_backups"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: This script must be run as root${NC}"
  exit 1
fi

# Check if Pterodactyl directory exists
if [ ! -d "$PANEL_PATH" ]; then
  echo -e "${RED}Error: Pterodactyl directory not found at ${PANEL_PATH}${NC}"
  echo -e "Please set the correct path in the script variables"
  exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"
echo -e "${YELLOW}Creating backup of modified files...${NC}"

# Backup existing files
TIMESTAMP=$(date +%Y%m%d%H%M%S)
if [ -f "$API_ROUTE_FILE" ]; then
  cp "$API_ROUTE_FILE" "${BACKUP_DIR}/api-client.php.${TIMESTAMP}.bak"
fi
if [ -f "$ROUTES_FILE" ]; then
  cp "$ROUTES_FILE" "${BACKUP_DIR}/routes-server-index.ts.${TIMESTAMP}.bak"
fi
if [ -f "$NAVIGATION_FILE" ]; then
  cp "$NAVIGATION_FILE" "${BACKUP_DIR}/ServerNavigation.tsx.${TIMESTAMP}.bak"
fi

# Remove API route
echo -e "${YELLOW}Removing API route...${NC}"
if [ -f "$API_ROUTE_FILE" ]; then
  sed -i '/\/client\/servers\/{server}\/players/,/});/d' "$API_ROUTE_FILE"
fi

# Remove frontend route
echo -e "${YELLOW}Removing frontend route...${NC}"
if [ -f "$ROUTES_FILE" ]; then
  sed -i "/path: '\/players'/d" "$ROUTES_FILE"
fi

# Remove navigation item
echo -e "${YELLOW}Removing navigation item...${NC}"
if [ -f "$NAVIGATION_FILE" ]; then
  sed -i "/name: 'Players'/d" "$NAVIGATION_FILE"
fi

# Remove components and API wrapper
echo -e "${YELLOW}Removing addon files...${NC}"
rm -rf "$ADDON_PATH"
rm -f "$API_WRAPPER_FILE"

# Remove empty players directory if exists
if [ -d "${PANEL_PATH}/resources/scripts/api/server/players" ]; then
  rmdir "${PANEL_PATH}/resources/scripts/api/server/players" 2>/dev/null
fi

# Build assets
echo -e "${YELLOW}Rebuilding frontend assets...${NC}"
cd "$PANEL_PATH" || exit
npm run build

echo -e "${GREEN}Uninstallation completed successfully!${NC}"
echo -e "Backups are stored in: ${BACKUP_DIR}"
echo -e "You may need to restart your webserver for changes to take effect."

exit 0
