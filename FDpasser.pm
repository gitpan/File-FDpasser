package File::FDpasser;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $OS %ostype);

use Socket;
use IO::Pipe;
use Fcntl; 

require Exporter;
require DynaLoader;
require AutoLoader;

@ISA = qw(Exporter AutoLoader DynaLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(

	     send_file
	     recv_fd
	     recv_fh
	     serv_accept_fd
	     serv_accept_fh
	     cli_conn
	     spipe
	     endp_create
	     endp_connect
	     my_getfl
	     get_fopen_mode

);

@EXPORT_OK = qw(

);



$VERSION = '0.06';

bootstrap File::FDpasser $VERSION;

BEGIN {
    %ostype=(linux=>'bsd',
	     bsdos=>'bsd',
	     freebsd=>'bsd',
	     solaris=>'svr',
	     dec_osf=>'bsd',
		 irix=>'bsd',
		 hpux=>'bsd'

	     );
    
    $OS=$ostype{$^O} || die "Platform $^O not supported!\n";
}

sub spipe {
    local(*RD,*WR);
    if ($OS eq 'bsd') {
	socketpair(RD, WR, AF_UNIX, SOCK_STREAM, PF_UNSPEC) || die "socketpair: $!\n";
    } else {
	pipe(RD,WR) || die "pipe: $!\n";
    }
    return (*RD{IO}, *WR{IO});
}

sub endp_create {
    my($name)=@_;
    my ($sck,$rem);
    if ($OS eq 'bsd') {
	local(*SCK);
	my $uaddr = sockaddr_un($name);
	socket(SCK,PF_UNIX,SOCK_STREAM,0) || return undef;
	unlink($name);
	bind(SCK, $uaddr) || return undef;
	listen(SCK,SOMAXCONN) || return undef;
	$sck=*SCK{IO};
	$sck->autoflush();
    } else {
	local(*SCK,*REM);
	pipe(SCK,REM);
	$sck=*SCK{IO};
	$rem=*REM{IO};
	$sck->autoflush();
	$rem->autoflush();
	unlink($name);
	bind_to_fs(fileno(REM),$name) || return undef;
    }
    return $sck;
}

sub endp_connect {
    local(*FH);
    my($serv)=@_;
    if ($OS eq 'bsd') {
	socket(FH, PF_UNIX, SOCK_STREAM, PF_UNSPEC) || return undef;
	my $sun = sockaddr_un($serv);
	connect(FH,$sun) || return undef;
    } else {
	open(FH,$serv) || return undef;
	if (!my_isastream(fileno(FH))) { close(FH); return undef; }
    }
    return *FH{IO};
}

sub recv_fd {
    my ($conn)=@_;
    if (ref($conn) =~ m/^IO::/) { $conn=fileno($conn); }
#    print "recv_fd: ",$conn,"\n";
    my $fd=my_recv_fd($conn);
#    print "recv_fd: $!\n";
    if ($fd <0) { return undef; }
    return $fd;
}

sub recv_fh {
    my ($conn)=@_;
    if (ref($conn) =~ m/^IO::/) { $conn=fileno($conn); }
#    print "recv_fh conn: $conn\n";
    my ($fd)=my_recv_fd($conn);
#    print "recv_fh fd: $fd\n";
    if ($fd <0) { return undef; }
    my $fh=IO::Handle->new();
    $fh->fdopen($fd,get_fopen_mode($fd)) || return undef;
    return $fh;
}

sub send_file {
    my($conn,$sendfd)=@_;
    my $fd_rc;
    if (ref($conn) =~ m/^IO::/) { $conn=fileno($conn); }
    if (ref($sendfd) =~ m/^IO::/) { $sendfd=fileno($sendfd); }
    if ($conn !~ /^\d+$/ or $sendfd !~ /^\d+$/) { die "Invalid args to send_file: $_[0], $_[1]\n"; }
#    print "send_file: $conn, $sendfd\n";
    $fd_rc=my_send_fd($conn,$sendfd) && return undef;
    return 1;
}

sub serv_accept_fd {
    my($lfd,$uid)=@_;
    if (ref($lfd) =~ m/^IO::/) { $lfd=fileno($lfd); } else { return undef; }
    my $fd=my_serv_accept($lfd,$uid);
#    print "retfd: $fd\n";
    if ($fd<0) { return undef; }
    return $fd;
}

sub serv_accept_fh {
    my($LFH,$uid)=@_;
    local(*FH);
    my $lfd;
    if (ref($LFH) =~ m/^IO::/) { $lfd=fileno($LFH); } else { return undef; }
    if ($OS eq 'bsd') { 
	accept(FH,$LFH) || return undef;
	return *FH{IO};
    } else {
	my $fd=my_serv_accept($lfd,$uid);
	if ($fd <0) { return undef; }
	my $fh=IO::Handle->new();
	$fh->fdopen($fd,get_fopen_mode($fd)) || return undef;
	return $fh;
    }
}

sub get_fopen_mode {
    my $fd=$_[0];

    my $rc=my_getfl($fd);
#    print "fd: $rc\n";
    return undef if $rc <0;
    my $acc=($rc&O_ACCMODE);
    my $app=($rc&O_APPEND);
    if ($acc == O_RDONLY) { return "r"; }
    if ($acc == O_WRONLY and !$app)  { return "w"; }
    if ($acc == O_WRONLY and $app) { return "a"; }
    if ($acc == O_RDWR and !$app) { return "w+"; }
    if ($acc == O_RDWR and $app) { return "a+"; }
}

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

File::FDpasser - Perl extension for blah blah blah

=head1 SYNOPSIS

  use File::FDpasser;

	($fd1,$fd2)=spipe(); 

	$fd=cli_conn($path);
	$listenfd=serv_listen($path);
	$new_fd=serv_accept_fd($listenfd, $uid);
	$ok=send_fd($clifd, $fd_to_send);
	$recvied_fd=recv_fd($sockpipe_fd);

         send_file
         recv_fd
         recv_fh
         serv_accept_fd
         serv_accept_fh
         cli_conn
         spipe
         endp_create
         endp_connect
         my_getfl
         get_fopen_mode

=head1 DESCRIPTION

No documentation yet 



=head1 AUTHOR

amh@mbl.is

=head1 SEE ALSO

perl(1).
http://gauss.mbl.is/~amh/FDpasser/.
Advanced Programming in the UNIX Environment, Addison-Wesley, 1992.
UNIX Network Programming, Prentice Hall, 1990.
=cut
