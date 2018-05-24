#' Custom site generator to safely build R Markdown website
#'
#' The site generator \code{safesite} modifies the render function produced by
#' the site generator \code{rmarkdown:::default_site} (see
#' \code{\link[rmarkdown]{render_site}}) to run \code{\link[rmarkdown]{render}}
#' in a separate R process using the R package \link{callr}.
#'
#' To use this alternative site generator, add the following line to the YAML
#' header of \code{index.Rmd}:
#'
#' \preformatted{site: safesite::safesite}
#'
#' @import rmarkdown
#' @export
safesite <- function(input, encoding = getOption("encoding"), ...) {

  generator <- rmarkdown:::default_site(input, encoding = getOption("encoding"), ...)
  
  # get the site config
  config <- site_config(input, encoding)
  if (is.null(config))
    stop("No site configuration (_site.yml) file found.")
  
  # helper function to get all input files. includes all .Rmd and
  # .md files that don't start with "_" (note that we don't do this
  # recursively because rmarkdown in general handles applying common
  # options/elements across subdirectories poorly)
  input_files <- function() {
    list.files(input, pattern = "^[^_].*\\.[Rr]?md$")
  }
  
  # Overwrite render function to use callr
  generator$render <- function(input_file,
                               output_format,
                               envir,
                               quiet,
                               encoding, ...) {
    
    # track outputs
    outputs <- c()

    # see if this is an incremental render
    incremental <- !is.null(input_file)

    # files list is either a single file (for incremental) or all
    # file within the input directory
    if (incremental)
      files <- input_file
    else {
      files <- file.path(input, input_files())
    }
    sapply(files, function(x) {
      # we suppress messages so that "Output created" isn't emitted
      # (which could result in RStudio previewing the wrong file)
      output <- suppressMessages(
        callr::r_safe(
          function(...) rmarkdown::render(...),
          args = list(input = x,
                      output_format = output_format,
                      output_options = list(lib_dir = "site_libs",
                                            self_contained = FALSE),
                      envir = envir,
                      quiet = quiet,
                      encoding = encoding)
        )
      )

      # add to global list of outputs
      outputs <<- c(outputs, output)

      # check for files dir and add that as well
      sidecar_files_dir <- rmarkdown:::knitr_files_dir(output)
      files_dir_info <- file.info(sidecar_files_dir)
      if (isTRUE(files_dir_info$isdir))
        outputs <<- c(outputs, sidecar_files_dir)
    })

    # do we have a relative output directory? if so then remove,
    # recreate, and copy outputs to it (we don't however remove
    # it for incremental builds)
    if (config$output_dir != '.') {

      # remove and recreate output dir if necessary
      output_dir <- file.path(input, config$output_dir)
      if (file.exists(output_dir)) {
        if (!incremental) {
          unlink(output_dir, recursive = TRUE)
          dir.create(output_dir)
        }
      } else {
        dir.create(output_dir)
      }

      # move outputs
      for (output in outputs) {

        # don't move it if it's a _files dir that has a _cache dir
        if (grepl("^.*_files$", output)) {
          cache_dir <- gsub("_files$", "_cache", output)
          if (rmarkdown:::dir_exists(cache_dir))
            next;
        }

        output_dest <- file.path(output_dir, basename(output))
        if (rmarkdown:::dir_exists(output_dest))
          unlink(output_dest, recursive = TRUE)
        file.rename(output, output_dest)
      }

      # copy lib dir a directory at a time (allows it to work with incremental)
      lib_dir <- file.path(input, "site_libs")
      output_lib_dir <- file.path(output_dir, "site_libs")
      if (!file.exists(output_lib_dir))
        dir.create(output_lib_dir)
      libs <- list.files(lib_dir)
      for (lib in libs)
        file.copy(file.path(lib_dir, lib), output_lib_dir, recursive = TRUE)
      unlink(lib_dir, recursive = TRUE)

      # copy other files
      rmarkdown:::copy_site_resources(input, encoding)
    }

    # Print output created for rstudio preview
    if (!quiet) {
      # determine output file
      output_file <- ifelse(is.null(input_file),
                            "index.html",
                            rmarkdown:::file_with_ext(basename(input_file), "html"))
      if (config$output_dir != ".")
        output_file <- file.path(config$output_dir, output_file)
      message("\nOutput created: ", output_file)
    }
  }

  generator
}
