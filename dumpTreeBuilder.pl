#!/usr/bin/perl

use strict;
use warnings;
use HTML::TreeBuilder 5 -weak;

foreach my $filename (@ARGV) {
	# Create empty tree.
	my $tree = HTML::TreeBuilder->new();
	$tree->ignore_unknown(0);
	$tree->parse_file($filename);
	$tree->dump();
}

exit;