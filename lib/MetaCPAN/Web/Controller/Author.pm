package MetaCPAN::Web::Controller::Author;
use strict;
use warnings;
use base 'MetaCPAN::Web::Controller';

sub index {
    my ( $self, $req ) = @_;
    my $cv = AE::cv;
    my ( undef, undef, $id ) = split( /\//, $req->path );

    my $out;

    my $author   = $self->model('Author')->get($id);
    my $releases = $self->model->request(
        '/release/_search', {
            query => {
                filtered => {
                    query  => { match_all => {} },
                    filter => { term      => { author => uc($id) } }
                }
            },
            sort => [
                'distribution', { 'version_numified' => { reverse => \1 } }
            ],
            size => 1000,
        }
    );

    ( $author & $releases )->(
        sub {
            my ( $author, $releases ) = shift->recv;
            unless ( $author->{pauseid} ) {
                $cv->send( $self->not_found($req) );
                return;
            }
            $cv->send(
                {   author   => $author,
                    releases => [
                        map { $_->{_source} } @{ $releases->{hits}->{hits} }
                    ],
                    took  => $releases->{took},
                    total => $releases->{hits}->{total}
                }
            );
        }
    );

    return $cv;
}

1;
