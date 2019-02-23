package TransBrowse::Controller::Main;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;

# This action will render a template
sub xmits {
    my $self = shift;

    $self->render;
}

sub items {
    my $self = shift;

    my $trans = $self->model->get_xmits;

    $self->render( json =>  { data => $trans->to_array } );
}

sub play {
    my $self = shift;
    my $file = $self->param('file');
    
    my $full_name = $self->model->get_full_name($file);

    $self->render_file(
	'filepath'            => $full_name,
	'content_disposition' => 'inline'
        );
}

sub setvoice {
    my $self = shift;

    my $response = $self->model->set_voice($self->param('xmit_key'),
                                           $self->param('is_voice'));

    $self->render( text => 'success', status => 200 );
}

1;
