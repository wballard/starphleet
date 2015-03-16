#!/bin/sh -x
cd /usr/lib/vmware-tools/modules/source
tar xf vmhgfs.tar
grep -q d_u.d_alias vmhgfs-only/inode.c && echo "already patched" && exit 0
sed -i -e s/d_alias/d_u.d_alias/ vmhgfs-only/inode.c
cp -p vmhgfs.tar vmhgfs.tar.orig
tar cf vmhgfs.tar vmhgfs-only
vmware-config-tools.pl -d -m