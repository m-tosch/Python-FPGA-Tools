# regex fun

[![](https://github.com/m-tosch/regex_fun/workflows/ci-build/badge.svg)](https://github.com/m-tosch/regex_fun/actions?query=workflow%3Aci-build)
[![](https://github.com/m-tosch/regex_fun/workflows/docs/badge.svg)](https://m-tosch.github.io/regex_fun/)
[![codecov](https://codecov.io/gh/m-tosch/regex_fun/branch/master/graph/badge.svg)](https://codecov.io/gh/m-tosch/regex_fun)

## Usage

TODO

## Documentation

The documentation can be found [here](https://m-tosch.github.io/regex_fun/)

see the /docs folder for more information

## Tests

If you have [pytest](https://pypi.org/project/pytest/) installed, you can run all tests from the command line:

```cmd
pytest
```

If you want to run a specific test file, e.g. `test_vhdl.py`:

```cmd
pytest ./tests/vhdl/test_vhdl.py
```

## Coverage

The coverage report can be found [here](https://codecov.io/gh/m-tosch/regex_fun)

If you have [pytest](https://pypi.org/project/pytest/) and [coverage](https://pypi.org/project/coverage/) installed, you can generate a coverage report from the command line:

```cmd
coverage run -m pytest
```

To generate an html report run

```cmd
coverage html
```

view the report by opening the index.html file inside the generated /htmlcov folder in a browser.

To generate other report forms, see the [cmd line usage](https://coverage.readthedocs.io/en/coverage-5.1/cmd.html) for the `coverage` package
