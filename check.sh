#!/bin/bash

# Cloudflare API Test Script
# Checks if Zone ID and API Token are configured correctly

# Load .env file
if [ -f ".env" ]; then
    source .env
else
    echo "ERROR: .env file not found!"
    exit 1
fi

echo "=== Cloudflare API Test ==="
echo "Zone ID: $CF_ZONE_ID"
echo "Record Name: $CF_RECORD_NAME"
echo "API Token: ${CF_API_TOKEN:0:10}..." # Show only first 10 characters
echo ""

# 1. Check zone information
echo "1. Checking zone information..."
zone_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json")

echo "Zone Response: $zone_response"
echo ""

# Check zone success
zone_success=$(echo "$zone_response" | grep -o '"success":[^,]*' | cut -d':' -f2)
if [ "$zone_success" = "true" ]; then
    zone_name=$(echo "$zone_response" | grep -o '"name":"[^"]*' | cut -d'"' -f4)
    echo "✅ Zone found successfully: $zone_name"
else
    echo "❌ Zone not found or API token permissions insufficient"
    echo "Errors:"
    echo "$zone_response" | grep -o '"message":"[^"]*' | cut -d'"' -f4
    exit 1
fi

echo ""

# 2. List DNS records
echo "2. Checking DNS records..."
dns_response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?type=A" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json")

echo "DNS Response: $dns_response"
echo ""

# Check DNS success
dns_success=$(echo "$dns_response" | grep -o '"success":[^,]*' | cut -d':' -f2)
if [ "$dns_success" = "true" ]; then
    echo "✅ DNS records retrieved successfully"

    # List A records
    echo ""
    echo "Current A records:"
    echo "$dns_response" | grep -o '"name":"[^"]*","content":"[^"]*' | while read record; do
        name=$(echo "$record" | cut -d'"' -f4)
        ip=$(echo "$record" | cut -d'"' -f8)
        echo "  - $name → $ip"
    done

    # Search for target record
    echo ""
    echo "3. Checking target record: $CF_RECORD_NAME"
    target_record=$(echo "$dns_response" | grep "\"name\":\"$CF_RECORD_NAME\"")
    if [ -n "$target_record" ]; then
        target_ip=$(echo "$target_record" | grep -o '"content":"[^"]*' | cut -d'"' -f4)
        echo "✅ Target record found: $CF_RECORD_NAME → $target_ip"
    else
        echo "❌ Target record not found: $CF_RECORD_NAME"
        echo "Please verify that the DNS record exists and the name is correct"
    fi

else
    echo "❌ Could not retrieve DNS records"
    echo "Errors:"
    echo "$dns_response" | grep -o '"message":"[^"]*' | cut -d'"' -f4
fi

echo ""
echo "=== Test Completed ==="