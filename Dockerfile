FROM ubuntu:22.04 AS builder

RUN apt-get update && \
    apt-get install -y curl tar ca-certificates wget && \
    update-ca-certificates

RUN curl -LO "https://ap-southeast-3-hwcloudcli.obs.ap-southeast-3.myhuaweicloud.com/cli/latest/huaweicloud-cli-linux-amd64.tar.gz" && \
    tar -zxvf huaweicloud-cli-linux-amd64.tar.gz && \
    chmod +x hcloud && \
    mv hcloud /usr/local/bin/

RUN wget https://obs-community-intl.obs.ap-southeast-1.myhuaweicloud.com/obsutil/current/obsutil_linux_amd64.tar.gz && \
    tar -xzvf obsutil_linux_amd64.tar.gz && \
    chmod 755 obsutil_linux_amd64_5.4.11/obsutil && \
    mv obsutil_linux_amd64_5.4.11/obsutil /usr/local/bin/

FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y expect zip unzip jq

COPY --from=builder /usr/local/bin/hcloud /usr/local/bin/hcloud
COPY --from=builder /usr/local/bin/obsutil /usr/local/bin/obsutil
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY ./entrypoint.sh entrypoint.sh

RUN chmod +x entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
