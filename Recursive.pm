package File::Copy::Recursive;

use strict;
use warnings;

use Carp;
use File::Copy; 
use File::Spec; #not really needed because File::Copy already gets it, but for good measure :)

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(fcopy rcopy dircopy);
our $VERSION = '0.10';
sub VERSION { $VERSION; }

our $MaxDepth = 0;
our $KeepMode = 1;
our $CPRFComp = 0; 
our $CopyLink = eval { symlink '',''; 1 } || 0;
our $PFSCheck = 1;

my $samecheck = sub {
   if($PFSCheck) {
      my $one = join '-', ( stat $_[0] )[0,1] || '';
      my $two = join '-', ( stat $_[1] )[0,1] || '';
      croak "$_[0] and $_[1] are identical" if $one eq $two && $one && $two;
   }
};

sub fcopy { 
   $samecheck->(@_);
   if(-l $_[0] && $CopyLink) {
      symlink readlink(shift()), shift() or return;
   } else {  
      copy(@_) or return;
      chmod scalar((stat($_[0]))[2]), $_[1] if $KeepMode;
   }
   return wantarray ? (1,0,0) : 1; # use 0's incase they do math on them and in case rcopy() is called in list context = no uninit val warnings 
}

sub rcopy { -d $_[0] ? dircopy(@_) : fcopy(@_) }

