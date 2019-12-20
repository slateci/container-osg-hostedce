#!/bin/bash

. /usr/local/bin/foreach_bosco_endpoint.sh

BOSCO_KEY=/etc/osg/bosco.key
setup_ssh_config () {
  echo "Adding user ${ruser}"
  ssh_dir="/home/${ruser}/.ssh"
  if ! getent passwd "${ruser}" > /dev/null 2>&1; then
     # setup user and SSH dir
     adduser --base-dir /home/ "${ruser}"
     mkdir -p $ssh_dir
     chown "${ruser}": $ssh_dir
     chmod 700 $ssh_dir

     # copy Bosco key
     ssh_key=$ssh_dir/bosco.key
     cp $BOSCO_KEY $ssh_key
     chmod 600 $ssh_key
     chown "${ruser}": $ssh_key
  fi

  # setup known hosts
  REMOTE_HOST_KEY=`ssh-keyscan -H "${rhost}"`
  for known_hosts in $ssh_dir/known_hosts /root/.ssh/known_hosts; do
      echo $REMOTE_HOST_KEY >>  $known_hosts
  done

  # add SSH config
  ssh_config=$ssh_dir/config
  if [ -f $ssh_config ]; then
      echo "IdentityFile ${ssh_key}" > $ssh_config
  fi
}

foreach_bosco_endpoint setup_ssh_config

# Set the appropriate SSH key for bosco_cluster commands
echo "IdentityFile ${BOSCO_KEY}" > /root/.ssh/config

# Install the WN client, CAs, and CRLs on the remote host
# Store logs in /var/log/condor-ce/ to simplify serving logs via Kubernetes
ENDPOINT_CONFIG=/etc/endpoints.ini
setup_endpoints_ini () {
    remote_home_dir=$(ssh -i $BOSCO_KEY ${ruser}@${rhost} pwd)
    remote_os_ver=$(ssh -i $BOSCO_KEY ${ruser}@${rhost} "rpm -E %rhel")
    cat <<EOF >> $ENDPOINT_CONFIG
[Endpoint ${RESOURCE_NAME}-${ruser}]
local_user = ${ruser}
remote_host = ${rhost}
remote_user = ${ruser}
remote_dir = $remote_home_dir/bosco-osg-wn-client
upstream_url = https://repo.opensciencegrid.org/tarball-install/3.4/osg-wn-client-latest.el${remote_os_ver}.x86_64.tar.gz
ssh_key = ${BOSCO_KEY}
EOF
}

foreach_bosco_endpoint setup_endpoints_ini
update-all-remote-wn-clients --log-dir /var/log/condor-ce/

# Populate the bosco override dir from a Git repo
GIT_SSH_KEY=/etc/osg/git.key
[[ -f $GIT_SSH_KEY ]] && export GIT_SSH_COMMAND="ssh -i $GIT_SSH_KEY"
[[ -z $BOSCO_GIT_ENDPOINT || -z $BOSCO_DIRECTORY ]] || \
    /usr/local/bin/bosco-override-setup.sh "$BOSCO_GIT_ENDPOINT" "$BOSCO_DIRECTORY"
unset GIT_SSH_COMMAND

/usr/local/bin/bosco-cluster-remote-hosts.sh
