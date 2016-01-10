unit class Math::Matrix;

has @.rows is required;
has Int $.row-count;
has Int $.column-count;

subset Pos_Int of Int where * > 0 ;

multi method new( @r ) {
    die "Expect an Array of Array" unless all @r ~~ Array;
    die "All Row must contains the same number of elements" unless @r[0] == all @r[*];
    self.bless( rows => @r , row-count => @r.elems, column-count => @r[0].elems );
}

method diagonal(Math::Matrix:U: @diag){
    die "Expect an List of Number" unless +@diag > 0 and [and] @diag >>~~>> Numeric;
    my @d;
    for ^+@diag X ^+@diag -> ($r, $c) {
        @d[$r][$c] = $r==$c ?? @diag[$r] !! 0;
    }
    self.bless( rows => @d, row-count => +@diag, column-count => +@diag );
}

method identity(Math::Matrix:U: Int $size) {
    my @identity;
    for ^$size X ^$size -> ($r, $c) {
        @identity[$r][$c] = ($r == $c ?? 1 !! 0);
    }
    self.bless( rows => @identity, row-count => $size, column-count => $size );
}

method zero(Math::Matrix:U: Int $rows, Int $cols = $rows) {
    my @zero;
    for ^$rows X ^$cols -> ($r, $c) {
        @zero[$r][$c] = 0;
    }
    self.bless( rows => @zero, row-count => $rows, column-count => $cols );
}

my class Row {
    has $.cells;

    multi method new( $c is rw ) {
        self.bless( cells => $c );
    }

    multi method elems(Row:D:) {
        $!cells.elems;
    }

    multi method AT-POS(Row:D: Int $index) {
        $!cells.elems;
        fail X::OutOfRange.new(
            :what<Column index> , :got($index), :range("0..{$!cells.elems - 1}")
        ) unless 0 <= $index < $!cells.elems;
        return-rw $!cells[$index];
    }

    multi method EXISTS-POS( Row:D: $index ) {
        return 0 <= $index < $!cells.elems;
    }
};

multi method elems(Math::Matrix:D: ) {
    @!rows.elems;
}

multi method AT-POS( Math::Matrix:D: Int $index ) {
    fail X::OutOfRange.new(
        :what<Row index> , :got($index), :range("0..{$.row-count -1 }")
    ) unless 0 <= $index < $.row-count;
    return Row.new( @!rows[$index] );
}

multi method EXISTS-POS( Math::Matrix:D: $index ) {
    return 0 <= $index < $.row-count;
}

multi method Str(Math::Matrix:D: ) {
    @.rows;
}

multi method perl(Math::Matrix:D: ) {
    self.WHAT.perl ~ ".new(" ~ @!rows.perl ~ ")";
}

multi method size(Math::Matrix:D: ){
    return $.row-count, $.column-count;
}


method equal(Math::Matrix:D: Math::Matrix $b --> Bool) {
    self.rows ~~ $b.rows;
}

method is-zero(Math::Matrix:D: --> Bool) {
    for ^$.row-count X ^$.column-count -> ($r, $c) {
        return False unless @!rows[$r][$c] == 0;
    }
    return True;
}

method is-square(Math::Matrix:D: --> Bool) {
    return $.column-count == $.row-count;
}

method is-invertible(Math::Matrix:D: --> Bool) {
    return self.is-square and self.determinant != 0;
}

method is-identity(Math::Matrix:D: --> Bool) {
    return False unless self.is-square;
    for ^$.row-count X ^$.row-count -> ($r, $c) {
        return False unless @!rows[$r][$c] == ($r == $c ?? 1 !! 0);
    }
    return True;
}

method is-diagonal(Math::Matrix:D: --> Bool) {
    return False unless self.is-square;
    for ^$.row-count X ^$.row-count -> ($r, $c) {
        return False if @!rows[$r][$c] != 0 and $r != $c;
    }
    return True;
}

method is-upper-triangular(Math::Matrix:D: --> Bool) {
    return False unless self.is-square;
    for ^$.row-count X ^$.row-count -> ($r, $c) {
        return False if @!rows[$r][$c] != 0 and $r > $c;
    }
    return True;
}

method is-lower-triangular(Math::Matrix:D: --> Bool) {
    return False unless self.is-square;
    for ^$.row-count X ^$.row-count -> ($r, $c) {
        return False if @!rows[$r][$c] != 0 and $r < $c;
    }
    return True;
}

