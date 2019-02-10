# This file is part of pslisten, distributed under the ISC license.
# For full terms see the included COPYING file.

use Socket qw(AF_INET6 inet_ntop inet_pton);
use feature qw(fc);
use strict;
use warnings;

sub gatherproc {
	my $pid = shift();
	unless (defined($pid)) {
		return {
			command => '?',
			euser   => '?',
			name    => '?',
			pid     => '?',
		};
	}

	my(%proc) = (
		command => undef,
		euser   => '?',
		name    => undef,
		pid     => $pid,
	);
	if (open(my $fh, '<', "/proc/$pid/cmdline")) {
		my $cmdline;
		my $readok = 0;
		if (not eof($fh) and $readok = defined($cmdline = readline($fh))) {
			$cmdline =~ tr/\000/ /;
			$cmdline =~ s/ +$//;
		}
		close($fh);
		$proc{command} = $cmdline if ($readok);
	}
	if (open(my $fh, '<', "/proc/$pid/status")) {
		my($euid, $name) = (undef, undef);
		my(@filters) = (
			{ src => qr/^Name:\t(.+)/,      dst => \$name },
			{ src => qr/^Uid:\t\d+\t(\d+)/, dst => \$euid },
		);
		my $got = 0;
		my $readok = 0;
		while ($got < @filters and not eof($fh) and $readok = defined(my $ln = readline($fh))) {
			foreach my $filter (grep { not defined(${$_->{dst}}) } @filters) {
				if ($ln =~ /$filter->{src}/) {
					${$filter->{dst}} = $1;
					$got++;
				}
			}
		}
		close($fh);
		if ($readok) {
			$proc{command} //= "[$name]";
			$proc{euser} = (getpwuid($euid))[0] if (defined($euid));
			$proc{name} = $name;
		}
	}
	die("Error: Information incomplete for process: $pid\n") if (grep { not defined($proc{$_}) } keys(%proc));
	return \%proc;
}

sub gatherprocs {
	my $procsref = shift();
	my $socksref = shift();
	my $pidstoshowref = shift();
	my($dh_proc, $dn_proc) = (undef, '/proc');
	if (opendir($dh_proc, $dn_proc)) {
		my @pidsfound;
		if (%{$pidstoshowref}) {
			@pidsfound = grep { -d "$dn_proc/$_" and exists($pidstoshowref->{$_}) } readdir($dh_proc);
		}
		else {
			@pidsfound = grep { -d "$dn_proc/$_" and /^\d+$/ } readdir($dh_proc);
		}
		closedir($dh_proc);
		foreach my $pid (@pidsfound) {
			my($dh_fd, $dn_fd) = (undef, "/proc/$pid/fd");
			if (opendir($dh_fd, $dn_fd)) {
				foreach (grep { -l "$dn_fd/$_" } readdir($dh_fd)) {
					# consider only processes with inodes belonging to listening sockets
					if (
						readlink("$dn_fd/$_") =~ /^socket:\[(?<inode>\d+)\]$/
						and exists($socksref->{$+{inode}})
					) {
						$procsref->{$+{inode}} = gatherproc($pid);
					}
				}
				closedir($dh_fd);
			}
			else {
				# do not die, as most probably just permission was denied
			}
		}
	}
	else {
		die("Error: $dn_proc: $!\n");
	}
}

sub gathersocks {
	my $socksref = shift();
	my $proto = shift();
	my $ipver = shift();
	my($fh, $fn) = (undef, "/proc/net/$proto" . ($ipver eq '4' ? '' : $ipver));
	if (open($fh, $fn)) {
		while (not eof($fh) and defined($_ = readline($fh))) {
			my(@fields) = split(' ');

			# skip lines without entry number and filter sockets by their state
			if (
				$fields[0] !~ /^\d+:$/
				or ($proto eq 'tcp' and $fields[3] ne '0A')
				or ($proto eq 'udp' and $fields[3] ne '07')
			) {
				next;
			}

			# store attributes with inode as key
			$socksref->{$fields[9]} = {
				proto => $proto,
				ipver => $ipver,
				port  => hex(substr($fields[1], rindex($fields[1], ':') + 1)),
			};

			# transform IP address to a well-known format
			my @blocks;
			my(%iptr) = (
				'4' => {
					blockcnt => 4,
					blocklen => 2,
					joinwith => '.',
					tr       => sub { return hex(shift()); },
				},
				'6' => {
					blockcnt => 8,
					blocklen => 4,
					joinwith => ':',
					tr       => sub { return shift(); },
				},
			);
			my $blocknum = 0;
			while (++$blocknum <= $iptr{$ipver}->{blockcnt}) {
				push(
					@blocks,
					$iptr{$ipver}->{tr}->(
						substr(
							$fields[1],
							($iptr{$ipver}->{blockcnt} - $blocknum) * $iptr{$ipver}->{blocklen},
							$iptr{$ipver}->{blocklen}
						)
					)
				)
			}
			$socksref->{$fields[9]}->{ip} = join($iptr{$ipver}->{joinwith}, @blocks);
			if ($ipver eq '6') {
				# normalize IPv6 address, f. e. from 0000:0100:0000:0000:0000:0000:0000:0000 to 0:100::
				$socksref->{$fields[9]}->{ip} = inet_ntop(AF_INET6, inet_pton(AF_INET6, $socksref->{$fields[9]}->{ip}));
			}
		}
		close($fh);
	}
	else {
		die("Error: $fn: $!\n");
	}
}

