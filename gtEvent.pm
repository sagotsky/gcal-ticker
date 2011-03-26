# gcal ticker event class for gticker

package gtEvent;
use DateTime;
use strict;
use warnings;
#use Data::Dumper;
use Tie::IxHash;

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

    my $sdate = DateTime->new (
        year => $syear,
        month => $smonth,
        day => $sday,
        hour => $shour,
        minute => $sminute,
        time_zone => $cfg->timezone(),
    );
    # we don't actually use end date yet, but it's here for when it seems useful
    my $edate = DateTime->new (
        year => $eyear,
        month => $emonth,
        day => $eday,
        hour => $ehour,
        minute => $eminute,
        time_zone => $cfg->timezone(),
    );

    # figure out this cal's color
    #my %colormap;
    #@colormap{ @{$cfg->calendars()} } = @{$cfg->colors()};
    #print Dumper %colormap;

    my %colormap = %{$cfg->colormap()};

    # store variables for later reference
    $self->{'date'} = $sdate;
    $self->{'title'} = $title;
    $self->{'cal'} = $cal;
    $self->{'format'} = $cfg->format();
    $self->{'color'} = $colormap{$cal};

    bless $self;
    return $self;
}

sub getText {
    my ($self) = @_;
    my $text = $self->{'title'};
    my $calcolor = $self->{'color'};
    my $format = $self->{'format'};
    my $timeleft = timeleft($self->{'date'});
    if ($timeleft < -30) {return ""}; # this should check end date.  current events should get a special label (can dzen change bgcolor?) and expire at event end.  this should fix all day events I think.
    my $tcolor = timecolor($timeleft);
    my $time  = timeunit($timeleft);

    my $textcolor = '#557799'; # getColor()
    my $sigil = '»';

    #timeleft, timeleft color

    # time popup?

    $sigil = color($sigil, $calcolor, $format);
    $text = color($text, $textcolor, $format);
    $time = color($time, $tcolor, $format);
    $text = $sigil . ' ' . $text . ' ' . $time . ' ';

    return $text;
}

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
        $text = "^fg($color)$text";
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

return(1);
