#!/bin/bash

. /usr/local/bin/foreach_bosco_endpoint.sh

# Condor needs to know the annoying randomly generated kubernetes pod hostname
export GARBAGE_HOSTNAME=$(hostname -f)
echo "SUPERUSERS = \$(SUPERUSERS), condor@daemon.htcondor.org/$GARBAGE_HOSTNAME, root@daemon.htcondor.org/$GARBAGE_HOSTNAME" \
>> /etc/condor-ce/config.d/99-hostname.conf
echo "FRIENDLY_DAEMONS = \$(FRIENDLY_DAEMONS), condor@daemon.htcondor.org/$GARBAGE_HOSTNAME condor@child/$GARBAGE_HOSTNAME" \
>> /etc/condor-ce/config.d/99-hostname.conf 

#kubernetes configmaps arent writeable
stat /tmp/99-local.ini
if [[ $? -eq 0 ]]; then
  cp /tmp/99-local.ini /etc/osg/config.d/99-local.ini
fi

setup_ssh_config () {
  echo "Adding user ${ruser}"
  ssh_dir="~${ruser}/.ssh"
  if [[ $(getent passwd "${ruser}" -ne 0) ]]; then
      # setup user and SSH dir
     adduser "${ruser}"
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
  if [[ -z $(grep "^Host ${rhost}$ $ssh_config") ]]; then
      cat <<EOF >> $ssh_config
Host ${rhost}
Hostname ${rhost}
IdentiyFile ${ssh_key}

EOF
  fi
}

foreach_bosco_endpoint setup_ssh_config

echo "Trying to populate hostname in 99-local.ini with a better value.."
pushd /etc/osg/config.d
  if [[ -z "$_CONDOR_NETWORK_HOSTNAME" ]]; then
    echo '$_CONDOR_NETWORK_HOSTNAME is empty, just using `hostname`'
    sed -i "s/localhost/$(hostname)/" 99-local.ini
  else
    echo '$_CONDOR_NETWORK_HOSTNAME is nonempty, substituting it in..'
    sed -i "s/localhost/$_CONDOR_NETWORK_HOSTNAME/" 99-local.ini
  fi
popd 

echo "Running OSG configure.."
# Run the OSG Configure script to set up bosco
osg-configure -c

echo "Copying setup script to remote side.."
# Run some additional adjustments as per Marco's doc
scp -i /etc/osg/bosco.key /etc/osg/remote-site-setup.sh $ENDPOINT:"~/remote-site-setup.sh"
ssh -i /etc/osg/bosco.key $ENDPOINT sh remote-site-setup.sh

# Cert stuff
if [ "${DEVELOPER,,}" == 'true' ]; then
    echo "Establishing OSG Test certificate.."
    # don't do this in the image to make it smaller for prod use
    yum install -y --enablerepo=devops-itb osg-ca-generator
    osg-ca-generator --host --vo osgtest
fi

hostcert_path=/etc/grid-security/hostcert.pem
hostkey_path=/etc/grid-security/hostkey.pem

if [ ! -f $hostcert_path ] && [ ! -f $hostkey_path ]; then
    echo "Establishing Let's Encrypt certificate.."
    # this needs to be automated for renewal
    certbot certonly -n --agree-tos --standalone --email $CE_CONTACT -d $CE_HOSTNAME
    ln -s /etc/letsencrypt/live/$CE_HOSTNAME/cert.pem $hostcert_path
    ln -s /etc/letsencrypt/live/$CE_HOSTNAME/privkey.pem $hostkey_path
fi

echo ">>>>> YOUR CERTIFICATE INFORMATION IS:"
openssl x509 -in $hostcert_path -noout -text
echo "><><><><><><><><><><><><><><><><><><><"

/usr/local/bin/bosco-cluster-remote-hosts.sh

echo "Copying local submit attributes file if it exists.."
if [[ -z "$LOCAL_ATTRIBUTES_FILE" ]]; then
  echo "No local submit attributes found"
else
  echo "transferring $LOCAL_ATTRIBUTES_FILE to remote side.."
  scp -i /etc/osg/bosco.key $LOCAL_ATTRIBUTES_FILE $ENDPOINT:"~/bosco/glite/bin/$LOCAL_ATTRIBUTES_FILE"
fi
