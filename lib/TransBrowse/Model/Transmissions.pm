package TransBrowse::Model::Transmissions;
use Mojo::Base -base;

use warnings;
use strict;

use File::Find::Rule;
use Math::Round;

use Audio::Wav;

use Carp ();
use Data::Dumper;

has postgres => sub { Carp::croak 'db is required' };
has log      => sub { Carp::croak 'log is required' };
has config   => sub { Carp::croak 'config is required' };

sub get_xmits {
    my $self = shift;

    my $trans = $self
	->postgres
	->db
	->query('select xmit_key, file, (regexp_matches(file, \'^[0-9.]+\'))[1]::numeric as freq, (regexp_matches(file, \'_([0-9.]+)\'))[1]::numeric as timestamp, entered, detect_voice, class from xmit_history where entered >= timestamp \'2019-06-16 16:00\' and entered <= timestamp \'2019-06-16 18:00\' order by timestamp asc limit 1000')    # Sprints 2019
#	->query('select xmit_key, file, (regexp_matches(file, \'^[0-9.]+\'))[1]::numeric as freq, (regexp_matches(file, \'_([0-9.]+)\'))[1]::numeric as timestamp, entered, detect_voice, class from xmit_history where entered >= timestamp \'2018-08-05 14:00\' and entered <= timestamp \'2018-08-05 16:00\' order by timestamp asc limit 1000')     # IMSA 2018
	->hashes;

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

sub create_training_data {
    my $self = shift;

    $self->log->debug('Creating training data');

    my $trans = $self
	->postgres
	->db
	->query('select xmit_key, file, (regexp_matches(file, \'^[0-9.]+\'))[1]::numeric as freq, (regexp_matches(file, \'_([0-9.]+)\'))[1]::numeric as timestamp, entered, class from xmit_history where class <> \'U\'')
	->hashes;

    my $base_dir = $self->config->{base_dir};
    $self->log->debug(sprintf('Base dir is %s', $base_dir));

    my $err;

    # Always start dump of training data with empty directory
    if (-e $base_dir) {
	$err = sprintf('Remove base dir (%s) to rebuild training data (no training data has been created)', $base_dir);
        $self->log->error(sprintf($err));
	return $err;
    }

    # create directory structure for training data
    if (!mkdir($base_dir)) {
	$err = sprintf('Could not create base dir (%s) for training data: %s (no training data has been created)', $base_dir, $!);
        $self->log->error(sprintf($err));
	return $err;
    }
    my $classes = $trans->uniq( sub { $_->{class} } );

    $classes->each( sub {
	if (!defined($self->config->{dir_map}{$_->{class}})) {
	    $err = sprintf('Config has no dir_map entry for "%s"', $_->{class});
            $self->log->error(sprintf($err));
	    return;
	}

	my $dir = sprintf('%s/%s', $base_dir, $self->config->{dir_map}{$_->{class}});
        if (!mkdir($dir)) {
	    $err = sprintf('Could not create class dir (%s) for training data: %s', $dir, $!);
            $self->log->error(sprintf($err));
	} else {
	    $self->log->info(sprintf('Created class dir for "%s": %s', $_->{class}, $dir));
	}
    });

    if ($err) {
	$self->log->error('No training data has been created');
	return $err;
    }

    my $wav = Audio::Wav->new;

    my $created = 0;
    $trans->each( sub {
	my $src = $self->get_full_name($_->{file});
        my $dst = sprintf('%s/%s/%s', $base_dir, $self->config->{dir_map}{$_->{class}}, $_->{file});

        my $read = $wav->read( $src );
        my $duration = $read->length_seconds;

        # use only middle second for first attempt at training
        $self->log->debug(sprintf('attempting to process: %s', $src));
	my @args = ( '/usr/bin/sox', $src, $dst, 'trim', $duration / 2 - 0.5, '1' );
	if (system( @args )  == 0) {
	    $created++;
	} else {
	    $self->log->error("system @args failed: $?");
	}
    });
    $self->log->info(sprintf('created %d of %d training files', $created, $trans->size));
    return 'Training data created';
}

1;
