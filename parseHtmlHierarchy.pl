#!/usr/bin/perl

use strict;
# use warnings;
use Getopt::Std;
use Data::Dumper;

my $dumpedFile = shift;

my %opts;
getopts('cdip', \%opts);

open(HTML, $dumpedFile);

my %htmlTree;
my $temp;

#$htmlTree{""} = {
#	'path' => ""
#};

while(my $line = <HTML>) {
	chomp($line);

	# Reset for new html page.
	if ($line =~ /html xlmns/) {
		undef %htmlTree;
		$htmlTree{""} = {
			'path' => ""
		};
	}

	if ($temp !~ /^$/) {
		$line = $temp . $line;
		$temp = "";
	}
	
	# Extract node and hierarchy info.	
	if ($line =~ /^\s*\<(script|link|meta)/){
		next;
	}
	
	# Open bracket case. Concatenate till brackets are closed.
	if ($line =~ /^\s*\<[^>]+$/) {
		$temp = $line;
		next;
	}
	
	if ($line !~ /^\s*\<([^\>\s]+)(.*)\@((\d+\.*)+)$/) {
		next;
	}
	my $tag = $1;
	my $info = $2;
	my $hierarchy = $3;
	# Parse class and id info.
	my $id;
	my $class;
	if ($info =~ /(id=\".*?\")|(class=\".*?\")/) {
		$id = $1;
		$class =$2;
		$id =~ s/id=\"(.*?)\"/$1/;
		$class =~ s/class=\"(.*?)\"/$1/;
	}
	# Create detail string.
	my $detail = $tag;
	if ($id !~ /^$/) {
		$detail .= "#$id";
	}
	if ($class !~ /^$/) {
		my $temp = $class;
		$temp =~ s/(\s+)/ /g;
		$temp =~ s/ /\./g;
		$detail .= ".$temp";
	}
	# print "Tag:$tag\tId:$id\tClass:$class\n";
	# print $detail, "\n";
	
	my @level = split('\.', $hierarchy);
	
	# Find parent hierarchy tags
	my $parent = $hierarchy;
	$parent =~ s/\.*\d+$//;
	
	# Create node object.
	$htmlTree{$hierarchy} = {
		'tag' => $tag,
		'id' => $id,
		'class' => $class,
		'parent' => $parent,
		'path' => $htmlTree{$parent}{'path'} . "/" . $tag,
		'detail' => ($htmlTree{$parent}{'detail'} =~ /^$/) ? $detail : $htmlTree{$parent}{'detail'} . " " . $detail
	};
	
	print "\t" x (scalar @level - 1), $htmlTree{$hierarchy}{'detail'}, "\n";
}
close(HTML);

exit;