sub dircopy {
   croak "$_[0] and $_[1] are the same" if $_[0] eq $_[1]; 
   $samecheck->(@_);
   croak "$_[0] is not a directory" if !-d $_[0];
   croak "$_[1] is not a directory" if -e $_[1] && !-d $_[1];

   if(!-d $_[1]) {
      my @parts = File::Spec->splitdir($_[1]);
      my $pth = $parts[0];
      for(0..$#parts) {
         mkdir $pth or return if !-d $pth;
         $pth = File::Spec->catdir($pth, $parts[$_ + 1]) unless $_ == $#parts;
      }
   } else {
      if($CPRFComp) {
         my @parts = File::Spec->splitdir($_[0]);
         while($parts[ $#parts ] eq '') { pop @parts; }
         $_[1] = File::Spec->catdir($_[1], $parts[$#parts]);
      }
   }
   my $baseend = $_[1];
   my $level = 0;
   my $filen = 0;
   my $dirn = 0;

   my $recurs; #must be my()ed before sub {} since it calls itself
   $recurs =  sub {
      my ($str,$end,$buf) = @_;
      $filen++ if $end eq $baseend; 
      $dirn++ if $end eq $baseend;
      mkdir $end or return if !-d $end;
      chmod scalar((stat($str))[2]), $end if $KeepMode;
      if($MaxDepth && $MaxDepth =~ m/^\d+$/ && $level >= $MaxDepth) {
         return ($filen,$dirn,$level) if wantarray;
         return $filen;
      }
      $level++;

      opendir DIRH, $str or return;
      my @files = grep( $_ ne "." && $_ ne "..", readdir(DIRH));
      closedir DIRH;

      for(@files) {
         my $org = File::Spec->catfile($str,$_);
         my $new = File::Spec->catfile($end,$_);
         if(-l $org && $CopyLink) {
            symlink readlink($org), $new or return;
         } elsif(-d $org) {
            $recurs->($org,$new,$buf) if defined $buf;
            $recurs->($org,$new) if !defined $buf;
            $filen++;
            $dirn++;
         } else {
            copy($org,$new,$buf) or return if defined $buf;
            copy($org,$new) or return if !defined $buf;
            chmod scalar((stat($org))[2]), $new if $KeepMode;
            $filen++;
         }
      }
      1;
   };

   $recurs->(@_) or return;
   return ($filen,$dirn,$level) if wantarray;
   return $filen;
}

1;
__END__

=head1 NAME

File::Copy::Recursive - Perl extension for recursively copying files and directories

=head1 SYNOPSIS

  use File::Copy::Recursive qw(fcopy rcopy dircopy);

  fcopy($orig,$new[,$buf]) or die $!;
  rcopy($orig,$new[,$buf]) or die $!;
  dircopy($orig,$new[,$buf]) or die $!;

=head1 DESCRIPTION

This module copies directories recursively (or single files, well... singley) to an optional depth and attempts to preserve each file or directory's mode.

=head2 EXPORT

None by default. But you can export all the functions as in the example above.

=head2 fcopy()

This function uses File::Copy's copy() function to copy a file but not a directory.
One difference to File::Copy::copy() is that fcopy attempts to preserve the mode (see Preserving Mode below)
The optional $buf in the synopsis if the same as File::Copy::copy()'s 3rd argument
returns the same as File::Copy::copy() in scalar context and 1,0,0 in list context to accomidate rcopy()'s list context on regular files. (See below for more info)

=head2 dircopy()

This function recursively traverses the $orig directory's structure and recursively copies it to the $new directory.
$new is created if necessary (multiple non existant directories is ok (IE foo/bar/baz). The script logically and portably creates all of them if necessary).
It attempts to preserve the mode (see Preserving Mode below) and 
by default it copies all the way down into the directory, (see Managing Depth) below.
If a directory is not specified it croaks just like fcopy croaks if its not a file that is specified.

returns true or false, for true in scalar context it returns the number of files and directories copied,
In list context it returns the number of files and directories, number of directories only, depth level traversed.

  my $num_of_files_and_dirs = dircopy($orig,$new);
  my($num_of_files_and_dirs,$num_of_dirs,$depth_traversed) = dircopy($orig,$new);

=head2 rcopy()

This function will allow you to specify a file *or* directory. It calls fcopy() if its a file and dircopy() if its a directory.
If you call rcopy() (or fcopy() for that matter) on a file in list context, the values will be 1,0,0 since no directories and no depth are used. 
This is important becasue if its a directory in list context and there is only the initial directory the return value is 1,1,1.

=head2 Preserving Mode

By default a quiet attempt is made to change the new file or directory to the mode of the old one.
To turn this behavior off set 
  $File::Copy::Recursive::KeepMode
to false;

=head2 Managing Depth

You can set the maximum depth a directory structure is recursed by setting:
  $File::Copy::Recursive::MaxDepth 
to a whole number greater than 0.

=head2 SymLinks

If your system supports symlinks then symlinks will be copied as symlinks instead of as the target file.
Perl's symlink() is used instead of File::Copy's copy()
You can customize this behavior by setting $File::Copy::Recursive::CopyLink to a true or false value.
It is already set to true or false dending on your system's support of symlinks so you can check it with an if statement to see how it will behave:

    if($File::Copy::Recursive::CopyLink) {
        print "Symlinks will be preserved\n";
    } else {
        print "Symlinks will not be preserved because your system does not support it\n";
    }

=head2 Turning off stat() check

By default the files or directories are checked to see if they are the same (IE linked, or two paths (absolute/relative or different relative paths) to the same file) by comparing the file's stat() info. 
It's a very efficient check that croaks if they are and shouldn't be turned off but if you must for some weird reason just set $File::Copy::Recursive::PFSCheck to a false value. ("PFS" stands for "Physical File System")

=head2 Emulating cp -rf dir1/ dir2/

By default dircopy($dir1,$dir2) will put $dir1's contents right into $dir2 whether $dir2 exists or not.

You can make dircopy() emulate cp -rf by setting $File::Copy::Recursive::CPRFComp to true.

That means that if $dir2 exists it puts the contents into $dir2/$dir1 instead of $dir1 just like cp -rf.
If $dir2 does not exist then the contents go into $dir2 like normal (also like cp -rf)

So assuming 'foo/file':

    dircopy('foo', 'bar') or die $!;
    # if bar does not exist the result is bar/file
    # if bar does exist the result is bar/file

    $File::Copy::Recursive::CPRFComp = 1;
    dircopy('foo', 'bar') or die $!;
    # if bar does not exist the result is bar/file
    # if bar does exist the result is bar/foo/file

=head1 SEE ALSO

L<File::Copy> L<File::Spec>

=head1 AUTHOR

Daniel Muey, L<http://drmuey.com/cpan_contact.pl>

=head1 COPYRIGHT AND LICENSE

Copyright 2004 by Daniel Muey

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
