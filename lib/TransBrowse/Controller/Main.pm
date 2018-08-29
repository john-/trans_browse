package TransBrowse::Controller::Main;

use Mojo::Base 'Mojolicious::Controller';
use Math::Round;
use Data::Dumper;

# This action will render a template
sub xmits {
    my $self = shift;

    my $trans = $self->model->get_xmits;
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

    $self->render(xmits => $trans->to_array);
}

sub play {
    my $self = shift;
    my $file = $self->param('file');
    
    my $full_name = $self->model->get_full_name($file);

    $self->render_file(
	#'filepath'            => "/home/pub/ham2mon/apps/wav/$file",
	#'filepath'            => "/home/pub/ham2mon/apps/wav_trimmed/$file",
	'filepath'            => $full_name,
	'content_disposition' => 'inline'
    );
    
}

1;
