Namesilo DDNS CLI
===================

`namesilo_ddns_cli` is a command line tool for Namesilo DDNS, which is written in Bash depending on wget/curl only.

It is designed mainly to reduce dependences and system load as much as possible. 
Therefore, light-weight Linux distributions are especially appropriate to use it, like Raspberry, Openwrt, Merlin, Unraid, DSM, QTS...

# Version 2 Upgrade (2020.11)

* Rewrite based on Bash builtin commands, and remove all other dependences except for `wget` or `curl`.
* No API request needed for normal running by using cache in log, and possible for IP-checking with high frequency.
* Create running log with automatic compression and length control.
* Enable command-line support.

# Feathers

* [x] Multi-Domains Support
* [x] IPv4 & IPv6 Support
* [x] Load Balancing for IP-Check
* [x] Minimal API requests by Cache
* [x] Logging with Length Control

# Requirements

* `wget` or `curl`

# Usage

```bash
Usage: namesilo_ddns.sh <command> ... [parameters ...]
Commands:
  --help                   Show this help message
  --version                Show version info
  --key, -k <apikey>       Specify Namesilo API key
  --host, -h <host>        Add a hostname
  --refetch, -r            Refetch records from Namesilo

Example:
  namesilo_ddns.sh -k c40031261ee449037a4b44b1 \
      -h yourdomain1.tld \
      -h subdomain1.yourdomain1.tld \
      -h subdomain2.yourdomain2.tld

Exit codes:
    0    Successfully updating for all host(s)
    2    Exist updating failed host(s)
    9    Arguments error

Tips:
  Strongly recommand to refetch records or clear caches in log,
  if your DNS records have been updated by other ways.
```

You can also edit the configs and settings in the head of script.

# Applications

## Regular Running for common Linux

  1. SSH to your device , and place `namesilo_ddns.sh` into somewhere, like `/opt/ddns/`.
  (Note: For EdgeOS, the script should be placed in `/config/scripts/`)

  2. Make sure your permissions of destination and script:
```bash
chmod u+w /opt/ddns
chmod u+x /opt/ddns/namesilo_ddns.sh
```

  3. Edit crontab config:
```bash
crontab -e
```
  
  4. Insert and save this line (updating the two hosts every 5 minutes):
```bash
*/5 * * * *  /opt/ddns/namesilo_ddns.sh -k c40031261ee449037a4b44b1 -h subdomain1.yourdomain1.tld -h subdomain2.yourdomain2.tld
```


## Regular Running for Synology DSM

  1. Place `namesilo_ddns.sh` into somewhere in your NAS, e.g. `/homes/<yourname>/ddns/`.

  2. Start `Control Panel`, click `Advanced Mode`, open `Task Scheduler`.

  3. Access `Create` --> `Scheduled Task` --> `User-defined script`.

  4. Toggle to `Schedule` tab, set running every 5 minutes daily.

  5. Toggle to `Task Settings` tab, in `Run command` input edited command below, e.g.
```bash
/var/services/homes/<yourname>/ddns/namesilo_ddns.sh -k c40031261ee449037a4b44b1 -h subdomain1.yourdomain1.tld -h subdomain2.yourdomain2.tld
```

  6. If you check out `Send run details by email` and `... only when ... terminates abnormally`, you will receive mail when occur error.

    
## Use in Asuswrt-Merlin

### Why use this solution? If you want to

  * DDNS multiple hosts

  * DDNS IPv6 hosts

  * reduce API requests greatly

  * check updating log

### Setup

  1. Edit the API key and hosts in this script, and save as `ddns-start`.
```bash
#!/usr/bin/env bash

./namesilo_ddns.sh -k c40031261ee449037a4b44b1 \
      -h subdomain1.yourdomain1.tld \
      -h subdomain2.yourdomain2.tld

if [ $? -eq 0 ]; then
  /sbin/ddns_custom_updated 1
else
  /sbin/ddns_custom_updated 0
fi
```

  2. SSH to  your router and place `ddns-start` and `namesilo_ddns.sh` under `/jffs/scripts/`.

  3. Make sure your permissions of destination and script:
```bash
chmod u+w /jffs/scripts
chmod u+x /jffs/scripts/namesilo_ddns.sh
chmod u+x /jffs/scripts/ddns-start
```

  4. Log into the router web UI:
      - Go to `Advanced Settings` > `WAN` > `DDNS`
      - Set `Server` to `Custom`
      - Click the `Apply` button

- [Reference](https://github.com/alphabt/asuswrt-merlin-ddns-namesilo)
