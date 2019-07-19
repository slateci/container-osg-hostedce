#!/bin/bash

# need to programmatically get users
for user in $(echo $CE_USERS | tr ',' ' '); do
  echo "Adding user $user"
  adduser $user 
  mkdir -p /home/$user/.ssh
  chown $user: /home/$user/.ssh
  ssh-keyscan -H $(echo $ENDPOINT | cut -d'@' -f2) >> /home/$user/.ssh/known_hosts
done

echo "Keyscanning.."
mkdir -p ~/.ssh
ssh-keyscan -H $(echo $ENDPOINT | cut -d'@' -f2) >> ~/.ssh/known_hosts

echo "Running OSG configure.."
# Run the OSG Configure script to set up bosco
osg-configure -c

echo "Copying setup script to remote side.."
# Run some additional adjustments as per Marco's doc
scp -i /etc/osg/bosco.key /etc/osg/remote-site-setup.sh $ENDPOINT:"~/remote-site-setup.sh"
ssh -i /etc/osg/bosco.key $ENDPOINT sh remote-site-setup.sh

echo "Establishing Let's Encrypt certificate.."
# Cert stuff
# this needs to be automated for renewal
certbot certonly -n --agree-tos --standalone --email $CE_CONTACT -d $CE_HOSTNAME 
ln -s /etc/letsencrypt/live/$CE_HOSTNAME/cert.pem /etc/grid-security/hostcert.pem
ln -s /etc/letsencrypt/live/$CE_HOSTNAME/privkey.pem /etc/grid-security/hostkey.pem

echo "Copying local submit attributes file if it exists.."
if [[ -z "$LOCAL_ATTRIBUTES_FILE" ]]; then
  echo "No local submit attributes found"
else
  echo "transferring $LOCAL_ATTRIBUTES_FILE to remote side.."
  scp -i /etc/osg/bosco.key $LOCAL_ATTRIBUTES_FILE $ENDPOINT:"~/bosco/glite/bin/$LOCAL_ATTRIBUTES_FILE"
fi

# now we do the bad thing beacuse it's a forking process and that makes supervisord sad
/usr/share/condor-ce/condor_ce_startup
