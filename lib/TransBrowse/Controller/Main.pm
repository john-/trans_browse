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
                                           $self->param('class'));

    $self->render( text => 'success', status => 200 );
}

sub create_training_data {
    my $self = shift;

    my $response = $self->model->create_training_data();

    $self->render( text => $response, status => 200 );
}

sub classify_file {
    my $self = shift;
    my $file = $self->param('file');

    my %hash = %{$self->model->classify($file)};

    my @response;
    my @keys = sort { $hash{$b} <=> $hash{$a} } keys %hash;
    foreach my $key ( @keys ) {
	push @response, sprintf('%-6s %6f', $key, $hash{$key});
    }

    $self->render( text => join("\n", @response), status => 200 );
}

1;
