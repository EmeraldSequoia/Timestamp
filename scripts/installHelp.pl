#!/usr/bin/perl -w

# Install help files into app bundle (not used in CwH)

use strict;

use File::Basename;
use File::Copy qw/cp/;
use IO::Handle;

STDOUT->autoflush(1);
STDERR->autoflush(1);

my $isDistributionBuild = ($ENV{BUILD_STYLE} =~ /distrib/i);

defined $ENV{BUILT_PRODUCTS_DIR} && defined $ENV{SRCROOT}
  or die "Must run under XCode\n";

chdir $ENV{SRCROOT}
  or die "Couldn't cd to $ENV{SRCROOT}: $!\n";

my $appFlavor = $ENV{PRODUCT_NAME};

my $appDir = "$ENV{BUILT_PRODUCTS_DIR}/$ENV{PRODUCT_NAME}.app";
my $destHelpDir = "$appDir/Help";
my $srcHelpDir = "$ENV{SRCROOT}/Help";

my $emeraldProduct = "Emerald $appFlavor";

sub copyFile {
    my $srcPath = shift;
    my $destPath = shift;
    unlink $destPath;
    if ($srcPath =~ /\.html$/i) {
	open SRC, $srcPath
	  or die "Couldn't read $srcPath: $!";
	open DEST, ">$destPath"
	  or die "Couldn't create $destPath: $!";
	while (<SRC>) {
	    s/\bEMERALD_PRODUCT\b/$emeraldProduct/g;
	    print DEST $_;
	}
	close SRC;
	close DEST;
    } else {
	cp $srcPath, $destPath
	  or die "Couldn't copy $srcPath to $destPath: $!\n";
    }
}

sub maybeCopyDir {
    my $srcPath = shift;
    my $destPath = shift;
    if (!-d $destPath) {
	mkdir $destPath, 0777
	    or die "Couldn't create directory $destPath: $!\n";
    }
    opendir DIR, $srcPath
	or die "Couldn't read directory $srcHelpDir: !$\n";
    my @files = grep !/^\./, readdir DIR;
    closedir DIR;
    foreach my $file (@files) {
	copyFile "$srcPath/$file", "$destPath/$file";
    }
}

opendir DIR, $srcHelpDir
  or die "Couldn't read directory $srcHelpDir: !$\n";
my @files = grep !/^\./, readdir DIR;
closedir DIR;

if (!-d $destHelpDir) {
    mkdir $destHelpDir, 0777
	or die "Couldn't create directory $destHelpDir: $!\n";
}

foreach my $file (@files) {
    my $path = "$srcHelpDir/$file";
    if (-d $path) {
	maybeCopyDir $path, "$destHelpDir/$file";
    } else {
	#next if $file =~ /HelpContentsTemplate|Help Contents|Complications|product\.css|roundedIcon\.png/;
	copyFile "$srcHelpDir/$file", "$destHelpDir/$file";
    }
}

print "Copied watch help files\n";
