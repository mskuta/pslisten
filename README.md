Description
===========

pslisten reports processes owning listening sockets. The relevant data is gathered from the special proc file system (`/proc`).  It is intended to be an alternative to `netstat -tulpe`. Similar to netstat superuser rights are required to collect information about sockets belonging to other users. For each open socket the associated protocol, IP, port, process ID, effective user and full command line are shown.


Installation
============

- Clone this repository.
- Run the included installation script by entering `sudo ./install.sh`. The default target directory for the executable is `/usr/local/bin`. Use the environment variable `PREFIX` to change this. For example, to install the software under your home directory, type `PREFIX=$HOME/.local ./install.sh` and make sure `$HOME/.local/bin` is in your `$PATH`.

Debian and derivatives (f. e. Ubuntu) 
-------------------------------------

- Download the latest .deb package from the Releases page.
- Install it by entering `sudo dpkg --install <.deb file name>`.


Usage
=====

```shell
Usage: pslisten [OPTIONS] [PID ...]
Options:
  -4  Display only IP version 4 sockets.
  -6  Display only IP version 6 sockets.
  -t  Display only TCP sockets.
  -u  Display only UDP sockets.
```

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


License
=======

This software is distributed under the ISC license.


