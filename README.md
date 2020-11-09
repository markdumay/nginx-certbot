# nginx-certbot (work in progress)

<!-- Tagline -->
<p align="center">
    <b>Automatically Renew Certificates For an Unprivileged Nginx Web Server</b>
    <br />
</p>


<!-- Badges -->
<p align="center">
    <a href="https://github.com/markdumay/nginx-certbot/commits/master" alt="Last commit">
        <img src="https://img.shields.io/github/last-commit/markdumay/nginx-certbot.svg" />
    </a>
    <a href="https://github.com/markdumay/nginx-certbot/issues" alt="Issues">
        <img src="https://img.shields.io/github/issues/markdumay/nginx-certbot.svg" />
    </a>
    <a href="https://github.com/markdumay/nginx-certbot/pulls" alt="Pulls">
        <img src="https://img.shields.io/github/issues-pr-raw/markdumay/nginx-certbot.svg" />
    </a>
    <a href="https://github.com/markdumay/nginx-certbot/blob/master/LICENSE" alt="License">
        <img src="https://img.shields.io/github/license/markdumay/nginx-certbot.svg" />
    </a>
</p>

<!-- Table of Contents -->
<p align="center">
  <a href="#about">About</a> •
  <a href="#built-with">Built With</a> •
  <a href="#prerequisites">Prerequisites</a> •
  <a href="#testing">Testing</a> •
  <a href="#deployment">Deployment</a> •
  <a href="#usage">Usage</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#credits">Credits</a> •
  <a href="#donate">Donate</a> •
  <a href="#license">License</a>
</p>


## About
[Nginx][nginx_url] is a popular open-source web server and reverse proxy. This repository sets up Nginx as an unprivileged Docker container to make it more secure. Furthermore, it uses [certbot][certbot_url] to automatically install and renew Let's Encrypt certificates, enabling Nginx to act as an HTTPS server. Certbot is run as a root-less container too. The script uses a DNS-01 challenge to support automated installation and renewal of wildcard certificates. More than 10 different DNS providers are supported, or any DNS server supporting RFC 2136 Dynamic Updates.

<!-- TODO: add tutorial deep-link 
Detailed background information is available on the author's [personal blog][blog].
-->

## Built With
The project uses the following core software components:
* [Certbot][certbot_url] - Open-source software tool for automatically using Let’s Encrypt certificates on manually-administrated websites to enable HTTPS.
* [Docker][docker_url] - Open-source container platform.
* [Nginx][nginx_url] - Open-source web server and reverse proxy.

## Prerequisites
*Nginx-certbot* can run on any Docker-capable host. The setup has been tested locally on macOS Catalina and in production on a server running Ubuntu 20.04 LTS. DNS integration has been tested with Cloudflare, although other DNS plugins are supported too. Additional prerequisites are:

* **A registered domain name is required** - A domain name is required to configure SSL certificates that will enable secure traffic to your web server.

* **Docker Engine and Docker Compose are required** - *nginx-certbot* is to be deployed as Docker container using Docker Compose for convenience. Docker Swarm is a prerequisite to enable Docker *secrets*, however, the use of Docker secrets itself is optional. This [reference guide][swarm_init] explains how to initialize Docker Swarm on your host.

* **A DNS provider supported by certbot is required** - *nginx-certbot* uses a DNS-01 challenge to issue and renew wildcard certificates automatically. As such, an account and token for a supported DNS provider is required. Supported DNS providers and protocols are: [Cloudflare][certbot-dns-cloudflare], [CloudXNS][certbot-dns-cloudxns], [Digital Ocean][certbot-dns-digitalocean], [DNSimple][certbot-dns-dnsimple], [DNS Made Easy][certbot-dns-dnsmadeeasy], [Gehirn][certbot-dns-gehirn], [Google][certbot-dns-google], [Linode][certbot-dns-linode], [LuaDNS][certbot-dns-luadns], [NS1][certbot-dns-nsone], [OVH][certbot-dns-ovh],
[RFC 2136 Dynamic Updates][certbot-dns-rfc2136], [AWS Route 53][certbot-dns-route53], and [Sakura Cloud DNS][certbot-dns-sakuracloud]. Click on each link to identify the required account and/or token information.


