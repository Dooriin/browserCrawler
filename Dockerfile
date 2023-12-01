ARG BROWSER_VERSION=1.58.135
ARG BROWSER_IMAGE_BASE=webrecorder/browsertrix-browser-base:brave-${BROWSER_VERSION}

FROM ${BROWSER_IMAGE_BASE}

# needed to add args to main build stage
ARG BROWSER_VERSION

ENV PROXY_HOST=localhost \
    PROXY_PORT=8080 \
    PROXY_CA_URL=http://wsgiprox/download/pem \
    PROXY_CA_FILE=/tmp/proxy-ca.pem \
    DISPLAY=:99 \
    GEOMETRY=1360x1020x16 \
    BROWSER_VERSION=${BROWSER_VERSION} \
    BROWSER_BIN=google-chrome \
    OPENSSL_CONF=/app/openssl.conf \
    VNC_PASS=vncpassw0rd! \
    USER_AGENTS="\
    Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36;\
    Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.77 Safari/537.36;\
    Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0;\
    Mozilla/5.0 (iPad; CPU OS 13_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/80.0.3987.95 Mobile/15E148 Safari/604.1;\
    Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.77 Safari/537.36;\
    Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36;\
    Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.140 Safari/537.36 Edge/17.17134;\
    Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36;\
    Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.132 Safari/537.36;\
    Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3;\
    Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/52.0.2743.116 Safari/537.36;\
    Mozilla/5.0 (Windows NT 5.1; rv:7.0.1) Gecko/20100101 Firefox/7.0.1;\
    Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/46.0.2486.0 Safari/537.36 Edge/13.10586;\
    Mozilla/5.0 (Windows NT 6.1; WOW64; Trident/7.0; AS; rv:11.0) like Gecko;\
    Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.140 Safari/537.36 Edge/17.17134"

WORKDIR /app

ADD requirements.txt /app/
RUN pip install 'uwsgi==2.0.21'
RUN pip install -U setuptools; pip install -r requirements.txt

ADD package.json /app/

# to allow forcing rebuilds from this stage
ARG REBUILD

# Prefetch tldextract so pywb is able to boot in environments with limited internet access
RUN tldextract --update

# Download and format ad host blocklist as JSON
RUN mkdir -p /tmp/ads && cd /tmp/ads && \
    curl -vs -o ad-hosts.txt https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts && \
    cat ad-hosts.txt | grep '^0.0.0.0 '| awk '{ print $2; }' | grep -v '0.0.0.0' | jq --raw-input --slurp 'split("\n")' > /app/ad-hosts.json && \
    rm /tmp/ads/ad-hosts.txt

RUN yarn install --network-timeout 1000000

ADD *.cjs /app/
ADD *.js /app/
ADD util/*.js /app/util/

ADD config/ /app/

ADD html/ /app/html/

RUN ln -s /app/main.js /usr/bin/crawl; ln -s /app/create-login-profile.js /usr/bin/create-login-profile

WORKDIR /crawls

# enable to test custom behaviors build (from browsertrix-behaviors)
# COPY behaviors.js /app/node_modules/browsertrix-behaviors/dist/behaviors.js

ADD docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["crawl"]
