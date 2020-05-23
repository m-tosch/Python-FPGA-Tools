# regex fun

[![](https://github.com/m-tosch/regex_fun/workflows/ci-build/badge.svg)](https://github.com/m-tosch/regex_fun/actions?query=workflow%3Aci-build)
[![](https://github.com/m-tosch/regex_fun/workflows/docs/badge.svg)](https://m-tosch.github.io/regex_fun/)


## Usage

TODO

## Documentation

The documentation can be found [here](https://m-tosch.github.io/regex_fun/) (for more information see the /docs folder)

To generate the documentation locally, sphinx must be installed. Inside the /docs folder, run

```cmd
<build-script> html
```

with `<build-script>` being either make.bat or Makefile depending on your system.


## Tests

If you have [pytest](https://pypi.org/project/pytest/) installed, you can run all tests from the command line:

```cmd
pytest
```

If you want to run a specific test file, e.g. `test_vhdl.py`:

```cmd
pytest ./tests/vhdl/test_vhdl.py
```