## Testing
It is recommended to test the services locally before deploying them in a production environment. Running the services with `docker-compose` greatly simplifies validating everything is working as expected. Below four steps will allow you to run the services on your local machine and validate they are working correctly.

### Step 1 - Clone the Repository
The first step is to clone the repository to a local folder. Assuming you are in the working folder of your choice, clone the repository files with `git clone`. Git automatically creates a new folder `nginx-certbot` and copies the files to this directory. The option `--recurse-submodules` ensures the embedded submodules are fetched too. Change your working folder to be prepared for the next steps. The code examples use `example.com` as the domain name and `cloudflare` as the DNS provider, replace them with the correct values.

```console
git clone --recurse-submodules https://github.com/markdumay/nginx-certbot.git
cd nginx-certbot
```

### Step 2 - Update the Environment Variables
The `docker-compose.yml` file uses environment variables to simplify the configuration. You can use the sample file in the repository as a starting point.

```console
mv sample.env .env
```

The `.env` file specifies eight variables. Adjust them as needed:


| Variable                            | Mandatory | Example            | Description |
|-------------------------------------|-----------|--------------------|-------------|
| **CERTBOT_DOMAIN**                  | Yes       | `example.com`      | Domain for which certbot will issue a wildcard certificate. Both `*.example.com` and `example.com` are issued. This means that, for example, `www.example.com` is covered by the certificate. However, `thisisa.subdomain.example.com` is not covered, as this requires a wildcard certificate for `*.subdomain.example.com`. |
| **CERTBOT_EMAIL**                   | Yes       | `mail@example.com` | An administrative email account to receive notifications from Let's Encrypt on.
| **CERTBOT_DNS_PLUGIN**              | Yes       | `cloudflare`       | A DNS provider supported by certbot. Supported values are [cloudflare][certbot-dns-cloudflare], [cloudxns][certbot-dns-cloudxns], [digitalocean][certbot-dns-digitalocean], [dnsimple][certbot-dns-dnsimple], [dnsmadeeasy][certbot-dns-dnsmadeeasy], [gehirn][certbot-dns-gehirn], [google][certbot-dns-google], [linode][certbot-dns-linode], [luadns][certbot-dns-luadns], [nsone][certbot-dns-nsone], [ovh][certbot-dns-ovh], [rfc2136][certbot-dns-rfc2136], [route53][certbot-dns-route53], and [sakuracloud][certbot-dns-sakuracloud]. Click on each link to identify the required account and/or token information. 
| **CERTBOT_DNS_PROPAGATION_SECONDS** | No        | `30`               | The duration in seconds for which certbot will await the DNS provider to have propagated the DNS-01 challenge text records. Adjust the value if needed, as the default value for each DNS provider might be too short, resulting in a validation error.
| **CERTBOT_DEPLOYMENT**              | Yes       | `test`             | Options are `test` or `production`. Use `test` for testing purposes to avoid hitting rate limits from Let's Encrypt. In test mode, no actual certificates are installed. |
| **HOST_PORT_HTTP**                  | Yes       | `80`               | The host port to map the nginx web server to for HTTP traffic. The default value for HTTP traffic is port 80, which needs to be available on your host.
| **HOST_PORT_HTTPS**                 | Yes       | `443`              | The host port to map the nginx web server to for secure, HTTPS traffic. The default value for HTTPS traffic is port 443, which needs to be available on your host.
| **NGINX_PORT_HTTP**                 | Yes       | `8080`             | The internal port for HTTP traffic within the nginx container. The value needs to be greater than 1023, as the container runs in unprivileged (non-root) mode.
| **NGINX_PORT_HTTPS**                | Yes       | `4430`             | The internal port for HTTPS traffic within the nginx container. The value needs to be greater than 1023, as the container runs in unprivileged (non-root) mode.

