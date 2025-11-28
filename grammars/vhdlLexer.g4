lexer grammar vhdlLexer;

options { caseInsensitive = true; }

channels { COMMENTS, NEWLINES }

ABS
    : 'ABS'
    ;

ACCESS
    : 'ACCESS'
    ;

ACROSS
    : 'ACROSS'
    ;

AFTER
    : 'AFTER'
    ;

ALIAS
    : 'ALIAS'
    ;

ALL
    : 'ALL'
    ;

AND
    : 'AND'
    ;

ARCHITECTURE
    : 'ARCHITECTURE'
    ;

ARRAY
    : 'ARRAY'
    ;

ASSERT
    : 'ASSERT'
    ;

ATTRIBUTE
    : 'ATTRIBUTE'
    ;

BEGIN
    : 'BEGIN'
    ;

BLOCK
    : 'BLOCK'
    ;

BODY
    : 'BODY'
    ;

BREAK
    : 'BREAK'
    ;

BUFFER
    : 'BUFFER'
    ;

BUS
    : 'BUS'
    ;

CASE
    : 'CASE'
    ;

COMPONENT
    : 'COMPONENT'
    ;

CONFIGURATION
    : 'CONFIGURATION'
    ;

CONSTANT
    : 'CONSTANT'
    ;

CONTEXT
    : 'CONTEXT'
    ;

DISCONNECT
    : 'DISCONNECT'
    ;

DOWNTO
    : 'DOWNTO'
    ;

END
    : 'END'
    ;

ENTITY
    : 'ENTITY'
    ;

ELSE
    : 'ELSE'
    ;

ELSIF
    : 'ELSIF'
    ;

EXIT
    : 'EXIT'
    ;

FILE
    : 'FILE'
    ;

FOR
    : 'FOR'
    ;

FUNCTION
    : 'FUNCTION'
    ;

GENERATE
    : 'GENERATE'
    ;

GENERIC
    : 'GENERIC'
    ;

GROUP
    : 'GROUP'
    ;

GUARDED
    : 'GUARDED'
    ;

IF
    : 'IF'
    ;

IMPURE
    : 'IMPURE'
    ;

IN
    : 'IN'
    ;

INERTIAL
    : 'INERTIAL'
    ;

INOUT
    : 'INOUT'
    ;

IS
    : 'IS'
    ;

LABEL
    : 'LABEL'
    ;

LIBRARY
    : 'LIBRARY'
    ;

LIMIT
    : 'LIMIT'
    ;

LINKAGE
    : 'LINKAGE'
    ;

LITERAL
    : 'LITERAL'
    ;

LOOP
    : 'LOOP'
    ;

MAP
    : 'MAP'
    ;

MOD
    : 'MOD'
    ;

NAND
    : 'NAND'
    ;

NATURE
    : 'NATURE'
    ;

NEW
    : 'NEW'
    ;

NEXT
    : 'NEXT'
    ;

NOISE
    : 'NOISE'
    ;

NOR
    : 'NOR'
    ;

NOT
    : 'NOT'
    ;

NULL_
    : 'NULL'
    ;

OF
    : 'OF'
    ;

ON
    : 'ON'
    ;

OPEN
    : 'OPEN'
    ;

OR
    : 'OR'
    ;

OTHERS
    : 'OTHERS'
    ;

OUT
    : 'OUT'
    ;

PACKAGE
    : 'PACKAGE'
    ;

PORT
    : 'PORT'
    ;

POSTPONED
    : 'POSTPONED'
    ;

PROCESS
    : 'PROCESS'
    ;

PROCEDURE
    : 'PROCEDURE'
    ;

PROCEDURAL
    : 'PROCEDURAL'
    ;

PURE
    : 'PURE'
    ;

QUANTITY
    : 'QUANTITY'
    ;

RANGE
    : 'RANGE'
    ;

REVERSE_RANGE
    : 'REVERSE_RANGE'
    ;

REJECT
    : 'REJECT'
    ;

REM
    : 'REM'
    ;

RECORD
    : 'RECORD'
    ;

REFERENCE
    : 'REFERENCE'
    ;

REGISTER
    : 'REGISTER'
    ;

REPORT
    : 'REPORT'
    ;

RETURN
    : 'RETURN'
    ;

ROL
    : 'ROL'
    ;

ROR
    : 'ROR'
    ;

SELECT
    : 'SELECT'
    ;

SEVERITY
    : 'SEVERITY'
    ;

SHARED
    : 'SHARED'
    ;

SIGNAL
    : 'SIGNAL'
    ;

SLA
    : 'SLA'
    ;

SLL
    : 'SLL'
    ;

SPECTRUM
    : 'SPECTRUM'
    ;

SRA
    : 'SRA'
    ;

SRL
    : 'SRL'
    ;

SUBNATURE
    : 'SUBNATURE'
    ;

SUBTYPE
    : 'SUBTYPE'
    ;

TERMINAL
    : 'TERMINAL'
    ;

THEN
    : 'THEN'
    ;

THROUGH
    : 'THROUGH'
    ;

TO
    : 'TO'
    ;

TOLERANCE
    : 'TOLERANCE'
    ;

TRANSPORT
    : 'TRANSPORT'
    ;

TYPE
    : 'TYPE'
    ;

UNAFFECTED
    : 'UNAFFECTED'
    ;

UNITS
    : 'UNITS'
    ;

