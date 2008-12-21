use inc::Module::Install;

name           'ppbuild';
all_from       'lib/ppbuild.pm';
install_script 'bin/ppbuild';

WriteAll;
