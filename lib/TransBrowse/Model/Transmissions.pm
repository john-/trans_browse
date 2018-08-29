package TransBrowse::Model::Transmissions;
use Mojo::Base -base;

use warnings;
use strict;

use File::Find::Rule;

use Carp ();
use Data::Dumper;

has postgres => sub { Carp::croak 'db is required' };

sub get_xmits {
    my $self = shift;

    return 
        $self
	->postgres
	->db
	->query('select file, (regexp_matches(file, \'_([0-9.]+)\'))[1]::numeric as timestamp, entered from xmit_history where entered >= timestamp \'2018-08-05 14:00\' and entered <= \'2018-08-05 16:00\' order by timestamp asc limit 100')
#	->query('select file from xmit_history limit 10 order by entered asc')
	->hashes;
};

sub get_full_name {
    my ($self, $file) = @_;

#    say "in get_full_name: $file";
#    my @files = File::Find::Rule->file()
#	->name( $file )
#	->in( '/home/pub/ham2mon/apps/wav' );
    #    say @files;
    return '/home/pub/ham2mon/apps/wav/' . $file;
};


1;
