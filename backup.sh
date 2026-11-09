#!/usr/bin/env bash
# Consistent backup: maintenance mode on, dump the database, copy files, maintenance mode off.
#
# Usage: sudo bash backup.sh /mnt/backup-disk/pi-cloud
# Run it from cron or a systemd timer for scheduled backups.
set -euo pipefail

cd "$(dirname "$0")"

BACKUP_DIR="${1:?Usage: $0 /path/to/backup/dir}"
STORAGE_ROOT="$(grep -E '^STORAGE_ROOT=' .env | cut -d= -f2-)"
STAMP="$(date +%Y-%m-%d_%H%M)"

occ() {
  docker compose exec -T -u www-data app php occ "$@"
}

mkdir -p "$BACKUP_DIR/db"

# Always leave maintenance mode, even if a step below fails.
trap 'occ maintenance:mode --off >/dev/null || true' EXIT
occ maintenance:mode --on

echo "Dumping database..."
docker compose exec -T db pg_dump -U nextcloud -d nextcloud --format=custom \
  > "$BACKUP_DIR/db/nextcloud_$STAMP.dump"

echo "Copying config and data..."
rsync -a --delete "$STORAGE_ROOT/html/config/" "$BACKUP_DIR/config/"
rsync -a --delete "$STORAGE_ROOT/data/" "$BACKUP_DIR/data/"

# Keep the 14 newest database dumps.
find "$BACKUP_DIR/db" -name 'nextcloud_*.dump' -type f -printf '%T@ %p\n' \
  | sort -rn | tail -n +15 | cut -d' ' -f2- | xargs -r rm --

echo "Backup finished: $BACKUP_DIR (database dump nextcloud_$STAMP.dump)"