UNTIL
    : 'UNTIL'
    ;

USE
    : 'USE'
    ;

VARIABLE
    : 'VARIABLE'
    ;

WAIT
    : 'WAIT'
    ;

WITH
    : 'WITH'
    ;

WHEN
    : 'WHEN'
    ;

WHILE
    : 'WHILE'
    ;

XNOR
    : 'XNOR'
    ;

XOR
    : 'XOR'
    ;

BASE_LITERAL
    // INTEGER must be checked to be between and including 2 and 16 (included) i.e.
    // INTEGER >=2 and INTEGER <=16
    // A Based integer (a number without a . such as 3) should not have a negative exponent
    // A Based fractional number with a . i.e. 3.0 may have a negative exponent
    // These should be checked in the Visitor/Listener whereby an appropriate error message
    // should be given
    : INTEGER '#' BASED_INTEGER ('.' BASED_INTEGER)? '#' (EXPONENT)?
    ;

BIT_STRING_LITERAL
    : BIT_STRING_LITERAL_BINARY
    | BIT_STRING_LITERAL_OCTAL
    | BIT_STRING_LITERAL_HEX
    ;

BIT_STRING_LITERAL_BINARY
    : 'B"' ('1' | '0' | '_')+ '"'
    ;

BIT_STRING_LITERAL_OCTAL
    : 'O"' ('7' | '6' | '5' | '4' | '3' | '2' | '1' | '0' | '_')+ '"'
    ;

BIT_STRING_LITERAL_HEX
    : 'X"' (
        'F'
        | 'E'
        | 'D'
        | 'C'
        | 'B'
        | 'A'
        | '9'
        | '8'
        | '7'
        | '6'
        | '5'
        | '4'
        | '3'
        | '2'
        | '1'
        | '0'
        | '_'
    )+ '"'
    ;

REAL_LITERAL
    : INTEGER '.' INTEGER (EXPONENT)?
    ;

BASIC_IDENTIFIER
    : LETTER ('_' ( LETTER | DIGIT) | LETTER | DIGIT)*
    ;

EXTENDED_IDENTIFIER
    : '\\' (
        LETTER
        | '0' ..'9'
        | '&'
        | '\''
        | '('
        | ')'
        | '+'
        | ','
        | '-'
        | '.'
        | '/'
        | ':'
        | ';'
        | '<'
        | '='
        | '>'
        | '|'
        | ' '
        | OTHER_SPECIAL_CHARACTER
        | '\\'
        | '#'
        | '['
        | ']'
        | '_'
    )+ '\\'
    ;

LETTER
    : 'A' ..'Z'
    ;

COMMENT
    : '--' (~'\n')* -> channel(COMMENTS)
    ;

TAB
    : ('\t')+ -> skip
    ;

SPACE
    : (' ')+ -> skip
    ;

NEWLINE
    : '\n' -> channel(NEWLINES)
    ;

CR
    : '\r' -> skip
    ;

CHARACTER_LITERAL
    : APOSTROPHE . APOSTROPHE
    ;

STRING_LITERAL
    : '"' (~('"' | '\n' | '\r') | '""')* '"'
    ;

OTHER_SPECIAL_CHARACTER
    : '!'
    | '$'
    | '%'
    | '@'
    | '?'
    | '^'
    | '`'
    | '{'
    | '}'
    | '~'
    | ' '
    | '\u00A4'
    | '\u00A6'
    | '\u00A7'
    | '\u00A9'
    | '\u00AB'
    | '\u00AC'
    | '\u00AD'
    | '\u00AE'
    | '\u00B0'
    | '\u00B1'
    | '\u00B5'
    | '\u00B6'
    | '\u00B7'
    | '\u2116'
    | '\u00BB'
    | '\u0400' ..'\u045E'
    ;

DOUBLESTAR
    : '**'
    ;

ASSIGN
    : '=='
    ;

LE
    : '<='
    ;

GE
    : '>='
    ;

ARROW
    : '=>'
    ;

NEQ
    : '/='
    ;

VARASGN
    : ':='
    ;

BOX
    : '<>'
    ;

DBLQUOTE
    : '"'
    ;

SEMI
    : ';'
    ;

COMMA
    : ','
    ;

AMPERSAND
    : '&'
    ;

LPAREN
    : '('
    ;

RPAREN
    : ')'
    ;

LBRACKET
    : '['
    ;

RBRACKET
    : ']'
    ;

COLON
    : ':'
    ;

MUL
    : '*'
    ;

DIV
    : '/'
    ;

PLUS
    : '+'
    ;

MINUS
    : '-'
    ;

LOWERTHAN
    : '<'
    ;

GREATERTHAN
    : '>'
    ;

EQ
    : '='
    ;

BAR
    : '|'
    ;

DOT
    : '.'
    ;

BACKSLASH
    : '\\'
    ;

EXPONENT
    : 'E' ('+' | '-')? INTEGER
    ;

HEXDIGIT
    : 'A' ..'F'
    ;

INTEGER
    : DIGIT ('_' | DIGIT)*
    ;

DIGIT
    : '0' ..'9'
    ;

BASED_INTEGER
    : EXTENDED_DIGIT ('_' | EXTENDED_DIGIT)*
    ;

EXTENDED_DIGIT
    : (DIGIT | LETTER)
    ;

APOSTROPHE
    : '\''
    ;