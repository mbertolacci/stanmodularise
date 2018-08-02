.read_file_to_string <- function(file) {
  paste0(readLines(file, warn = FALSE), collapse = '\n')
}

.make_stan_cc <- function(file, stan_files_path) {
  file <- sub('\\.cc$', '.stan', file)
  cppcode <- rstan::stanc(
    file, allow_undefined = TRUE,
    obfuscate_model_name = FALSE
  )$cppcode

  hpp_code <- paste(
    '#ifndef MODELS_HPP', '#define MODELS_HPP', '#define STAN__SERVICES__COMMAND_HPP',
    '#include <rstan/rstaninc.hpp>',
    cppcode,
    '#endif',
    sep = '\n',
    collapse = '\n'
  )

  hpp_file <- sub('\\.stan$', '.hpp', file)

  if (!file.exists(hpp_file) || hpp_code != .read_file_to_string(hpp_file)) {
    cat(hpp_code, file = sub('\\.stan$', '.hpp', file), append = FALSE)
  }

  f <- sub('\\.stan$', '', basename(file))
  model_name <- gsub('-', '_', f)
  module_name <- paste0('stan_fit4', model_name, '_mod')

  temp_cpp_file_name <- sprintf(
    '%s_%s.cpp',
    f,
    paste0(sample(letters, 8), collapse = '')
  )
  suppressMessages(Rcpp::exposeClass(
    class = paste0('model_', model_name),
    constructors = list(c('SEXP', 'SEXP', 'SEXP')),
    fields = character(),
    methods = c(
      'call_sampler',
      'param_names', 'param_names_oi', 'param_fnames_oi',
      'param_dims',  'param_dims_oi', 'update_param_oi', 'param_oi_tidx',
      'grad_log_prob', 'log_prob',
      'unconstrain_pars', 'constrain_pars', 'num_pars_unconstrained',
      'unconstrained_param_names', 'constrained_param_names'
    ),
    file = temp_cpp_file_name,
    header = sprintf(
      paste0(
        '#include "stan_files/%s.hpp"\n',
        'typedef rstan::stan_fit<stan_model, boost::random::ecuyer1988> stan_model_fit;'
      ),
      f
    ),
    module = module_name,
    CppClass = 'stan_model_fit',
    Rfile = FALSE
  ))

  # Need to do this here because exposeClass adds src/ itself
  temp_cpp_file_path <- file.path('src', temp_cpp_file_name)
  cpp_file_path <- file.path('src', paste0(f, '.cpp'))
  if (
    !file.exists(cpp_file_path) ||
    (.read_file_to_string(cpp_file_path) != .read_file_to_string(temp_cpp_file_path))
  ) {
    file.rename(temp_cpp_file_path, cpp_file_path)
  } else {
    file.remove(temp_cpp_file_path)
  }

  list(
    name = model_name,
    stan_file = file,
    module_name = module_name
  )
}

#' Convert stan files to C++ modules in a package
#'
#' Converts stan files to C++ modules in a package.
#' @param pkg The directory containing the package.
#' @export
modularise_stan_files <- function(pkg = '.') {
  withr::with_dir(pkg, {
    stan_files_path <- file.path('src', 'stan_files')
    stopifnot(file.exists(stan_files_path))

    .stan_modules <- lapply(
      dir(stan_files_path, pattern = 'stan$', full.names = TRUE),
      .make_stan_cc,
      stan_files_path
    )
    names(.stan_modules) <- sapply(.stan_modules, getElement, 'name')

    stan_models_R <- file.path('R', 'StanModels.R')
    cat('# Automatically generated\n', file = stan_models_R, append = FALSE)
    for (module in .stan_modules) {
      cat(sprintf(
        'loadModule(\'%s\', TRUE)\n',
        module$module_name
      ), file = stan_models_R, append = TRUE)
    }

    dump('.stan_modules', file = stan_models_R, append = TRUE)
    cat(paste(
      '.stan_models <- lapply(.stan_modules, function(input) {',
      '  stanfit <- rstan::stanc(',
      '   input$stan_file,',
      '   allow_undefined = TRUE,',
      '   obfuscate_model_name = FALSE',
      '  )',
      '  stanfit$model_cpp <- list(',
      '   model_cppname = stanfit$model_name,',
      '   model_cppcode = stanfit$cppcode',
      '  )',
      '  do.call(',
      '    methods::new,',
      '    args = c(',
      '      stanfit[-(1:3)],',
      '      Class = \'stanmodel\',',
      '      mk_cppmodule = function(x) get(paste0(\'model_\', input$name))',
      '    )',
      '  )',
      '})\n',
      sep = '\n'
    ), file = stan_models_R, append = TRUE)
  })
}
