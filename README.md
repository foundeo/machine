# machine

## Setup

Run `setup-ubuntu.sh` using `sudo` or as `root`

    git clone https://github.com/foundeo/machine.git
    chmod a+x setup-ubuntu.sh
    ./setup-ubuntu.sh

Check to make sure it is working by running:

    box version

## Create a machine.json file

    {
        "stage":"production",

        "webserver": {
            "type":"nginx"
        },

        "sites": {
            "example": {
                "path": "/web/example.com/",
                "wwwroot": "",
                "host": "example.com",
                "aliases": ["www.example.com"],
                "webserver": {
                    "https": true,
                    "ssl_certificate": "/etc/letsencrypt/live/example.com/fullchain.pem",
                    "ssl_certificate_key": "/etc/letsencrypt/live/example.com/privkey.pem",
                    "ssl_trusted_certificate": "/etc/letsencrypt/live/example.com/chain.pem"
                },
                "deploy": {
                    "git": "https://github.com/foundeo/cfmetrics.git"
                }
            }
            
        }
    }

## Apply the machine.json to the server

The machine command is an admin tool, and is indended to run as root. So always run with `sudo` or as `root`, the servers it creates will not run as root.

    box machine apply /path/to/machine.json

### What does `machine apply` do?

For each site defined it will do the following:

1) Clones the git repository (`deploy/git`) to the `path`
2) Creates a user with the site_id (`example` in this case)
3) Creates a systemd service (named `example` in this case) which runs as the user created
4) Sets up a nginx site (creates `/etc/nginx/sites-enabled/example.conf`)
