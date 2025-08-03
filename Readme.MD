# Home Assistant Cloudflare Remote Access

Home Assistant Cloudflare Remote Access makes your Home Assistant system securely, quickly, and reliably accessible through Cloudflare. It enables you to manage your smart home from anywhere in the world without opening ports on your router or setting up a VPN.



## If you have a domain and your modem allows port forwarding
You can automatically assign your external IP to the domain you specified by forwarding it to your device with Home Assistant installed on your modem.


> Important : You need to specify the ports you can use at [https://developers.cloudflare.com/fundamentals/reference/network-ports/](https://developers.cloudflare.com/fundamentals/reference/network-ports/).


## Env Settings

```
CF_API_TOKEN=your_cloudflare_api_token_here

CF_ZONE_ID=your_zone_id_here

CF_RECORD_NAME=has.yourdomain.com

CF_TTL=300

LOG_FILE=/var/log/dns_updater.log

IP_FILE=/tmp/last_ip.txt
```

After setting your .env file, you can define a cron job that will be triggered at any time (hourly is recommended) from the directory where you installed it.


If you want to check the env values, the check.sh script will check your env values and provide information.


## Alternative: Zero Trust

I will also write a script for its automatic installation. You can think of this as a to-do list.