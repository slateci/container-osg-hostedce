#!/bin/bash
set -u

. /usr/local/bin/foreach_bosco_endpoint.sh

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
     cp /etc/osg/bosco.key $ssh_key
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

stat osg-wn-client
if [[ $? -ne 0 ]]; then
  echo "No WN client found. Assuming setup.."
  which curl
  if [[ $? -eq 0 ]]; then
    curl -O http://repo.opensciencegrid.org/tarball-install/3.4/osg-wn-client-latest.el7.x86_64.tar.gz
  else
    wget http://repo.opensciencegrid.org/tarball-install/3.4/osg-wn-client-latest.el7.x86_64.tar.gz
  fi

  echo "Extracting WN Client"
  tar -xvzf osg-wn-client-latest.el7.x86_64.tar.gz
  pushd osg-wn-client
  ./osg/osg-post-install
  source ~/osg-wn-client/setup.sh
  osg-ca-manage setupCA --url osg

  echo -e "#!/bin/bash \n source $HOME/osg-wn-client/setup.sh \n osg-ca-manage refreshCA \n osg-ca-manage fetchCRL" > update_certs.sh
  echo "0 0 * * * $HOME/osg-wn-client/update_certs.sh &>> $HOME/update_certs.log" > update_certs.cron
  chmod 755 $HOME/osg-wn-client/update_certs.sh
  crontab update_certs.cron

  popd

fi

# Populate the bosco override dir from a Git repo
GIT_SSH_KEY=/etc/osg/git.key
[[ -f $GIT_SSH_KEY ]] && GIT_SSH_COMMAND='ssh -i $GIT_SSH_KEY'
[[ -z $BOSCO_GIT_ENDPOINT ]] || \
    /usr/local/bin/bosco-override-setup.sh "$BOSCO_GIT_ENDPOINT" "$BOSCO_DIRECTORY"
unset GIT_SSH_COMMAND

/usr/local/bin/bosco-cluster-remote-hosts.sh
