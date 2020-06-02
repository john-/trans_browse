package TransBrowse::Model::Transmissions;
use Mojo::Base -base;

use warnings;
use strict;

use File::Find::Rule;
use Math::Round;

use TransmissionIdentifier;

use File::Path 'make_path';

use DateTime;

use Carp ();
use Data::Dumper;

has postgres => sub { Carp::croak 'db is required' };
has log      => sub { Carp::croak 'log is required' };
has config   => sub { Carp::croak 'config is required' };
has trans_ident => sub { TransmissionIdentifier->new( { load_params => 1,
                                                        params => '/cart/xmit_mxnet/xmit.params',
                                                        labels => '/cart/xmit_mxnet/labels.txt' }
                                                     ) };

sub get_xmits {
    my $self = shift;

    my $trans = $self
	->postgres
	->db
	->query('select xmit_key, file, (regexp_matches(file, \'^[0-9.]+\'))[1]::numeric as freq, (regexp_matches(file, \'_([0-9.]+)\'))[1]::numeric as timestamp, entered, detect_voice, class from xmit_history where entered >= cast(? as timestamp) and entered <= cast(? as timestamp) and class = any(?::text[]) and detect_voice = any(?::boolean[]) order by timestamp asc limit 1000',
            $self->config->{query}{begin},
            $self->config->{query}{end} || DateTime->now,
            $self->config->{query}{classes},
            $self->config->{query}{detect_voice},
        )    # IMSA 2019
#	->query('select xmit_key, file, (regexp_matches(file, \'^[0-9.]+\'))[1]::numeric as freq, (regexp_matches(file, \'_([0-9.]+)\'))[1]::numeric as timestamp, entered, detect_voice, class from xmit_history where entered >= timestamp \'2019-08-04 13:30\' and entered <= timestamp \'2019-08-04 16:30\' order by timestamp asc limit 1000')    # IMSA 2019
#	->query('select xmit_key, file, (regexp_matches(file, \'^[0-9.]+\'))[1]::numeric as freq, (regexp_matches(file, \'_([0-9.]+)\'))[1]::numeric as timestamp, entered, detect_voice, class from xmit_history where entered >= timestamp \'2019-06-16 16:00\' and entered <= timestamp \'2019-06-16 18:00\' order by timestamp asc limit 1000')    # Sprints 2019
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

    $self->log->info('Creating training data');

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
    #if (-e $base_dir) {
	#$err = sprintf('Could not create base dir (%s) for training data: %s (no training data has been created)', $base_dir, $!);
       # $self->log->error(sprintf($err));
#	return $err;
 #   }
    my $classes = $trans->uniq( sub { $_->{class} } );

    foreach my $phase ('train', 'test') {
	$classes->each( sub {

	    if (!defined($self->config->{dir_map}{$_->{class}})) {
		$err = sprintf('Config has no dir_map entry for "%s"', $_->{class});
		$self->log->error(sprintf($err));
		return;
	    }

	    my $dir = sprintf('%s/%s/%s', $base_dir, $phase, $self->config->{dir_map}{$_->{class}});
	    if (make_path($dir)) {
		$self->log->info(
                   sprintf('Created class dir for phase %s "%s": %s', $phase, $_->{class}, $dir));
	    } else {
	        $err = sprintf(
                  'Could not create dir (%s) for training data.  No training data created', $dir);
	        $self->log->error($err);
	        return $err;
	    }
	});
    }

    #my $wav_to_png = TransmissionIdentifier->new;
    my $train_amount = int($trans->size * 0.8 );
    my $phase = 'train'; # start out creating training data thn switch to test

    my $created = 0;
    $trans->shuffle->each( sub {
	if ($created > $train_amount) { $phase = 'test' }

	my $src = $self->get_full_name($_->{file});
        my $dst = sprintf('%s/%s/%s/%s.png', $base_dir, $phase, 
            $self->config->{dir_map}{$_->{class}}, $_->{file});

        my $file = $self->trans_ident->audio_to_spectrogram( input => $src , output => $dst );

	if ($file) {
            $created++;
            $self->log->debug(sprintf('created: %s', $file));
	}
    });
    $self->log->info(sprintf('created %d of %d training files', $created, $trans->size));
    return 'Training data created';
}

sub classify {
    my ($self, $file) = @_;

    my $input = $self->get_full_name($file);
    my $class;
    $class = $self->trans_ident->classify( input => $input );
    #$self->log->error(sprintf($err));
    return $class;
}

1;
