package TransBrowse;
use Mojo::Base 'Mojolicious';

use Mojo::Pg;

use TransBrowse::Model::Transmissions;

has postgres => sub {
    return Mojo::Pg->new('postgresql://script@/cart');
};

# This method will run once at server start
sub startup {
  my $self = shift;

  $self->helper(model => sub {
      my $c = shift;
      return TransBrowse::Model::Transmissions->new(
	  postgres => $c->app->postgres,
      );
  });

  $self->plugin('RenderFile');
  
  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('main#xmits');
  $r->get('/play')->to('main#play');
  $r->get('/items')->to('main#items');
}

1;
