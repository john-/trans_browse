package TransBrowse::Model::Transmissions;
use Mojo::Base -base;

use warnings;
use strict;

use File::Find::Rule;
use Math::Round;

use Carp ();
use Data::Dumper;

has postgres => sub { Carp::croak 'db is required' };
has log      => sub { Carp::croak 'log is required' };

sub get_xmits {
    my $self = shift;

    my $trans = $self
	->postgres
	->db
	->query('select xmit_key, file, (regexp_matches(file, \'^[0-9.]+\'))[1]::numeric as freq, (regexp_matches(file, \'_([0-9.]+)\'))[1]::numeric as timestamp, entered, detect_voice, class from xmit_history where entered >= timestamp \'2018-08-05 14:00\' and entered <= timestamp \'2018-08-05 16:00\' order by timestamp asc limit 1000')
#	->query('select file from xmit_history limit 10 order by entered asc')
	->hashes;

#    $trans->each( sub {
#        if ( $_->{file} =~ /^(\d+.\d+)_(\d+).wav/ ) {
#            my $pos =  ($1 - int($1)) / 0.0125 ;
	    #            $pos = nearest( 0.01, $pos );
#            $_->{freq_detect} = $1;
#            $_->{pos} = $pos;
#            $_->{freq_rounded} = int($1) + 0.0125 * sprintf('%.f', $pos);
#            $_->{time} = $2;
#        }
#    } );

    return $trans;
};

sub get_full_name {
    my ($self, $file) = @_;

    my @files = File::Find::Rule->file()
	->name( $file )
	->in( '/cart/data/wav' );
    return $files[0];
};

sub set_voice {
    my ($self, $xmit_key, $class) = @_;

    eval {
        $self
	    ->postgres
	    ->db
            ->update('xmit_history', {class => $class}, {xmit_key => $xmit_key});
    };
    $self->log->error($@) if $@;
};


1;
