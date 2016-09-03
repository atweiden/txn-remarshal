use v6;
use TXN::Parser;
use TXN::Parser::Types;
unit module TXN::Remarshal;

# sub from-txn {{{

multi sub from-txn(
    Str $content,
    *%opts (
        Str :$txn-dir,
        Int :$date-local-offset
    )
) is export returns Array
{
    my TXN::Parser::AST::Entry @entry =
        TXN::Parser.parse($content, |%opts).made;
}

multi sub from-txn(
    Str :$file!,
    *%opts (
        Str :$txn-dir,
        Int :$date-local-offset
    )
) is export returns Array
{
    my TXN::Parser::AST::Entry @entry =
        TXN::Parser.parsefile($file, |%opts).made;
}

# end sub from-txn }}}
# sub to-txn {{{

# --- Entry {{{

multi sub to-txn(TXN::Parser::AST::Entry @entry) is export returns Str
{
    @entry.map({ to-txn($_) }).join("\n" x 2);
}

multi sub to-txn(TXN::Parser::AST::Entry $entry) is export returns Str
{
    my TXN::Parser::AST::Entry::Header $header = $entry.header;
    my TXN::Parser::AST::Entry::Posting @posting = $entry.posting;
    my Str $s = join("\n", to-txn($header), to-txn(@posting));
    $s;
}

# --- end Entry }}}
# --- Entry::Header {{{

multi sub to-txn(TXN::Parser::AST::Entry::Header $header) returns Str
{
    my Dateish $date = $header.date;
    my Str $description = $header.description if $header.description;
    my UInt $important = $header.important;
    my Str @tag = $header.tag if $header.tag;

    my Str $s = ~$date;
    $s ~= "\n" ~ to-txn(:@tag) if @tag;
    $s ~= ' ' ~ '!' x $important if $important > 0;

    if $description
    {
        my Str $d = qq:to/EOF/;
        '''
        $description
        '''
        EOF
        $s ~= "\n" ~ $d.trim;
    }

    $s.trim;
}

# --- end Entry::Header }}}
# --- Entry::Posting {{{

multi sub to-txn(TXN::Parser::AST::Entry::Posting @posting) returns Str
{
    @posting.map({ to-txn($_) }).join("\n");
}

multi sub to-txn(TXN::Parser::AST::Entry::Posting $posting) returns Str
{
    my TXN::Parser::AST::Entry::Posting::Account $account = $posting.account;
    my TXN::Parser::AST::Entry::Posting::Amount $amount = $posting.amount;
    my DecInc $decinc = $posting.decinc;
    my TXN::Parser::AST::Entry::Posting::Annot $annot = $posting.annot
        if $posting.annot;

    my Bool $needs-minus = so $decinc ~~ DEC;

    # check if $amount includes C<:plus-or-minus('-')>
    # if so, we don't need to negate the posting amount
    my Bool $has-minus = $amount.plus-or-minus
        ?? $amount.plus-or-minus eq '-'
        !! False;

    my Str $s = to-txn($account) ~ ' ' x 4;
    if $needs-minus
    {
        unless $has-minus
        {
            $s ~= '-';
        }
    }

    $s ~= to-txn($amount);
    $s ~= ' ' ~ to-txn($annot) if $annot;
    $s;
}

# --- end Entry::Posting }}}
# --- Entry::Posting::Account {{{

multi sub to-txn(TXN::Parser::AST::Entry::Posting::Account $account) returns Str
{
    my Silo $silo = $account.silo;
    my Str $entity = $account.entity;
    my Str @path = $account.path if $account.path;

    my Str $s = $silo.gist.tclc ~ ':' ~ to-txn(:$entity);
    $s ~= ':' ~ to-txn(:@path) if @path;
    $s;
}

# --- end Entry::Posting::Account }}}
# --- Entry::Posting::Amount {{{

multi sub to-txn(TXN::Parser::AST::Entry::Posting::Amount $amount) returns Str
{
    my Str $asset-code = $amount.asset-code;
    my Quantity $asset-quantity = $amount.asset-quantity;
    my AssetSymbol $asset-symbol = $amount.asset-symbol if $amount.asset-symbol;
    my PlusMinus $plus-or-minus = $amount.plus-or-minus if $amount.plus-or-minus;

    my Str $s = '';
    $s ~= $plus-or-minus if $plus-or-minus;
    $s ~= $asset-symbol if $asset-symbol;
    $s ~= $asset-quantity;
    $s ~= ' ' ~ to-txn(:$asset-code);
    $s;
}