method is-symmetric(Math::Matrix:D: --> Bool) {
    return False unless self.is-square;
    return True if $.row-count < 2;
    for ^($.row-count - 1) -> $r {
        for $r + 1 .. $.row-count - 1 -> $c {
            return False unless @!rows[$r][$c] == @!rows[$c][$r];
        }
    }
    return True;
}

method is-orthogonal(Math::Matrix:D: --> Bool) {
    return False unless self.is-square;
    return self.dotProduct( self.T ) eqv Math::Matrix.identity( $.row-count );
}

method T(Math::Matrix:D: --> Math::Matrix:D  )         { self.transposed }
method transposed(Math::Matrix:D: --> Math::Matrix:D ) {
    my @transposed;
    for ^$!row-count X ^$!column-count -> ($r, $c) { @transposed[$c][$r] = @!rows[$r][$c] }
    return Math::Matrix.new( @transposed );
}

method inverted(Math::Matrix:D: --> Math::Matrix:D) {
    fail "Number of columns has to be same as number of rows" unless self.is-square;
    fail "Matrix is not invertible, singular because defect (determinant = 0)" if self.determinant == 0;
    my @clone = @!rows.clone;
    my @inverted;
    for ^$!row-count X ^$!column-count -> ($r, $c) { @inverted[$r][$c] = ($r == $c ?? 1 !! 0) }
    for ^$!column-count -> $c {
        my $swap_row_nr = $c;       # make sure that diagonal element != 0, later == 1
        $swap_row_nr++ while @clone[$swap_row_nr][$c] == 0;
        (@clone[$c], @clone[$swap_row_nr])       = (@clone[$swap_row_nr], @clone[$c]);
        (@inverted[$c], @inverted[$swap_row_nr]) = (@inverted[$swap_row_nr], @inverted[$c]);
        @inverted[$c] =  @inverted[$c] >>/>>  @clone[$c][$c];
        @clone[$c]    =  @clone[$c]    >>/>>  @clone[$c][$c];
        for $c + 1 ..^ $!row-count -> $r {
            @inverted[$r] = @inverted[$r]  >>-<<  @clone[$r][$c] <<*<< @inverted[$c];
            @clone[$r]    = @clone[$r]  >>-<<  @clone[$r][$c] <<*<< @clone[$c];
        }
    }
    for reverse(1 ..^ $!column-count) -> $c {
        for ^$c -> $r {
            @inverted[$r] = @inverted[$r]  >>-<<  @clone[$r][$c] <<*<< @inverted[$c];
            @clone[$r]    = @clone[$r]  >>-<<  @clone[$r][$c] <<*<< @clone[$c];
        }
    }
    return Math::Matrix.new( @inverted );
}

multi method dotProduct(Math::Matrix:D: Math::Matrix $b ) {
    my @product;
    die "Number of columns of the second matrix is different from number of rows of the first operand" unless self.column-count == $b.row-count;
    for ^$.row-count X ^$b.column-count -> ($r, $c) {
        @product[$r][$c] += @!rows[$r][$_] * $b.rows[$_][$c] for ^$b.row-count;
    }
    return Math::Matrix.new( @product );;
}

multi method multiply(Math::Matrix:D: Real $r ) {
    self.apply( * * $r );
}

method apply(Math::Matrix:D: &coderef) {
    return Math::Matrix.new( [ @.rows.map: {
            [ $_.map( &coderef ) ]
    } ] );
}

method negative() {
    self.apply( - * );
}

method add(Math::Matrix:D: Math::Matrix $b where { $!row-count == $b.row-count and $!column-count == $b.column-count } ) {
    my @sum;
    for ^$!row-count X ^$b.column-count -> ($r, $c) {
        @sum[$r][$c] = @!rows[$r][$c] + $b.rows[$r][$c];
    }
    return Math::Matrix.new( @sum );
}

method subtract(Math::Matrix:D: Math::Matrix $b where { $!row-count == $b.row-count and $!column-count == $b.column-count } ) {
    my @subtract;
    for ^$!row-count X ^$b.column-count -> ($r, $c) {
        @subtract[$r][$c] = @!rows[$r][$c] - $b.rows[$r][$c];
    }
    return Math::Matrix.new( @subtract );
}

multi method multiply(Math::Matrix:D: Math::Matrix $b where { $!row-count == $b.row-count and $!column-count == $b.column-count } ) {
    my @multiply;
    for ^$!row-count X ^$b.column-count -> ($r, $c) {
        @multiply[$r][$c] = @!rows[$r][$c] * $b.rows[$r][$c];
    }
    return Math::Matrix.new( @multiply );
}

