pslisten
========

Description
-----------

pslisten reports processes owning listening sockets. For each open port the related IP, protocol, process ID, effective user and full command line are shown. Similar to `netstat -p` superuser rights are required to display this information about sockets belonging to other users.

Example
-------

Show open ports of all running `java` processes:
```shell
pgrep --exact java | xargs sudo pslisten
```

