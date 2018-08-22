FROM phusion/baseimage:0.10.2
MAINTAINER Denys Zhdanov <denis.zhdanov@gmail.com>

ENV GO_CARBON_VERSION="0.13.0"
ENV GRAFANA_CARBON_VERSION="5.2.3"


RUN apt-get -y update \
  && apt-get -y upgrade \
  && apt-get -y --force-yes install ca-certificates \
  apt-transport-https \
  wget \
  nginx \
  git \
  sqlite3 \
  libcairo2 \
  libcairo2-dev \
  && curl -s https://packagecloud.io/install/repositories/go-graphite/stable/script.deb.sh | bash \
  && apt-get install -y carbonapi carbonzipper \
  && mkdir /etc/carbonapi/ \
  && rm -rf /var/lib/apt/lists/*

# install go-carbon
RUN wget https://github.com/lomik/go-carbon/releases/download/v${GO_CARBON_VERSION}/go-carbon_${GO_CARBON_VERSION}_amd64.deb \
  && dpkg -i go-carbon_${GO_CARBON_VERSION}_amd64.deb \
  && rm /go-carbon_${GO_CARBON_VERSION}_amd64.deb \
  && mkdir -p /var/lib/graphite/whisper \
  && mkdir -p /var/lib/graphite/dump \
  && service go-carbon stop

# install grafana
ADD conf/etc/grafana/grafana.ini /etc/grafana/grafana.ini
RUN wget https://s3-us-west-2.amazonaws.com/grafana-releases/release/grafana_${GRAFANA_CARBON_VERSION}_amd64.deb  \
  && dpkg -i grafana_${GRAFANA_CARBON_VERSION}_amd64.deb \
  && rm /grafana_${GRAFANA_CARBON_VERSION}_amd64.deb \
  && service grafana-server restart \
  && sleep 5 \
  && curl -X POST -H 'Content-Type: application/json' -u 'admin:admin' \
  -d '{ "name": "carbonapi", "type": "graphite", "url": "http://127.0.0.1:8081", "access": "proxy", "basicAuth": false }' \
  "http://127.0.0.1:3000/api/datasources" \
  && service grafana-server stop \
  && mkdir -p /usr/share/grafana/data \
  && mv -fv /var/lib/grafana/* /usr/share/grafana/data

# config nginx
RUN rm /etc/nginx/sites-enabled/default
ADD conf/etc/nginx/nginx.conf /etc/nginx/nginx.conf
ADD conf/etc/nginx/sites-enabled/go-graphite.conf /etc/nginx/sites-enabled/go-graphite.conf

# config go-carbon
ADD conf/etc/go-carbon/go-carbon.conf /etc/go-carbon/go-carbon.conf
ADD conf/etc/go-carbon/storage-aggregation.conf /etc/go-carbon/storage-aggregation.conf
ADD conf/etc/go-carbon/storage-schemas.conf /etc/go-carbon/storage-schemas.conf

# config carbonapi
ADD conf/etc/carbonapi/carbonapi.yaml /etc/carbonapi/carbonapi.yaml

# logging support
RUN mkdir -p /var/log/go-carbon /var/log/carbonapi /var/log/nginx
ADD conf/etc/logrotate.d/go-graphite.conf /etc/logrotate.d/go-graphite.conf

# daemons
ADD conf/etc/service/go-carbon/run /etc/service/go-carbon/run
ADD conf/etc/service/carbonapi/run /etc/service/carbonapi/run
ADD conf/etc/service/grafana/run /etc/service/grafana/run
ADD conf/etc/service/nginx/run /etc/service/nginx/run

# cleanup
RUN apt-get clean\
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# defaults
EXPOSE 80 2003 2004 8080 8081
VOLUME ["/etc/go-carbon", "/etc/carbonapi", "/var/lib/graphite", "/etc/nginx", "/etc/grafana", "/etc/logrotate.d", "/var/log"]
WORKDIR /
ENV HOME /root
CMD ["/sbin/my_init"]
