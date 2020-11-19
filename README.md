Namesilo DDNS without Dependences
===================

`namesilo_ddns_wodep` is a shell script for Namesilo DDNS based on Bash builtin commands.

It is designed for light-weight Linux distributions to dispense with 3rd-party dependences or libraries.

### Version 2 Upgrade (2020.11)

* Rewrite based on Bash builtin commands, and remove all other dependences except for `wget` or `curl`.
* No API request needed for normal running by using cache, and possible for IP-checking with high frequency.
* Create running log with automatic compression and length control.
* Enable command-line support.

### Feathers

* [x] Multi-Domains Support
* [x] IPv4 & IPv6 Support
* [x] Command-Line Support
* [x] Load Balancing for IP-Checking
* [x] Logging with length control
* [x] Minimal API requests

### Requirements

* Necessary: `wget` or `curl`
* Optional:  `date`, `sleep`

### Tested System

* `DSM 6.2.3`
* `Ubuntu 20.04.1 LTS (WSL2)`
* `EdgeOS (Debian 9)`

### Usage

```
Usage: namesilo_ddns.sh <command> ... [parameters ...]
Commands:
  --help                   Show this help message
  --version                Show version info
  --key, -k <apikey>       Specify API key of Namesilo
  --host, -h <host>        Add a host for DDNS
  --force-fetch            Force fetching cached records
  --force-update           Force updating unchanged IP
  --ipv4/--ipv6 <ipaddr>   Filter records to be updated with
                             the IP address (default: auto)

Example:
  namesilo_ddns.sh -k c40031261ee449037a4b44b1 \
      -h yourdomain1.tld \
      -h subdomain1.yourdomain1.tld \
      -h subdomain2.yourdomain2.tld

Exit codes:
    0    All hosts have been updated successful.
    1    Occur error during preparing parameters.
    2    Occur error during fetching & updating records.

Tips:
  Recommand to force fetching records or delete cache in log,
  if one of your DNS records have been modified in other ways.
```

You can also edit the configs and settings in the head of script.
