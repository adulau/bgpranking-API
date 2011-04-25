#!/usr/bin/perl
#
# BGP Ranking API - simple API (whois-like) to get ASN ranking value
#
# To run your own, you'll need the following:
#
# - A BGP Ranking installation (https://github.com/Rafiot/bgp-ranking)
# - An additional Redis server for caching computed values
#
# Copyright (C) 2011 Alexandre Dulaunoy
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

$| = 1;

my $redisbgpranking = "1.2.3.4:6379";
my $rediscaching = "127.0.0.0:6379";

use strict;
use warnings;

use Redis;
use Date::Calc qw(Add_Delta_Days Day_of_Week);
use Date::Calc qw(Today Add_Delta_Days);
use Number::FormatEng qw(:all);

my @date = Add_Delta_Days( Today(), -1 );

if ( $date[1] < 10 ) {
    $date[1] = "0" . $date[1];
}

if ( $date[2] < 10 ) {
    $date[2] = "0" . $date[2];
}

my $yesterday = $date[0] . "-" . $date[1] . "-" . $date[2];

my @Source = (
    "ZeustrackerIpBlockList", "URLQuery",
    "MalwareDomainListIP",    "DshieldDaily",
    "DshieldTopIPs",          "SpyeyetrackerIpBlockList",
    "AmadaIpBlockList",       "BlocklistDe"
);

my $r = Redis->new( server => $redisbgpranking );
$r->select("6");
my $rc = Redis->new( server => $rediscaching );
$rc->select("2");
my $asn = "";

my $input = <STDIN>;
$asn = substr $input, 0, 32;
chomp($asn);
if ( !checkASN($asn) ) {
    print "ASN format incorrect";
    ByeBye();
}
my ( $total, $visibility ) = fetchASN($asn);
my $value = $asn . "," . $total . "," . $visibility;

cacheValue($value);
print $value. "\n";
ByeBye();

sub ByeBye {
    $r->quit();
    $rc->quit();
    exit();
}

sub cacheValue {
    my $value = shift;
    my $key   = "rank|" . $asn . "|" . $yesterday . "|c4";
    $rc->set( $key => $value );
}

sub checkASN {
    my $asn = shift;
    if ( $asn =~
/^(429496729[0-6]|42949672[0-8]\d|4294967[01]\d{2}|429496[0-6]\d{3}|42949[0-5]\d{4}|4294[0-8]\d{5}|429[0-3]\d{6}|42[0-8]\d{7}|4[01]\d{8}|[1-3]\d{9}|[1-9]\d{8}|[1-9]\d{7}|[1-9]\d{6}|[1-9]\d{5}|[1-9]\d{4}|[1-9]\d{3}|[1-9]\d{2}|[1-9]\d|\d)$/
      )
    {
        return 1;
    }
    return undef;

}

sub fetchASN {

    my $asn         = shift;
    my $total       = 1;
    my $sourcetotal = 1;
    my $sourceview  = 0;
    foreach my $lsource (@Source) {

        my $key = $asn . "|" . $yesterday . "|" . $lsource . "|rankv4";

        if ( $r->exists($key) ) {
            my $rankingvalue = $r->get($key);
            my $decrankingvalue = sprintf( "%.20f", $rankingvalue );

            $total      = $total + $decrankingvalue;
            $sourceview = $sourceview + 1;
        }
        $sourcetotal = $sourcetotal + 1;

    }
    my $visibility = $sourceview . "/" . $sourcetotal;
    return ( $total, $visibility );

}