multi method determinant(Math::Matrix:D: --> Numeric) {
    fail "Number of columns has to be same as number of rows" unless self.is-square;
    return 1            if $!row-count == 0;
    return @!rows[0][0] if $!row-count == 1;
    if $!row-count == 2 {
        return @!rows[0][0] * @!rows[1][1] 
             - @!rows[0][1] * @!rows[1][0];
    } elsif $!row-count == 3 {
        return @!rows[0][0] * @!rows[1][1] * @!rows[2][2]
             + @!rows[0][1] * @!rows[1][2] * @!rows[2][0]
             + @!rows[0][2] * @!rows[1][0] * @!rows[2][1]
             - @!rows[0][2] * @!rows[1][1] * @!rows[2][0]
             - @!rows[0][1] * @!rows[1][0] * @!rows[2][2]
             - @!rows[0][0] * @!rows[1][2] * @!rows[2][1];
    } else {
        my $det = 0;
        for ^$!column-count -> $x {
            my @intermediate;
            for 1..^$!row-count -> $r {
                my @r;
                for (0..^$x,$x^..^$!column-count).flat -> $c {
                        @r.push( @!rows[$r][$c] );
                }
                @intermediate.push( [@r] );
            }
            if $x %% 2 { 
                $det += @!rows[0][$x] * Math::Matrix.new( @intermediate ).determinant();
            } else {
                $det -= @!rows[0][$x] * Math::Matrix.new( @intermediate ).determinant();
            }
        }
        return $det;
    }
}

multi method trace(Math::Matrix:D: --> Numeric) {
    fail "Not square matrix" unless self.is-square;
    my $tr = 0;
    for ^$!row-count -> $r { $tr += @!rows[$r][$r] }
    return $tr;
}

multi method density(Math::Matrix:D: --> Rat) {
    my $valcount = 0;
    for ^$.row-count X ^$.column-count -> ($r, $c) { $valcount++ if @!rows[$r][$c] != 0 }
    return $valcount / ($.row-count * $.column-count);
}

multi method rank(Math::Matrix:D: --> Int) {
    my $rank = 0;
    my @nz;  # none zero rows
    for @!rows -> $r {
        push @nz, $r unless [and]($r.flat X== 0);
    }
    return $rank unless @nz;
P:  while shift @nz -> $p {
        for @nz -> $cmp_row {
            my $cmp_col = 0;
            $cmp_col++ while $p[$cmp_col] == 0 and $cmp_row[$cmp_col] == 0;
            next          if $p[$cmp_col] == 0 or  $cmp_row[$cmp_col] == 0;
            my $q =          $p[$cmp_col]    /     $cmp_row[$cmp_col];
            my $diff =       $p  >>-<<   ($q <<*<< $cmp_row);
            next P        if [and]($diff.flat X== 0);
        }
        $rank++;
    }
    return $rank;
}

multi method kernel(Math::Matrix:D: --> Int) {
    return min(self.size) - self.rank;
}

multi method norm(Math::Matrix:D: Pos_Int $p = 2, Pos_Int $q = 1 --> Numeric) {
    my $norm = 0;
    for ^$!column-count -> $col {
        my $col_value = 0;
        for ^$!row-count -> $row {
            $col_value += abs(@!rows[$row][$col]) ** $p;
        }
        $norm += $col_value ** ($q / $p);
    }
    return $norm ** (1/$q);   
}

multi sub infix:<⋅>( Math::Matrix $a, Math::Matrix $b where { $a.column-count == $b.row-count} ) is export {
    $a.dotProduct( $b );
}

multi sub infix:<dot>(Math::Matrix $a, Math::Matrix $b) is export {
    $a ⋅ $b;
}

multi sub infix:<*>(Math::Matrix $a, Real $r) is export {
    $a.multiply( $r );
}

multi sub infix:<*>(Real $r, Math::Matrix $a) is export {
    $a.multiply( $r );
}

multi sub infix:<*>(Math::Matrix $a, Math::Matrix $b  where { $a.row-count == $b.row-count and $a.column-count == $b.column-count}) is export {
    $a.multiply( $b );
}

multi sub infix:<+>(Math::Matrix $a, Math::Matrix $b) is export {
    $a.add($b);
}

multi sub infix:<->(Math::Matrix $a, Math::Matrix $b) is export {
    $a.subtract($b);
}

