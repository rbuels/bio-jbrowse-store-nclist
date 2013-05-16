use strict;
use warnings;

use Test::More;

use Bio::GFF3::LowLevel::Parser;
use Bio::JBrowse::FeatureStream::GFF3;

sub open_gff3(@) {
    return map Bio::GFF3::LowLevel::Parser->open( $_ ), @_;
}


my @f = snarf_stream( Bio::JBrowse::FeatureStream::GFF3->new( open_gff3( 'xt/data/au9_scaffold_subset_sync.gff3' )) );
is( scalar @f, 6, 'got right feature count' ) or diag explain \@f;
#diag explain \@f;
@f = snarf_stream( Bio::JBrowse::FeatureStream::GFF3->new( open_gff3( 'xt/data/au9_scaffold_subset_sync.gff3', 'xt/data/au9_scaffold_subset_sync.gff3') ) );
is( scalar @f, 6*2, 'got right double feature count' ) or diag explain \@f;

done_testing;

sub snarf_stream {
    my ( $stream ) = @_;
    my @r;
    while( my $f = $stream->() ) {
        push @r, $f;
    }
    return @r;
}
