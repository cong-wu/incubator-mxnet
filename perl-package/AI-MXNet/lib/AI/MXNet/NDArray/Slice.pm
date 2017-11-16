package AI::MXNet::NDArray::Slice;
use strict;
use warnings;
use Mouse;
use AI::MXNet::Base;
use AI::MXNet::Function::Parameters;

=head1 NAME

    AI::MXNet::NDArray::Slice - A convenience class for slicing of the AI::MXNet::NDArray objects.
=cut

has parent => (is => 'ro', isa => 'AI::MXNet::NDArray', required => 1);
has begin  => (is => 'ro', isa => 'Shape', required => 1);
has end    => (is => 'ro', isa => 'Shape', required => 1);
use overload 
    '.=' => \&set,
    '='  => sub { $_[0] },
    '""' => sub { my $self = $_[0]->sever; "$self" },
    '**' => sub { my $self = $_[0]->sever; $self ** $_[1] },
    '==' => sub { my $self = $_[0]->sever; $self == $_[1] },
    '!=' => sub { my $self = $_[0]->sever; $self != $_[1] },
    '+'  => sub { my $self = $_[0]->sever; $self +  $_[1] },
    '*'  => sub { my $self = $_[0]->sever; $self *  $_[1] },
    '-'  => sub { my $self = $_[0]->sever; $_[2] ? $_[1] - $self : $self - $_[1] },
    '/'  => sub { my $self = $_[0]->sever; $_[2] ? $_[1] / $self : $self / $_[1] },
    '+=' => sub { my ($self, $other) = @_; my $in = $self->sever; $self .= ($in+$_[1]) },
    '-=' => sub { my ($self, $other) = @_; my $in = $self->sever; $self .= ($in-$_[1]) },
    '*=' => sub { my ($self, $other) = @_; my $in = $self->sever; $self .= ($in*$_[1]) },
    '/=' => sub { my ($self, $other) = @_; my $in = $self->sever; $self .= ($in/$_[1]) },
    '**='=> sub { my ($self, $other) = @_; my $in = $self->sever; $self .= ($in**$_[1]) },
    '>'  => sub { my $self = $_[0]->sever; return $_[2] ? $_[1] >  $self : $self >  $_[1] },
    '>=' => sub { my $self = $_[0]->sever; return $_[2] ? $_[1] >= $self : $self >= $_[1] },
    '<'  => sub { my $self = $_[0]->sever; return $_[2] ? $_[1] <  $self : $self <  $_[1] },
    '<=' => sub { my $self = $_[0]->sever; return $_[2] ? $_[1] <= $self : $self <= $_[1] };

method set(AcceptableInput $value, $reverse=)
{
    confess("set value must be defined") unless defined $value;
    confess("${\ $self->parent } is not writable") unless $self->parent->writable;
    my $shape = [ map {
        my($begin, $end) = @$_;
        ($end-$begin);
    } zip($self->begin, $self->end) ];
    if(ref $value)
    {
        if(blessed($value) and $value->isa('AI::MXNet::NDArray'))
        {
            $value = $value->as_in_context($self->parent->context);
        }
        elsif(blessed($value) and $value->isa('AI::MXNet::NDArray::Slice'))
        {
            $value = $value->sever->as_in_context($self->parent->context);
        }
        else
        {
            $value = AI::MXNet::NDArray->array($value, ctx => $self->parent->context);
        }
        confess("value $value does not match slice dim sizes [@$shape]")
            if @{$value->shape} != @$shape;
        for(zip($shape, $value->shape)) {
                my ($dsize, $vdsize) = @$_;
                confess("Slice [@$shape]  != $value given as value")
                    if $dsize != $vdsize;
        }
        AI::MXNet::NDArray->_crop_assign(
            $self->parent,
            $value,
            { out => $self->parent, begin => $self->begin, end => $self->end }
        );
    }
    else
    {
        AI::MXNet::NDArray->_crop_assign_scalar(
            $self->parent,
            { "scalar" => $value, out => $self->parent, begin => $self->begin, end => $self->end }
        );
    }
    return $self->parent;
}

method sever()
{
    return AI::MXNet::NDArray->crop(
            $self->parent,
            { begin => $self->begin, end => $self->end }
    );
}

{
    no warnings 'misc';
    use attributes 'AI::MXNet::NDArray::Slice', \&AI::MXNet::NDArray::Slice::sever, 'lvalue';
}

sub notsupported  { confess("NDArray only support continuous slicing on axis 0"); }
sub AUTOLOAD {
    my $sub = $AI::MXNet::NDArray::Slice::AUTOLOAD;
    $sub =~ s/.*:://;
    my $self = shift;
    return $self->sever->$sub(@_);
}

1;
