package Bio::JBrowse::FeatureStream;
use strict;
use warnings;

# given a hashref like {  tagname => [ value1, value2 ], ... }
# flatten it to numbered tagnames like { tagname => value1, tagname2 => value2 }
sub _flatten_multivalues {
    my ( $self, $h ) = @_;
    my %flattened;

    for my $key ( keys %$h ) {
        my $v = $h->{$key};
        for( my $i = 0; $i < @$v; $i++ ) {
            $flattened{ $key.($i ? $i+1 : '')} = $v->[$i];
        }
    }

    return \%flattened;
}

1;
