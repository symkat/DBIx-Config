package DBIx::Config;
use 5.005;
use warnings;
use strict;
use base 'DBI';
use DBIx::Config::db;
use DBIx::Config::st;

our $VERSION = '0.000001'; # 0.0.1
$VERSION = eval $VERSION;

our @CONFIG_PATHS = ( './dbic', $ENV{HOME} . '/.dbic', '/etc/dbic' );

sub connect {
    my ( $class, @info ) = @_;
    
    print "Inside connect in ::root\n";

    my $config = $class->_make_config(@info);

    # Take responsibility for passing through normal-looking
    # credentials.
    $config = $class->load_credentials($config)
        unless $config->{dsn} =~ /dbi:/i;

    return $class->SUPER::connect( __PACKAGE__->_dbi_credentials($config) );
}

# Normalize arguments into a single hash.  If we get a single hashref,
# return it.
# Check if $user and $pass are hashes to support things like
# ->connect( 'CONFIG_FILE', { hostname => 'db.foo.com' } );

sub _make_config {
    my ( $class, $dsn, $user, $pass, $dbi_attr, $extra_attr ) = @_;
    return $dsn if ref $dsn eq 'HASH';


    return { 
        dsn => $dsn, 
        %{ref $user eq 'HASH' ? $user : { user => $user }},
        %{ref $pass eq 'HASH' ? $pass : { password => $pass }},
        %{$dbi_attr || {} }, 
        %{ $extra_attr || {} } 
    }; 
}

sub _dbi_credentials {
    my ( $class, $config ) = @_;

    return (
        delete $config->{dsn},
        delete $config->{user},
        delete $config->{password},
        $config,
    );
}

sub load_credentials {
    my ( $class, $connect_args ) = @_;
    require Config::Any; # Only loaded if we need to load credentials.

    # While ->connect is responsible for returning normal-looking
    # credential information, we do it here as well so that it can be
    # independently unit tested.
    return $connect_args if $connect_args->{dsn} =~ /^dbi:/i; 

    my $ConfigAny = Config::Any->load_stems( 
        { stems => $class->config_paths, use_ext => 1 } 
    );

    for my $cfile ( @$ConfigAny ) {
        for my $filename ( keys %$cfile ) {
            for my $database ( keys %{$cfile->{$filename}} ) {
                if ( $database eq $connect_args->{dsn} ) {
                    my $loaded_credentials = $cfile->{$filename}->{$database};
                    return $class->filter_loaded_credentials(
                        $loaded_credentials,$connect_args
                    );
                }
            }
        }
    }
}

# Intended to be sub-classed, we'll just return the
# credentials we used in the first place.
sub filter_loaded_credentials { $_[1] };

sub config_paths {
    my $class = shift;

    @CONFIG_PATHS = @{ $_[0] } if @_;
    return [ @CONFIG_PATHS ];
}
#__PACKAGE__->mk_classaccessor('config_paths'); 
#__PACKAGE__->config_paths([('./dbic', $ENV{HOME} . '/.dbic', '/etc/dbic')]);




=head1 NAME

DBIx::Config - Manage credentials for DBI

=head1 DESCRIPTION

=head1 SYNOPSIS

=head1 CONFIG FILES

=head1 OVERRIDING

=head1 AUTHOR

SymKat I<E<lt>symkat@symkat.comE<gt>>

=head1 CONTRIBUTORS

=over 4

=item * 

=back

=head1 COPYRIGHT

Copyright (c) 2012 the Daemon::Control L</AUTHOR> and 
L</CONTRIBUTORS> as listed above.

=head1 LICENSE

This library is free software and may be distributed 
under the same terms as perl itself.

=head1 AVAILABILITY

The latest version of this software is available at
L<https://github.com/symkat/DBIx-Config>