multi sub infix:<**>(Math::Matrix $a where { $a.is-square }, Int $e) is export {
    return Math::Matrix.identity( $a.row-count ) if $e ==  0;
    my $p = $a.clone;
    $p = $p.dotProduct( $a ) for 2 .. abs $e;
    $p = $p.inverted         if  $e < 0;
    return $p;
}


=begin pod
=head1 NAME
Math::Matrix - Simple Matrix mathematics
=head1 SYNOPSIS

Matrix stuff, transposition, dot Product, and so on

=head1 DESCRIPTION

Perl6 already provide a lot of tools to work with array, shaped array, and so on,
however, even hyper operators does not seem to be enough to do matrix calculation
Purpose of that library is to propose some tools for Matrix calculation.

I should probably use shaped array for the implementation, but i am encountering
some issues for now. Problem being it might break the syntax for creation of a Matrix, 
use with consideration...

=head1 METHODS

=head2 method new
    method new( [[1,2],[3,4]])

   A constructor, takes parameters like:
=item rows : an array of row, each row being an array of cells

   Number of cell per row must be identical

=head2 method diagonal

    my $matrix = Math::Matrix.diagonal( 2, 4, 5 );
    This method is a constructor that returns an diagonal matrix of the size given 
    by count of the parameter.
    All the cells are set to 0 except the top/left to bottom/right diagonale, 
    set to given values.

=head2 method identity

    my $matrix = Math::Matrix.identity( 3 );
    This method is a constructor that returns an identity matrix of the size given in parameter
    All the cells are set to 0 except the top/left to bottom/right diagonale, set to 1

=head2 method equal

    if $matrixa.equal( $matrixb ) {
    if $matrixa eqv $matrixb {

    Checks two matrices for Equality

=head2 method is-square

    if $matrix.is-square {

    Tells if number of rows and colums are the same

=head2 method is-symmetric

    if $matrix.is-symmetric {

    Returns True if every cell with coordinates x y has same value as the cell on y x.

=head2 method is-orthogonal

    if $matrix.is-orthogonal {

    Is True if the matrix multiplied (dotProduct) with its transposed version (T)
    is an identity matrix.

=head2 method T

    return a new Matrix, which is the transposition of the current one

=head2 method inverted

    return a new Matrix, which is the inverted of the current one

=head2 method dotProduct

    my $product = $matrix1.dotProduct( $matrix2 )
    return a new Matrix, result of the dotProduct of the current matrix with matrix2
    Call be called throug operator ⋅ or dot , like following:
    my $c = $a ⋅ $b ;
    my $c = $a dot $b ;

    Matrix can be multiplied by a Real as well, and with operator *
    my $c = $a.multiply( 2.5 );
    my $c = 2.5 * $a;
    my $c = $a * 2.5;

=head2 method apply

    my $new = $matrix.apply( * + 2 );
    return a new matrix which is the current one with the function given in parameter applied to every cells

=head2 method negative

    my $new = $matrix.negative();
    return the negative of a matrix

=head2 method add

    my $new = $matrix.add( $matrix2 );
    Return addition of 2 matrices of the same size, can use operator +
    $new = $matrix + $matrix2;

=head2 method subtract

    my $new = $matrix.subtract( $matrix2 );
    Return substraction of 2 matrices of the same size, can use operator -
    $new = $matrix - $matrix2;

=head2 method multiply

    my $new = $matrix.multiply( $matrix2 );
    Return multiply of elements of 2 matrices of the same size, can use operator *
    $new = $matrix * $matrix2;

=head2 method determinant

    my $det = $matrix.determinant( );
    Calculate the determinant of a square matrix

=head2 method trace

    my $tr = $matrix.trace( );
    Calculate the trace of a square matrix

=head2 method density

    my $dst = $matrix.density( );      #  number of none-zero values / all cells
    useful to idenify sparse and full matrices

=head2 method rank

    my $r = $matrix.rank( );
    rank is the number of independent row or column vectors
    or als calles independent dimensions 
    (thats why this command is sometimes calles dim)

=head2 method kernel

    my $tr = $matrix.kernel( );
    kernel of matrix, number of dependent rows or columns

=head2 method norm

    my $norm = $matrix.norm( );   # euclidian norm (L2, p = 2)
    my $norm = $matrix.norm(1);   # p-norm, L1 = sum of all cells
    my $norm = $matrix.norm(4,3); # p,q - norm, p = 4, q = 3   

=end pod
