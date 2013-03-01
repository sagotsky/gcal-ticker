# gcal ticker event class for gticker

package gtEvent;
use DateTime;
use strict;
use warnings;
#use Data::Dumper;
use Tie::IxHash;

# log notifications so we don't repeat any alarms.  
# deleting $self->notify in gtEvent isn't working
# it should fail if a new ste of events downloads,
# but fails way too frequently for that to be the case.
our @notifications = ();
sub notify {
    my ($options, $cal, $text) = @_;
    #if (! grep(/$text/, @notifications) ) {
    if (! grep(/\Q$text\E/, @notifications) ) {
        `notify-send $options "$cal" "$text"`;
        push(@notifications, $text);
        if ($#notifications > 10) {shift @notifications};
    }
}

sub new{
    my ($module, $cal, $def, $cfg) = @_;
    my ($self) = {};
    my ($date, $title) = split( /,/ , $def);

    #parse the date
    my ($smonth, $sday, $shour, $sminute, $dash, $emonth, $eday, $ehour, $eminute) =
    split( /[\s\:]/ , $date );

    # dates don't include year, so try and figure it out
    my $now_year = DateTime->now( time_zone => $cfg->timezone() )->year ;
    my $now_month = DateTime->now( time_zone => $cfg->timezone() )->month ;

    my $syear = $now_year;
    my $eyear = $now_year;

    $smonth = m2n($smonth);
    $emonth = m2n($emonth);

    if ($now_month > $smonth) {$syear += 1};
    if ($now_month > $emonth) {$eyear += 1};

    # dirty hack to avoid leap year by fudging feb 29 
    if ($sday == 29 && $smonth == 2 && $syear % 4 != 0) {
      $sday = 28; 
    }

    my $sdate = DateTime->new (
        year => $syear,
        month => $smonth,
        day => $sday,
        hour => $shour,
        minute => $sminute,
        time_zone => $cfg->timezone(),
    );

    # dirty hack to avoid leap year by fudging feb 29 
    if ($eday == 29 && $emonth == 2 && $syear % 4 != 0) {
      $eday = 28; 
    }
    my $edate = DateTime->new (
        year => $eyear,
        month => $emonth,
        day => $eday,
        hour => $ehour,
        minute => $eminute,
        time_zone => $cfg->timezone(),
    );

    # figure out this cal's color
    my %colormap = %{$cfg->colormap()};

    # store variables for later reference
    $self->{'date'} = $sdate;
    $self->{'edate'} = $edate;
    $self->{'title'} = $title;
    $self->{'cal'} = $cal;
    $self->{'format'} = $cfg->format();
    $self->{'color'} = $colormap{$cal};
    $self->{'doNotify'} = $cfg->notify();
    #$self->{'notifyOptions'} = " -t 5000 -i /usr/share/pixmaps/gnome-set-time.png -h int:x:1200 -h int:y:24 ";
    $self->{'notifyOptions'} = $cfg->notifyoptions();
    $self->{'maxchars'} = $cfg->maxchars();

    if ($cfg->alert() >= 0) { $self->{'alert'} = $cfg->alert(); }
    else { $self->{'alert'} = 5; }
    
    bless $self;
    return $self;
}

sub getText {
    my ($self) = @_;
    my $text = $self->{'title'};
    #my $text = substr($self->{'title'}, 0, $self->{'maxchars'}); # . '…';
    if (length($text) > $self->{'maxchars'}) {
      $text = substr($text, 0, $self->{'maxchars'}) . '..';
    }
    my $calcolor = $self->{'color'};
    my $format = $self->{'format'};
    my ($sigil, $tcolor, $timesigil);

    my $timeleft = timeleft($self->{'date'});
    my $endtime = timeleft($self->{'edate'});

    #if (0 < $timeleft && $timeleft < 10 && $self->{'doNotify'}) { #should donotify be a function that sets itself?
    #delete $self->{'doNotify'} ;
        #`notify-send "$self->{'cal'}" "$text"`; # might trigger twice, if new @events is created...
        #`notify-send $self->{'notifyOptions'} "$self->{'cal'}" "$text"`;
        #}

    my $time   = timeunit($timeleft);
    my $textcolor = '#557799'; # getColor()

    if ($endtime < 0) {return ""};

    # upcoming/current event pre
    if ($timeleft >= 0) {
        # upcoming event

        # notify (may happen twice if gcal downloads between notifications)
        if ($self->{'alert'} > $timeleft && $self->{'doNotify'} ) {
            delete $self->{'doNotify'} ;
            #`notify-send $self->{'notifyOptions'} "$self->{'cal'}" "$text"`;
            notify($self->{'notifyOptions'}, $self->{'cal'}, $text);
        }

        $tcolor = timecolor($timeleft);
        $sigil = ' »';
        $timesigil = "";
    } else {
        # current event
        $sigil = ' «';
        $tcolor = "#cccccc";
        $timesigil = ":";
        $time = timeunit($endtime);  
    }

    $sigil = color($sigil, $calcolor, $format); 
    $text  = color($text, $textcolor, $format);
    $time  = color($time, $tcolor, $format);
    $text  = $sigil . ' ' . $text . ' ' . $timesigil.$time . ' ';

    # post process wrapping.
    if ($timeleft < 0 && $self->{'format'} eq 'dzen') { $text = '^bg(#223344) ' . $text . '^bg() ' };

    return $text;
}

# minutes left until a date
sub timeleft {
    my ($date) = @_;
    return int( ($date->epoch - DateTime->now()->epoch)/60 );
}

sub timecolor {
    my ($minutes) = @_;
    my $color = "";

    if ($minutes > 24*60)    { $color = '#888888';}
    elsif ($minutes ~~ [60..24*60])       { $color = '#aaaaaa';}
    elsif ($minutes ~~ [10..59] )       { $color = '#ffffff';}
    elsif ($minutes ~~ [0..9] )       { $color = '#00ff00';}
    elsif ($minutes ~~ [-9..-1] )       { $color = '#ff5500';}
    elsif ($minutes < -10 )       { $color = '#ff3333';} 
    else                        { $color = '#cccccc';}
    #if ($minutes > 24*60)    { $color = '#888888';}
    #elsif ($minutes > 60)       { $color = '#aaaaaa';}
    #elsif ($minutes < 0 )       { $color = '#ff5500';}
    #elsif ($minutes < -10 )       { $color = '#333333';} 
    #else                        { $color = '#cccccc';}

    return $color;
}

sub timeunit {
    my ($tl) = @_;
    my $unit = 'm';

    # hash 60->min, 60-hour, 24-day.  loop through and see what divides.  use that as final unit.
    my %units = ();
    tie %units, "Tie::IxHash"; # preserves order
    %units = (
        'h' => 60,
        'd' => 24,
        'w' => 07,
        'y' => 52,
    );

    while ( my ($u, $n) = each(%units) ) {
        if ($tl/$n >= 1) {
            $tl = $tl/$n;
            $unit = $u;
        }  else {
            last; # perl equivalent of break.  useful for "last if (condition)"
        }
    }
    $tl = sprintf("%.1f", $tl); # %.nf = round to n significant digits
    return $tl.$unit;
}

sub color {
    my ($text, $color, $format) = @_;
    if ($format eq "html" ) {
        $text = '<font style=\'color:'.$color.'>'.$text.'</font>';
    } elsif ($format eq "xmobar") {
        $text = "<fc=$color>$text</fc>";
    } elsif ($format eq "dzen") {
        $text = "^fg($color)$text^fg()";
    } elsif ($format eq "term") {
        $text = $text;  # we need a return color...
    }

    return $text;
}

sub getDate {
    my ($self) = @_;
    return $self->{'date'};
}

sub m2n {
    my ($mon) = @_;
    my %dates = ( 
        'Jan'=>  '1',
        'Feb'=>  '2',
        'Mar'=>  '3',
        'Apr'=>  '4',
        'May'=>  '5',
        'Jun'=>  '6',
        'Jul'=>  '7',
        'Aug'=>  '8',
        'Sep'=>  '9',
        'Oct'=> '10',
        'Nov'=> '11',
        'Dec'=> '12',
    );

    return $dates{$mon};
}

#sub escapeChars {
#my ($str) = @_;
#$str =~ s/([&'^><])/\\$1/g;
#return $str;
#}

return(1);
