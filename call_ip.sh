#!/data/data/com.termux/files/usr/bin/sh
interfaces=$(su -c 'ip -o link show | awk -F": " "{print \$2}" | cut -d"@" -f1 | sort -u')
