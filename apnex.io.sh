fwd -> vs (crt) -> map -> svc -> neg -> end

## create external network-endpoint-group
gcloud compute network-endpoint-groups create neg-github-raw --network-endpoint-type="internet-fqdn-port" --global

## add-endpoint to network-endpoint-group
gcloud compute network-endpoint-groups update neg-github-raw --add-endpoint="fqdn=raw.githubusercontent.com,port=443" --global

## create external network-endpoint-group
gcloud compute network-endpoint-groups create neg-github --network-endpoint-type="internet-fqdn-port" --global

## add-endpoint to network-endpoint-group
gcloud compute network-endpoint-groups update neg-github --add-endpoint="fqdn=github.com,port=443" --global

## show group
gcloud compute network-endpoint-groups list --global

## show contents
gcloud compute network-endpoint-groups list-network-endpoints neg-github-raw --global
gcloud compute network-endpoint-groups list-network-endpoints neg-github --global

## create backend-service
gcloud compute backend-services create svc-github-raw --enable-cdn --protocol=HTTPS --global

## create backend-service
gcloud compute backend-services create svc-github --enable-cdn --protocol=HTTPS --global

## add network-endpoint-group to backend-service
gcloud compute backend-services add-backend svc-github-raw --network-endpoint-group "neg-github-raw" --global-network-endpoint-group --global

## add network-endpoint-group to backend-service
gcloud compute backend-services add-backend svc-github --network-endpoint-group "neg-github" --global-network-endpoint-group --global

#### APNEX.IO

## create url map
gcloud compute url-maps create map-apnex-io --default-service svc-github-raw --global

### CREATE MANAGED CERTIFICATE
[root@obpc lab]# gcloud compute ssl-certificates create ssl-apnex-io --domains=apnex.io --global
Created [https://www.googleapis.com/compute/v1/projects/labops/global/sslCertificates/ssl-apnex-io].
NAME          TYPE     CREATION_TIMESTAMP             EXPIRE_TIME  MANAGED_STATUS
ssl-apnex-io  MANAGED  2021-06-11T20:58:52.516-07:00               PROVISIONING
    apnex.io: PROVISIONING

## create target-https-proxy
gcloud compute target-https-proxies create vs-apnex-io --url-map=map-apnex-io --ssl-certificates=ssl-apnex-io --global

## verify certificate
gcloud compute target-https-proxies describe vs-apnex-io --format="get(sslCertificates)" --global

## reserved static external ip address
gcloud compute addresses create ip4-apnex-io --ip-version=IPV4 --global

## create forwarding-rule
gcloud compute forwarding-rules create fwd-labops --ip-protocol=TCP --ports=443 --target-https-proxy=vs-apnex-io --address=ip4-apnex-io --global


## Craft url-map-spec
cat << EOF > /tmp/map-redirect.yaml
kind: compute#urlMap
name: map-redirect
defaultUrlRedirect:
   redirectResponseCode: MOVED_PERMANENTLY_DEFAULT
   httpsRedirect: True
EOF

## Create new URL map for HTTP->HTTPS
gcloud compute url-maps import map-redirect \
   --source /tmp/map-redirect.yaml \
   --global

## Create a new HTTP-PROXY
gcloud compute target-http-proxies create vs-redirect \
   --url-map=map-redirect \
   --global

## HTTP->HTTPS redirect
gcloud compute forwarding-rules create fwd-apnex-io-http \
   --address=ip4-apnex-io \
   --target-http-proxy=vs-redirect \
   --ports=80 \
   --global

cat << EOF > /tmp/map-apnex-io.yaml
kind: compute#urlMap
name: map-apnex-io
defaultRouteAction:
  urlRewrite:
    pathPrefixRewrite: /apnex/labops
defaultService: https://www.googleapis.com/compute/v1/projects/labops/global/backendServices/svc-github-raw
hostRules:
- hosts:
  - labops.sh
  pathMatcher: path-matcher-1
pathMatchers:
- defaultUrlRedirect:
    hostRedirect: github.com
    httpsRedirect: true
    prefixRedirect: /apnex/labops
    redirectResponseCode: MOVED_PERMANENTLY_DEFAULT
    stripQuery: false
  name: path-matcher-1
  pathRules:
  - paths:
    - /docker/*
    routeAction:
      urlRewrite:
        hostRewrite: raw.githubusercontent.com
        pathPrefixRewrite: /apnex/labops/master/docker/
    service: https://www.googleapis.com/compute/v1/projects/labops/global/backendServices/svc-github-raw
  - paths:
    - /rke/*
    routeAction:
      urlRewrite:
        hostRewrite: raw.githubusercontent.com
        pathPrefixRewrite: /apnex/labops/master/rke/
    service: https://www.googleapis.com/compute/v1/projects/labops/global/backendServices/svc-github-raw
selfLink: https://www.googleapis.com/compute/v1/projects/labops/global/urlMaps/map-labops

gcloud compute addresses describe ip4-address \
    --format="get(address)" \
    --global