# --- Entry::Posting::Amount }}}
# --- Entry::Posting::Annot {{{

multi sub to-txn(TXN::Parser::AST::Entry::Posting::Annot $annot) returns Str
{
    my TXN::Parser::AST::Entry::Posting::Annot::Inherit $inherit =
        $annot.inherit if $annot.inherit;
    my TXN::Parser::AST::Entry::Posting::Annot::Lot $lot =
        $annot.lot if $annot.lot;
    my TXN::Parser::AST::Entry::Posting::Annot::XE $xe =
        $annot.xe if $annot.xe;

    my Str @a;
    push @a, to-txn($xe) if $xe;
    push @a, to-txn($inherit) if $inherit;
    push @a, to-txn($lot) if $lot;

    my Str $s = '';
    $s ~= join(' ', @a);
    $s;
}

# --- end Entry::Posting::Annot }}}
# --- Entry::Posting::Annot::Inherit {{{

multi sub to-txn(TXN::Parser::AST::Entry::Posting::Annot::Inherit $inherit) returns Str
{
    my Str $asset-code = $inherit.asset-code;
    my Quantity $asset-quantity = $inherit.asset-quantity;
    my AssetSymbol $asset-symbol = $inherit.asset-symbol if $inherit.asset-symbol;

    my Str $s = '« ';
    $s ~= $asset-symbol if $asset-symbol;
    $s ~= $asset-quantity;
    $s ~= ' ' ~ to-txn(:$asset-code);
    $s;
}

# --- end Entry::Posting::Annot::Inherit }}}
# --- Entry::Posting::Annot::Lot {{{

multi sub to-txn(TXN::Parser::AST::Entry::Posting::Annot::Lot $lot) returns Str
{
    my Str $name = $lot.name;
    my DecInc $decinc = $lot.decinc;

    my Str $s = '';
    given $decinc
    {
        when DEC
        {
            $s ~= '←';
        }
        when INC
        {
            $s ~= '→';
        }
    }
    $s ~= ' [' ~ to-txn(:$name) ~ ']';
    $s;
}

# --- end Entry::Posting::Annot::Lot }}}
# --- Entry::Posting::Annot::XE {{{

multi sub to-txn(TXN::Parser::AST::Entry::Posting::Annot::XE $xe) returns Str
{
    my Str $asset-code = $xe.asset-code;
    my Quantity $asset-quantity = $xe.asset-quantity;
    my AssetSymbol $asset-symbol = $xe.asset-symbol if $xe.asset-symbol;

    my Str $s = '@ ';
    $s ~= $asset-symbol if $asset-symbol;
    $s ~= $asset-quantity;
    $s ~= ' ' ~ to-txn(:$asset-code);
    $s;
}

# --- end Entry::Posting::Annot::XE }}}

# --- asset-code {{{

multi sub to-txn(AssetCode :$asset-code!) returns Str
{
    $asset-code;
}

multi sub to-txn(Str :$asset-code!) returns Str
{
    $asset-code.perl;
}

# --- end asset-code }}}
# --- entity {{{

multi sub to-txn(VarName :$entity!) returns Str
{
    $entity;
}

multi sub to-txn(Str :$entity!) returns Str
{
    $entity.perl;
}

# --- end entity }}}
# --- name {{{

multi sub to-txn(VarName :$name!) returns Str
{
    $name;
}

multi sub to-txn(Str :$name!) returns Str
{
    $name.perl;
}

# --- end name }}}
# --- path {{{

multi sub to-txn(Str :@path!) returns Str
{
    @path.map({ to-txn(:path($_)) }).join(':');
}

multi sub to-txn(VarName :$path!) returns Str
{
    $path;
}

multi sub to-txn(Str :$path!) returns Str
{
    $path.perl;
}

# --- end path }}}
# --- tag {{{

multi sub to-txn(Str :@tag!) returns Str
{
    @tag.map({ '#' ~ to-txn(:tag($_)) }).join(' ');
}

multi sub to-txn(VarName :$tag!) returns Str
{
    $tag;
}

multi sub to-txn(Str :$tag!) returns Str
{
    $tag.perl;
}

# --- end tag }}}

# end sub to-txn }}}

# vim: set filetype=perl6 foldmethod=marker foldlevel=0:
