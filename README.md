# stanmodularise

Partial alternative to [rstantools](https://github.com/stan-dev/rstantools/) `rstan_package_skeleton`. Instead of converting stan files to C++ files in the build process, the package developer does so manually by calling `modularise_stan_files` in this package. This avoids a lot of compilation time.

This package is not complete, I haven't tested it much, etc, etc.

How to create a package using this:

1. Create the package with [`usethis::create_package`](https://github.com/r-lib/usethis)
1. Add [Rcpp](https://github.com/RcppCore/Rcpp) to the package (e.g., via `usethis::use_rcpp`)
1. Add `StanHeaders` , `rstan` , `BH` , `Rcpp` to the `LinkingTo` section of `DESCRIPTION`
1. Add
    ```
    STANHEADERS_SRC = \
        `"$(R_HOME)/bin$(R_ARCH_BIN)/Rscript" \
            --vanilla \
            -e "cat(system.file('include', 'src', package = 'StanHeaders'))"`
    PKG_CPPFLAGS = \
        -I"../inst/include" \
        -I"$(STANHEADERS_SRC)" \
        -DBOOST_RESULT_OF_USE_TR1 \
        -DBOOST_NO_DECLTYPE \
        -DBOOST_DISABLE_ASSERTS \
        -DEIGEN_NO_DEBUG \
        -DBOOST_MATH_OVERFLOW_ERROR_POLICY=errno_on_error
    ```
      to `src/Makevars` and
    ```
    STANHEADERS_SRC = `"$(R_HOME)/bin$(R_ARCH_BIN)/Rscript" --vanilla -e "cat(system.file('include', 'src', package = 'StanHeaders'))"`
    BOOST_NOT_IN_BH_SRC = `"$(R_HOME)/bin$(R_ARCH_BIN)/Rscript" --vanilla -e "cat(system.file('include', 'boost_not_in_BH', package = 'rstan'))"`
    PKG_CPPFLAGS = -I"../inst/include" -I"$(STANHEADERS_SRC)" -I"$(BOOST_NOT_IN_BH_SRC)" -DBOOST_RESULT_OF_USE_TR1 -DBOOST_NO_DECLTYPE -DBOOST_DISABLE_ASSERTS -DEIGEN_NO_DEBUG -DBOOST_NO_CXX11_RVALUE_REFERENCES
    ```
      to `src/Makevars.win`.
1. Create a `stan_files` directory in `src` and add your stan files
1. Run `modularise_stan_files` from this package
1. Run `devtools::document` to build the package

If all goes well, just as with `rstantools`, you should have a `.stan_models` variable available in your package.
