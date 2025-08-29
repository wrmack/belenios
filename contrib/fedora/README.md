Deploying Belenios using systemd-nspawn
=======================================

This file contains the same information as contrib/nspawn/README.md but amended for use on a Fedora workstation and using podman instead of docker.


Introduction
------------

This file documents a technique with a (relatively) small runtime
footprint on the deployment server. With this technique, the
"development" and the "deployment" environments are distinguished and
can be on different machines. The benefit is that the development
environment takes several gigabytes while the deployment environment
takes less than 100 MB. Several instances can be deployed on the same
machine. It is expected that these instances listen on localhost, and
that a reverse-proxy on the host exposes them on different vhosts or
directories of some vhost, with TLS. Configuring the reverse-proxy is
documented [here](../../doc/reverse-proxy.md).

This technique requires a Debian-based Linux (trixie/sid at the time
of writing) and working unprivileged user namespaces. Podman is used to 
create a Debian container.


Building the image
------------------

The whole process takes approx. 15 min, depending on the host and
Internet connection.

### On a Fedora-based system (using Podman)

Make sure you have sufficient space (>= 10 GB).

Build the building environment:

    sudo podman build -f contrib/fedora/nspawn-build.Dockerfile -t belenios-nspawn-image .

Prepare the directory on the host where images will be built:

    mkdir -p _docker
    sudo podman run --rm belenios-nspawn-image tar -C /tmp -c build | tar -C _docker -x

Run the Debian container to build the squashfs image:

    sudo podman run -it --name belcont --volume=$PWD:/tmp/belenios:Z --volume=$PWD/_docker/build:/tmp/build:Z --rm --userns=keep-id --privileged --security-opt=label=disable belenios-nspawn-image

# Inside the container do:
    make

Deploying
---------

We assume the deployment server runs Linux, systemd and has
`systemd-nspawn` installed. We also assume that `systemd-resolved` is
running, and an [MTA](../../doc/mta.md) is installed and listening on
localhost.

When deploying on a server for the first time, run:

 * `mkdir /srv/belenios-containers`
 * `cp belenios-nspawn /srv/belenios-containers`
 * `cp belenios-container@.service /etc/systemd/system`

You might want to update `belenios-nspawn` and
`belenios-container@.service` as Belenios evolves.

Let `SQUASHFS` be the `.squashfs` image, built in the previous
section.

To deploy an instance named `main`:

 * create a directory `/srv/belenios-containers/main`
 * copy there `$SQUASHFS`
 * make there a symlink `rootfs.squashfs` pointing to `$SQUASHFS`
 * create a `belenios` sub-directory belonging to user 1000 and
   group 1000
 * create there sub-directories `etc` and `var`
 * create `etc/ocsigenserver.conf.in` file (you can take the one
   in Belenios sources as example)

Beware, the `belenios` directory and its contents must belong to user
and group 1000, which correspond to user and group `belenios` inside
the deployment environment, but may appear as different names on the
host.

You can then run the instance with:

    systemctl start belenios-container@main.service

You should now be able to browse to your instance!

Of course, you can run other `systemctl` commands such as `status`,
`enable`, etc.


Troubleshooting
---------------


### Cannot connect to Belenios web server

You can open a shell inside the container with (replace `main` with
the name of your instance):

    machinectl shell belenios-main

The systemd unit running the web server (inside the container) is
called `belenios-server.service` so you can, for example, run:

    systemctl status belenios-server

to see if the unit is running and debug it if needed. You can also use
`journalctl` or read Belenios-specific logs in `/var/belenios/log`.


### Mails are not delivered

Be sure the MTA on the host works properly. Its logs can be helpful in
debugging mail delivery problems.

Usually, the `return-path` setting in `ocsigenserver.conf.in` must be
set to a valid e-mail address.


cat > /etc/msmtprc <<XOF
defaults
tls on
tls_starttls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
syslog on

account ses
host email-smtp.us-east-1.amazonaws.com
port 587
auth on
user AKIA3BQFZYK6ZWIIXT7P
password BJxphimKySkSFomd5GdhbEYR3yD2cE3IdKRJ8OSmdfPm
from elections@wrmack.com

account default : ses
# from %U@belenios
syslog LOG_MAIL
XOF

[ec2-user@ip-172-31-30-217 ~]$ ls -al /etc/resolv.conf
lrwxrwxrwx. 1 root root 32 Jul 30  2024 /etc/resolv.conf -> /run/systemd/resolve/resolv.conf

[ec2-user@ip-172-31-30-217 ~]$ cat /run/systemd/resolve/resolv.conf
# This is /run/systemd/resolve/resolv.conf managed by man:systemd-resolved(8).
# Do not edit.
#
# This file might be symlinked as /etc/resolv.conf. If you're looking at
# /etc/resolv.conf and seeing this text, you have followed the symlink.
#
# This is a dynamic resolv.conf file for connecting local clients directly to
# all known uplink DNS servers. This file lists all configured search domains.
#
# Third party programs should typically not access this file directly, but only
# through the symlink at /etc/resolv.conf. To manage man:resolv.conf(5) in a
# different way, replace this symlink by a static file or a different symlink.
#
# See man:systemd-resolved.service(8) for details about the supported modes of
# operation for /etc/resolv.conf.

nameserver 172.31.0.2
search ec2.internal

MACHINE       CLASS     SERVICE        OS     VERSION ADDRESSES
belenios-main container systemd-nspawn debian 13      -