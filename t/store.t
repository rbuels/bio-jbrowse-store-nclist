use strict;
use warnings;


use File::Next;
use File::Temp 'tempdir';
use Test::More;

use JSON 2;

use Bio::JBrowse::Store::NCList;

my $dir = tempdir( CLEANUP => 1 );
my $store = Bio::JBrowse::Store::NCList->new({ path => $dir });
my @test_features = (
    { seq_id => 'ctgB', start => 20, end => 20 },
    { seq_id => 'ctgA', start => 43, end => 70 },
    { seq_id => 'ctgA', start => 4102, end => 4800, biggie => 'smalls' },
    { seq_id => 'ctgA', start => 42, end => 64, noggin => 'fogbat',
      subfeatures => [
          { start => 44,
            end => 44
            }
          ]
      },
    );

{ # test sorting
    my @sorted_features = snarf_stream(
        $store->_sort( do {
            my @t = @test_features;
            sub { shift @t }
        })
        );
    is_deeply( \@sorted_features,
               [
                   {
                       'end' => 64,
                       'noggin' => 'fogbat',
                       'seq_id' => 'ctgA',
                       'start' => '42',
                       subfeatures => [
                           { start => 44,
                             end => 44
                             }
                           ]
                       },
                   {
                       'end' => 70,
                       'seq_id' => 'ctgA',
                       'start' => '43'
                       },
                   {
                       'end' => 4800,
                       'seq_id' => 'ctgA',
                       'start' => '4102',
                       biggie => 'smalls',
                       },
                   {
                       'end' => 20,
                       'seq_id' => 'ctgB',
                       'start' => '20'
                       }
                   ],
               'sort works') or diag explain \@sorted_features;
}

$store->insert( do {
    my @t = @test_features;
    sub { shift @t }
});

my $content = slurp_tree( $dir );
is( $content->{'ctgA/trackData.json'}{featureCount}, 3 );
is( $content->{'ctgB/trackData.json'}{featureCount}, 1 );
# diag explain $content;

done_testing;


sub snarf_stream {
    my ( $stream ) = @_;
    my @results;
    while( my $f = $stream->() ) {
        push @results, $f;
    }
    return @results;
}

sub slurp {
    my ( $file, $gzip ) = @_;
    no warnings 'uninitialized';
    open my $f, "<$gzip", shift or die;
    local $/;
    scalar <$f>;
}

sub slurp_tree {
    my ( $dir ) = @_;

    my %data;

    my $output_files_iter = File::Next::files( $dir );
    while( my $file = $output_files_iter->() ) {
        next if $file =~ /\.htaccess$/;
        my $rel = File::Spec->abs2rel( $file, $dir );
        $data{ $rel } = $rel =~ /\.json$/  ? JSON->new->decode( slurp( $file ) ) :
                        $rel =~ /\.jsonz$/ ? JSON->new->decode( slurp( $file, ':gzip' ) ) :
                                             slurp( $file );
    }

    return \%data;
}
