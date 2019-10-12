package TransBrowse;
use Mojo::Base 'Mojolicious';

use Mojo::Pg;

use TransBrowse::Model::Transmissions;

use FindBin qw($Bin);

use Data::Dumper;

# This method will run once at server start
sub startup {
  my $self = shift;

  # Configuration
  my $config =
    $self->plugin( Config => { file => "$Bin/../conf/trans_browse.conf" } );
  $self->helper( config => sub { return $config } );
  $self->secrets( $self->config('secrets') );

  $self->helper( postgres => sub { state $pg = Mojo::Pg->new( $config->{pg} ) } );

  $self->helper(model => sub {
      my $c = shift;
      return TransBrowse::Model::Transmissions->new(
	  postgres => $self->postgres,
	  log      => $c->app->log,
	  config   => $self->config,
      );
  });

  $self->plugin('RenderFile');
  
  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('main#xmits');
  $r->get('/play')->to('main#play');
  $r->get('/items')->to('main#items');
  $r->post('/setvoice')->to('main#setvoice');
  $r->get('/create_training_data')->to('main#create_training_data');
  $r->get('/classify_file')->to('main#classify_file');
}

1;
