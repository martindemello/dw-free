#!/usr/bin/perl

use v5.10;
use strict;
BEGIN { require "$ENV{LJHOME}/cgi-bin/ljlib.pl"; }
use DW::Media;

use Getopt::Long;

sub usage {
    die "Usage: $0 -u USER MEDIAID\n";
}

my ( $user, $versionid );
GetOptions(
    'user=s' => \$user,
);
if ( @ARGV ) {
    if ( $ARGV[0] =~ /^\d+$/ ) {
        $versionid = shift;
    } else {
        usage();
    }
} else {
    usage();
}

my $u = LJ::load_user( $user )
    or usage();

# Select row from media_versions
my @mv = $u->selectrow_array( "SELECT mediaid FROM media_versions" .
                              " WHERE userid=? AND versionid=?", undef,
                              $u->id, $versionid );
unless ( @mv ) {
    say 'User has no matching media, nothing to do.';
    exit 0;
}

my ( $mediaid ) = @mv;

if ( $mediaid == $versionid ) {
    # this is the original, so the corresponding row in
    # the media table needs to have its state updated
    $u->do( "UPDATE media SET state='D' WHERE userid=? AND mediaid=?", undef,
            $u->id, $mediaid );
    if ( $u->err ) {
        say "Error updating media table: " . $u->errstr;
        exit 1;
    } else {
        say "User's mediaid $mediaid has been marked as deleted.";
    }

    # next, find any resized versions and queue them for deletion as well
    my @thumbs = $u->selectrow_array(
        "SELECT versionid FROM media_versions WHERE userid=? AND mediaid=?" .
        " AND mediaid != versionid", undef, $u->id, $mediaid );
    push @mv, @thumbs;

} else {
    @mv = ( $versionid );
}

my $mogc = LJ::mogclient();

unless ( $mogc ) {
    say "MogileFS not available, exiting.";
    exit 0;
}

foreach my $id ( @mv ) {
    # create a fake object to get the mogkey
    my $fakeobj = bless { userid => $u->id, versionid => $id }, 'DW::Media::Photo';
    my $mogkey = $fakeobj->mogkey;
    # this will return true whether the file existed or not
    $mogc->delete( $mogkey );
    say "MogileFS file $mogkey has been deleted.";
}

exit 0;
