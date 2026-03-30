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

#[test]
fn entity_with_ports() {
    assert_format(
        r#"entity foo is port (a : in std_logic; b : out std_logic); end foo;"#,
        r#"entity foo is
    port (
        a : in  std_logic;
        b : out std_logic
    );
end entity foo;"#,
    );
}

#[test]
fn entity_with_comments() {
    assert_format(
        r#"-- leading comment
entity foo is -- entity comment
port (a : in std_logic; b : out std_logic); -- port comment
end foo; -- end comment"#,
        r#"-- leading comment
entity foo is
    port (
        a : in  std_logic;
        b : out std_logic
    );
end entity foo; -- end comment -- entity comment -- port comment"#,
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

#[test]
fn architecture_with_signal() {
    assert_format(
        r#"architecture rtl of foo is signal s : std_logic; begin end rtl;"#,
        r#"architecture rtl of foo is
    signal s : std_logic;
begin

end architecture rtl;"#,
    );
}

#[test]
fn architecture_with_comments() {
    assert_format(
        r#"-- arch leading
architecture rtl of foo is -- arch comment
signal s : std_logic; -- signal comment
begin -- begin comment
end rtl; -- end comment"#,
        r#"-- arch leading
architecture rtl of foo is
    signal s : std_logic; -- signal comment
begin -- begin comment

end architecture rtl; -- end comment -- arch comment"#,
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

#[test]
fn package_with_constant() {
    assert_format(
        r#"package pkg is constant c : integer := 42; end pkg;"#,
        r#"package pkg is
    constant c : integer := 42;
end package pkg;"#,
    );
}

#[test]
fn package_with_comments() {
    assert_format(
        r#"-- package leading
package pkg is -- package comment
constant c : integer := 42; -- const comment
end pkg; -- end comment"#,
        r#"-- package leading
package pkg is
    constant c : integer := 42; -- const comment
end package pkg; -- end comment -- package comment"#,
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

#[test]
fn package_body_with_function() {
    assert_format(
        r#"package body pkg is function f return integer is begin return 1; end f; end pkg;"#,
        r#"package body pkg is
    pure function f return integer is
    begin
        return 1;
    end function f;
end package body pkg;"#,
    );
}

#[test]
fn package_body_with_comments() {
    assert_format(
        r#"-- body leading
package body pkg is -- body comment
function f return integer is -- func comment
begin return 1; end f; -- end func
end pkg; -- end body"#,
        r#"-- body leading
package body pkg is
    pure function f return integer is
    begin
        return 1;
    end function f; -- func comment -- end func
end package body pkg; -- end body -- body comment"#,
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

#[test]
fn context_declaration_with_comments() {
    assert_format(
        r#"-- context leading
context ctx is -- context comment
library ieee; -- lib comment
use ieee.std_logic_1164.all; -- use comment
end ctx; -- end comment"#,
        r#"-- context leading
context ctx is
    library ieee;
    use ieee.std_logic_1164.all;
end context ctx; -- context comment -- lib comment -- use comment -- end comment"#,
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

#[test]
fn configuration_with_binding() {
    assert_format(
        r#"configuration cfg of ent is for rtl for inst : comp use entity work.comp; end for; end for; end cfg;"#,
        r#"configuration cfg of ent is
    for rtl
        for inst: comp
            use entity work.comp;
        end for;
    end for;
end configuration cfg;"#,
    );
}

#[test]
fn configuration_with_comments() {
    assert_format(
        r#"-- config leading
configuration cfg of ent is -- config comment
for rtl -- for comment
for inst : comp use entity work.comp; end for; -- inner end
end for; -- outer end
end cfg; -- end config"#,
        r#"-- config leading
configuration cfg of ent is
    for rtl
        for inst: comp
            use entity work.comp;
        end for;
    end for;
end configuration cfg; -- config comment -- for comment -- inner end -- outer end -- end config"#,
    );
}
