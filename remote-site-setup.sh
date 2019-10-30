#!/bin/bash
set -u

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
  echo "0 0 * * * $HOME/osg-wn-client/update_certs.sh >> $HOME/update_certs.log" > update_certs.cron
  chmod 755 $HOME/osg-wn-client/update_certs.sh
  crontab update_certs.cron

  popd

fi