### Step 3 - Specify DNS Credentials
Pending on your selected DNS provider, you will need to specify the API token and/or account credentials to connect with the DNS provider for the automated DNS-01 challenge. You can either specify the credentials as environment variables or as Docker secrets. Docker secrets are a bit more secure and are more suitable for a production environment. Please check the documentation of your DNS provider in the <a href="#prerequisites">Prerequisites</a> section. 

#### Option 3a - Using Environment Variables
Following the recommended [cloudflare][certbot-dns-cloudflare] configuration, you will need to add an API token `dns_cloudflare_api_token`. Add the following line to `docker-compose.yml`:
```yml
[...]
services:
    certbot:
        [...]
        environment:
            - dns_cloudflare_api_token=${dns_cloudflare_api_token}
```

Now add the token to your `.env` file, replacing the token with the real value:
```
[...]
dns_cloudflare_api_token=0123456789abcdef0123456789abcdef01234567
```

#### Option 3b - Using Docker Secrets
As Docker Compose does not support external Swarm secrets, we will create local secret files for testing purposes. The credentials are stored as plain text, so this is not recommended for production. Add the secret to `docker-compose.yml` first, and authorize the certbot service.
```yml
version: "3"

secrets:
    dns_cloudflare_api_token:
        file: secrets/dns_cloudflare_api_token

[...]

services:
    certbot:
        [...]
        secrets:
            - dns_cloudflare_api_token
```

Now create the file-based secret:
```console
mkdir secrets
printf 0123456789abcdef0123456789abcdef01234567 > secrets/dns_cloudflare_api_token
```

### Step 4 - Run Docker Containers
Test the Docker containers with the below commands. Be sure to have set the value of `CERTBOT_DEPLOYMENT` to `test` first.

```console
docker-compose build --no-cache
docker-compose up
```

The images for Nginx and Certbot need to be created first, as they instruct the containers to run in unprivileged mode. Both images use the base images provided by Certbot and Nginx respectively. Certbot provides base images for each specific DNS plugin to minimize the image size. Run the containers in interactive mode with `docker-compose up` once the building has finished successfully. You should see several messages now. The below excerpt shows the key messages per section.

#### Initializing Certbot Configuration
During boot, the custom Certbot container initializes the environment variables and Docker secrets, if applicable. The following environment variables need to be present and have to conform to the expected format:
* CERTBOT_DOMAIN
* CERTBOT_EMAIL
* CERTBOT_DNS_PLUGIN
* CERTBOT_DEPLOYMENT

The following environment variable is optional:
* CERTBOT_DNS_PROPAGATION_SECONDS

Also, at least one token variable for the DNS plugin needs to be provided as either environment variable or Docker secret. Secrets that start with a prefix of the specified DNS plugin are initialized automatically. For example, `dns_cloudflare_api_token` is initialized if the `CERTBOT_DNS_PLUGIN` is set to `cloudflare`.

```
certbot_1  | Step 1 from 3: Initializing configuration
```

The container terminates with an exit code if variables are missing or incorrect.

#### Updating Certbot Configuration
Once the environment variables have been initialized successfully, the container generates a configuration file for the specified DNS plugin. This file contains the credentials to connect with the DNS provider, and as such, should be protected. The file is put in the home directory of the default (non-root) `certbot` user. The file has the name of the specified DNS plugin, in this case, `cloudflare`.
```
certbot_1  | Step 2 from 3: Updating certbot configuration
certbot_1  | Generating certbot configuration file ('/home/certbot/.secrets/certbot/cloudflare.ini')
```

#### Issuing Certificates
In test mode, Certbot performs a test run with the staging server of Let's Encrypt. This allows you to test the configuration without hitting rate limits.

```
certbot_1  | Step 3 from 3: Issuing certificate for 'example.com'
certbot_1  | Running in test mode
certbot_1  | Executing certbot
certbot_1  | Saving debug log to /var/log/certbot/letsencrypt.log
certbot_1  | Plugins selected: Authenticator dns-cloudflare, Installer None
certbot_1  | Obtaining a new certificate
```

