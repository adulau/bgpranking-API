#!/usr/bin/perl
#
#    Whois-like API to BGP Ranking
#
#    Copyright (C) 2011 Alexandre Dulaunoy
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#


$| = 1;

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

# source format
#my @Source = (
#    "ZeustrackerIpBlockList", "URLQuery",
#    "MalwareDomainListIP",    "DshieldDaily",
#    "DshieldTopIPs",          "SpyeyetrackerIpBlockList",
#    "AmadaIpBlockList",       "BlocklistDe"
#);

my $r = Redis->new( server => '149.13.33.68:6379' );
$r->select("6");
my $rc = Redis->new( server => '127.0.0.1:6379' );
$rc->select("2");
my $asn = "";

my $input = <STDIN>;
$asn = substr $input, 0, 32;
chomp($asn);
if ( !checkASN($asn) ) {
    print "ASN format incorrect";
    ByeBye();
}
my ( $total, $visibility, $best, $score ) = fetchASN($asn);
my $value =
  $asn . "," . $total . "," . $visibility . "," . $best . "," . $score;

print "# ASN,Rank,Matched BL,Best Ranking,Current Position\n";
print $value. "\n";
cacheValue($value);
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
    $r->select("5");
    my @Source = $r->smembers( $yesterday . "|sources" );
    $r->select("6");
    my $r2 = Redis->new( server => '149.13.33.68:6382' );
    $r2->select("6");
    my $asrank = $r2->zrevrank( $yesterday . "|global|rankv4", $asn );
    if ( !defined($asrank) ) { $asrank = "not ranked"; }
    my $astotal = $r2->zcard( $yesterday . "|global|rankv4" );
    my $score   = $asrank . "/" . $astotal;
    my @bestrank =
      $r2->zrevrange( $yesterday . "|global|rankv4", 0, 0, "WITHSCORES" );
    my $best = 1 + $bestrank[1];

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
    return ( $total, $visibility, $best, $score );

}
