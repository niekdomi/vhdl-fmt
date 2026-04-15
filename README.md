# vhdl-fmt

> A fast and opinionated VHDL code formatter designed to improve
> readability and enforce consistency across your projects.

> [!IMPORTANT]
> The formatter is still a **work in progress**. Given the complexity of the VHDL
> language specification and my limited familiarity with all its nuances, some
> code may not be formatted correctly. In rare cases, parts of the code might be
> unintentionally altered or omitted. If you run into any issues, please feel
> free to open an issue or submit a pull request with a fix.

## Installation

The release binary can be found [here](https://github.com/niekdomi/vhdl-fmt/releases)

## Usage

Run `vhdl-fmt <file>` to format a VHDL file. By default, the formatted output is
written to **stdout**.

```bash
vhdl-fmt file.vhd
```

### Command-Line Options

| Flag                | Alias       | Description                                                                                                |
| ------------------- | ----------- | ---------------------------------------------------------------------------------------------------------- |
| `--write`           | `-w`        | Overwrite the input file(s) with the formatted output.                                                     |
| `--check`           | `-c`        | Verify whether the input file(s) are correctly formatted. Exits with a non-zero status if any file is not. |
| `--location <path>` | `-l <path>` | Specify a custom configuration file location.                                                              |
| `--help`            | `-h`        | Display this help message.                                                                                 |
| `--version`         | `-v`        | Print the formatter version.                                                                               |

## Configuration

`vhdl-fmt` can be configured using a **TOML** file. By default, it searches for
a `vhdl-fmt.toml` or `.vhdl-fmt.toml` in the current working directory. An alternative path can be
provided via the `-l` / `--location` option.

### Available Options

The example below shows all supported configuration options along with their
default values:

```toml
# vhdl-fmt.toml
line_length = 100

[indentation]
size = 4

[casing]
keywords = "preserve"    # | "lower_case" | "upper_case"
identifiers = "preserve" # | "lower_case" | "upper_case"
constants = "preserve"   # | "lower_case" | "upper_case"
```

The formatter preserves the original casing by default.

### Opinionated Defaults

The formatter deliberately enforces a specific style. The following behaviors
are **not configurable**:

- Indentation **always** uses spaces. Tabs are automatically converted to spaces.
- Multiple consecutive blank lines are collapsed into a single empty line.
- Lines exceeding the maximum length are wrapped, for example:

**Input:**

```vhdl
if ((status_reg(overflow_flag_c) = '1') and (status_reg(carry_flag_c) = '1')) or ((status_reg(zero_flag_c) = '1') and (status_reg(sign_flag_c) = '1')) then
```

**Output:**

```vhdl
if ((status_reg(overflow_flag_c) = '1') and
    (status_reg(carry_flag_c) = '1')) or
   ((status_reg(zero_flag_c) = '1') and
    (status_reg(sign_flag_c) = '1'))
then
    -- ...
end if;
```

---

**Input:**

```vhdl
output_value <= input_operand_left + input_operand_right + accumulator_value + pipeline_offset + correction_term + rounding_bias;
```

**Output:**

```vhdl
output_value <= input_operand_left +
                input_operand_right +
                accumulator_value +
                pipeline_offset +
                correction_term +
                rounding_bias;
```

- Declarations (`:`, `:=`), assignments (`<=`, `:=`), and similar constructs
  within the same logical block (not separated by comments or blank lines) are
  aligned.
- If a label is used (e.g. `my_proc: process`), the corresponding end label is
  enforced (`end process my_proc;`).
- Blocks always use explicit end keywords.
- Line endings (`\n` vs. `\r\n`) are preserved. This should be controlled via
  `.editorconfig` or `.gitattributes`.

---

## Alternatives

When this project was started, we were not aware of the existence of
[vhdl-style-guide](https://github.com/jeremiah-c-leary/vhdl-style-guide), which
also provides formatting capabilities.

A brief comparison highlights the differences:

**vhdl-style-guide**

- Highly configurable
- Includes certain style guide and linting features that are not provided by
  `vhdl-fmt`

**vhdl-fmt**

- Strongly opinionated, enforces a consistent style
- Significantly faster. A 2300lines VHDL file (116kB) takes <15ms to format,
  making it well suited for editor _format-on-save_ workflows
