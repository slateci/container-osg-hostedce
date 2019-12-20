FROM opensciencegrid/software-base:fresh
LABEL maintainer "OSG Software <help@opensciencegrid.org>"

RUN yum install -y --enablerepo=osg-minefield \
                   osg-ce-bosco \
                   git \
                   openssh-clients \
                   certbot && \
    yum clean all && \
    rm -rf /var/cache/yum/

COPY 25-hosted-ce-setup.sh /etc/osg/image-config.d/
COPY 30-remote-site-setup.sh /etc/osg/image-config.d/

COPY 99-container.conf /usr/share/condor-ce/config.d/
# can be dropped when provided by upstream osg-ce packaging
COPY 51-gratia.conf /usr/share/condor-ce/config.d/51-gratia.conf

# can be dropped when provided by upstream htcondor-ce packaging
RUN mkdir -p /etc/condor-ce/bosco_override

# can be dropped when these are upstreamed to htcondor-ce
COPY bosco-cluster-remote-hosts.sh /usr/local/bin/bosco-cluster-remote-hosts.sh
COPY foreach_bosco_endpoint.sh     /usr/local/bin/foreach_bosco_endpoint.sh

# do the bad thing of overwriting the existing cron job for fetch-crl
ADD fetch-crl /etc/cron.d/fetch-crl

# Include script to drain the CE and upload accounting data to prepare for container teardown
COPY drain-ce.sh /usr/local/bin/

# Set up Bosco override dir from Git repo (SOFTWARE-3903)
# Expects a Git repo with the following directory structure:
#     RESOURCE_NAME_1/
#         bosco_override/
#         ...
#     RESOURCE_NAME_2/
#         bosco_override/
#         ...
#     ...
COPY bosco-override-setup.sh /usr/local/bin

# Manage HTCondor-CE with supervisor
COPY 10-htcondor-ce.conf /etc/supervisord.d/

ENTRYPOINT ["/usr/local/sbin/supervisord_startup.sh"]
