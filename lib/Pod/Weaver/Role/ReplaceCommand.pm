package Pod::Weaver::Role::ReplaceCommand;

use 5.010001;
use Moose::Role;

use Encode qw(decode encode);
#use Pod::Elemental;
use Pod::Elemental::Element::Nested;

# AUTHORITY
# DATE
# DIST
# VERSION

sub replace_command {
    my ($self, $document, $command_name, $command_content, $text, $opts) = @_;

    $opts //= {};
    $opts->{ignore} //= 0;

    # convert characters to bytes, which is expected by read_string()
    $text = encode('UTF-8', $text, Encode::FB_CROAK);

    my $text_elem = Pod::Elemental->read_string($text);

    # dump document
    #use DD; dd $document->children;
    #say $document->as_debug_string;
    say $document->as_pod_string;

    # find the wanted region below root
    my $child_elem;
    my $g_elem_pos;
    my $prev_command_elem;
    {
        my $i = -1;
        for my $child (@{ $document->children }) {
            $i++;
            next unless $elem->can('command');
            $self->log_debug(["Found command element %s", $elem->command]);
            if ($elem->command eq $command_name) {
                if ($elem->as_pod_string =~ $command_content) {
                    $command_elem_pos = $i;
                    $command_elem = $elem;
                    last;
                } else {
                    $self->log_debug(["Skipped, content %s not the wanted command content %s", $elem->as_pod_string, $command_content]);
                }
            } else {
                $self->log_debug(["Skipped, command %s not the wanted command %s", $elem->command, $command_name]);
                $prev_command_elem = $elem;
            }
        }
    }
    if (!$command_elem) {
        if ($opts->{ignore}) {
            $self->log_debug(["Can't find POD command '$command_name', ignoring"]);
            return;
        } else {
            die "Can't find POD command '$command_name' to replace in POD document";
        }
    }

    if ($prev_command_elem) {
        push @{ $prev_command_elem->children }, @{ $text_elem->children };
        splice @{ $document->children }, $command_elem_pos, 1;
    } else {
        splice @{ $document->children }, $command_elem_pos, 1, @{ $text_elem->children };
    }

    return 1;
}

no Moose::Role;
1;
# ABSTRACT: Replace a POD command with a text

=head1 SYNOPSIS

Sample document:

 =head1 SYNOPSIS

 =head9 usage

 =head1 DESCRIPTION

 blah...

Sample code:

 my $usage_text = <<EOT;
 Usage: B<prog> [options]

 _;

 $self->replace_command($document, 'head1', qr/usage/, $usage_text);


=head1 DESCRIPTION


=head1 METHODS

=head2 replace_command

Usage:

 $obj->replace_command($document, $command_name, $text [, \%opts]) => bool

Replace POD5 command (a C<=command_name ...> section) in document C<$document>
named C<$command_name> and replace it with string C<$text>.

Options:

=over

=item * ignore

Bool. Default false. If set to true, then if POD5 command is not found, will not
die with error but do nothing.

=back
