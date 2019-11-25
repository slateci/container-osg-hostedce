#!/bin/bash
set -u

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
  ssh-keyscan -H "${rhost}" >> $ssh_dir/known_hosts

  # add host SSH config
  ssh_config=$ssh_dir/config
  if ! grep -q "^Host ${rhost}$" $ssh_config; then
      cat <<EOF >> $ssh_config
Host ${rhost}
IdentityFile ${ssh_key}

EOF
  fi
}

foreach_bosco_endpoint setup_ssh_config

# Install the WN client, CAs, and CRLs on the remote host
# Store logs in /var/log/condor-ce/ to simplify serving logs via Kubernetes
ENDPOINT_CONFIG=/etc/endpoints.ini
setup_endpoints_ini () {
    remote_home_dir=$(ssh -i $BOSCO_KEY ${ruser}@${rhost} pwd)
    cat <<EOF >> $ENDPOINT_CONFIG
[Endpoint ${RESOURCE_NAME}-${ruser}]
local_user = ${ruser}
remote_host = ${rhost}
remote_user = ${ruser}
remote_dir = $remote_home_dir/bosco-osg-wn-client
ssh_key = ${BOSCO_KEY}
EOF
}

cat <<EOF > $ENDPOINT_CONFIG
[DEFAULT]
upstream_url = https://repo.opensciencegrid.org/tarball-install/3.4/osg-wn-client-latest.${REMOTE_OS_VER}.x86_64.tar.gz
EOF
foreach_bosco_endpoint setup_endpoints_ini
update-all-remote-wn-clients --log-dir /var/log/condor-ce/

# Populate the bosco override dir from a Git repo
GIT_SSH_KEY=/etc/osg/git.key
[[ -f $GIT_SSH_KEY ]] && GIT_SSH_COMMAND='ssh -i $GIT_SSH_KEY'
[[ -z $BOSCO_GIT_ENDPOINT ]] || \
    /usr/local/bin/bosco-override-setup.sh "$BOSCO_GIT_ENDPOINT" "$BOSCO_DIRECTORY"
unset GIT_SSH_COMMAND

/usr/local/bin/bosco-cluster-remote-hosts.sh