The Certbot container uses a DNS-01 challenge for Let's Encrypt to validate ownership of your domain. The DNS configuration is automated using the provided credentials. By default, `nginx-certbot` requests the main certificate and a wildcard certificate for your domain. Two TXT records are published to your DNS server, one for the main domain and one for the wildcard domain. Certbot waits for a specific interval to allow the DNS changes to propagate. The interval is tailored for each supported DNS plugin and can be overwritten with the `CERTBOT_DNS_PROPAGATION_SECONDS` environment variable. In this example, the delay is set to 30 seconds.

```
certbot_1  | Performing the following challenges:
certbot_1  | dns-01 challenge for example.com
certbot_1  | dns-01 challenge for example.com
certbot_1  | Waiting 30 seconds for DNS changes to propagate
```

Certbot notifies you the dry run was successful or not. `Nginx-certbot` uses the following non-standard paths, at it runs in unprivileged mode:
* `/var/lib/certbot` - Core folder used for signaling locking of files by Certbot.
* `/var/log/certbot` - Log files of Certbot (with log rotation). `nginx-certbot` appends its messages to these log files too. The log files contain sensitive information, such as the DNS token.
* `/etc/certbot` - The main folder containing the DNS account settings and issued certificates.

```
certbot_1  | Waiting for verification...
certbot_1  | Cleaning up challenges
certbot_1  | Non-standard path(s), might not work with crontab installed by your operating system package manager
certbot_1  | IMPORTANT NOTES:
certbot_1  |  - The dry run was successful.
```

#### Initializing Nginx
The custom Nginx container uses a default configuration with SSL settings recommended by the [Mozilla SSL Configuration Generator][mozilla-ssl]. Next to that, a default HTTP server is configured using a template (see `config/nginx/templates/default.conf.template`). During initialization, nginx uses this template and the environment variables to generate a default HTTP server. The generated file is put at the location `/etc/nginx/conf.d/default.conf`.

```
nginx_1    | /docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
nginx_1    | /docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
nginx_1    | /docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
nginx_1    | 10-listen-on-ipv6-by-default.sh: Getting the checksum of /etc/nginx/conf.d/default.conf
nginx_1    | 10-listen-on-ipv6-by-default.sh: Enabled listen on IPv6 in /etc/nginx/conf.d/default.conf
nginx_1    | /docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
nginx_1    | 20-envsubst-on-templates.sh: Running envsubst on /etc/nginx/templates/default.conf.template to /etc/nginx/conf.d/default.conf
nginx_1    | /docker-entrypoint.sh: Configuration complete; ready for start up
```

#### Installing Certificates
During testing, no actual certificates are installed. Nginx waits for the files `fullchain.pem` and `privkey.pem` to become available in the certificates folder, e.g. `/etc/letsencrypt/live/example.com/`. The files are polled every 30 seconds until they are available.
```
nginx_1    | /docker-entrypoint.sh: Waiting for certificates ('/etc/letsencrypt/live/example.com')
```

Cancel execution of the containers with `ctrl-c` to proceed to the production configuration.


## Deployment
The steps for deploying in production are slightly different than for local testing. The next four steps highlight the changes.

### Step 1 - Clone the Repository
*Unchanged*

### Step 2 - Update the Environment Variables
*Unchanged, however, set CERTBOT_DEPLOYMENT to production once everything is working properly*

### Step 3 - Specify DNS Credentials
#### Option 3a - Using Environment Variables
*Unchanged*

#### Option 3b - Using Docker Secrets
Instead of file-based secrets, you will now create more secure secrets. Docker secrets can be easily created using pipes. Do not forget to include the final `-`, as this instructs Docker to use piped input. Update the token as needed.

```console
printf 0123456789abcdef0123456789abcdef01234567 | docker secret create dns_cloudflare_api_token -
```

If you do not feel comfortable copying secrets from your command line, you can use the wrapper `create_secret.sh`. This script prompts for a secret and ensures sensitive data is not displayed on your console. The script is available in the folder `/docker-secret` of your repository.

