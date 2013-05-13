use strict;
use warnings;

use Test::More;
use Bio::JBrowse::Store::NCList::ArrayRepr;

my @test_features = (
    { start => 20,
      end => 30,
      strand => 1,
      fogbat => 'noggin'
    },
    { start => 40,
      end => 50,
      strand => 1,
      fogbat => 'zonker',
      fogHAT => 'slow ride',
      take_it => 'easy',
    },
);

my $repr =  Bio::JBrowse::Store::NCList::ArrayRepr->new;

my $stream = $repr->convert_hashref_stream( sub { shift @test_features } );
my $out = [ snarf_stream( $stream ) ];
is_deeply( $out, [
  [
    0,
    20,
    30,
    1,
    'noggin'
  ],
  [
    1,
    40,
    50,
    1,
    'zonker',
    'easy',
    'slow ride'
  ]
], 'got right output' ) or diag explain $out;
is( $repr->get( $out->[1], 'fogHAT'  ), 'slow ride' );
is( $repr->get( $out->[1], 'take_it' ), 'easy'      );
is( $repr->get( $out->[0], 'fogbat'  ), 'noggin'    );


done_testing;

sub snarf_stream {
    my ( $stream ) = @_;
    my @results;
    while( my $f = $stream->() ) {
        push @results, $f;
    }
    return @results;
}
