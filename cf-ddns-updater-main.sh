#!/usr/bin/env bash
set -euo pipefail

source /etc/cloudflare-ddns.env

# Validate IPv4
REIP='^((25[0-5]|(2[0-4]|1[0-9]|[1-9]|)[0-9])\.){3}(25[0-5]|(2[0-4]|1[0-9]|[1-9]|)[0-9])$'

# Get current public IPv4
IP="$(curl -4 -s https://api.ipify.org --max-time 10 || true)"
if [[ -z "$IP" || ! "$IP" =~ $REIP ]]; then
         logger -t cf-ddns "ERROR: Could not determine valid public IPv4 (got: '$IP')"
  exit 1
fi


# Get Zone ID
ZONE_ID="$(
  curl -sS -H "Authorization: Bearer $CF_API_TOKEN" \
       -H "Content-Type: application/json" \
       "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME" \
  | jq -r '.result[0].id'
)"
if [[ -z "${ZONE_ID}" || "${ZONE_ID}" == "null" ]]; then
        logger -t cf-ddns "ERROR: Could not resolve Zone ID for ${ZONE_NAME}"
  exit 1
fi

updated_any=0
update_lines=()

for RECORD in "${RECORDS[@]}"; do
  RECORD_JSON="$(
    curl -sS -H "Authorization: Bearer $CF_API_TOKEN" \
         -H "Content-Type: application/json" \
         "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$RECORD&type=A"
  )"

  RECORD_ID="$(echo "$RECORD_JSON" | jq -r '.result[0].id')"
  OLD_IP="$(echo "$RECORD_JSON" | jq -r '.result[0].content')"
  PROXIED="$(echo "$RECORD_JSON" | jq -r '.result[0].proxied')"

  if [[ -z "${RECORD_ID}" || "${RECORD_ID}" == "null" ]]; then
    logger -t cf-ddns "WARN: No A record found for ${RECORD} (skipping)"
    continue
  fi

  # Preserve current proxy state; default to true if missing/weird
  if [[ "${PROXIED}" != "true" && "${PROXIED}" != "false" ]]; then
    PROXIED="true"
  fi

  # No change needed
  if [[ "${IP}" == "${OLD_IP}" ]]; then
    continue
  fi

  # Update record
  curl -sS -X PUT \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
    --data "{\"type\":\"A\",\"name\":\"$RECORD\",\"content\":\"$IP\",\"ttl\":300,\"proxied\":$PROXIED}" \
    | jq -e '.success == true' >/dev/null
logger -t cf-ddns "Updated ${RECORD}: ${OLD_IP} -> ${IP} (proxied=${PROXIED})"
  updated_any=1
  update_lines+=( "Updated $RECORD: $OLD_IP -> $IP (proxied=$PROXIED)" )
done

# Notify via ntfy only if something changed
if [[ "${updated_any}" -eq 1 && -n "${NTFY_URL:-}" ]]; then
  DATE="$(date "+%Y-%m-%d %H:%M:%S")"
  MESSAGE="DDNS Alert: External IP Changed on $DATE, new IP is $IP

$(printf '%s\n' "${update_lines[@]}")"
  curl -sS -d "$MESSAGE" "$NTFY_URL" >/dev/null || true
fi
