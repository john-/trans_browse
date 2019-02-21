package TransBrowse::Model::Transmissions;
use Mojo::Base -base;

use warnings;
use strict;

use File::Find::Rule;
use Math::Round;

use Carp ();
use Data::Dumper;

has postgres => sub { Carp::croak 'db is required' };

sub get_xmits {
    my $self = shift;

    my $trans = $self
	->postgres
	->db
	->query('select file, (regexp_matches(file, \'_([0-9.]+)\'))[1]::numeric as timestamp, entered, detect_voice, is_voice from xmit_history where entered >= timestamp \'2018-08-05 14:00\' and entered <= timestamp \'2018-08-05 16:00\' order by timestamp asc limit 1000')
#	->query('select file from xmit_history limit 10 order by entered asc')
	->hashes;

    $trans->each( sub {
        if ( $_->{file} =~ /^(\d+.\d+)_(\d+).wav/ ) {
            my $pos =  ($1 - int($1)) / 0.0125 ;
            $pos = nearest( 0.01, $pos );
            $_->{freq_detect} = $1;
            $_->{pos} = $pos;
            $_->{freq_rounded} = int($1) + 0.0125 * sprintf('%.f', $pos);
            $_->{time} = $2;
        }
    } );

    return $trans;
};

sub get_full_name {
    my ($self, $file) = @_;

    # right now file needs to be in main wav file directory and not a subdir
#    say "in get_full_name: $file";
#    my @files = File::Find::Rule->file()
#	->name( $file )
#	->in( '/home/pub/ham2mon/apps/wav' );
    #    say @files;
    return '/home/pub/ham2mon/apps/wav/' . $file;
};


1;
