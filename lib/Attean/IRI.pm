use v5.14;
use warnings;

=head1 NAME

Attean::IRI - RDF Internationalized Resource Identifiers (IRIs)

=head1 VERSION

This document describes Attean::IRI version 0.024

=head1 SYNOPSIS

  use v5.14;
  use Attean;
  my $term = Attean::IRI->new('http://example.org/');
  $term->ntriples_string; # <http://example.org/>

=head1 DESCRIPTION

The Attean::IRI class represents RDF IRIs.
It conforms to the L<Attean::API::IRI|Attean::API::Term> role
and extends the L<IRI> class.

=head1 METHODS

=over 4

=cut

package Attean::IRI 0.024 {
	use Moo;
	use Types::Standard qw(Str);
	use IRI 0.005;
	use namespace::clean;

	extends 'IRI';
	
	has 'ntriples_string'	=> (is => 'ro', isa => Str, lazy => 1, builder => '_ntriples_string');

=item C<< equals ( $iri ) >>

Returns true if C<< $iri >> is equal to the invocant, false otherwise.

=cut

	sub equals {
		# This overrides the Attean::API::TermOrVariable::equals implementation
		# to allow lazy IRIs to remain unparsed for the case where neither has
		# a base IRI.
		my ($a, $b)	= @_;
		if ($b->isa('Attean::IRI')) {
			unless ($a->has_base or $b->has_base) {
				return ($a->value eq $b->value);
			}
		}
		return ($a->as_string eq $b->as_string);
	}
	
	with 'Attean::API::IRI';
	with 'Attean::API::BlankOrIRI';

	around BUILDARGS => sub {
		my $orig 	= shift;
		my $class	= shift;
		my $args;
		if (scalar(@_) == 1) {
			$args	= $class->$orig(value => shift);
		} else {
			$args	= $class->$orig(@_);
		}
		
		if (exists $args->{base}) {
			# fully qualify IRIs
			my $iri	= IRI->new( %$args );
			$args	= { value => $iri->as_string };
		}
		return $args;
	};

=item C<< as_string >>

Returns the IRI value.

=cut

	sub as_string {
		my $self	= shift;
		return $self->abs;
	}
}

1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/attean/issues>.

=head1 SEE ALSO

L<IRI>

L<http://www.ietf.org/rfc/rfc3987.txt>



=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2014--2019 Gregory Todd Williams.
This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
