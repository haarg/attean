use Test::Modern;
use Test::Exception;

use v5.14;
use warnings;
no warnings 'redefine';

use Attean;
use Attean::RDF;
use Type::Tiny::Role;

{
	my $store	= Attean->get_store('SimpleTripleStore')->new();
	isa_ok($store, 'AtteanX::Store::SimpleTripleStore');
	my $model	= Attean::MutableTripleModel->new( stores => { 'http://example.org/graph' => $store } );
	isa_ok($model, 'Attean::MutableTripleModel');
	
	my $s	= Attean::Blank->new('x');
	my $p	= Attean::IRI->new('http://example.org/p1');
	my $o	= Attean::Literal->new(value => 'foo', language => 'en-US');
	my $g	= Attean::IRI->new('http://example.org/graph');
	my $q	= Attean::Quad->new($s, $p, $o, $g);
	does_ok($q, 'Attean::API::Quad');
	isa_ok($q, 'Attean::Quad');
	
	$model->add_quad($q);
	is($model->size, 1);
	
	{
		my $iter	= $model->get_quads($s, undef, undef, $g);
		does_ok($iter, 'Attean::API::Iterator');
		my $q	= $iter->next;
		does_ok($q, 'Attean::API::Quad');
		my ($s, $p, $o, $g)	= $q->values;
		is($s->value, 'x');
		is($o->value, 'foo');
	}
	
	my $s2	= Attean::IRI->new('http://example.org/values');
	foreach my $value (1 .. 3) {
		my $o	= Attean::Literal->new(value => $value, datatype => 'http://www.w3.org/2001/XMLSchema#integer');
		my $p	= Attean::IRI->new("http://example.org/p$value");
		my $q	= Attean::Quad->new($s2, $p, $o, $g);
		$model->add_quad($q);
	}
	is($model->size, 4);
	is($model->count_quads($s), 1);
	is($model->count_quads($s2), 3);
	is($model->count_quads(), 4);
	is($model->count_quads_estimate($s2), 3);
	is($model->count_quads(undef, $p), 2);
	ok($model->holds($s2));
	ok(!$model->holds($s2, $g));

	{
		note('get_quads single-term matching with undef placeholders');
		my $iter	= $model->get_quads($s2);
		while (my $q = $iter->next()) {
			my $o	= $q->object->value;
			like($o, qr/^[123]$/, "Literal value: $o");
		}
	}
	
	{
		note('get_quads single-term matching with variable object placeholders');
		my @vars	= map { Attean::Variable->new($_) } qw(p o g);
		my $iter	= $model->get_quads($s2, @vars);
		does_ok($iter, 'Attean::API::Iterator');
		while (my $q = $iter->next()) {
			my $o	= $q->object->value;
			like($o, qr/^[123]$/, "Literal value: $o");
		}
	}
	
	{
		note('get_bindings single-term matching');
		my $v		= Attean::Variable->new('pred');
		my $iter	= $model->get_bindings($s2, $v);
		does_ok($iter, 'Attean::API::Iterator');
		my $count	= 0;
		while (my $b = $iter->next()) {
			$count++;
			does_ok($b, 'Attean::API::Result');
			is_deeply([$b->variables], [qw(pred)], 'expected binding variables');
			my $p	= $b->value('pred');
			my $v	= $p->value;
			does_ok($p, 'Attean::API::Term');
			like($v, qr<^http://example.org/p[123]$>, "Predicate value: $v");
		}
		is($count, 3, 'expected binding count');
	}
	
	{
		note('get_quads union-term matching');
		my $p2		= Attean::IRI->new("http://example.org/p2");
		my $p3		= Attean::IRI->new("http://example.org/p3");
		my $iter	= $model->get_quads(undef, [$p2, $p3]);
		my $count	= 0;
		while (my $q = $iter->next()) {
			$count++;
			my $o	= $q->object->value;
			like($o, qr/^[23]$/, "Literal value: $o");
		}
		is($count, 2);
	}
	
	note('removing data...');
	$model->remove_quad($q);
	is($model->size, 3);
	is($model->count_quads(undef, $p), 1);
	
	{
		note('objects() matching');
		my $objects	= $model->objects();
		does_ok($objects, 'Attean::API::Iterator');
		is($objects->item_type, 'Attean::API::Term', 'expected item_type');
		my $count	= 0;
		while (my $obj = $objects->next) {
			$count++;
			does_ok($obj, 'Attean::API::Literal');
			like($obj->value, qr/^[123]$/, "Literal value: $o");
		}
		is($count, 3);
	}
}

{
	my $store1	= Attean->get_store('SimpleTripleStore')->new();
	isa_ok($store1, 'AtteanX::Store::SimpleTripleStore');

	my $o	= Attean::Literal->new(value => 'foo', language => 'en-US');
	$store1->add_triple(triple(blank('x'), iri('http://example.org/p1'), $o));

	my $model	= Attean::AddativeMutableTripleModel->new( stores => { 'http://example.org/graph' => $store1 }, store_constructor => sub { return Attean->get_store('SimpleTripleStore')->new() } );
	isa_ok($model, 'Attean::AddativeMutableTripleModel');
	my @graphs1	= $model->get_graphs->elements;
	is(scalar(@graphs1), 1);
	is($graphs1[0]->value, 'http://example.org/graph');
	
	my $store2	= Attean->get_store('SimpleTripleStore')->new();
	$store2->add_triple(triple(blank('x'), iri('http://example.org/p1'), Attean::Literal->integer(3)));
	$model->add_store('http://example.org/graph2' => $store2);
	my @graphs2	= sort map { $_->value } $model->get_graphs->elements;
	is(scalar(@graphs2), 2);
	is_deeply(\@graphs2, ['http://example.org/graph', 'http://example.org/graph2']);
	
	$model->create_graph(iri('http://example.org/graph3'));
	my @graphs3	= sort map { $_->value } $model->get_graphs->elements;
	is(scalar(@graphs3), 3);
	is_deeply(\@graphs3, ['http://example.org/graph', 'http://example.org/graph2', 'http://example.org/graph3']);
	
	$model->drop_graph(iri('http://example.org/graph'));
	my @graphs4	= sort map { $_->value } $model->get_graphs->elements;
	is(scalar(@graphs4), 2);
	is_deeply(\@graphs4, ['http://example.org/graph2', 'http://example.org/graph3']);
}

{
	my $store	= Attean->get_store('SimpleTripleStore')->new();
	my $model	= Attean::MutableTripleModel->new( stores => { 'http://example.org/graph' => $store } );
	my $g		= Attean::IRI->new('http://example.org/graph');
	my $a		= Attean->get_parser('SPARQL')->parse('SELECT * WHERE { ?s ?p ?o }');
	my @p		= $model->plans_for_algebra($a, undef, [$g], [$g]);
	is(scalar(@p), 0);
}

{
	my $store	= Attean->get_store('SimpleTripleStore')->new();
	my $model	= Attean::MutableTripleModel->new( stores => { 'http://example.org/graph' => $store } );
	my $g		= Attean::IRI->new('http://example.org/graph');
	dies_ok { $model->create_graph($g) } 'create_graph dies on Attean::MutableTripleModel';
}

{
	my $store	= Attean->get_store('SimpleTripleStore')->new();
	my $model	= Attean::MutableTripleModel->new( stores => { 'http://example.org/graph' => $store } );
	my $g		= Attean::IRI->new('http://example.org/graph');
	my @pre_graphs	= $model->get_graphs->elements;
	is(scalar(@pre_graphs), 1);

	$model->drop_graph($g);

	my @post_graphs	= $model->get_graphs->elements;
	is(scalar(@post_graphs), 0);
}

{
	my $store	= Attean->get_store('SimpleTripleStore')->new();
	my $model	= Attean::MutableTripleModel->new( stores => { 'http://example.org/graph' => $store } );
	my $g		= Attean::IRI->new('http://example.org/graph');
	dies_ok { $model->clear_graph($g) } 'clear_graph dies on Attean::MutableTripleModel';
}

subtest 'Model add_iter' => sub {
	my $store	= Attean->get_store('SimpleTripleStore')->new();
	my $model	= Attean::MutableTripleModel->new( stores => { 'http://example.org/graph' => $store } );
	
	my $s	= Attean::Blank->new('x');
	my $p	= Attean::IRI->new('http://example.org/p1');
	my $o1	= Attean::Literal->new(value => 'foo', language => 'en-US');
	my $o2	= Attean::Literal->new(value => 'bar', language => 'en-GB');
	my $g	= Attean::IRI->new('http://example.org/graph');
	my $q1	= Attean::Quad->new($s, $p, $o1, $g);
	my $q2	= Attean::Quad->new($s, $p, $o2, $g);
	my $i	= Attean::ListIterator->new(values => [$q1, $q2], item_type => 'Attean::API::Quad');
	is($model->size, 0, 'size before add_iter');
	$model->add_iter($i);
	is($model->size, 2, 'size after add_iter');
};

done_testing();
