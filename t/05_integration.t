#!/usr/bin/perl
use warnings;
use strict;
use DBIx::Config;
use Test::More;

DBIx::Config->config_paths( [ "etc/config", "t/etc/config" ] );

my $dbh = DBIx::Config->connect( "TEST" );

ok my $sth = $dbh->prepare( "CREATE TABLE hash( key string, value string )" );
   ok $sth->execute();

   ok $sth = $dbh->prepare( "INSERT INTO hash VALUES( ?, ? )" );
   ok $sth->execute( "Hello", "World" );
   
   ok $sth = $dbh->prepare( "SELECT value FROM hash WHERE key = ?" );
   ok $sth->execute( "Hello" );

   is( ($sth->fetchrow_array)[0], "World" );


# Can Manually Connect Too?
$dbh = DBIx::Config->connect( "dbi:SQLite:dbname=:memory:" );

ok $sth = $dbh->prepare( "CREATE TABLE hash( key string, value string )" );
ok $sth->execute();

ok $sth = $dbh->prepare( "INSERT INTO hash VALUES( ?, ? )" );
ok $sth->execute( "Hello", "World" );

ok $sth = $dbh->prepare( "SELECT value FROM hash WHERE key = ?" );
ok $sth->execute( "Hello" );

is( ($sth->fetchrow_array)[0], "World" );


done_testing;
