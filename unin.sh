#!/bin/bash

# Uninstaller untuk SA-MP Player List Addon
# Pastikan dijalankan sebagai root

PANEL_PATH="/var/www/pterodactyl"

echo -e "\033[1;34mMemulai penghapusan addon Player List SA-MP\033[0m"

# Hapus controller
echo "Menghapus PlayerController..."
rm -f $PANEL_PATH/app/Http/Controllers/Api/Client/Servers/PlayerController.php

# Hapus route API
echo "Menghapus route API..."
sed -i "/Route::get('\/servers\/{server}\/players.*/d" $PANEL_PATH/routes/api.php

# Hapus komponen frontend
echo "Menghapus komponen frontend..."
rm -rf $PANEL_PATH/resources/scripts/components/server/players

# Hapus route frontend
echo "Menghapus route frontend..."
sed -i "/import PlayerListContainer from '.\/players\/PlayerListContainer';/d" $PANEL_PATH/resources/scripts/routes/server/ServerRouter.tsx
sed -i "/<Route path=\`\${match.path}\/players\`} component={PlayerListContainer} \/>/d" $PANEL_PATH/resources/scripts/routes/server/ServerRouter.tsx

# Hapus menu navigasi
echo "Menghapus menu navigasi..."
sed -i "/import useServer from '.\/plugins\/useServer';/d" $PANEL_PATH/resources/scripts/components/server/ServerConsole.tsx
sed -i "/const server = useServer();/d" $PANEL_PATH/resources/scripts/components/server/ServerConsole.tsx
sed -i "/{server.nestId === 40 \&\& server.eggId === 132 \&\& (/,/)}/d" $PANEL_PATH/resources/scripts/components/server/ServerConsole.tsx

# Hapus dependency
echo "Menghapus dependency..."
rm -rf $PANEL_PATH/vendor/samphp/query

# Update composer autoload
echo "Memperbarui autoload composer..."
cd $PANEL_PATH
composer dump-autoload

# Set permissions
chown -R www-data:www-data $PANEL_PATH
echo -e "\033[1;32mAutoload berhasil diperbarui\033[0m"

# Build frontend
echo "Membangun ulang aset frontend..."
yarn build:production
echo -e "\033[1;32mBuild frontend selesai\033[0m"

echo -e "\033[1;32m\nPenghapusan berhasil!\n\033[0m"
echo "Fitur Player List telah dihapus dari panel"
