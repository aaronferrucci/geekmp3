use strict;
use warnings;

# cmd line input: location of all the files
@ARGV == 1 or die "Usage: $0 <dir containing all the files>";
my $dir = $ARGV[0];

# Find all the mp3 files
print "scanning '$dir'...\n";
opendir(my $dh, $dir) or die "Can't open directory '$dir': $!";
my @mp3s = sort grep {/\S+\d{2}\.mp3/} readdir $dh;
closedir($dh);

# print "mp3s: " . "\n" . join("", map {"  $_\n"} @mp3s) . "\n";

# Find submitter names 
my @submitters = grep {/\S+01\.mp3/} @mp3s;
map {s/01\.mp3//g} @submitters;
# print "@{[0 + @submitters]} submitters:\n";
# print map {"  $_\n"} @submitters;

# extract existing tags
my $tags = {};
for my $mp3 (map {"$dir/$_"} @mp3s) {
  $tags->{$mp3} = {};
  my $rawtags = `id3v2 -l $mp3`;
  # id3v2 tags?
  my $album = "";
  if ($rawtags =~ /No ID3v2 tag/) {
    # no id3v2 tags, fall back on id3v1
    if ($rawtags =~ /Album\s*:\s*(\S.*\S)\s*Year/) {
      $album = $1;
    }
  } else {
    # prefer id3v2 tags
    if ($rawtags =~ /TALB.*:\s*(.*)$/) {
      $album = $1;
    }
  }
  $tags->{$mp3}->{album} = $album;

} 


for my $mp3 (sort keys %$tags) {
  print "$mp3\n";
  print map {"  $_: $tags->{$mp3}->{$_}\n"} sort keys %{$tags->{$mp3}};
}


