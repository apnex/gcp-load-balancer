## `gcp-load-balancer`
A collection of useful scripts and CLI examples for the `google cloud` load-balancing platform  
Clone repository and adjust parameters as required  

---

### `what is it?`
The example outlined in this repo is a set of configurations for the `google cloud` External HTTPS Load-balancer.  
It exposes a custom domain with a valid SSL certificate as a 'vanity fqdn' fronting a number of `github.com` workflows.  

The solution is built wiring together a range of different mechanisms on the GCP platform.  
The GCP components include:
- Cloud DNS
- External HTTPS LB
- Cloud Functions

<solution diagram>

Wildcard REGEX and Capture Group variables are not currently supported by the native GCP External LB.  
Luckily (or more likely by design and more awesomely!) you can extend the External LB functionality.  
This is achieved by offloading traffic processing and steering logic to a Cloud Function.  
This Cloud Function can then process incoming requests and perform any rewrite or steering logic directly in `nodejs`!

---

### `why does it exist?`
I wanted the ability to use the custom vanity domain `apnex.io` as a minified front-end to `github.com`  
This includes:  
- shortened browser access to individual repos  
- git `clone` / `commit` / `push`  
- shortened curl / browser access to `raw.githubusercontent.com` file content  
- redirect any unencrypted HTTP requests -> HTTPS

This makes it easier for me to link and refer to github committed content.  
This also becomes useful for pulling / executing automation scripts from multiple repos resembling a public API.  

Some examples of what I needed this to do:  

**Browse to main github page or of any individual repo**  
```
https://apnex.io
https://apnex.io/gcp-load-balancer
https://apnex.io/terraform-avi
```

**Git clone / push any repo under `github.com/apnex`**
```
git clone https://apnex.io/gcp-load-balancer
git clone https://apnex.io/terraform-avi
git clone https://apnex.io/labops
```

**Curl raw content from any individual repo**
```
curl -fsSL https://apnex.io/labops/docker/install
curl -fsSL https://apnex.io/terraform/install.sh
curl -fsSL https://apnex.io/terraform-avi/phase0-deploy/main.tf
```

---

### `how does it work?`
It works by employing advanced traffic steering techniques of incoming specific requests to different backend services.  

#### url-map traffic manipulation
![diagram](gcp-loadbalancer.svg)

---

### `how do I build it?`
This can be built using the UI, API, or CLI.  
**Note: the `url-map` component uses advanced traffic engineering functions and is CLI / API only at this stage.**  

The GCP `load-balancer` object-model is as follows:
```
load-balancer
 ┣━ forwarding-rules
 ┃   ┣━ target-https-proxies
 ┃   ┃   ┣━ url-maps
 ┃   ┃   ┃   ┗━ backend-services
 ┃   ┃   ┃       ┗━ network-endpoint-groups
 ┃   ┃   ┗━ ssl-certificates
 ┃   ┗━ addresses
 ┣━ forwarding-rules
 ┃   ┣━ target-https-proxies
 ┃   ┃   ┣━ url-maps
 ┃   ┃   ┗━ ssl-certificates
 ┃   ┗━ addresses
 ┗━ ...
```

The following steps show how to construct it via the `gcloud` CLI.  

#### create external `network-endpoint-group` `neg-github-raw`
```
gcloud compute network-endpoint-groups create neg-github-raw \
	--network-endpoint-type="internet-fqdn-port" \
--global
```

#### add endpoint to network-endpoint-group `neg-github-raw`
```
gcloud compute network-endpoint-groups update neg-github-raw \
	--add-endpoint="fqdn=raw.githubusercontent.com,port=443" \
--global
```

#### create external `network-endpoint-group` `neg-github`
```
gcloud compute network-endpoint-groups create neg-github \
	--network-endpoint-type="internet-fqdn-port"
--global
```

#### add endpoint to network-endpoint-group `neg-github`
```
gcloud compute network-endpoint-groups update neg-github
	--add-endpoint="fqdn=github.com,port=443"
--global
```

#### create backend-service `svc-github-raw`
```
gcloud compute backend-services create svc-github-raw \
	--enable-cdn \
	--protocol=HTTPS \
--global
```

#### create backend-service `svc-github`
```
gcloud compute backend-services create svc-github \
	--enable-cdn \
	--protocol=HTTPS \
--global
```

#### add network-endpoint-group to backend-service `svc-github-raw`
```
gcloud compute backend-services add-backend svc-github-raw \
	--network-endpoint-group "neg-github-raw" \
	--global-network-endpoint-group
--global
```

#### add network-endpoint-group to backend-service `svc-github`
```
gcloud compute backend-services add-backend svc-github \
	--network-endpoint-group=neg-github \
	--global-network-endpoint-group \
--global
```

