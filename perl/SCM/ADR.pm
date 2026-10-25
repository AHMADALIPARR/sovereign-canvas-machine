# Copyright (C) 2026 AHMAD ALI PARR
# This file is part of the Sovereign Canvas Machine (SCM-002).
# Licensed under the GNU Affero General Public License v3.0.
# See LICENSE for details.

package SCM::ADR;
use strict;
use warnings;
use Digest::SHA qw(sha256_hex);
use File::Spec;
use Exporter 'import';
our @EXPORT_OK = qw(digest check);

sub _root_from_env {
    return $ENV{SCM_ROOT} if $ENV{SCM_ROOT};
    my $lib = $INC{'SCM/ADR.pm'} // '';
    $lib =~ s{/perl/SCM/ADR\.pm$}{};
    return $lib;
}

sub digest {
    my ($root) = @_;
    $root = _root_from_env() unless defined $root;
    my $dir = File::Spec->catdir($root, 'adr');
    opendir my $dh, $dir or die "adr dir: $!";
    my @files = sort grep { /\.md$/ && !/^\./ } readdir $dh;
    closedir $dh;
    my $data = '';
    for my $name (@files) {
        open my $fh, '<', File::Spec->catfile($dir, $name) or die $!;
        local $/;
        my $body = <$fh>;
        close $fh;
        $data .= $name . "\n" . $body . "\n";
    }
    return sha256_hex($data);
}

sub check {
    my ($root) = @_;
    $root = _root_from_env() unless defined $root;
    my $path = File::Spec->catfile($root, 'adr', 'DIGEST');
    open my $fh, '<', $path or return (0, 'missing_digest');
    my $sealed = <$fh>;
    close $fh;
    $sealed =~ s/\s+\z//;
    # Fail closed: an unreadable ADR directory must reject the proposal,
    # not crash the pipeline. digest() dies on opendir failure, so catch
    # it here and turn it into a denial.
    my $got = eval { digest($root) };
    return (0, 'adr_unreadable') if $@ || !defined $got;
    return (0, 'adr_mismatch') unless $sealed eq $got;
    return (1, $got);
}

1;
