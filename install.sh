#!/bin/bash

# Installer untuk SA-MP Player List Addon
# Pastikan dijalankan sebagai root

PANEL_PATH="/var/www/pterodactyl"
TEMP_DIR="/tmp/pterodactyl_samp_addon"

echo -e "\033[1;34mMemulai instalasi addon Player List SA-MP\033[0m"

# Buat direktori temp
mkdir -p $TEMP_DIR
cd $TEMP_DIR

# Download dependency PHP
echo "Mengunduh samp-query PHP library..."
wget -O samphp-query.zip https://github.com/samphp/query/archive/refs/heads/master.zip
unzip samphp-query.zip
mv query-master $PANEL_PATH/vendor/samphp/query

# Buat file controller
echo "Membuat PlayerController..."
cat > $PANEL_PATH/app/Http/Controllers/Api/Client/Servers/PlayerController.php <<EOL
<?php

namespace App\Http\Controllers\Api\Client\Servers;

use Illuminate\Http\Request;
use App\Http\Controllers\Controller;
use App\Models\Server;
use Illuminate\Support\Facades\Log;
use SampQuery\SampQuery;

class PlayerController extends Controller
{
    public function index(Server \$server)
    {
        if (\$server->nest_id !== 40 || \$server->egg_id !== 132) {
            return response()->json(['error' => 'Fitur ini tidak tersedia untuk server ini'], 403);
        }

        try {
            \$allocations = \$server->allocations;
            \$primaryAllocation = \$allocations->firstWhere('is_default', true);

            if (!\$primaryAllocation) {
                throw new \Exception('Alokasi server tidak ditemukan');
            }

            \$query = new SampQuery(\$primaryAllocation->ip, \$primaryAllocation->port);
            \$players = \$query->getPlayers();

            return response()->json([
                'players' => array_map(function (\$player) {
                    return [
                        'id' => \$player['id'],
                        'name' => \$player['name'],
                        'score' => \$player['score'],
                        'ping' => \$player['ping']
                    ];
                }, \$players)
            ]);
        } catch (\Exception \$e) {
            Log::error('SA-MP Query Error: ' . \$e->getMessage());
            return response()->json(['error' => 'Gagal mengambil data pemain'], 500);
        }
    }
}
EOL

# Tambahkan route API
echo "Menambahkan route API..."
grep -q "PlayerController" $PANEL_PATH/routes/api.php || sed -i "/Route::group(['prefix' => 'client'], function () {/a \    Route::get('/servers/{server}/players', 'Api\\\\Client\\\\Servers\\\\PlayerController@index');" $PANEL_PATH/routes/api.php

# Buat komponen frontend
echo "Membuat komponen frontend..."
mkdir -p $PANEL_PATH/resources/scripts/components/server/players

cat > $PANEL_PATH/resources/scripts/components/server/players/PlayerListContainer.tsx <<EOL
import React, { useEffect, useState } from 'react';
import { ServerContext } from '@/state/server';
import useFlash from '@/plugins/useFlash';
import { http } from '@/helpers/http';
import Spinner from '@/components/elements/Spinner';
import tw from 'twin.macro';
import styled from 'styled-components';
import GreyRowBox from '@/components/elements/GreyRowBox';
import PageContentBlock from '@/components/elements/PageContentBlock';

const Container = styled.div\`
    \${tw\`text-2xl flex flex-col\`};
\`;

const PlayerRow = ({ player }: { player: any }) => (
    <GreyRowBox css={tw\`mb-2\`}>
        <div css={tw\`flex items-center\`}>
            <div css={tw\`ml-4 flex-1 overflow-hidden\`}>
                <p css={tw\`text-sm break-words\`}>{player.name}</p>
                <p css={tw\`text-2xs text-neutral-300 uppercase break-words\`}>
                    Score: {player.score}, Ping: {player.ping}
                </p>
            </div>
        </div>
    </GreyRowBox>
);

export default () => {
    const [players, setPlayers] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);
    const { clearFlashes, addFlash } = useFlash();
    const uuid = ServerContext.useStoreState(state => state.server.data!.uuid);
    const server = ServerContext.useStoreState(state => state.server.data!);

    useEffect(() => {
        setLoading(true);
        clearFlashes('players');
        
        http.get(\`/api/client/servers/\${uuid}/players\`)
            .then(data => {
                setPlayers(data.players || []);
                setLoading(false);
            })
            .catch(error => {
                console.error(error);
                addFlash({ key: 'players', type: 'error', message: 'Gagal memuat data pemain' });
                setLoading(false);
            });
    }, []);

    return (
        <PageContentBlock title={'Player List'}>
            <Container>
                <h1 css={tw\`text-3xl mb-4\`}>Daftar Pemain Online</h1>
                
                {loading ? (
                    <Spinner size={'large'} centered />
                ) : players.length < 1 ? (
                    <p css={tw\`text-center text-sm text-neutral-400\`}>
                        Tidak ada pemain yang online
                    </p>
                ) : (
                    players.map((player, index) => (
                        <PlayerRow key={index} player={player} />
                    ))
                )}
            </Container>
        </PageContentBlock>
    );
};
EOL

# Tambahkan route frontend
echo "Menambahkan route frontend..."
sed -i "/import { ServerContext } from '@/state\/server';/a import PlayerListContainer from '@/components/server/players/PlayerListContainer';" $PANEL_PATH/resources/scripts/routes/server/ServerRouter.tsx
sed -i "/<Route path={match.path} component={ServerConsole} exact \/>/a \            <Route path=\`\${match.path}/players\`} component={PlayerListContainer} />" $PANEL_PATH/resources/scripts/routes/server/ServerRouter.tsx

# Tambahkan menu navigasi
echo "Menambahkan menu navigasi..."
sed -i "/import { NavLink, useRouteMatch } from 'react-router-dom';/a import useServer from '@/plugins/useServer';" $PANEL_PATH/resources/scripts/components/server/ServerConsole.tsx
sed -i "/const match = useRouteMatch();/a const server = useServer();" $PANEL_PATH/resources/scripts/components/server/ServerConsole.tsx
sed -i "/<\/NavLink>/a {server.nestId === 40 \&\& server.eggId === 132 \&\& (\n                <NavLink to=\`\${match.url}/players\`>\n                    Players\n                </NavLink>\n            )}" $PANEL_PATH/resources/scripts/components/server/ServerConsole.tsx

# Update composer autoload
echo "Memperbarui autoload composer..."
cd $PANEL_PATH
composer dump-autoload

# Set permissions
chown -R www-data:www-data $PANEL_PATH
echo -e "\033[1;32mAutoload berhasil diperbarui\033[0m"

# Build frontend
echo "Membangun aset frontend (mungkin memakan waktu)..."
yarn install
yarn build:production
echo -e "\033[1;32mBuild frontend selesai\033[0m"

# Bersihkan temp
rm -rf $TEMP_DIR

echo -e "\033[1;32m\nInstalasi berhasil!\n\033[0m"
echo "Fitur Player List sekarang tersedia untuk:"
echo "- Nest ID: 40"
echo "- Egg ID: 132"
