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
ADDON_PATH="${PANEL_PATH}/resources/scripts/components/server/players"
API_ROUTE_FILE="${PANEL_PATH}/routes/api-client.php"
ROUTES_FILE="${PANEL_PATH}/resources/scripts/routes/server/index.ts"
NAVIGATION_FILE="${PANEL_PATH}/resources/scripts/components/server/ServerNavigation.tsx"
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

# Create addon directory
echo -e "${YELLOW}Creating addon directory...${NC}"
mkdir -p "$ADDON_PATH"

# Create PlayersContainer.tsx
echo -e "${YELLOW}Creating PlayersContainer component...${NC}"
cat > "${ADDON_PATH}/PlayersContainer.tsx" << 'EOL'
import React from 'react';
import { ServerContext } from '@/state/server';
import Players from '@/components/server/players/Players';

export default () => {
    const server = ServerContext.useStoreState(state => state.server.data!);
    
    return <Players server={server} />;
};
EOL

# Create Players.tsx
echo -e "${YELLOW}Creating Players component...${NC}"
cat > "${ADDON_PATH}/Players.tsx" << 'EOL'
import React, { useState, useEffect } from 'react';
import { Server } from '@/api/server/getServer';
import getServerPlayers from '@/api/server/players/getServerPlayers';
import Spinner from '@/components/elements/Spinner';
import { Alert } from '@/components/elements/alert';

interface Props {
    server: Server;
}

interface Player {
    id: number;
    name: string;
    score: number;
    ping: number;
}

