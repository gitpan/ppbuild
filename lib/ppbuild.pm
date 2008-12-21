use strict;
use warnings;

#{{{ POD

=pod

=head1 NAME

ppbuild - Perl Project Build System

=head1 DESCRIPTION

Replacement for make on large perl projects. Similar to rake in concept, but no
need to install and learn Ruby. The goal is to have a similar sytax to make
when defining tasks (or rules in make), while bringing in the power of being
able to write your rules in perl.

Some tasks are just simpler to write as shell commands. Doing this in ppbuild is
just as easy as in make. In fact, shell tasks are easier since there is no need
to put a tab before each command. As well all the commands in the rule run in
the same shell session.

=head1 SYNOPSIS

Makefile.ppb:

    use ppbuild; #This is required.

    Describe "MyTask", "Completes the first task";
    Task "MyTask", "Dependency Task 1", "Dep Task 2", ..., sub {
        ... Perl code to Complete the task ...
    }

    Describe "MyTask2", "Completes MyTask2";
    Task "MyTask2", qw/ MyTask /, <<EOT;
        echo "Task: MyTask2"
        ... Other shell commands ...
    EOT

    Task "MyTask3", qw/ MyTask MyTask2 / , "Shell commands";

    Describe "MyFile", "Creates file 'MyFile'";
    File "MyFile, qw/ MyTask /, "touch MyFile";

    Describe "MyGroup", "Runs all the tasks";
    Group "MyGroup", qw/ MyTask MyTask2 MyTask3 MyFile /;

To use it:
    $ ppbuild MyTask

    $ ppbuild MyGroup

    $ ppbuild --file Makefile.ppb --tasks
    Tasks:
     MyTask  - Completes the first task
     MyTask2 - Completes MyTask2
     ...

    $ ppbuild MyTask2 MyFile

    $ ppbuild ..tasks to run..

=head1 HOW IT WORKS

The ppbuild script uses a .ppb file to build a project. This is similar to make
and Makefiles. .ppb files are pure perl files. To define a task use the Task,
Group, or File functions. Give a task a desription using the Describe function.

The first argument to any Task creation function is the name of the task. The
last argument is usually the code to run. All arguments in the middle should be
names of tasks that need to run first. The code argument can be a string, or a
perl sub. If the code is a sub it will be run when the task is run. If the code
is a string it will be passed to the shell using system().

The ppbuild script automatically adds ppbuild to the library search path. If you
wish to write build system specific support files you can place them in a ppbuild
directory and not need to manually call perl -I ppbuild, or add use lib 'ppbuild'
yourself in your .ppb file. As well if you will be sharing the codebase with
others, and do not want to add ppbuild as a requirement you can copy ppbuild.pm into
the ppbuild directory in the project.

=head1 FUNCTIONS

=over 4

=cut

#}}}

package ppbuild;
use vars qw($VERSION);

$VERSION = '1.02';

use Exporter 'import';
our @EXPORT = qw/ Task File Group Describe /;
our @EXPORT_OK = qw/ RunTask TaskList /;

my %tasks;
my %descriptions;

=item Describe()

Used to add or retrieve a task description.

    Describe( 'MyTask', 'Description' );
    Describe 'MyTask', "Description";
    my $description = Describe( 'MyTask' );

Exported by default.

=cut

sub Describe {
    my ( $name, $description ) = @_;
    $descriptions{ $name } = $description if $description;
    return $descriptions{ $name };
}

=item Task()

Defines a task.

    Task 'MyTask1', qw/ Dependancy /, "Shell Code";
    Task 'MyTask2', sub { ..Perl Code... };
    Task 'MyTask3', <<EOT;
    ...Lots of shell commands...
    EOT

Exported by default.

=cut

sub Task {
    my $name = shift;
    return 0 unless $name;
    my $code = pop;
    my $depends = [ @_ ];

    _addtask(
        name => $name,
        code => $code,
        depends => $depends,
    );
}

=item File()

Specifies a file to be created. Will not run if file already exists. Syntax is
identical to Task().

Exported by default.

=cut

sub File {
    my $name = shift;
    return 0 unless $name;
    my $code = pop;
    my $depends = [ @_ ];

    _addtask(
        name => $name,
        file => $name,
        code => $code,
        depends => $depends,
    );
}

=item Group()

Group together several tasks as one new task. Tasks will run in specified
order. Syntax is identical to Task() except it *DOES NOT* take code as the last
argument.

Exported by default.

=cut

sub Group {
    my $name = shift;
    return 0 unless $name;
    my $depends = [ @_ ];

    _addtask(
        name => $name,
        depends => $depends,
    );
}

=item RunTask()

Run the specified task.

First argument is the task to run.
If the Second argument is true the task will be forced to run even if it has
been run already.

Not exported by default.

=cut

sub RunTask {
    my ( $name, $again ) = @_;

    die( "No such task: $name\n" ) unless $tasks{ $name };

    # Run the Tasks this one depends on:
    RunTask( $_ ) for @{ $tasks{ $name }->{ depends }};

    my $file = $tasks{ $name }->{ file };

    # Unless we are told to run the task an additional time We want to return
    # true if the task has been run, or the file to be created is done.
    unless ( $again ) {
        return if $tasks{ $name }->{ ran };
        # This message should only be displayed if the rule was explicetly
        # stated in the command line, not if it is depended on by the called
        # Task. Thats why it is not stored anywhere.
        return "$file is up to date\n" if ( $file and -e $file );
    }

    # If the rule has no code assume it is a group, return true
    return unless my $code = $tasks{ $name }->{ code };

    my $exit;
    my $ref = ref $code;
    if ( $ref eq 'CODE' ) {
        $exit = $code->();
    }
    elsif ( $ref ) {
        die( "Unknown Task code: '$ref' for task '$name'.\n" );
    }
    else { # Not a reference, shell 'script'
        exit($? >> 8) if system( $code );
    }

    croak( "File '$file' does not exist after File Task!\n" ) if ( $file and not -e $file );

    $tasks{ $name }->{ ran }++;

    return $exit;
}

=item TaskList()

Returns a list of task names. Return is an array, not an arrayref.

    my @tasks = TaskList();
    my ( $task1, $task2 ) = TaskList();

=cut

sub TaskList {
    return keys %tasks;
}

sub _addtask {
    my %params = @_;
    my $name = $params{ name };

    croak( "Task '$name' has already been defined!\n" ) if $tasks{ $name };

    $tasks{ $name } = { %params };
}

1;

__END__

=back

=head1 AUTHOR

Chad Granum E<lt>exodist7@gmail.comE<gt>

=head1 COPYRIGHT

Copyright 2008 Chad Granum

You should have received a copy of the GNU General Public License
along with this.  If not, see <http://www.gnu.org/licenses/>.

=cut

