#!/usr/sbin/perl
use strict;
use warnings;

use Test::More tests => 22;
use Test::Exception;

use_ok( 'ppbuild' );
use ppbuild qw/ Describe Task File Group RunTask TaskList /;

use vars qw/ $tmp /;

is( Describe( "A", "Description A" ), "Description A", "Check setting a description function style" );
is( Describe( "A" ), "Description A", "Verify value of description" );
Describe "B", "Description B";
is( Describe( "B" ), "Description B", "Description was set using make-like syntax" );

ok( Task( 'TaskA', "echo 'TaskA'" ), "Create TaskA" );
dies_ok { Task( 'TaskA', "echo 'TaskA'" ) } "Cannot create TaskA twice.";

$tmp = "";
Task 'SetTmp', sub { $tmp = 'SetTmp' };
is( RunTask( 'SetTmp' ), 'SetTmp', "SetTmp ran" );
is( $tmp, 'SetTmp', "Task set the tmp variable." );
is_deeply( [ TaskList() ], [ sort 'TaskA', 'SetTmp' ], "Both tasks are in list." );

File 'fileA', 'echo "Not making fileA"';
dies_ok { RunTask( 'FileA' ) } "Dies when file is not created in file task";

die( "Try deleting the file: 'fileB'" ) unless
    ok( not (-e 'fileB'), "fileB does not already exist." );
$tmp = File 'fileB', 'touch fileB';
ok( RunTask( 'fileB' ) || 1, "fileB task does not die" );
ok( -e 'fileB', "fileB was created" );
ok( $tmp->{ ran }, "fileB has run." );
$tmp->{ ran } = undef;
is( RunTask( 'fileB' ) , "fileB is up to date\n", "fileB already created" );
unlink( 'fileB' );

ok( $tmp = Group( 'MyGroup', 'a', 'b' ), "Group works" );
is_deeply(
    $tmp,
    {
        depends => [ qw/ a b /],
        name => 'MyGroup'
    },
    "MyGroup is right."
);

$tmp = Task 'Hi', sub { return 'Hi' };
is( RunTask( 'Hi' ), 'Hi', "Task runs the first time." );
is( RunTask( 'Hi' ), undef, "Task does not run the second time." );
is( RunTask( 'Hi', 1 ), 'Hi', "Task forced to run again" );

dies_ok { RunTask( 'FakeTask' ) } "Cannot run non-existant task";

Task 'BadCode', [ 'a', 'b' ];
dies_ok { RunTask( 'BadCode' ) } "Cannot run an array as code.";