export default ({ server }: Props) => {
    const [players, setPlayers] = useState<Player[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        const loadPlayers = () => {
            getServerPlayers(server.uuid)
                .then(data => {
                    setPlayers(data.players || []);
                    setError(null);
                })
                .catch(error => {
                    setError(error.message || 'Failed to load player data');
                })
                .finally(() => setLoading(false));
        };

        loadPlayers();
        const interval = setInterval(loadPlayers, 30000);

        return () => clearInterval(interval);
    }, [server.uuid]);

    return (
        <div className="bg-gray-900 p-6 rounded-lg">
            <h2 className="text-xl font-bold text-gray-100 mb-4">Players Online</h2>
            
            {loading ? (
                <Spinner size="large" centered />
            ) : error ? (
                <Alert type="danger">{error}</Alert>
            ) : players.length === 0 ? (
                <p className="text-gray-400">No players currently online.</p>
            ) : (
                <div className="overflow-x-auto">
                    <table className="w-full bg-gray-800 rounded">
                        <thead>
                            <tr className="border-b border-gray-700">
                                <th className="px-4 py-2 text-left text-gray-300">ID</th>
                                <th className="px-4 py-2 text-left text-gray-300">Name</th>
                                <th className="px-4 py-2 text-left text-gray-300">Score</th>
                                <th className="px-4 py-2 text-left text-gray-300">Ping</th>
                            </tr>
                        </thead>
                        <tbody>
                            {players.map(player => (
                                <tr key={player.id} className="border-b border-gray-700 hover:bg-gray-750">
                                    <td className="px-4 py-2 text-gray-300">{player.id}</td>
                                    <td className="px-4 py-2 text-gray-300">{player.name}</td>
                                    <td className="px-4 py-2 text-gray-300">{player.score}</td>
                                    <td className="px-4 py-2 text-gray-300">{player.ping}</td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                    <div className="mt-3 text-sm text-gray-400">
                        Total players: {players.length}
                    </div>
                </div>
            )}
        </div>
    );
};
EOL

# Create getServerPlayers.ts
echo -e "${YELLOW}Creating API wrapper...${NC}"
mkdir -p "${PANEL_PATH}/resources/scripts/api/server/players"
cat > "${PANEL_PATH}/resources/scripts/api/server/players/getServerPlayers.ts" << 'EOL'
import { AxiosError } from 'axios';
import http from '@/api/http';

interface PlayersResponse {
    players: Array<{
        id: number;
        name: string;
        score: number;
        ping: number;
    }>;
    online: number;
}

export default async (uuid: string): Promise<PlayersResponse> => {
    try {
        const { data } = await http.get(`/api/client/servers/${uuid}/players`);
        return data;
    } catch (e) {
        throw new Error(((e as AxiosError).response?.data as any)?.error || 'Failed to fetch players');
    }
};
EOL

# Add API route
echo -e "${YELLOW}Adding API route...${NC}"
if ! grep -q "'/client/servers/{server}/players'" "$API_ROUTE_FILE"; then
  grep -q "use GuzzleHttp" "$API_ROUTE_FILE" || sed -i "/<?php/a use GuzzleHttp\\Client;\nuse GuzzleHttp\\Exception\\RequestException;" "$API_ROUTE_FILE"
  
  cat >> "$API_ROUTE_FILE" << 'EOL'

Route::get('/client/servers/{server}/players', function (Request $request, $server) {
    $auth = $request->header('Authorization');
    $panelUrl = config('app.url');
    
    $client = new Client([
        'base_uri' => $panelUrl,
        'headers' => [
            'Authorization' => $auth,
            'Accept' => 'application/json',
        ],
        'verify' => false,
    ]);
    
    try {
        $response = $client->get("/api/client/servers/{$server}");
        $serverData = json_decode($response->getBody(), true);
        
        if ($serverData['attributes']['nest_id'] != 40 || $serverData['attributes']['egg_id'] != 132) {
            return response()->json([
                'error' => 'This endpoint is only available for SA-MP servers (Nest 40, Egg 132)'
            ], 400);
        }
        
        $allocations = $serverData['attributes']['relationships']['allocations']['data'];
        $primaryAllocation = array_values(array_filter($allocations, function($alloc) {
            return $alloc['attributes']['is_default'];
        }))[0];
        
        $ip = $primaryAllocation['attributes']['ip'];
        $port = $primaryAllocation['attributes']['port'];
        
        $queryClient = new Client(['timeout' => 5]);
        $queryResponse = $queryClient->get("http://api.samp-servers.net/v2/{$ip}:{$port}/info");
        $queryData = json_decode($queryResponse->getBody(), true);
        
        return response()->json([
            'players' => $queryData['players'] ?? [],
            'online' => $queryData['online'] ?? 0,
        ]);
        
    } catch (RequestException $e) {
        return response()->json(['error' => 'Failed to query server: ' . $e->getMessage()], 500);
    } catch (Exception $e) {
        return response()->json(['error' => 'An error occurred: ' . $e->getMessage()], 500);
    }
});
EOL
fi

# Add route to frontend
echo -e "${YELLOW}Adding frontend route...${NC}"
if [ -f "$ROUTES_FILE" ]; then
  if ! grep -q "path: '/players'" "$ROUTES_FILE"; then
    sed -i "/const routes = \[/a \\
    {\\
        path: '/players',\\
        permission: null,\\
        name: 'Players',\\
        component: lazy(() => import('@/components/server/players/PlayersContainer')),\\
    }," "$ROUTES_FILE"
  fi
fi

# Add navigation item
echo -e "${YELLOW}Adding navigation item...${NC}"
if [ -f "$NAVIGATION_FILE" ]; then
  if ! grep -q "name: 'Players'" "$NAVIGATION_FILE"; then
    sed -i "/const routes = \[/a \\
    {\\
        name: 'Players',\\
        path: 'players',\\
        icon: <UsersIcon />,\\
        permission: null,\\
    }," "$NAVIGATION_FILE"
    
    # Add import for UsersIcon if not already present
    if ! grep -q "UsersIcon" "$NAVIGATION_FILE"; then
      sed -i "/^import/ a import { Users as UsersIcon } from 'react-feather';" "$NAVIGATION_FILE"
    fi
  fi
fi


# Set permissions
echo -e "${YELLOW}Setting permissions...${NC}"
chown -R www-data:www-data "$ADDON_PATH"
chmod -R 755 "$ADDON_PATH"

# Build assets
echo -e "${YELLOW}Building frontend assets...${NC}"
cd "$PANEL_PATH" || exit
npm run build

echo -e "${GREEN}Installation completed successfully!${NC}"
echo -e "Backups are stored in: ${BACKUP_DIR}"
echo -e "You may need to restart your webserver for changes to take effect."

exit 0
