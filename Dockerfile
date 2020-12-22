FROM ubuntu:18.04

RUN apt-get update -y
RUN apt-get upgrade -y



RUN apt install curl apt-transport-https ca-certificates gnupg openjdk-11-jdk-headless -y 

RUN curl -fsSl https://downloads.ortussolutions.com/debs/gpg | apt-key add -
RUN echo "deb https://downloads.ortussolutions.com/debs/noarch /" | tee -a /etc/apt/sources.list.d/commandbox.list
RUN apt-get update && apt-get install commandbox -y

RUN box install commandbox-cfconfig

RUN apt install nginx git -y

COPY ./ModuleConfig.cfc /tmp/ModuleConfig.cfc
COPY ./box.json /tmp/box.json

RUN cd /tmp/ && box package link

#systemd emulation
RUN apt install -y python
RUN curl https://raw.githubusercontent.com/gdraheim/docker-systemctl-images/v1.4.4147/files/docker/systemctl.py -o /usr/bin/systemctl
RUN test -L /bin/systemctl || ln -sf /usr/bin/systemctl /bin/systemctl
RUN chmod a+x /usr/bin/systemctl

ENV DEBIAN_FRONTEND=noninteractive
RUN apt install vim certbot -y --no-install-recommends

RUN echo "127.0.0.1 example.com" >> /etc/hosts
RUN echo "127.0.0.1 www.example.com" >> /etc/hosts

RUN echo 8

COPY . /tmp/

RUN chmod a+x /tmp/test/test.sh

#RUN box machine apply /tmp/example.json

CMD ["/usr/bin/systemctl"]