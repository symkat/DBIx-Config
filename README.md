# NAME

DBIx::Config - Manage credentials for DBI

# DESCRIPTION

DBIx::Config wraps around [DBI](http://search.cpan.org/perldoc?DBI) to provide a simple way of loading database 
credentials from a file.  The aim is make it simpler for operations teams to 
manage database credentials.  

# SYNOPSIS

Given a file like `/etc/dbi.yaml`, containing:

    MY_DATABASE:
        dsn:            "dbi:Pg:host=localhost;database=blog"
        user:           "TheDoctor"
        password:       "dnoPydoleM"
        TraceLevel:     1

The following code would allow you to connect the database:

    #!/usr/bin/perl
    use warnings;
    use strict;
    use DBIx::Config;

    my $dbh = DBIx::Config->connect( "MY_DATABASE" );

Of course, backwards compatibility is kept, so the following would also work:

    #!/usr/bin/perl
    use warnings;
    use strict;
    use DBIx::Config;

    my $dbh = DBIx::Config->connect(
        "dbi:Pg:host=localhost;database=blog", 
        "TheDoctor", 
        "dnoPydoleM", 
        { 
            TraceLevel => 1, 
        },
    );

For cases where you may use something like `DBIx::Connector`, a
method is provided that will simply return the connection credentials:



    !/usr/bin/perl
    use warnings;
    use strict;
    use DBIx::Connector;
    use DBIx::Config;

    my $conn = DBIx::Connector->new(DBIx::Config->connect_info("MY_DATABASE"));

# CONFIG FILES

By default the following configuration files are examined, in order listed,
for credentials.  Configuration files are loaded with [Config::Any](http://search.cpan.org/perldoc?Config::Any).  You
should append the extention that Config::Any will recognize your file in
to the list below.  For instance ./dbic will look for files such as
`./dbic.yaml`, `./dbic.conf`, etc.  For documentation on acceptable files
please see [Config::Any](http://search.cpan.org/perldoc?Config::Any).  The first file which has the given credentials 
is used.

- \`$ENV{DBIX\_CONFIG\_DIR}\` . '/dbic', 

`$ENV{DBIX_CONFIG_DIR}` can be configured at run-time, for instance:

    DBIX_CONFIG_DIR="/var/local/" ./my_program.pl

- \`$ENV{DBIX\_CONFIG\_DIR}\` . '/dbi', 

`$ENV{DBIX_CONFIG_DIR}` can be configured at run-time, for instance:

    DBIX_CONFIG_DIR="/var/local/" ./my_program.pl

- ./dbic 
- ./dbi
- $HOME/.dbic
- $HOME/.dbi 
- /etc/dbic
- /etc/dbi
- /etc/dbi

# USE SPECIFIC CONFIG FILES

If you would rather explicitly state the configuration files you
want loaded, you can use the class accessor `config_files`
instead.

    #!/usr/bin/perl
    use warnings;
    use strict;
    use DBIx::Config

    my $DBI = DBIx::Config->new( config_files => [
        '/var/www/secret/dbic.yaml',
        '/opt/database.yaml',
    ]);
    my $dbh = $DBI->connect( "MY_DATABASE" );

This will check the files, `/var/www/secret/dbic.yaml`, 
and `/opt/database.yaml` in the same way as `config_paths`, 
however it will only check the specific files, instead of checking 
for each extension that [Config::Any](http://search.cpan.org/perldoc?Config::Any) supports.  You MUST use the 
extension that corresponds to the file type you are loading.  
See [Config::Any](http://search.cpan.org/perldoc?Config::Any) for information on supported file types and 
extension mapping.

# OVERRIDING

## config\_files

The configuration files may be changed by setting an accessor:

    #!/usr/bin/perl
    use warnings;
    use strict;
    use DBIx::Config

    my $DBI = DBIx::Config->new(config_paths => ['./dbcreds', '/etc/dbcreds']);
    my $dbh = $DBI->connect( "MY_DATABASE" );

This would check, in order, `dbcreds` in the current directory, and then `/etc/dbcreds`,
checking for valid configuration file extentions appended to the given file.

## filter\_loaded\_credentials

You may want to change the credentials that have been loaded, before they are used
to connect to the DB.  A coderef is taken that will allow you to make programatic
changes to the loaded credentials, while giving you access to the origional data
structure used to connect.

    DBIx::Config->new(
        filter_loaded_credentials => sub {
            my ( $self, $loaded_credentials, $connect_args ) = @_;
            ...
            return $loaded_credentials;
        }
    )

Your coderef will take three arguments.  

- \`$self\`, the instance of DBIx::Config your code was called from. C
- \`$loaded\_credentials\`, the credentials loaded from the config file.
- \`$connect\_args\`, the normalized data structure of the inital \`connect\` call.

Your coderef should return the same structure given by `$loaded_credentials`.

As an example, the following code will use the credentials from `/etc/dbi`, but
use its a hostname defined in the code itself.

`/etc/dbi` (note `host=%s`):

    MY_DATABASE:
        dsn: "DBI:mysql:database=students;host=%s;port=3306"
        user: "WalterWhite"
        password: "relykS"

The Perl script:

    #!/usr/bin/perl
    use warnings;
    use strict;
    use DBIx::Config;

    my $dbh = DBIx::Config->new(
        # If we have %s, replace it with a hostname.
        filter_loaded_credentials => sub {
            my ( $self, $loaded_credentials, $connect_args ) = @_;

                if ( $loaded_credentials->{dsn} =~ /\%s/ ) {
                    $loaded_credentials->{dsn} = sprintf( 
                        $loaded_credentials->{dsn}, $connect_args->{hostname} 
                    );
                }
                return $loaded_credentials;
            }
        )->connect( "MY_DATABASE", { hostname => "127.0.0.1" } );

## load\_credentials

Override this function to change the way that DBIx::Config loads credentials. 
The function takes the class name, as well as a hashref.

If you take the route of having ->connect('DATABASE') used as a key for whatever 
configuration you are loading, DATABASE would be $config->{dsn}

    $obj->connect( 
        "SomeTarget", 
        "Yuri", 
        "Yawny", 
        { 
            TraceLevel => 1 
        } 
    );

Would result in the following data structure as $config in load\_credentials($self, $config):

    {
        dsn             => "SomeTarget",
        user            => "Yuri",
        password        => "Yawny",
        TraceLevel      => 1,
    }

Currently, load\_credentials will NOT be called if the first argument to ->connect() 
looks like a valid DSN. This is determined by match the DSN with /^dbi:/i.

The function should return the same structure. For instance:

    #!/usr/bin/perl
    use warnings;
    use strict;
    use DBIx::Config;
    use LWP::Simple;
    use JSON;

    my $DBI = DBIx::Config->new(
        load_credentials => sub {
            my ( $self, $config ) = @_;
            

            return decode_json( 
                get( "http://someserver.com/v1.0/database?name=" . $config->{dsn} )
            );
        } 
    )

    my $dbh = $DBI->connect( "MAGIC_DATABASE" );

# SEE ALSO

- \[DBIx::Class::Schema::Config\](http://search.cpan.org/perldoc?DBIx::Class::Schema::Config)

# AUTHOR

- Kaitlyn Parkhurst (SymKat) \_<symkat@symkat.com>\_ (\[http://symkat.com/\](http://symkat.com/))

# CONTRIBUTORS

- Matt S. Trout (mst) \_<mst@shadowcat.co.uk>\_

# COPYRIGHT

Copyright (c) 2012 the DBIx::Config ["AUTHOR"](#AUTHOR) and ["CONTRIBUTORS"](#CONTRIBUTORS) as listed 
above.

# LICENSE

This library is free software and may be distributed under the same terms as 
perl itself.

# AVAILABILITY

The latest version of this software is available at 
[https://github.com/symkat/DBIx-Config](https://github.com/symkat/DBIx-Config)