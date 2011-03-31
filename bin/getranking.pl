$| = 1;
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

my $r = Redis->new( server => '149.13.33.68:6379' );
$r->select("6");
$asn = $ARGV[0];

my $total = 1;
foreach my $lsource (@Source) {

    $key = $asn . "|" . $yesterday . "|" . $lsource . "|rankv4";

    if ( $r->exists($key) ) {
        my $rankingvalue = $r->get($key);
        my $decrankingvalue = sprintf( "%.20f", $rankingvalue );

        #print $key."=". $decrankingvalue ."\n";
        $total = $total + $decrankingvalue;
    }

}
print $total. "\n";
$r->quit();
