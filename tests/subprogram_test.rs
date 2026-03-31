mod common;

use common::assert_format;

fn wrap(decl: &str) -> String {
    format!(
        r#"package p is
{decl}
end p;"#,
        decl = decl
    )
}

//===----------------------------------------------------------------------===//
// Subprogram declarations
//===----------------------------------------------------------------------===//

#[test]
fn procedure_declaration() {
    assert_format(
        &wrap("procedure reset;"),
        r#"package p is
    procedure reset;
end package p;"#,
    );
}

#[test]
fn impure_function() {
    assert_format(
        &wrap("impure function f return integer;"),
        r#"package p is
    function f return integer;
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Subprogram specifications
//===----------------------------------------------------------------------===//

#[test]
fn function_with_return() {
    assert_format(
        &wrap("function add(a, b : integer) return integer;"),
        r#"package p is
    pure function add (
        constant a, b : integer
    ) return integer;
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Subprogram header (generic clause)
//===----------------------------------------------------------------------===//

#[test]
fn generic_procedure() {
    assert_format(
        &wrap("procedure proc generic(type t) parameter(x : t);"),
        r#"package p is
    procedure proc
        generic (
            type t
        ) (
        constant x : t
    );
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Subprogram body
//===----------------------------------------------------------------------===//

#[test]
fn function_body() {
    assert_format(
        r#"package body p is function inc(x : integer) return integer is begin return x + 1; end inc; end p;"#,
        r#"package body p is
    pure function inc (
        constant x : integer
    ) return integer is
    begin
        return x + 1;
    end function inc;
end package body p;"#,
    );
}

#[test]
fn procedure_body() {
    assert_format(
        r#"package body p is procedure proc is begin null; end proc; end p;"#,
        r#"package body p is
    procedure proc is
    begin
        null;
    end procedure proc;
end package body p;"#,
    );
}

#[test]
fn procedure_body_with_comments() {
    assert_format(
        r#"-- proc body leading
package body p is -- body comment
procedure proc is -- proc comment
begin -- begin comment
null; -- null comment
end proc; -- end proc
end p; -- end body"#,
        r#"-- proc body leading
package body p is
    procedure proc is
    begin -- begin comment
        null; -- null comment
    end procedure proc; -- proc comment -- end proc
end package body p; -- end body -- body comment"#,
    );
}

//===----------------------------------------------------------------------===//
// Signatures
//===----------------------------------------------------------------------===//

#[test]
fn alias_with_signature() {
    assert_format(
        &wrap("alias add is \"+\" [integer, integer return integer];"),
        r#"package p is
    alias add is "+"[integer, integer return integer];
end package p;"#,
    );
}

//===----------------------------------------------------------------------===//
// Subprogram instantiation
//===----------------------------------------------------------------------===//

#[test]
fn function_instantiation() {
    assert_format(
        &wrap("function my_add is new generic_add generic map(t => integer);"),
        r#"package p is
    function my_add is new generic_add generic map (t => integer);
end package p;"#,
    );
}
