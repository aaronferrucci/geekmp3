use strict;
use warnings;

# I'll use id3v2 to grab existing tags from mp3 files,
# and also it's referred to in the output script. So
# if it's not available, stop now.
my $cmd = "id3v2";
`which $cmd` ne "" or die "Can't locate $cmd";

# cmd line input: location of all the files
@ARGV == 1 or die "Usage: $0 <dir containing all the files>";
my $dir = $ARGV[0];

# Find all the mp3 files
print "# scanning '$dir'...\n";
opendir(my $dh, $dir) or die "Can't open directory '$dir': $!";
my @mp3s = sort grep {/\S+\d{2}\.mp3/} readdir $dh;
closedir($dh);

# Find submitter names 
my @submitters = grep {/\S+01\.mp3/} @mp3s;
map {s/01\.mp3//g} @submitters;
my $i = 0;
# hash of submitter name to album index
my $submitter_indices = {map {$_, ++$i} @submitters};

# New album name
my $twentyfour = "Twenty-Four Hours: The Geek Music Lists, 2003";

my $tags = {};
my $max_track = {};
for my $mp3 (@mp3s) {
  $tags->{$mp3} = {};

  my $submitter = "";
  my $track = "";
  my $prefix = "";
  if ($mp3 =~ /(\S+)(\d{2})\.mp3/) {
    $prefix = "$1$2 - ";
    $submitter = $1;
    $track = 0 + $2;
    $tags->{$mp3}->{submitter} = $submitter;
    $tags->{$mp3}->{track} = $track;

    $max_track->{$submitter} = $track
      if (not exists $max_track->{$submitter}) or $track > $max_track->{$submitter};
  }
  my $filepath = "$dir/$mp3";
  my @rawtags = `id3v2 -l $filepath`;
  my $toal = "";
  my $tit2 = "";
  for my $line (@rawtags) {
    chomp $line;
    # TAL and TALB
    if ($line =~ /TALB?\s*[^:]+:\s*(.*?)\s*$/) {
      $toal = $1;
    }
    # prefer the v2 tag above.
    if ($toal eq "" and $line =~ /Album\s*:\s*(\S.*\S)\s*Year/) {
      $toal = $1;
    }
    # TT2 and TIT2
    if ($line =~ /TI?T2\s*[^:]+:\s*(.*?)\s*$/) {
      $tit2 = $1;
    }
    if ($tit2 eq "" and $line =~ /Title\s*:\s*(\S.*\S)\s*Artist/) {
      $tit2 = $1;
    }
  }

  # Be cowardly: if the album is already "Twenty-Four Hours...", then
  # probably these mp3s were already processed. To continue would mean
  # losing the original album name, so stop here.
  die "'$mp3' already has album name '$twentyfour'; these files were probably already processed." if ($toal eq $twentyfour);

  # original album
  $tags->{$mp3}->{TOAL} = $toal;
  # original filename
  $tags->{$mp3}->{TOFN} = $mp3;
  # album name
  $tags->{$mp3}->{TALB} = $twentyfour;
  # album n/m
  $tags->{$mp3}->{TPOS} = "$submitter_indices->{$submitter}/@{[scalar @submitters]}";
  # title
  if ($prefix ne "" and $tit2 ne "") {
    $tags->{$mp3}->{TIT2} = "$prefix$tit2";
  }
} 

# Set the track tag:
for my $mp3 (sort keys %$tags) {
  my $submitter = $tags->{$mp3}->{submitter};
  my $max_track = $max_track->{$submitter};
  my $track = $tags->{$mp3}->{track};
  # track x/y
  $tags->{$mp3}->{TRCK} = "$track/$max_track";
}

my @tagnames = sort qw(TIT2 TOFN TOAL TALB TPOS TRCK);
for my $mp3 (sort keys %$tags) {
  my $cmd = "id3v2 ";

  for my $tag (@tagnames) {
    if (exists $tags->{$mp3}->{$tag} and $tags->{$mp3}->{$tag} ne "") {
      $cmd .= "--$tag \"$tags->{$mp3}->{$tag}\" ";
    }
  }
  $cmd .= "$dir/$mp3";
  print "$cmd\n";
}

