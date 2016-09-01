# TXN::Remarshal

Double-entry accounting ledger file format converter


## Synopsis

```perl6
use TXN::Remarshal;

my Str $txn = Q:to/EOF/;
2014-01-01 "I started the year with $1000 in Bankwest"
  Assets:Personal:Bankwest:Cheque    $1000 USD
  Equity:Personal                    $1000 USD
EOF

# convenience wrappers
my TXN::Parser::AST::Entry @entry = from-txn($txn);
my Str $s = to-txn(@entry);

# txn ↔ entry
my TXN::Parser::AST::Entry @entry = remarshal($txn, :if<txn>, :of<entry>);
my Str $ledger = remarshal(@entry, :if<entry>, :of<txn>);

# entry ↔ hash
my Hash @a = remarshal(@entry, :if<entry>, :of<hash>);
my TXN::Parser::AST::Entry @e = remarshal(@a, :if<hash>, :of<entry>);

# hash ↔ json
my Str $json = remarshal(@a, :if<hash>, :of<json>);
my Hash @b = remarshal($json, :if<json>, :of<hash>);
```


## Licensing

This is free and unencumbered public domain software. For more
information, see http://unlicense.org/ or the accompanying UNLICENSE file.
