#!/usr/bin/perl -s
use strict;
use warnings;
use Carp qw( carp );
use List::MoreUtils qw( uniq );
use Path::Class qw( file );
use Filesys::Notify::Simple;

our $VERSION = "0.01";

our( $makeprg, $beforemake, $aftermake );
my @files = @ARGV;

$makeprg = "make"
    unless defined $makeprg;

if ( $makeprg eq "make" ) {
    carp "Ignore specified ", scalar( @files ), " files, write to Makefile instead."
        if @files;

    watch_and_run( );
}
elsif ( $makeprg ne "make" && @files ) {
    use_temporary_makefile( @files );
}
else {
    die usage( );
}

exit;

sub usage {
    <<USAGE;
usage: $0 [-makeprg=<programname> <files ...>]
USAGE
}

sub trigger {
    my $program = shift;

    system( $program ) == 0
        or warn "Could not run $program.[$!]";
}

sub use_temporary_makefile {
    my @files   = @_;
    my $watcher = Filesys::Notify::Simple->new( \@files );
    my $run_sub = sub {
        trigger( $beforemake )
            if defined $beforemake;

        foreach my $event ( @_ ) {
            system( $makeprg, $event->{path} ) == 0
                or warn "Could not run $makeprg with $event->{path}.[$!]";
        }

        trigger( $aftermake )
            if defined $aftermake;
    };

    while ( 1 ) {
        $watcher->wait( $run_sub );
    }
}

sub get_files_from_makefile {
    my $file    = file( "Makefile" );
    my @targets = map { m{\A (\w+) [:][ ] }msx ? $1 : ( ) }
                  $file->slurp( chomp => 1 );
    my @files   = grep { my $file = $_; ! grep { $_ eq $file } @targets }
                  uniq
                  map { split m{\s+}, $_ }
                  map { m{\A \w+ [:][ ] (.*) }msx ? $1 : ( ) }
                  $file->slurp( chomp => 1 );
    unshift @files, $file;

    return \@files;
}

sub watch_and_run {
    my $watcher = Filesys::Notify::Simple->new( get_files_from_makefile( ) );
    my $run_sub = sub {
        my @events = @_;

        trigger( $beforemake )
            if defined $beforemake;

        system( $makeprg ) == 0
            or warn "Making failed.[$!]";

        trigger( $aftermake )
            if defined $aftermake;

        if ( grep { $_->{path} =~ m{ Makefile \z}msx } @events ) {
            $watcher = Filesys::Notify::Simple->new( get_files_from_makefile( ) );
        }
    };

    while ( 1 ) {
        $watcher->wait( $run_sub );
    }
}


__END__

=head1 NAME

watch_runner - runs make command when file is changed

=head1 SYNOPSIS

  watch_runner [-makeprg=<programname> <files ...>]

  watch_runner: will run 'make' on change
  watch_runner -makeprg=perl -beforemake=clear -aftermake='echo ... at $(date +%H:%M:%S)' sam.pl: run 'perl sam.pl' on sam.pl's change

=head1 DESCRIPTION

If some files are changed, then this will run a command.

This detects a change by Filesys::Notify::Simple.

=head1 OPTION

=over

=item -makeprg=<programname>

=item -beforemake=<programname>

=item -aftermake=<programname>

=item file

=back

=head1 AUTHOR

kuniyoshi E<lt>kuniyoshi@cpan.orgE<gt>

=head1 SEE ALSO

=over

=item Filesys::Notify::Simple

=back

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


