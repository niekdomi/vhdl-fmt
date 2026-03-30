mod common;

use common::assert_format;

//===---------------------------------------------------------------------===//
// Context clause
//===---------------------------------------------------------------------===//

#[test]
fn context_clause_library_and_use() {
    assert_format(
        r#"library ieee; use ieee.std_logic_1164.all; entity e is end e;"#,
        r#"library ieee;
use ieee.std_logic_1164.all;
entity e is
end entity e;"#,
    );
}

//===---------------------------------------------------------------------===//
// Entity declaration
//===---------------------------------------------------------------------===//

#[test]
fn entity_empty() {
    assert_format(
        r#"entity foo is end foo;"#,
        r#"entity foo is
end entity foo;"#,
    );
}

//===---------------------------------------------------------------------===//
// Architecture body
//===---------------------------------------------------------------------===//

#[test]
fn architecture_empty() {
    assert_format(
        r#"architecture rtl of foo is begin end rtl;"#,
        r#"architecture rtl of foo is
begin

end architecture rtl;"#,
    );
}

//===---------------------------------------------------------------------===//
// Package declaration
//===---------------------------------------------------------------------===//

#[test]
fn package_empty() {
    assert_format(
        r#"package pkg is end pkg;"#,
        r#"package pkg is
end package pkg;"#,
    );
}

//===---------------------------------------------------------------------===//
// Package body
//===---------------------------------------------------------------------===//

#[test]
fn package_body_empty() {
    assert_format(
        r#"package body pkg is end pkg;"#,
        r#"package body pkg is
end package body pkg;"#,
    );
}

//===---------------------------------------------------------------------===//
// Context declaration
//===---------------------------------------------------------------------===//

#[test]
fn context_declaration() {
    assert_format(
        r#"context ctx is library ieee; use ieee.std_logic_1164.all; end ctx;"#,
        r#"context ctx is
    library ieee;
    use ieee.std_logic_1164.all;
end context ctx;"#,
    );
}

//===---------------------------------------------------------------------===//
// Configuration declaration
//===---------------------------------------------------------------------===//

#[test]
fn configuration_simple() {
    assert_format(
        r#"configuration cfg of ent is for rtl end for; end cfg;"#,
        r#"configuration cfg of ent is
    for rtl
    end for;
end configuration cfg;"#,
    );
}
