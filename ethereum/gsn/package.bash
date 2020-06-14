#! /bin/bash

cat >docker-compose.bash <<END
#! /bin/bash

docker run --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "$PWD:$PWD" \
        -w "$PWD" \
        docker/compose:1.24.0 $*

END
chmod +x docker-compose.bash
cat >docker-compose.yaml <<END
version: '3'

services:
  https-portal:
    image: steveltn/https-portal:1
    ports:
      - '80:80'
      - '443:443'
    restart: always
    environment:
      DOMAINS: '${HOST} -> http://gsn'
      STAGE: 'production'

  gsn:
    image: opengsn/jsrelay:\$\{JSRELAY\}
    restart: always
    ports:
      - '8090:80' #needed for debugging without https frontend


    volumes:
      - ./gsndata:/app/data    #can be left out, to keep private-key inside the docker
    environment:
      url: https://\$\{HOST\}
      port: 80
      ethereumNodeUrl: \$\{NODE_URL\}
      relayHubAddress: \$\{RELAY_HUB\}
      gasPricePercent: \$\{GAS_PRICE_PERCENT\}
      baseRelayFee: \$\{BASE_FEE\}
      pctRelayFee: \$\{PERCENT_FEE\}
END
cat >.env <<END
HOST=qbzzt.duckdns.org
NODE_URK=https://kovan.infura.io/v3/455c4353c93d4b0092c542f38cceed41
RELAY_HUB=0x2E0d94754b348D208D64d52d78BcD443aFA9fa52

#can't use localhost: must specify device IP
#NODE_URL=http://192.168.1.241:8545

#GAS_PRICE_PERCENT=70
SERVER_CONFIG_FILE=server-config.json
#BASE_FEE=
#PERCENT_FEE=

#docker image tag
JSRELAY=0.9.0
END
