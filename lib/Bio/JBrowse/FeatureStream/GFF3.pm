package Bio::JBrowse::FeatureStream::GFF3;
use strict;
use warnings;

use base 'Bio::JBrowse::FeatureStream';

sub new {
    my ( $class, @parsers ) = @_;

    return sub {} unless @parsers;

    my @items;
    my $cur_p = shift @parsers;
    my $item_stream = sub {
        return shift @items || do {
            my $i;
            until( ref $i eq 'ARRAY' ) {
                $i = $cur_p->next_item
                    or $cur_p = shift @parsers
                    or return;
            }
            @items = @$i;
            shift @items;
        };
    };

    my $self;
    $self = sub {
        my $item = $item_stream->() or return;
        return $self->_convert( $item );
    };
    return bless $self, $class;
}

sub _convert {
    my ( $self, $f ) = @_;

    $f->{score} += 0 if defined $f->{score};
    $f->{phase} += 0 if defined $f->{phase};

    my $a = delete $f->{attributes};
    my %h;
    for my $key ( keys %$f) {
        my $lck = lc $key;
        my $v = $f->{$key};
        if( defined $v && ( ref($v) ne 'ARRAY' || @$v ) ) {
            unshift @{ $h{ $lck } ||= [] }, $v;
        }
    }
    # rename child_features to subfeatures
    if( $h{child_features} ) {
        $h{subfeatures} = [
            map {
                [ map $self->_convert( $_ ), map @$_, @$_ ]
            } @{delete $h{child_features}}
        ];
    }
    if( $h{derived_features} ) {
        $h{derived_features} = [
            map {
                [ map $self->_convert( $_ ), map @$_, @$_ ]
            } @{$h{derived_features}}
        ];
    }

    my %skip_attributes = ( Parent => 1 );
    for my $key ( sort keys %{ $a || {} } ) {
        my $lck = lc $key;
        if( !$skip_attributes{$key} ) {
            push @{ $h{$lck} ||= [] }, @{$a->{$key}};
        }
    }

    my $flat = $self->_flatten_multivalues( \%h );
    return $flat;
}

1;
