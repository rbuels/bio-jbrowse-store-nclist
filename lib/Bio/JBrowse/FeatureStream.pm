package Bio::JBrowse::FeatureStream;
use strict;
use warnings;

my %must_flatten =
   map { $_ => 1 }
   qw( name id start end score strand description note );
# given a hashref like {  tagname => [ value1, value2 ], ... }
# flatten it to numbered tagnames like { tagname => value1, tagname2 => value2 }
sub _flatten_multivalues {
    my ( $self, $h ) = @_;
    my %flattened;

    for my $key ( keys %$h ) {
        my $v = $h->{$key};
        if( @$v == 1 ) {
            $flattened{ $key } = $v->[0];
        }
        elsif( $must_flatten{ lc $key } ) {
            for( my $i = 0; $i < @$v; $i++ ) {
                $flattened{ $key.($i ? $i+1 : '')} = $v->[$i];
            }
        } else {
            $flattened{ $key } = $v;
        }
    }

    return \%flattened;
}

1;