```console
./create_secret.sh dns_cloudflare_api_token
```

Set `external` to `true` in the `secrets` section of `docker-compose.yml` to use Docker secrets instead of local files.

```Dockerfile
[...]
secrets:
    dns_cloudflare_api_token:
        external: true
```

### Step 4 - Run Docker Service
Pending your choice to use environment variables or Docker secrets, you can deploy your service using Docker Compose or Stack Deploy.

#### Option 4a - Using Environment Variables
*Unchanged, however, use `docker-compose up -d` to run the containers in the background*

#### Option 4b - Using Docker Secrets
Docker Swarm is needed to support external Docker secrets. As such, the services will be deployed as part of a Docker Stack in production. Deploy the stack using `docker-compose` as input. This ensures the environment variables are parsed correctly.

```console
docker-compose config | docker stack deploy -c - nginx-certbot
```

Run the following command to inspect the status of the Docker Stack.

```console
docker stack services nginx-certbot
```

You should see the value `1/1` for `REPLICAS` for the certbot and nginx services if the stack was initialized correctly. It might take a while before the services are up and running, so simply repeat the command after a few minutes if needed.

```
ID  NAME                   MODE        REPLICAS  IMAGE                                PORTS
*** nginx-certbot_certbot  replicated  1/1       markdumay/certbot-cloudflare:latest  
*** nginx-certbot_nginx    replicated  1/1       markdumay/nginx-unprivileged:latest  *:443->4430/tcp, *:80->8080/tcp

```

You can view the service logs with `docker service logs nginx-certbot_certbot` or `docker service logs nginx-certbot_nginx` once the services are up and running. Refer to the paragraph <a href="#step-4---run-with-docker-compose">Step 4 - Run with Docker Compose</a> for validation of the logs.

Debugging swarm services can be quite tedious. If for some reason your service does not initiate properly, you can get its task ID with `docker service ps nginx-certbot_certbot` or `docker service ps nginx-certbot_nginx`. Running `docker inspect <task-id>` might give you some clues to what is happening. Use `docker stack rm nginx-certbot` to remove the docker stack entirely.


## Usage
### Testing Basic Functionality
Having followed the steps in this guide, you should have a default HTTP server running on port `80` of your host by now. Test the availability with the following command from your host. Replace the port if needed to reflect the configuration in your `.env` file. If all goes well, the web server should return a page based on `config/nginx/index.html`.
```
curl localhost
```

In case of errors, test if the web server is available from within the `nginx` container. Run the following command from your host,  updating the internal port `8080` if needed.
```
docker exec -it nginx-certbot_nginx curl localhost:8080
```

### Configuring a Secure Web Server
Add support for an encrypted server once the basic web server is up and running. Create a new file `nginx/templates/example.com.conf.template`, renaming `example.com` to your domain. Below configuration redirects all HTTP traffic to HTTPS, and redirects `www.example.com` to `example.com`. Restart the Docker services/stack to initialize the new server.

```
# Redirect all non-encrypted to encrypted traffic
server {
    server_name ${CERTBOT_DOMAIN};
    listen ${NGINX_PORT_HTTP};
    listen [::]:${NGINX_PORT_HTTP};

    location / {
        return 301 https://$server_name$request_uri;
    }
}

# Redirect all www to non-www
server {
    server_name www.${CERTBOT_DOMAIN};
    listen ${NGINX_PORT_HTTP};
    listen [::]:${NGINX_PORT_HTTP};
    listen ${NGINX_PORT_HTTPS} ssl http2;
    listen [::]:${NGINX_PORT_HTTPS} ssl http2;

    # Configure certificate and session
    ssl_certificate /etc/certbot/live/${CERTBOT_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/certbot/live/${CERTBOT_DOMAIN}/privkey.pem;

    return 301 https://${CERTBOT_DOMAIN}$request_uri;
}

# Handle HTTPS requests
server {
    server_name ${CERTBOT_DOMAIN};
    listen ${NGINX_PORT_HTTPS} ssl http2;
    listen [::]:${NGINX_PORT_HTTPS} ssl http2;

    # Configure certificate and session
    ssl_certificate /etc/certbot/live/${CERTBOT_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/certbot/live/${CERTBOT_DOMAIN}/privkey.pem;

	# Add index.php to the list if you are using PHP
	root /var/www/html;
	index index.html index.htm;

	location / {
		# First attempt to serve request as file, then
		# as directory, then fall back to displaying a 404.
		try_files $uri $uri/ =404;
	}
}
```

