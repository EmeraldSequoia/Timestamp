#!/usr/bin/perl -w

use strict;

my $firstVersionRun = shift;
my $latestVersionMsgGiven = shift;
defined $latestVersionMsgGiven
  or die "Usage:  $0  <first-version-run>  <latest-version-message-given>\n";

system("resetSimulatorLastVersionRun.pl $firstVersionRun $latestVersionMsgGiven Timestamp");

