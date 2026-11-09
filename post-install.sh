#!/usr/bin/env bash
# One-time tuning after the first `docker compose up -d` has finished installing.
#
# Usage: bash post-install.sh
set -euo pipefail

cd "$(dirname "$0")"

occ() {
  docker compose exec -T -u www-data app php occ "$@"
}

echo "Waiting for Nextcloud to finish installing..."
for _ in $(seq 1 60); do
  if occ status --output=json 2>/dev/null | grep -q '"installed":true'; then
    break
  fi
  sleep 5
done
occ status

# Background jobs run from the cron container instead of on page loads.
occ background:cron

# Run heavy background jobs between 01:00 and 05:00 UTC.
occ config:system:set maintenance_window_start --type=integer --value=1

# Lets Nextcloud parse phone numbers without a country code.
occ config:system:set default_phone_region --value=DE

# Add any missing database indices (cheap, avoids admin-panel warnings).
occ db:add-missing-indices

echo "Done. Check Administration settings > Overview for remaining warnings."
