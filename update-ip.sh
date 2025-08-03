#!/bin/bash


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    echo "ERROR: .env file not found: $SCRIPT_DIR/.env"
    exit 1
fi

if [ -z "$CF_API_TOKEN" ] || [ -z "$CF_ZONE_ID" ] || [ -z "$CF_RECORD_NAME" ]; then
    echo "ERROR: Required .env variables are missing!"
    echo "Define the CF_API_TOKEN, CF_ZONE_ID, and CF_RECORD_NAME variables in the .env file."
    exit 1
fi


LOG_FILE="${LOG_FILE:-$SCRIPT_DIR/dns_updater.log}"
IP_FILE="${IP_FILE:-$SCRIPT_DIR/last_ip.txt}"
CF_API_URL="https://api.cloudflare.com/client/v4"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

get_current_ip() {
    local ip

    ip=$(curl -s --connect-timeout 10 https://api.ipify.org)
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "$ip"
        return 0
    fi

    ip=$(curl -s --connect-timeout 10 https://icanhazip.com | tr -d '\n')
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "$ip"
        return 0
    fi

    ip=$(curl -s --connect-timeout 10 https://httpbin.org/ip | grep -o '"origin":"[^"]*' | cut -d'"' -f4 | cut -d',' -f1)
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "$ip"
        return 0
    fi

    return 1
}

get_dns_record() {
    local response
    response=$(curl -s -X GET "$CF_API_URL/zones/$CF_ZONE_ID/dns_records?name=$CF_RECORD_NAME&type=A" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json")

    if [ $? -ne 0 ]; then
        return 1
    fi

    echo "$response"
}

update_dns_record() {
    local record_id="$1"
    local new_ip="$2"

    local response
    response=$(curl -s -X PUT "$CF_API_URL/zones/$CF_ZONE_ID/dns_records/$record_id" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"$CF_RECORD_NAME\",\"content\":\"$new_ip\",\"ttl\":${CF_TTL:-300}}")

    if [ $? -ne 0 ]; then
        return 1
    fi

    echo "$response"
}

main() {
    log "[START]"

    # Mevcut IP adresini al
    log "Current public IP address is being retrieved..."
    current_ip=$(get_current_ip)

    if [ -z "$current_ip" ]; then
        log "ERROR: Current IP address could not be obtained"
        exit 1
    fi

    log "Current IP: $current_ip"

    # Önceki IP adresini kontrol et
    if [ -f "$IP_FILE" ]; then
        last_ip=$(cat "$IP_FILE" 2>/dev/null)
        log "Previous IP: $last_ip"

        if [ "$current_ip" = "$last_ip" ]; then
            log "The IP address has not changed, no update is required."
            exit 0
        fi
    else
        log "First work - no previous IP record"
    fi

    # Cloudflare DNS kaydını al
    log "Checking Cloudflare DNS record..."
    dns_response=$(get_dns_record)

    if [ -z "$dns_response" ]; then
        log "ERROR: Unable to access Cloudflare API"
        exit 1
    fi

    # JSON response'u parse et
    success=$(echo "$dns_response" | grep -o '"success":[^,]*' | cut -d':' -f2)

    if [ "$success" != "true" ]; then
        log "ERROR: Cloudflare API error: $dns_response"
        exit 1
    fi

    # DNS kayıt bilgilerini al
    record_id=$(echo "$dns_response" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
    current_dns_ip=$(echo "$dns_response" | grep -o '"content":"[^"]*' | head -1 | cut -d'"' -f4)

    if [ -z "$record_id" ]; then
        log "ERROR: DNS record not found: $CF_RECORD_NAME"
        exit 1
    fi

    log "DNS record ID: $record_id"
    log "Current IP in DNS: $current_dns_ip"

    if [ "$current_ip" != "$current_dns_ip" ]; then
        log "IP address has changed, DNS record is being updated..."

        update_response=$(update_dns_record "$record_id" "$current_ip")

        if [ -z "$update_response" ]; then
            log "ERROR: DNS record could not be updated"
            exit 1
        fi

        update_success=$(echo "$update_response" | grep -o '"success":[^,]*' | cut -d':' -f2)

        if [ "$update_success" = "true" ]; then
            log "SUCCESSFUL: DNS record updated ($current_dns_ip -> $current_ip)"
            echo "$current_ip" > "$IP_FILE"
        else
            log "ERROR: DNS record could not be updated: $update_response"
            exit 1
        fi
    else
        log "The IP in the DNS record is already up to date."
        echo "$current_ip" > "$IP_FILE"
    fi

    log "DNS updater completed"
}

main "$@"