#!/bin/bash

# Pterodactyl SA-MP Players Addon Installer
# Author: Your Name
# Description: Installs the SA-MP Players List addon for Pterodactyl Panel

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variables
PANEL_PATH="/var/www/pterodactyl"
ADDON_NAME="samp-players"
ADDON_PATH="${PANEL_PATH}/resources/scripts/addons/${ADDON_NAME}"
API_ROUTE_FILE="${PANEL_PATH}/routes/api-client.php"
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
  cp "$API_ROUTE_FILE" "${BACKUP_DIR}/api.php.${TIMESTAMP}.bak"
fi

# Create addon directory
echo -e "${YELLOW}Creating addon directory...${NC}"
mkdir -p "$ADDON_PATH"

# Create Players.vue component
echo -e "${YELLOW}Creating Players.vue component...${NC}"
cat > "${ADDON_PATH}/Players.vue" << 'EOL'
<template>
  <div class="container">
    <div class="row">
      <div class="col-xs-12">
        <div class="panel panel-default">
          <div class="panel-heading">
            <h3 class="panel-title">Player List</h3>
          </div>
          <div class="panel-body">
            <div v-if="loading" class="text-center">
              <i class="fa fa-spinner fa-spin"></i> Loading player data...
            </div>
            <div v-else-if="error" class="alert alert-danger">
              {{ error }}
            </div>
            <div v-else>
              <div v-if="players.length === 0" class="alert alert-info">
                No players currently online.
              </div>
              <table v-else class="table table-striped table-bordered">
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Name</th>
                    <th>Score</th>
                    <th>Ping</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="player in players" :key="player.id">
                    <td>{{ player.id }}</td>
                    <td>{{ player.name }}</td>
                    <td>{{ player.score }}</td>
                    <td>{{ player.ping }}</td>
                  </tr>
                </tbody>
              </table>
              <p class="text-muted">Total players online: {{ players.length }}</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  data() {
    return {
      loading: true,
      error: null,
      players: [],
      refreshInterval: null
    }
  },
  mounted() {
    this.fetchPlayers();
    // Refresh every 30 seconds
    this.refreshInterval = setInterval(this.fetchPlayers, 30000);
  },
  beforeDestroy() {
    clearInterval(this.refreshInterval);
  },
  methods: {
    async fetchPlayers() {
      this.loading = true;
      this.error = null;
      
      try {
        const response = await axios.get('/api/client/servers/' + this.$route.params.uuid + '/players');
        this.players = response.data.players || [];
      } catch (error) {
        console.error('Failed to fetch players:', error);
        this.error = 'Failed to load player data. Please try again later.';
      } finally {
        this.loading = false;
      }
    }
  }
}
</script>

<style scoped>
.table {
  margin-top: 15px;
}
</style>
EOL

# Add API route
echo -e "${YELLOW}Adding API route...${NC}"
if ! grep -q "'/client/servers/{server}/players'" "$API_ROUTE_FILE"; then
  sed -i "/<?php/a \\nuse Illuminate\\Http\\Request;\nuse Illuminate\\Support\\Facades\\Route;\nuse GuzzleHttp\\Client;\nuse GuzzleHttp\\Exception\\RequestException;" "$API_ROUTE_FILE"
  
  cat >> "$API_ROUTE_FILE" << 'EOL'

Route::get('/client/servers/{server}/players', function (Request $request, $server) {
    $auth = $request->header('Authorization');
    $panelUrl = config('app.url');
    
    // Verify the server exists and get its details
    $client = new Client([
        'base_uri' => $panelUrl,
        'headers' => [
            'Authorization' => $auth,
            'Accept' => 'application/json',
        ],
        'verify' => false, // Only for development, remove in production
    ]);
    
    try {
        // Get server details
        $response = $client->get("/api/client/servers/{$server}");
        $serverData = json_decode($response->getBody(), true);
        
        // Check if this is the correct nest/egg
        if ($serverData['attributes']['nest_id'] != 40 || $serverData['attributes']['egg_id'] != 132) {
            return response()->json([
                'error' => 'This endpoint is only available for SA-MP servers (Nest 40, Egg 132)'
            ], 400);
        }
        
        // Get server IP and port
        $allocations = $serverData['attributes']['relationships']['allocations']['data'];
        $primaryAllocation = array_values(array_filter($allocations, function($alloc) {
            return $alloc['attributes']['is_default'];
        }))[0];
        
        $ip = $primaryAllocation['attributes']['ip'];
        $port = $primaryAllocation['attributes']['port'];
        
        // Query SA-MP server
        $queryClient = new Client([
            'timeout' => 5,
        ]);
        
        $queryResponse = $queryClient->get("http://api.samp-servers.net/v2/{$ip}:{$port}/info");
        $queryData = json_decode($queryResponse->getBody(), true);
        
        return response()->json([
            'players' => $queryData['players'] ?? [],
            'online' => $queryData['online'] ?? 0,
        ]);
        
    } catch (RequestException $e) {
        return response()->json([
            'error' => 'Failed to query server: ' . $e->getMessage()
        ], 500);
    } catch (Exception $e) {
        return response()->json([
            'error' => 'An error occurred: ' . $e->getMessage()
        ], 500);
    }
});
EOL
fi

# Set permissions
echo -e "${YELLOW}Setting permissions...${NC}"
chown -R www-data:www-data "$ADDON_PATH"
chmod 755 "$ADDON_PATH"

# Clear cache
echo -e "${YELLOW}Clearing cache...${NC}"
php artisan cache:clear
php artisan view:clear

echo -e "${GREEN}Installation completed successfully!${NC}"
echo -e "Backups are stored in: ${BACKUP_DIR}"
echo -e "You may need to configure your Pterodactyl frontend to include this addon in the navigation."

exit 0
