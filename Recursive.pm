package File::Copy::Recursive;

use 5.008001;
use strict;
use warnings;

use Carp;
use File::Copy; 
use File::Spec; #not really needed because File::Copy already gets it, but for good measure :)

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(fcopy rcopy dircopy);
our $VERSION = '0.01';

our $MaxDepth = 0;
our $KeepMode = 1;

sub fcopy { copy(@_) or return;chmod scalar((stat($_[0]))[2]), $_[1] if $KeepMode; }

sub rcopy { -d $_[0] ? dircopy(@_) : fcopy(@_) }

sub dircopy {
   croak "$_[0] and $_[1] are the same" if $_[0] eq $_[1];
   croak "$_[0] is not a directory" if !-d $_[0];
   croak "$_[1] is not a directory" if -e $_[1] && !-d $_[1];
   mkdir $_[1] or return if !-d $_[1];

   my $level = 0;
   my $filen = 0;
   my $dirn = 0;

   my $recurs; #must be my()ed before sub {} since it calls itself
   $recurs =  sub {
      my ($str,$end,$buf) = @_;
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
         if(-d $org) {
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
   };

   $recurs->(@_);
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

=head2 dircopy()

This function recursively traverses the $orig directory's structure and recursively copies it to the $new directory.
$new is created if necessary.
It attempts to preserve the mode (see Preserving Mode below) and 
by default it copies all the way down into the directory, (see Managing Depth) below.
If a directory is not specified it croaks just like fcopy croaks if its not a file that is specified.

=head2 rcopy()

This function will allow you to specify a file *or* directory. It calls fcopy() if its a file and dircopy() if its a directory.

=head2 Preserving Mode

By default a quiet attempt is made to change the new file or directory to the mode of the old one.
To turn this behavior off set 
  $File::Copy::Recursive::KeepMode
to false;

=head2 Managing Depth

You can set the maximum depth a directory structure is recursed by setting:
  $File::Copy::Recursive::MaxDepth 
to a whole number greater than 0.

=head1 SEE ALSO


 L<File::Copy> L<File::Spec>

=head1 AUTHOR

Daniel Muey, L<http://drmuey.com/cpan_contact.pl>

=head1 COPYRIGHT AND LICENSE

Copyright 2004 by Daniel Muey

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
