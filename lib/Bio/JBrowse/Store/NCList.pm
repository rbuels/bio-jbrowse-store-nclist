package Bio::JBrowse::Store::NCList;
use strict;
use warnings;

use Carp ();
use Scalar::Util ();

use Storable ();

use Sort::External ();

use Bio::JBrowse::Store::NCList::ArrayRepr ();
use Bio::JBrowse::Store::NCList::IntervalStore ();
use Bio::JBrowse::Store::NCList::JSONFileStorage ();

=head1 NAME

Bio::JBrowse::Store::NCList - stores feature data in an on-disk lazy
nested-containment list optimized for chunked fetching over HTTP

=head1 SYNOPSIS

  my $store = Bio::JBrowse::Store::NCList->new({
      path   => "path/to/directory"
  });

  # insert plain hashrefs of feature data into the store
  $store->insert( $stream, ... );
  $store->insert_presorted( $sorted_stream, ... );

  # retrieve feature data from the store
  my $fstream = $store->get_features({ seq_id => 'chr1', start => 60, end => 85 });
  while( my $feature = $fstream->() ) {
      # do something with the feature
  }

=head1 METHODS

=head2 new( \%args )

 Create a new store, overwriting any existing files.

=head3 Arguments

=over 4

=item path

path to the directory in which to put the formatted files

=item compress

if true, store the data files in gzipped format

=back

=cut

sub new {
    return shift->_new( { %{+shift}, write => 1 } );
}

sub open {
    return shift->_new( { %{+shift}, write => 0 } );
}

sub _new {
    my ( $class, $args ) = @_;

    my $self = bless { %$args }, $class;

    $self->{array_rep} = Bio::JBrowse::Store::NCList::ArrayRepr->new;

    if( $self->{write} ) {
        if( -e $self->{path} ) {
            File::Path::rmtree( $self->{path} );
        }
        File::Path::mkpath( $self->{path} );
        unless( -d $self->{path} ) {
            die "$! attempting to make directory '$self->{path}'\n";
        }
    }

    -e $self->{path}
        or die "Target directory $self->{path} does not exist, and cannot create.\n";
    -d $self->{path}
        or die "Target directory $self->{path} exists, but is not a directory.\n";

    return $self;
}
# || Bio::JBrowse::Store::NCList::JSONFileStorage->new( $outDir, $args->{compress}),

=head2 insert_presorted( $stream, ... )

=cut

sub insert_presorted {
    my ( $self, @streams ) = @_;

    my $arep = $self->{array_rep};
    my $stream = $self->_combine_streams( @streams );

    my $curr_refseq = 'no reference sequence yet, cousin.';
    my $interval_store;
    while( my $f = $stream->() ) {
        unless( $interval_store && $curr_refseq eq $f->{seq_id} ) {
            $interval_store->finishLoad if $interval_store;
            $interval_store = Bio::JBrowse::Store::NCList::IntervalStore->new({
                store => Bio::JBrowse::Store::NCList::JSONFileStorage->new(
                    $self->_refseq_path( $f->{seq_id} ),
                    $self->{compress}
                    ),
                arrayRepr => $arep
                });
            $interval_store->startLoad( sub { 1 }, 2_000 );
            $curr_refseq = $f->{seq_id};
        }
        delete $f->{seq_id};
        my $a = $arep->convert_hashref( $f );
        $interval_store->addSorted( $a );
    }
    $interval_store->finishLoad if $interval_store;
}

sub _refseq_path {
    my ( $self, $refseq_name ) = @_;
    return File::Spec->catdir( $self->{path}, $refseq_name );
}

=head2 insert( $stream, ... )

=cut

sub insert {
    my $self = shift;
    $self->insert_presorted( $self->_sort( @_ )  );
}

# take zero or more streams and make one stream that feeds from them
# all
sub _combine_streams {
    my ( $self, @streams ) = @_;

    return sub {} unless @streams;

    return $streams[0] if @streams == 1;

    return sub {
        return $streams[0]->() || @streams > 1 && do {
            shift @streams;
            $streams[0]->();
        };
    };
}

sub _sort {
    my ( $self, @streams ) = @_;

    # make a single stream
    my $stream = $self->_combine_streams( @streams );

    # put the stream through an external sorter, sorting by ref seq
    # and start coordinate
    my $sorter = Sort::External->new( cache_size => 1_000_000 );
    while( my $f = $stream->() ) {
        # use Data::Dump 'dump';
        # warn dump( $f );
        $sorter->feed( "$f->{seq_id}\0".pack('N',$f->{start}).pack('N',~(0+$f->{end})).Storable::freeze( $f ) );
    }
    $sorter->finish;

    # return a stream that reads from the external sorter
    return sub {
        my $s = $sorter->fetch
            or return;
        return Storable::thaw( substr( $s, 1+index( $s, "\0" )+8 ) );
    };
}

1;
