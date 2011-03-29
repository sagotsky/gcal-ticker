#!/usr/bin/perl

# displays events from googlecl in one line
# optionally also colors by cal for xmobar, dzen, term?

use strict;
use warnings;
use gtEvent;
use DateTime;
use AppConfig;
use Data::Dumper;

use lib "$ENV{PWD}";

our $debugging = 0;
sub d {
    print STDERR "> @_\n" if $debugging;
}

sub getcfg {
    my $cfg = AppConfig->new();

    # our variables.  Int, String, !bool.  can be coerced into arrays
    $cfg->define("help|h|?|!");
    $cfg->define("days|d|=i");
    $cfg->define("format|f|=s");
    $cfg->define("refresh|r|=i");
    $cfg->define("seconds|s|=i");
    $cfg->define("timezone|tz|=s");
    $cfg->define("calendars|c|=s@");
    $cfg->define("colors|k|=s@");
    $cfg->define("verbose|debug|v|!");

    # internal variables passed as part of $cfg.  don't expect then to be honored.
    $cfg->define("colormap|=s%");

    # set some defaults
    $cfg->days(21);
    $cfg->format('text');
    $cfg->refresh(600);
    $cfg->timezone('America/New_York');
    $cfg->seconds(60);

    # read from file, override from cli
    $cfg->file("$ENV{HOME}/.gcalticker");
    $cfg->args();

    #build color map
    my @colors = @{$cfg->colors()};
    foreach(@{$cfg->calendars()}) {
        $cfg->colormap($_ . '=' . shift @colors);
    }

    if ($cfg->verbose()) {$debugging=1};
    return $cfg;
}

sub getCalData {
    my ($cfg) = @_;
    my @calData = ();
    d("getting gcal data");

    my $start = DateTime->now( time_zone => $cfg->timezone() ); #start needs a bigger range if we're catching older long term events
    $start->subtract( days => $cfg->days() ); #make sure to catch older events that may not have finished.
    my $end = DateTime->now( time_zone => $cfg->timezone() );
    $end->add( days => $cfg->days() );
    my $dates = '-d' . $start->ymd . ',' . $end->ymd;

    foreach( @{ $cfg->calendars() } ) {
        my $r = `google calendar $dates list --fields when,title --cal="$_"`;
        my $cal = $_;
        #push( @calData, split(/\n/, $r) );
        # instead, lets just make the event in caldata and pass that back to be rendered.
        foreach( split(/\n/, $r )) {
            if (  length($_) && ($_ !~ m/\[$cal\]/)  ) {  # skip heading line
                push( @calData, gtEvent->new($cal, $_, $cfg) );
            }
        }
    }

    # sort all events before returning them
    @calData = sort {$a->getDate()->epoch <=> $b->getDate()->epoch} @calData;
    return @calData;
}

#sub makeEvents {
#my ( $calref, $cfg) = @_;
#my (@calData) = @$calref;
#my @events = ();
#
#return @events;
#}

sub agenda {
    d("making agenda");
    my ($events, $cfg) = @_;
#    my (@events) = @$events_ref;

    my $output = "";
    if (@{$events} == 0) {
        d('@events is empty');
        @{$events} = getCalData($cfg);
        # this doesn't change the original events, i think.  we get a new empty one from 
        # ref each time and then set it.
    }

    foreach(@{$events}) {
        $output .= $_->getText()
    }

    return substr($output,0,800);
}

sub help {
    my $msg = <<EOF;

ticker2.pl displays the next set of events from your google calendar.
The following options can be passed as command line arguments or read
in from your ~/.gtickerrc file.  Calendars and colors are *required*

--help -h -?
Display this help message

--days -d
Range of days of data to retrieve.  Goes forward and back.  So if you
retrieve 7 days of data, you actually get everything from 7 days ago 
until 7 days from now.  

--format -f
How should output be formatted.  Current options include html, xmobar, 
and dzen.  Terminal output is planned, but currently unsupported.

--refresh -r
How often should google calendar be downloaded, in seconds.  Default is 
600 seconds.

--seconds -s
How often should ticker be re-displayed.  Default is 60 seconds.

--timezone -tz
Local timezone.  Default is America/New_york

--calendars -c
Comma separated list of calendars to download.  Calendars with spaces in
the title should be quoted.  Calendars can be input over several lines
in rc file (see example)

--colors -k
Colors to tag each calendar.  Use one color per calendar or face the 
wrath of ambiguous perl errors.

--verbose --debug -v
Show debug output

EOF

    print STDERR $msg;
    exit;
}

sub init {
    $|++; # don't wait for a newline
    my $slept = 0;
    my @events = ();
    my $cfg = getcfg();

    help() if $cfg->help();
    
    do {
        print agenda(\@events, $cfg) . "\n";
        d(".");
        if ($slept > $cfg->refresh()) {
            undef @events;
            d("emptying events");
        }
    } while ( $slept += sleep( $cfg->seconds() ) );
}

init()
