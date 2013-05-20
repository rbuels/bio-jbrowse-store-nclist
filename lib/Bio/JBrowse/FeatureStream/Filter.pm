package Bio::JBrowse::FeatureStream::Filter;
# ABSTRACT: filter another stream using a subroutine
use strict;
use warnings;

use base 'Bio::JBrowse::FeatureStream';


=method new( $stream, $filter_sub )

Filter a stream of features according to whether the given subroutine
returns true for a feature.  Recurses to subfeatures and returns those
if the sub returns true for them, but not the parent feature.

=cut

sub new {
    my ( $class, $stream, $filter_sub ) = @_;

    my $self;
    my @buffer;
    return $self = bless sub {
        my @buffer;
        return shift @buffer || do {
            while( !@buffer && ( my $f = $stream->() ) ) {
                push @buffer, $self->_apply_filter( $filter_sub, $f );
            }
            shift @buffer;
        };
    }, $class;
}

sub _apply_filter {
    my ( $self, $filter_sub, $feature ) = @_;

    return $feature if $filter_sub->( $feature );
    return map $self->_apply_filter( $filter_sub, $_ ), @{ $feature->{subfeatures} || [] };
}

1;
