# Description

pslisten reports processes owning listening sockets. The relevant data is gathered from the special proc file system (`/proc`).  It is intended to be an alternative to `netstat -tulpe`. Similar to netstat superuser rights are required to collect information about sockets belonging to other users. For each open socket the associated protocol, IP, port, process ID, effective user and full command line are shown.


# Installation

## From package

### Debian and derivatives (Ubuntu, Raspbian, etc.)

1. Download the latest .deb package from the [Releases](https://github.com/mskuta/pslisten/releases/latest) page.
2. Install it: `sudo dpkg --install pslisten_x.y.z_all.deb`

## From source

### As root user

1. Clone this repository: `git clone https://github.com/mskuta/pslisten.git`
2. Run the included installation script: `sudo pslisten/install.sh`
3. Make sure `/usr/local/bin` is in your `$PATH`.

### As unprivileged user

1. Clone this repository: `git clone https://github.com/mskuta/pslisten.git`
2. Run the included installation script: `PREFIX=$HOME/.local pslisten/install.sh`
3. Make sure `$HOME/.local/bin` is in your `$PATH`.


# Usage

```
Usage: pslisten [OPTIONS] [PID ...]
Options:
  -4  Display only IP version 4 sockets.
  -6  Display only IP version 6 sockets.
  -t  Display only TCP sockets.
  -u  Display only UDP sockets.
```

## Examples

Display listening IPv4 TCP sockets:
```shell
sudo pslisten -4 -t
```

Show open ports of all running `java` processes:
```shell
pgrep --exact java | xargs sudo pslisten
```


# License

This software is distributed under the ISC license.