Testing the secure web server requires you have either configured your DNS server or adjusted your local host database. The DNS server requires two `A` type records for the names `www` and `example.com` that point to your hosts' IP address. The local host database can be found at `/etc/hosts` on most Linux and macOS systems. Add the following entry:
```
127.0.0.1       www.example.com example.com
```

### Renewing Certificates
The custom Certbot service validates the installed certificates every 12 hours (see `config/certbot/docker_entrypoint.sh`). The certificate itself is renewed every 60 days. Nginx is reloaded every 6 hours to pick up any renewed certificates automatically (see `config/nginx/docker_entrypoint.sh`).


## Contributing
1. Clone the repository and create a new branch 
    ```console
    git checkout https://github.com/markdumay/nginx-certbot.git -b name_for_new_branch
    ```
2. Make and test the changes
3. Submit a Pull Request with a comprehensive description of the changes

## Credits
*Nginx-certbot* is inspired by the following blog article:
* MikesBytes - [Hosting a site with docker + nginx + certbot + wildcard certs][article_mikesbytes]

## Donate
<a href="https://www.buymeacoffee.com/markdumay" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/lato-orange.png" alt="Buy Me A Coffee" style="height: 51px !important;width: 217px !important;"></a>

## License
<a href="https://github.com/markdumay/nginx-certbot/blob/master/LICENSE" alt="License">
    <img src="https://img.shields.io/github/license/markdumay/nginx-certbot.svg" />
</a>

Copyright © [Mark Dumay][blog]



<!-- MARKDOWN PUBLIC LINKS -->
[docker_url]: https://docker.com
[certbot_url]: https://certbot.eff.org
[certbot-dns-cloudflare]: https://certbot-dns-cloudflare.readthedocs.io
[certbot-dns-cloudxns]: https://certbot-dns-cloudxns.readthedocs.io
[certbot-dns-digitalocean]: https://certbot-dns-digitalocean.readthedocs.io
[certbot-dns-dnsimple]: https://certbot-dns-dnsimple.readthedocs.io
[certbot-dns-dnsmadeeasy]: https://certbot-dns-dnsmadeeasy.readthedocs.io
[certbot-dns-gehirn]: https://certbot-dns-gehirn.readthedocs.io
[certbot-dns-google]: https://certbot-dns-google.readthedocs.io
[certbot-dns-linode]: https://certbot-dns-linode.readthedocs.io
[certbot-dns-luadns]: https://certbot-dns-luadns.readthedocs.io
[certbot-dns-nsone]: https://certbot-dns-nsone.readthedocs.io
[certbot-dns-ovh]: https://certbot-dns-ovh.readthedocs.io
[certbot-dns-rfc2136]: https://certbot-dns-rfc2136.readthedocs.io
[certbot-dns-route53]: https://certbot-dns-route53.readthedocs.io
[certbot-dns-sakuracloud]: https://certbot-dns-sakuracloud.readthedocs.io
[mozilla-ssl]: https://ssl-config.mozilla.org
[nginx_url]: https://nginx.org
[swarm_init]: https://docs.docker.com/engine/reference/commandline/swarm_init/


[article_mikesbytes]: https://mikesbytes.org/web/2020/02/29/docker-nginx-letsencrypt.html

<!-- MARKDOWN MAINTAINED LINKS -->
<!-- TODO: add blog link
[blog]: https://markdumay.com
-->
[blog]: https://github.com/markdumay
[repository]: https://github.com/markdumay/nginx-certbot.git