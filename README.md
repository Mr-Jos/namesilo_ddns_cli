Namesilo DDNS without Dependences
===================

`namesilo_ddns_wodep` is a shell script for Namesilo DDNS updating.

It is designed for light-weight Linux distributions to dispense with 3rd-party dependences or libraries.

### Feathers

* [x] Multi-Domains Support
* [x] IPv4 & IPv6 Support
* [x] Updating Report
* [x] Automatic TTL Inheriting
* [x] Minimal Calling Namesilo API
* [x] Public IP Request Balancing

### Requirements:
* Necessary: `wget` or `curl`
* Optional:  `ping` `ping6` `sleep`

### Test

Tested in `DSM 6.1.7`, `Ubuntu 16.04 LTS`, `Centos 7.4.1708`.

## Usage

### For General Linux Distributions

1. Download the script to somewhere, e.g. `/opt/namesilo_ddns_wodep.sh`

2. Edit the script, set your `APIKEY` and `HOST` at the beginning.

3. Run the script and test your settings.

4. (Optional) Create cronjob. Edit `/etc/crontab` and add the line below:

        40  *  *  *  *  /opt/namesilo_ddns_wodep.sh


### For Synology DSM

1. Download the script to your PC.

2. Edit the script, set your `APIKEY` and `HOST` at the beginning.

3. Log in your Synology DSM and start `File Station`, upload the script to your home directory, e.g. `/homes/<yourname>/`

4. Set `Task Scheduler`.
    * Start `Control Panel`, click `Advanced Mode`, open `Task Scheduler`
    * Access `Create` --> `Scheduled Task` --> `User-defined script`
    * Set `Schedule`, e.g. run every 1 hour daily
    * Set `Task Settings`, input `Run command`, e.g.

            /var/services/homes/<yourname>/namesilo_ddns_wodep.sh

    * (Optional) Send report via mail. Check out `Send run details by email` and `... only when ... terminates abnormally`. The report will not be sent if no record is updated.
