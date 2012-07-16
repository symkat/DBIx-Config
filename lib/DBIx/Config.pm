package DBIx::Config;
use 5.005;
use warnings;
use strict;
use DBI;

our $VERSION = '0.000001'; # 0.0.1
$VERSION = eval $VERSION;

sub new {
    my ( $class, $args ) = @_;
    
    my $self = bless {
        config_paths => [ 
            './dbic', './dbi',  
            $ENV{HOME} . '/.dbic',  $ENV{HOME} . '/.dbi',
            '/etc/dbic', '/etc/dbi',
        ],
    }, $class;

    for my $arg ( keys %{$args} ) {
        $self->$arg( delete $args->{$arg} ) if $self->can( $arg );
    }

   die "Unknown arguments to the constructor: " . join( " ", keys %$args )
       if keys( %$args );

    return $self;
}

sub connect {
    my ( $self, @info ) = @_;

    if ( ! ref $self eq __PACKAGE__ ) {
        return $self->new->connect(@info);
    }

    my $config = $self->_make_config(@info);

    # Take responsibility for passing through normal-looking
    # credentials.
    $config = $self->default_load_credentials($config)
        unless $config->{dsn} =~ /dbi:/i;

    return DBI->connect( $self->_dbi_credentials($config) );
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

sub default_load_credentials {
    my ( $self, $connect_args ) = @_;

    if ( $self->load_credentials ) {
        return $self->load_credentials->( $self, $connect_args );
    }

    require Config::Any; # Only loaded if we need to load credentials.

    # While ->connect is responsible for returning normal-looking
    # credential information, we do it here as well so that it can be
    # independently unit tested.
    return $connect_args if $connect_args->{dsn} =~ /^dbi:/i; 

    my $ConfigAny = Config::Any->load_stems( 
        { stems => $self->config_paths, use_ext => 1 } 
    );

    for my $cfile ( @$ConfigAny ) {
        for my $filename ( keys %$cfile ) {
            for my $database ( keys %{$cfile->{$filename}} ) {
                if ( $database eq $connect_args->{dsn} ) {
                    my $loaded_credentials = $cfile->{$filename}->{$database};
                    return $self->default_filter_loaded_credentials(
                        $loaded_credentials,$connect_args
                    );
                }
            }
        }
    }
}

sub default_filter_loaded_credentials {
    my ( $self, $loaded_credentials,$connect_args ) = @_;
    if ( $self->filter_loaded_credentials ) {
        return $self->filter_loaded_credentials->( 
            $self, $loaded_credentials,$connect_args 
        );
    }
    return $loaded_credentials;
}

sub config_paths {
    my $self = shift;
    $self->{config_paths} = shift if @_;
    return $self->{config_paths};
}

sub filter_loaded_credentials {
    my $self = shift;
    $self->{filter_loaded_credentials} = shift if @_;
    return $self->{filter_loaded_credentials};
}

sub load_credentials {
    my $self = shift;
    $self->{load_credentials} = shift if @_;
    return $self->{load_credentials};
}

1;

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

