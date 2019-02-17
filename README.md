pslisten
========

Description
-----------

pslisten reports processes owning listening sockets. For each open port the related IP, protocol, process ID, effective user and full command line are shown. Similar to `netstat -p` superuser rights are required to display this information about sockets belonging to other users.

Examples
--------

Display listening IPv4 TCP sockets:
```shell
sudo pslisten -4 -t
```

Show open ports of all running `java` processes:
```shell
pgrep --exact java | xargs sudo pslisten
```

