#!/bin/bash

# Installs the config for a resource onto the host.
# Usage: `install-resource <RESOURCE>`


prog=${0##*/}
progdir=${0%/*}

fail () {
	echo "$prog:" "$@" >&2
	exit 1
}

msg () {
	echo "$prog:" "$@" >&2
}


sudo=
if [[ `id -u` != 0 ]]; then
	sudo=sudo
fi

resource=${1:?Usage: $prog RESOURCE}
resourcedir=$progdir/$resource

[[ -d $resourcedir ]]  || \
	fail "Resource directory $resourcedir does not exist or is not a directory"

# osg-configure config
$sudo rsync -r \
	$resourcedir/osg-configure/ /etc/osg/config.d  ||  \
	fail "Unable to install osg-configure config"
$sudo chown -R root:root /etc/osg/config.d  ||  \
	fail "Unable to chown osg-configure config"

# bosco_override dir
if [[ -d $resourcedir/bosco_override ]]; then
	$sudo rsync -r --delete-after \
		$resourcedir/bosco_override/ /etc/osg/bosco_override  || \
		fail "Unable to install bosco_override dir"
	$sudo chown -R root:root /etc/osg/bosco_override  || \
		fail "Unable to chown bosco_override dir"
fi

# endpoints.ini
$sudo install -m 0644 -o root -g root \
	$resourcedir/endpoints.ini /etc/endpoints.ini  || \
	fail "Unable to install endpoints.ini"

msg "Install complete"

# vim:noet:sw=8:sts=8:ts=8