sub parseargs {
	my $progname = shift();
	my $argvref = shift();
	my $optsref = shift();
	my $pidstoshowref = shift();
	my $argi = 0;
	my $usage = <<END;
Usage: $progname [OPTIONS] [PID ...]
Options:
  -4  Display only IP version 4 sockets.
  -6  Display only IP version 6 sockets.
  -t  Display only TCP sockets.
  -u  Display only UDP sockets.
END
	while (
		$argi < @{$argvref}
		and substr($argvref->[$argi], 0, 1) eq '-'
		and length($argvref->[$argi]) > 1
	) {
		my $i = 1;
		while ($i < length($argvref->[$argi])) {
			for (substr($argvref->[$argi], $i, 1)) {
				if (/4/) {
					push(@{$optsref->{ipversions}}, '4');
				}
				elsif (/6/) {
					push(@{$optsref->{ipversions}}, '6');
				}
				elsif (/t/) {
					push(@{$optsref->{protocols}}, 'tcp');
				}
				elsif (/u/) {
					push(@{$optsref->{protocols}}, 'udp');
				}
				else {
					die($usage);
				}
			}
			$i++;
		}
		$argi++;
	}
	@{$optsref->{ipversions}} = ('4', '6') unless ($optsref->{ipversions});
	@{$optsref->{protocols}} = ('tcp', 'udp') unless ($optsref->{protocols});

	# do not accept arbitrary values as PIDs
	%{$pidstoshowref} = map { $_ => 1 } @{$argvref}[$argi .. $#{$argvref}];
	if (%{$pidstoshowref}) {
		my $pidmax;
		my($fh, $fn) = (undef, '/proc/sys/kernel/pid_max');
		if (open($fh, '<', $fn)) {
			$pidmax = readline($fh);
			close($fh);
		}
		else {
			warn("Warning: $fn: $!\n");
		}
		die($usage) if (grep { $_ !~ /^\d+$/ or $_ == 0 or (defined($pidmax) and $_ > $pidmax) } keys(%{$pidstoshowref}));
	}
}

my %opts;
my %pidstoshow;
eval { parseargs(substr($0, rindex($0, '/') + 1), \@ARGV, \%opts, \%pidstoshow) };
die("$@") if ($@);

my %socks;
foreach my $proto (@{$opts{protocols}}) {
	foreach my $ipver (@{$opts{ipversions}}) {
		eval { gathersocks(\%socks, $proto, $ipver) };
		warn("Warning: $@") if ($@);
	}
}

my %procs;
eval { gatherprocs(\%procs, \%socks, \%pidstoshow) };
die("$@") if ($@);

# adapt sockets to show based on user's input
if (%pidstoshow) {
	delete(@socks{grep { not exists($procs{$_}) } keys(%socks)});
}
else {
	$procs{$_} = gatherproc(undef) foreach (grep  { not exists($procs{$_}) } keys(%socks));
}

my(%maxlen) = (
	euser => 5,
	ip    => 2,
	ipver => 1,
	pid   => 3,
	port  => 4,
	proto => 4,
);
foreach (keys(%socks)) {
	# determine largest lengths of certain attributes for formatting
	my(%len) = (
		euser => length($procs{$_}->{euser}),
		ip    => length($socks{$_}->{ip}),
		ipver => length($socks{$_}->{ipver}),
		pid   => length($procs{$_}->{pid}),
		port  => length($socks{$_}->{port}),
		proto => length($socks{$_}->{proto}),
	);
	$maxlen{$_} = ($len{$_}, $maxlen{$_})[$len{$_} < $maxlen{$_}] foreach (keys(%maxlen));
}

my $format =
	'%-' . ($maxlen{proto} + $maxlen{ipver}) . 's' .
	' %-' . $maxlen{ip} . 's' .
	' %' . $maxlen{port} . 's' .
	' %' . $maxlen{pid} . 's' .
	' %-' . $maxlen{euser} . 's' .
	' %s'
;
printf("$format\n", 'PROTO', 'IP', 'PORT', 'PID', 'EUSER', 'COMMAND');
foreach (
	sort {
		fc($procs{$a}->{name}) cmp fc($procs{$b}->{name})
		or $procs{$a}->{pid} cmp $procs{$b}->{pid}
		or $socks{$a}->{proto} cmp $socks{$b}->{proto}
		or $socks{$a}->{ipver} <=> $socks{$b}->{ipver}
		or $socks{$a}->{ip} cmp $socks{$b}->{ip}
		or $socks{$a}->{port} <=> $socks{$b}->{port}
	} keys(%socks)
) {
	printf(
		"$format\n",
		$socks{$_}->{proto} . ($socks{$_}->{ipver} eq '4' ? '' : $socks{$_}->{ipver}),
		$socks{$_}->{ip},
		$socks{$_}->{port},
		$procs{$_}->{pid},
		$procs{$_}->{euser},
		$procs{$_}->{command},
	);
}

# vim: noet sw=8 ts=8
