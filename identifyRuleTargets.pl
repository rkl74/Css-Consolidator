#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;

my $cssRules = shift;
my $outputfile = shift;
my $parsedHTMLHierarchy = shift;

my %selectors;
my @files;
push(@files, $cssRules);

my ($rules_ref, $mobile_rules_ref) = &extractRules(@files);
my (%rules, %mobile_rules) = (%{$rules_ref}, %{$mobile_rules_ref});

open(OUT, ">$outputfile");
foreach my $selector (sort {$a cmp $b} keys %rules) {
	foreach my $item (@{$rules{$selector}}) {
		print OUT $selector, " ", $item->{'css'}, "\n";
	}
}
close(OUT);

#Define rules to examine html page.
open(CSSRULES, $outputfile);
while (my $line = <CSSRULES>) {
	chomp($line);
	# Assume 1 css selector rule per line.
	$line =~ /^([^\{]+)\s(\{.*?\})$/;	
	my ($selector, $rules) = ($1, $2);
	$selectors{$selector}{$rules}++;
}
close(CSSRULES);

# Convert selector into appropriate regex.
my %selectorRegex;
foreach my $selector (keys %selectors) {
	$selectorRegex{$selector} = &regexify($selector);
	# print "Selector: $selector\nRegex: ", $selectorRegex{$selector}, "\n";
}

my %usedSelectors = &examineHTML($parsedHTMLHierarchy);

foreach my $file (@files) {
	&printSelectorsInOrder($file);
}

# Print out selectors being used.
#print join("\n", sort {$a cmp $b} keys %usedSelectors);

# foreach my $selector (sort {$a cmp $b} keys %used) {
	# print $selector, "\n";
	# foreach my $rule (@{$rules{$selector}}) {
		# print $selector, " ", $rule->{'css'}, "\n";
	# }
# }


####################
# SUBROUTINES
####################

# Extract rules from css file.
sub extractRules() {
	my @files = shift @_;
	my %rules;
	my %mobile_rules;

	while (my $file = shift @files) {
		# Process each file one at a time.
		open(CSS, $file) || die "$file not found!\n";
		$file =~ s/\\(.*?.css)$/$1/;
		# push (@processedFiles, $file);
		my $everything;
		while (my $line = <CSS>) {
			chomp($line);
			$everything .= $line;
		}
		close(CSS);
		
		# Remove comments.
		while ($everything =~ s/\/\*(.*?)\*\///) {
		}

		my @mediaScreenObjs;
		# Parse media screens out.
		while ($everything =~ /\@media/) {
			$everything =~ s/(\@media[^\{]+\{([^\{]*\{[^\{\}]*\}[^\{\}}]*)+\})//;
			push(@mediaScreenObjs, $1);
		}
		
		# Parse regular rules.
		my @cssObjs = split("}", $everything);

		# Identify selectors seen.
		foreach my $item (@cssObjs) {
			$item .= "}";
			$item =~ s/\s*([^\{]+)\s*(\{.*\})/$2/;
			my @selectors = split(",", $1);
			# Cleaning up white-space for consistency.
			$item =~ s/^\s*//;
			$item =~ s/\s*;\s*/;/g;
			$item =~ s/\s*\:\s*/\:/g;
			$item =~ s/\s*\{\s*/\{/;
			$item =~ s/\s*\}/\}/;
			foreach my $selector (@selectors) {
				$selector =~ s/^\s*(\S+)/$1/;
				$selector =~ s/(\S+)\s*$/$1/;
				push(@{$rules{$selector}}, {
					'file' => $file,
					'css' => $item
				});
			}
		}
		
		# Identify mobile selectors seen.
		foreach my $item (@mediaScreenObjs) {
			$item =~ /(\@media[^\{]*)\{(.*)\}/;
			my @mobileObjs = split("}", $2);
			foreach my $mobileItem (@mobileObjs) {
				$mobileItem .= "}";
				$mobileItem =~ s/\s*([^\{]+)\s*(\{.*\})/$2/;
				my @selectors = split(",", $1);
				# Cleaning up white-space for consistency.
				$mobileItem =~ s/^\s*//;
				$mobileItem =~ s/\s*;\s*/;/g;
				$mobileItem =~ s/\s*\:\s*/\:/g;
				$mobileItem =~ s/\s*\{\s*/ \{/;
				$mobileItem =~ s/\s*\}/\}/;
				foreach my $selector (@selectors) {
					$selector =~ s/^\s*(\S+)/$1/;
					$selector =~ s/(\S+)\s*$/$1/;
					push(@{$mobile_rules{$selector}}, {
						'file' => $file,
						'css' => $mobileItem
					});
					# Record seen mobile selectors
					#$seen_mobile_selectors{$selector}++;
					# Record seen mobile selectors in file;
					#$mobile_cssfile{$file}{$selector}++;
				}
			}
		}
	}
	return (\%rules, \%mobile_rules);
}

# Examine html page with defined css rules.
sub examineHTML() {
	my $parsedHTMLHierarchy = shift;
	my %used;
	open(HTML, $parsedHTMLHierarchy);
	while (my $line = <HTML>) {
		chomp($line);
		my $original = $line;
		$line =~ s/^\s+//;	
		$line = " $line ";
		my @found;
		foreach my $selector (keys %selectorRegex) {
			# Pseudo-classes are added by default.
			# Logic to include all pseudo-classes can be extensive.
			if ($selector =~ /:/) {
				$used{$selector}++;
				next;
			}
			# For exceptions that HTML::TreeBuilder doesn't pick up.
			my $hrException = &regexify("hr");
			if ($selector =~ /$hrException/) {
				$used{$selector}++;
				next;
			}
			my $regex = $selectorRegex{$selector};
			# Non-pseudo-classes
			if ($line =~ /$regex/) {
				push(@found, $selector);
				$used{$selector}++;
			}
		}
		# print $original, "\tSelectors:", join(",", @found), "\n";
	}
	close(HTML);
	return %used;
}

# Breakdown one-level selector into parts. One-level selector = div#id.classes
sub breakdownSelector() {
	my $selector = shift;
	if ($selector =~ /\*/) {
		return ("*", "*", ("*"));
	}
	my ($tag, $id, @classes);
	if ($selector =~ /^([^#\.\s]+).*$/) {
		$tag = $1;
	}
	if ($selector =~ /(#[^\.\s]+)/) {
		$id = $1;
	}
	@classes = $selector =~ m/(\.[^\.*]*)/g;
	return ($tag, $id, @classes);
}

# Convert css selector rule into regular expression.
sub regexify() {
	my $selector = shift;
	my $regex;
	my @selectors;
	# Check for direct child logic. Ex: div > p
	if ($selector =~ /\>/) {
		@selectors = split(">", $selector);
		my @levels;
		foreach my $part (@selectors) {
			$part =~ s/^\s*(.*)\s*$/$1/;
			push(@levels, &regexify($part));
		}
		for (my $i = 0; $i < scalar @levels; $i++) {
			$levels[$i] =~ s/^\\s\+(.*)\\s\+$/$1/;
		}
		$regex = join("\\s+", @levels);
		$regex = "\\s+$regex\\s+";
		return $regex;
	}
	@selectors = split(" ", $selector);
	# Possible selectors:
	# div#id.class	-> \s+div#id(\.class|\.[^\s\.]+)+s+
	# div#id		-> \s+div#id(\.class|\.[^\s\.]+)\s+
	# div.class		-> \s+div(#\w+)(\.class|\.[^\s\.]+)+s+
	# #id.class		-> \s+(div)#id(\.class|\.[^\s\.]+)+s+
	# div			-> \s+div(#id)(\.class|\.[^\s\.]+)\s+
	# #id			-> \s+(div)#id(\.class|\.[^\s\.]+)\s+
	# .class		-> \s+(div)(#id)(\.class|\.[^\s\.]+)+\s+
	# *				-> \s+(\.*)\s+
	# print "Selector: $selector\nHTML: $line\n";
	my @whole;
	foreach my $part (@selectors) {
		$part =~ s/\-/\\\-/g;
		my ($tag, $id, @classes) = &breakdownSelector($part);
		my $part_regex;
		my $class_regex;
		# If there is * selector
		if (defined($tag) && $tag =~ /\*/) {
			$part_regex = "\.*";
		}
		# No * selector
		else {
			if (!defined($tag)) {
				$tag = "([^\\.#\\s]+)*";
			}
			if (!defined($id)) {
				$id = "(#[^\\.]+)*";
			}
			$part_regex = $tag . $id;
			if (scalar @classes == 0) {
				$class_regex = "(\\.[^\\s\\.]+)*";
			}
			else {
				foreach my $e (@classes) {
					$e =~ s/\./\\\./g;
					$e = "((\\.[^\\s\\.]+)*$e(\\.[^\\s\\.]+)*)"
				}
				$class_regex = join("|", @classes);
				$class_regex = "($class_regex)+";
			}
			$part_regex .= $class_regex;
		}
		push (@whole, $part_regex);
	}
	$regex = join("(\\s+.*?\\s+|\\s+)", @whole);
	$regex = "\\s+$regex\\s+";
	return $regex;
}

sub printSelectorsInOrder() {
	my $file = shift;
	open(CSS, $file);
	my $everything;
	while (my $line = <CSS>) {
		chomp($line);
		$everything .= $line;
	}
	close(CSS);
	# Remove comments.
	while ($everything =~ s/\/\*(.*?)\*\///) {
	}

	my @mediaScreenObjs;
	# Parse media screens out.
	while ($everything =~ /\@media/) {
		$everything =~ s/(\@media[^\{]+\{([^\{]*\{[^\{\}]*\}[^\{\}}]*)+\})//;
		push(@mediaScreenObjs, $1);
	}
	
	# Parse regular rules.
	my @cssObjs = split("}", $everything);

	# Identify selectors seen.
	foreach my $item (@cssObjs) {
		$item .= "}";
		$item =~ s/\s*([^\{]+)\s*(\{.*\})/$2/;
		my @selectors = split(",", $1);
		# Cleaning up white-space for consistency.
		$item =~ s/^\s*//;
		$item =~ s/\s*;\s*/;/g;
		$item =~ s/\s*\:\s*/\:/g;
		$item =~ s/\s*\{\s*/\{/;
		$item =~ s/\s*\}/\}/;
		foreach my $selector (@selectors) {
			$selector =~ s/^\s*(\S+)/$1/;
			$selector =~ s/(\S+)\s*$/$1/;
			if (exists $usedSelectors{$selector}) {
				print "$selector $item", "\n";
			}
		}
	}
}