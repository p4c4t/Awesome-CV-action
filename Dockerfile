FROM danteev/texlive

RUN \
    echo "===> Update repositories" && \
    apt-get update && \
    echo "===> Install jq, curl and chktex" && \
    apt-get install -y curl jq chktex && \
    echo "===> Clean up" && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY fonts /usr/local/share/fonts

ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

