package Bio::JBrowse::Store::NCList::ArrayRepr;
#ABSTRACT: compact array-based serialization of hashrefs

use strict;
use warnings;
use Carp;

=head1 DESCRIPTION

    The ArrayRepr class is for operating on indexed representations of objects.

    For example, if we have a lot of objects with similar attributes, e.g.:

        [
            {start: 1, end: 2, strand: -1},
            {start: 5, end: 6, strand: 1},
            ...
        ]

    we can represent them more compactly (e.g., in JSON) something like this:

        class = ["start", "end", "strand"]

        [
            [1, 2, -1],
            [5, 6, 1],
            ...
        ]

    If we want to represent a few different kinds of objects in our big list,
    we can have multiple "class" arrays, and tag each object to identify
    which "class" array describes it.

    For example, if we have a lot of instances of a few types of objects,
    like this:

        [
            {start: 1, end: 2, strand: 1, id: 1},
            {start: 5, end: 6, strand: 1, id: 2},
            ...
            {start: 10, end: 20, chunk: 1},
            {start: 30, end: 40, chunk: 2},
            ...
        ]

    We could use the first array position to indicate the "class" for the
    object, like this:

        classes = [["start", "end", "strand", "id"], ["start", "end", "chunk"]]

        [
            [0, 1, 2, 1, 1],
            [0, 5, 6, 1, 2],
            ...
            [1, 10, 20, 1],
            [1, 30, 40, 1]
        ]

    Also, if we occasionally want to add an ad-hoc attribute, we could just
    stick an optional dictionary onto the end:

        classes = [["start", "end", "strand", "id"], ["start", "end", "chunk"]]

        [
            [0, 1, 2, 1, 1],
            [0, 5, 6, 1, 2, {foo: 1}]
        ]

    Given that individual objects are being represented by arrays, generic
    code needs some way to differentiate arrays that are meant to be objects
    from arrays that are actually meant to be arrays.
    So for each class, we include a dict with <attribute name>: true mappings
    for each attribute that is meant to be an array.

    Also, in cases where some attribute values are the same for all objects
    in a particular set, it may be convenient to define a prototype ("proto")
    with default values for all objects in the set

    In the end, we get something like this:

        classes = [
            { "attributes"  : [ "Start", "End", "Subfeatures" ],
              "proto"       : { "Chrom"       : "chr1"   },
              "isArrayAttr" : { "Subfeatures" : true     }
            }
        ]

    That's what this class facilitates.

=cut

sub new {
    my ($class, $classes) = @_;
    $classes ||= [];

    # fields is an array of (map from attribute name to attribute index)
    my @fields;
    for my $attributes ( map $_->{attributes}, @$classes ) {
        my $field_index = 1;
        push @fields, { map { $_ => $field_index++ } @$attributes };
    }

    my $self = {
        fields  => \@fields,
        classes => $classes,
        classes_by_fingerprint => {
            map { join( '-', @{$_->{attributes}} ) => $_ } @$classes
        }
    };

    bless $self, $class;
    return $self;
}

sub convert_hashref_stream {
    my ( $self, $in_stream ) = @_;
    return sub {
        my $f = $in_stream->();
        return unless $f;

        my $class = $self->getClass( $f );
        return [ $class->{index}, map { $f->{$_} } @{$class->{attributes}} ];
    };
}

my %skip_field = map { $_ => 1 } qw( start end strand );
sub getClass {
    my ( $self, $feature ) = @_;

    my @attrs = keys %$feature;
    my $attr_fingerprint = join '-', @attrs;

    return $self->{classes_by_fingerprint}{$attr_fingerprint} ||= do {
        my @attributes = ( 'start', 'end', 'strand', ( grep !$skip_field{$_}, @attrs ) );
        my $i = 0;
        my $class = {
            attributes => \@attributes,
            attr_idx => { map { $_ => ++$i } @attributes },
            # assumes that if a field is an array for one feature, it will be for all of them
            isArrayAttr => { map { $_ => 1 } grep ref($feature->{$_}) eq 'ARRAY', @attrs }
        };
        push @{ $self->{fields} }, $class->{attr_idx};
        push @{ $self->{classes} }, $class;
        $class->{index} = $#{ $self->{classes} };
        return $class;
    };
}


sub get {
    my ($self, $obj, $attr) = @_;
    my $fields = $self->{'fields'}->[$obj->[0]];
    if (defined($fields) && defined($fields->{$attr})) {
        return $obj->[$fields->{$attr}];
    } else {
        my $cls = $self->{'classes'}->[$obj->[0]];
        return unless defined($cls);
        my $adhocIndex = $#{$cls->{'attributes'}} + 2;
        if (($adhocIndex > $#{$obj})
            or (not defined($obj->[$adhocIndex]->{$attr})) ) {
            if (defined($cls->{'proto'})
                and (defined($cls->{'proto'}->{$attr})) ) {
                return $cls->{'proto'}->{$attr};
            }
            return undef;
        }
        return $obj->[$adhocIndex]->{$attr};
    }
}

sub fastGet {
    # this method can be used if the attribute is guaranteed to be in
    # the attributes array for the object's class
    my ($self, $obj, $attr) = @_;
    return $obj->[$self->{'fields'}->[$obj->[0]]->{$attr}];
}

sub set {
    my ($self, $obj, $attr, $val) = @_;
    my $fields = $self->{'fields'}->[$obj->[0]];
    if (defined($fields) && defined($fields->{$attr})) {
        $obj->[$fields->{$attr}] = $val;
    } else {
        my $cls = $self->{'classes'}->[$obj->[0]];
        return unless defined($cls);
        my $adhocIndex = $#{$cls->{'attributes'}} + 2;
        if ($adhocIndex > $#{$obj}) {
            $obj->[$adhocIndex] = {}
        }
        $obj->[$adhocIndex]->{$attr} = $val;
    }
}

sub fastSet {
    # this method can be used if the attribute is guaranteed to be in
    # the attributes array for the object's class
    my ($self, $obj, $attr, $val) = @_;
    $obj->[$self->{'fields'}->[$obj->[0]]->{$attr}] = $val;
}

sub makeSetter {
    my ($self, $attr) = @_;
    return sub {
        my ($obj, $val) = @_;
        $self->set($obj, $attr, $val);
    };
}

sub makeGetter {
    my ($self, $attr) = @_;
    return sub {
        my ($obj) = @_;
        return $self->get($obj, $attr);
    };
}

sub attrIndices {
    my ($self, $attr) = @_;
    return [ map { $_->{$attr} } @{$self->{'fields'}} ];
}
sub makeFastSetter {
    # this method can be used if the attribute is guaranteed to be in
    # the attributes array for the object's class
    my ($self, $attr) = @_;
    my $indices = $self->attrIndices($attr);
    return sub {
        my ($obj, $val) = @_;
        if (defined($indices->[$obj->[0]])) {
            $obj->[$indices->[$obj->[0]]] = $val;
        } else {
            # report error?
        }
    };
}
sub makeFastGetter {
    # this method can be used if the attribute is guaranteed to be in
    # the attributes array for the object's class
    my ($self, $attr) = (@_);
    my $indices = $self->attrIndices($attr);
    croak "no attribute '$attr' found in representation" unless grep defined, @$indices;
    return sub {
        my ($obj) = @_;
        if ( defined $obj && defined $obj->[0] && defined $indices->[ $obj->[0] ] ) {
            return $obj->[$indices->[$obj->[0]]];
        } else {
            # report error?
            return undef;
        }
    };
}

1;
