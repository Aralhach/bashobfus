#!/usr/bin/perl -w
use strict;
use warnings;
use feature ':5.10';

sub print_usage() {
	say "$0 is a bash shell script minifier/obfuscator.";
	say "It deletes full line comments, whitespaces and tabs, and obfuscates variable names.";
	say "Usage:";
	say "\t $0 -h \t This help message.";
	say "\t $0 -i <input_file> -o <output_file> [-V <new_var_string>] -C -F";
	say "\t Where:";
	say "\t\t<input_file>\tis the shell script you want to obfuscate";
	say "\t\t<output_file>\tis where you want to save the obfuscated script";
	say "\t\t<new_var_string>\tis an optional argument that defines what all variables will be changed to.";
	say "\t\t\tThe default is 'a', which means all variables will be changed to a0,a1,a2,a3,...";
	say "\t\t-C\tis an option to clean out full line comments and blank lines.";
	say "\t\t-F\tis an option to flatten out the code (remove indentations)";
	exit 0;
}

sub parse_cmd_args {
	my $input_file="";
	my $output_file="";
	my $delete_blanks="";
	my $flatten="";
	my $new_variable_prefix="a";
	for my $argnum (0 .. $#ARGV) {
		if ($ARGV[$argnum] eq "-i") {
			$input_file=$ARGV[$argnum+1];
			$argnum++;
		} elsif ($ARGV[$argnum] eq "-o") {
			$output_file=$ARGV[$argnum+1];
			$argnum++;
		} elsif ($ARGV[$argnum] eq "-h") {
			&print_usage();
		} elsif ($ARGV[$argnum] eq "-V") {
			$new_variable_prefix=$ARGV[$argnum+1];
			$argnum++;
		} elsif ($ARGV[$argnum] eq "-C") {
			$delete_blanks=1;
		} elsif ($ARGV[$argnum] eq "-F") {
			$flatten=1;
		}
	}
	if ($input_file eq "" || $output_file eq "") {
		say "Input or output file not specified!!";
		&print_usage();
	}
	return ($input_file,$output_file,$new_variable_prefix,$delete_blanks,$flatten);
}

sub parse_vars_from_file {
	my $file_name=shift;
	open(my $file_handle, "<", $file_name) || die "Couldn't open '".$file_name."' for reading because: ".$!;
	my %vars=();
	while(my $line=<$file_handle>) {
		# First pull var names from declarations
		if ($line =~ m/^[ \t]*([a-z]+[a-z0-9_]*)=/) {
			$vars{$1}=1;
		# Then, from read statements
		} elsif (($line =~ m/^[ \t]*read -s ([a-z]+[a-z0-9_]*)/) || ($line =~ m/^[ \t]*read ([a-z]+[a-z0-9_]*)/)) {
			$vars{$1}=1;
		# Then, from for loops
		} elsif ($line =~ m/^[ \t]*for ([a-z]+[a-z0-9_]*) /) {
			$vars{$1}=1;
		# Then, from array access
		} elsif ($line =~ m/^[ \t]*([a-z]+[a-z0-9_]*)\[.+\]=/) {
			$vars{$1}=1;
		}
	}
	close $file_handle;
	return keys %vars;
}

sub obfuscate {
	my $input_file=shift;
	my $output_file=shift;
	my $new_variable_prefix=shift;
	my $delete_blanks=shift;
	my $flatten=shift;
	my @sorted_vars=@_;

	open(my $ifh, "<", $input_file) || die "Couldn't open '".$input_file."' for reading because: ".$!;
	open(my $ofh, ">", $output_file) || die "Couldn't open '".$output_file."' for writing because: ".$!;
	my %var_obfus=();
	my $var_index=0;
	for my $var (@sorted_vars) {
		$var_obfus{$var}=$new_variable_prefix.$var_index;
		$var_index++;
	}
	my %vars=();
	while(my $line=<$ifh>) {
		if ($delete_blanks && (($line =~ m/^#[^!].*/) || ($line =~ m/^[ \t]*$/))) {
			next;
		}
		if ($flatten) {
			$line =~ s/^[ \t]*//;
		}
		for my $var (@sorted_vars) {
			# Substitute var names in declarations
			$line =~ s/^([ \t]*)$var=/$1$var_obfus{$var}=/;
			# Then, in read statements
			$line =~ s/^([ \t]*read .*)$var/$1$var_obfus{$var}/;
			# Then, in for loops
			$line =~ s/^([ \t]*for )$var/$1$var_obfus{$var}/;
			# Then, in array access
			$line =~ s/^([ \t]*)$var(\[.+\]=)/$1$var_obfus{$var}$2/;
			# General "$" usage while making sure we're not inside ''
			while ($line =~ m/^(([^\']*('[^']*')*[^']*)*)\$$var/) {
				$line =~ s/^(([^\']*('[^']*')*[^']*)*)\$$var/$1\$$var_obfus{$var}/;
			}
			# Only allow a $var to be replaced between '' if they're already inside ""
			while ($line =~ m/^([^']*(('[^']*')*("[^"]")*)*"[^"]*)\$$var/) {
				$line =~ s/^([^']*(('[^']*')*("[^"]")*)*"[^"]*)\$$var/$1\$$var_obfus{$var}/;
			}
			# Special case ${var} usage while making sure we're not inside ''
			while ($line =~ m/^(([^']*('[^']*')*[^']*)*)\$\{$var/) {
				$line =~ s/^(([^']*('[^']*')*[^']*)*)\$\{$var/$1\$\{$var_obfus{$var}/;
			}
			# Likewise, allow ${var} between '' only if we're already between ""
			while ($line =~ m/^([^']*(('[^']*')*("[^"]")*)*"[^"]*)\$\{$var/) {
				$line =~ s/^([^']*(('[^']*')*("[^"]")*)*"[^"]*)\$\{$var/$1\$\{$var_obfus{$var}/;
			}
		}
		# Print whatever got through the filters
		print $ofh $line
	}
	close $ifh;
	close $ofh;
}

my ($input_file,$output_file,$new_variable_prefix,$delete_blanks,$flatten)=&parse_cmd_args();
my @parsed_vars=&parse_vars_from_file($input_file);
my @sorted_vars = sort { length($b) <=> length($a) } @parsed_vars;
&obfuscate($input_file,$output_file,$new_variable_prefix,$delete_blanks,$flatten,@sorted_vars);
