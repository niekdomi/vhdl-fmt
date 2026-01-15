# vhdl-fmt

> A fast, modern and configurable VHDL code formatter built to improve readability and consistency in your projects.

**NOTE: The formatter does not work yet and is still under development.**

## Installation

**TODO**

## Usage

Run `vhdl-fmt <file>` to format a VHDL file. By default, the formatted output will be printed to **stdout**.

```bash
vhdl-fmt file.vhd
```

### Command-Line Options

| Flag                | Alias       | Description                                                                                                    |
| :------------------ | :---------- | :------------------------------------------------------------------------------------------------------------- |
| `--write`           | `-w`        | **Overwrite** the input file(s) with the formatted output.                                                     |
| `--check`           | `-c`        | Check if the input file(s) are formatted correctly. Exits with a non-zero status if any file is not compliant. |
| `--location <path>` | `-l <path>` | Specify the path to a custom configuration file.                                                               |
| `--help`            | `-h`        | Print this help message.                                                                                       |
| `--version`         | `-v`        | Print the tool version.                                                                                        |

## Configuration

`vhdl-fmt` can be configured with a **YAML** file. By default, it looks for a `vhdl-fmt.yaml` in the current working directory. You can specify an alternative path using the `-l` or `--location` flag.

### Available Options

The following example shows all configurable options with their default settings:

```yaml
# The maximum desired line length
line_length: 100

indentation:
  style: "spaces" # "spaces" or "tabs"
  size: 4

end_of_line: "auto" # "lf", "crlf", "auto" (detects from input)

formatting:
  port_map:
    # Align the signals in port map instantiations
    align_signals: true

  declarations:
    # Align the ':' characters for declarations
    align_colons: true

    # Align the types (e.g., 'std_logic')
    align_types: true

    # Align the initial value assignments (':=')
    align_initialization: true

casing: # "lower_case" or "UPPER_CASE"
  keywords: "lower_case"
  constants: "UPPER_CASE"
  identifiers: "lower_case"
```

_(You can find a complete example configuration file in `example/vhdl-fmt.yaml`)_

---

## Contribution

Contributions are welcome\! Please fork the repository and open a pull request to submit your changes.

### Dependencies for Development

To ensure consistent code quality across contributions, we recommend to use the provided dev container.

Otherwise if you prefer to use your own environment, the following tools are part of the development and CI pipeline:

- `clang` (`clang`, `clang-format`, `clang-tidy`)
- `cmake`
- `conan`
- `gersemi`
- `ninja`

**NOTE:**

- `clang` version 21 is required. This might not be the latest version on some Linux distributions.
- `gersemi` and `clang-format` are not strictly required for development, but the CI pipeline will fail if files are not formatted correctly.
- If you install `gersemi` and `conan` with a python package manager, e.g., `uv`, the following steps may help:
  ```bash
  uv venv
  uv pip install conan gersemi
  source .venv/bin/activate
  ```
  You may use `active.fish` or whatever shell you use. You can quit the `venv` with `deactivate`
