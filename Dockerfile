FROM opensciencegrid/software-base:fresh
LABEL maintainer "Lincoln Bryant <lincolnb@uchicago.edu>"

RUN yum install -y yum-plugin-priorities
RUN yum install -y osg-ca-certs osg-ce-bosco fetch-crl gratia-probes-cron openssh openssh-clients certbot

COPY hosted-ce-setup.sh /etc/osg/image-config.d/hosted-ce-setup.sh
#COPY hosted-ce.conf /etc/supervisord.d/hosted-ce.conf
COPY remote-site-setup.sh /etc/osg/remote-site-setup.sh

# do the bad thing of overwriting the existing cron job for fetch-crl
ADD fetch-crl /etc/cron.d/fetch-crl

#ENTRYPOINT ["osg-configure","-c"]
ENTRYPOINT ["/usr/local/sbin/supervisord_startup.sh"]
