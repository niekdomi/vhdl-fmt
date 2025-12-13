# vhdl-fmt

> A fast, modern, and opinionated VHDL code formatter designed to improve readability and enforce consistency across your projects.

**NOTE:** The formatter is still under active development and not all features are fully implemented yet.

## Installation

**TODO**

## Usage

Run `vhdl-fmt <file>` to format a VHDL file. By default, the formatted output is written to **stdout**.

```bash
vhdl-fmt file.vhd
```

### Command-Line Options

| Flag                | Alias       | Description                                                                                                |
| :------------------ | :---------- | :--------------------------------------------------------------------------------------------------------- |
| `--write`           | `-w`        | Overwrite the input file(s) with the formatted output.                                                     |
| `--check`           | `-c`        | Verify whether the input file(s) are correctly formatted. Exits with a non-zero status if any file is not. |
| `--location <path>` | `-l <path>` | Specify a custom configuration file location.                                                              |
| `--help`            | `-h`        | Display this help message.                                                                                 |
| `--version`         | `-v`        | Print the formatter version.                                                                               |

## Configuration

`vhdl-fmt` can be configured using a **YAML** file. By default, it searches for a `vhdl-fmt.yaml` in the current working directory. An alternative path can be provided via the `-l` / `--location` option.

### Available Options

The example below shows all supported configuration options along with their default values:

```yaml
line_length: 100

indentation:
  size: 4

casing:
  keywords: "lower_case" # "lower_case" | "UPPER_CASE"
  identifiers: "lower_case" # "lower_case" | "UPPER_CASE"
  constants: "UPPER_CASE" # "lower_case" | "UPPER_CASE"
```

### Opinionated Defaults

The formatter deliberately enforces a specific style. The following behaviors are **not configurable**:

- Indentation always uses spaces. Tabs are automatically converted to spaces.

- Multiple consecutive blank lines are collapsed into a single empty line.

- Lines exceeding the maximum length are wrapped, with operators aligned for readability, for example:

  ```vhd
  if (lhs(flag_pos_inf_c) = '1'
     and rhs(flag_pos_inf_c) = '1')
     or (lhs(flag_neg_inf_c) = '1'
     or compare_eq = '1') then
  end if;

  output_value <= input_operand_left
                + input_operand_right
                + accumulator_value
                + pipeline_offset
                + correction_term
                + rounding_bias;
  ```

- Declarations (`:`, `:=`), assignments (`<=`, `:=`), and similar constructs within the same logical block (not separated by comments or blank lines) are aligned.

- If a label is used (e.g. `my_proc: process`), the corresponding end label is enforced (`end process my_proc;`).

- Certain blocks always use explicit end keywords:
  - `end architecture`
  - `end case`
  - `end entity`
  - `end if`
  - `end loop`
  - `end process`

- Line endings (`\n` vs. `\r\n`) are preserved. This should be controlled via `.editorconfig` or `.gitattributes`.

---

## Contribution

Contributions are welcome. Please fork the repository and open a pull request with your changes.

### Development Dependencies

For a consistent development experience, using the provided dev container is recommended.

If you prefer a local setup, the following tools are used in development and CI:

- `clang` (`clang`, `clang-format`, `clang-tidy`)
- `cmake`
- `conan`
- `gersemi`
- `ninja`

**Notes:**

- `clang` version 21 is required and may not be available by default on all Linux distributions.
- `gersemi` and `clang-format` are optional locally, but CI will fail if formatting does not match.
- If you install `gersemi` and `conan` via a Python package manager (e.g. `uv`), the following may help:

  ```bash
  uv venv
  uv pip install conan gersemi==0.19.3
  source .venv/bin/activate
  ```

  You may use `active.fish` or whatever shell you use. Exit the environment with `deactivate`.

### Running and Building the Project

The project provides a `Makefile` with several convenient targets to simplify common development tasks:

- `make`: Builds the project in **debug** mode.
- `make BUILD_TYPE=Release`: Builds the project in **release** mode with additional optimizations enabled.
- `make test`: Executes the full test suite.
- `make format`: Formats the source files according to the project’s formatting rules.
- `make check-format`: Verifies that all files are correctly formatted.
- `make lint-diff`: Runs `clang-tidy` only on files that have changed, which significantly reduces execution time.
- `make coverage-show`: Generates the coverage report and opens the HTML report in the browser.

You can always inspect the `Makefile` to discover additional targets and available shortcuts.

## Alternatives

When this project was started, we were not aware of the existence of [vhdl-style-guide](https://github.com/jeremiah-c-leary/vhdl-style-guide), which also provides formatting capabilities.

A brief comparison highlights the differences:

- **vhdl-style-guide**
  - Highly configurable
  - Includes certain style guide and linting features that are not provided by `vhdl-fmt`

- **vhdl-fmt**
  - Strongly opinionated, enforces a consistent style
  - Significantly faster (up to 30x–50x), making it well suited for editor format-on-save workflows
