#!/bin/bash
# =======================================
# Pterodactyl Addon Installer
# Addon: SAMP Player List
# =======================================

PTERO_PATH="/var/www/pterodactyl"
ADDON_PATH="$(pwd)"

echo "🔹 Installing SAMP Player List Addon..."

# Copy Controller
mkdir -p "$PTERO_PATH/app/Http/Controllers/Addon"
cp "$ADDON_PATH/PlayerListController.php" "$PTERO_PATH/app/Http/Controllers/Addon/PlayerListController.php"

# Copy Vue component
mkdir -p "$PTERO_PATH/resources/scripts/components/server"
cp "$ADDON_PATH/PlayerTab.vue" "$PTERO_PATH/resources/scripts/components/server/PlayerTab.vue"

# Append route
ROUTE_FILE="$PTERO_PATH/routes/client.php"
if ! grep -q "PlayerListController" "$ROUTE_FILE"; then
    echo "" >> "$ROUTE_FILE"
    echo "use App\Http\Controllers\Addon\PlayerListController;" >> "$ROUTE_FILE"
    echo "Route::get('/server/{server}/players', [PlayerListController::class, 'getPlayers'])->name('server.players');" >> "$ROUTE_FILE"
fi

# Install SAMP Query library (PHP)
cd "$PTERO_PATH"
composer require aleedhillon/php-sampquery

# Build frontend
npm install && npm run build

echo "✅ Installation complete!"
