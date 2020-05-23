# Documentation

The documentation is build with [sphinx](https://www.sphinx-doc.org/en/master/). It can be accessed [here](https://m-tosch.github.io/regex_fun/)

## set-up

The documentation is separated from the master and uploaded to the [gh-pages](https://github.com/m-tosch/regex_fun/tree/gh-pages) branch by an automatic [workflow](https://github.com/m-tosch/regex_fun/actions?query=workflow%3Adocs)

## local build

To generate the documentation locally, sphinx must be installed.

Inside the /docs folder, run

```cmd
<build-script> html
```

with `<build-script>` being either the make.bat or Makefile depending on your system.

This will create a /html folder in which you find an index.html file to view the documentation in a browser