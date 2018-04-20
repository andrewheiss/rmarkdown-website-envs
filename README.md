# R Markdown websites and bleeding environments

While **bookdown** and **blogdown** knit collections of `.Rmd` files in their own standalone environments, [R Markdown websites](https://rmarkdown.rstudio.com/rmarkdown_websites.html) ([by design](https://github.com/rstudio/rmarkdown/issues/1326#issuecomment-382957907)) do not. Instead, each `.Rmd` shares a global environment, which causes a few side effects with namespaces and variables bleeding into each other.

This mini project shows what happens and offers some solutions.

## Getting started

Download or clone this repository and open `rmarkdown-website-envs.Rproj` in RStudio. Press `⌘⇧B` to build the site (`ctrl + shift +  B` on Windows). 

## Main issues

### Variable bleeding

In `01_something.Rmd`, I define `x <- 14` but never use it. In `02_something-else.Rmd`, I reference `x` and it works, but only when building the site. When running `02_something-else.Rmd` interactively or when knitting it on its own, `x` doesn't exist.

### Namespace bleeding

In `01_something.Rmd` I load **here** and use `here()` in a file path to write a CSV to disk (since this is [the recommended way to deal with relative paths in RStudio projects](https://www.tidyverse.org/articles/2017/12/workflow-vs-script/#use-projects-and-the-here-package)). In `02_something-else.Rmd`, I load **lubridate**, which has its own (now-deprecated) `here()` and which conflicts with `here::here()`. When running `02_something-else.Rmd` interactively or knitting it on its own, everything works because **lubridate** is loaded before **here**, so `here::here()` takes precedence. 

When building the whole site, though, each `.Rmd` file shares the same environment: because `02_something-else.Rmd` is knitted after `01_something.Rmd`, it uses all the packages already loaded from `01_something.Rmd`. This breaks things. For example, in `02_something-else.Rmd`, `lubridate::here()`  takes precedence over `here::here()` because **lubridate** in #2 is loaded after **here** is loaded in #1. Instead of building the correct file path, R builds a path using the current date (since that's what `lubridate::here()` is for):

    Error: '2018-04-20 11:54:32/data/cars.csv' does not exist in current working directory


## Solutions

- **Don't use R Markdown websites and use blogdown instead**: Sure, **blogdown** is great and I use the heck out of it for other things, but it's generally overkill for smaller project-specific sites. Plus, R Markdown websites exist for a reason—they're easy to use and set up. 

- **Live with it**: I've been building project-specific sites with R Markdown for a couple years and just barely ran into this issue, so this is definitely an edge case. Write your code as if each `.Rmd` file stands alone (i.e. pass R objects between files with `saveRDS()` and `readRDS()`, etc.) and everything should normally be fine.

- **Use package namespace prefixes**: If you're only using a couple functions from a package that causes namespace conflicts with another package (like, if you only need `ymd()` from **lubridate**), don't load the offending package and just use a prefix (e.g. `lubridate::ymd()`). This doesn't scale, though, if you're using lots of functions from the conflicting package, in which case…

- **Unload all the packages at the top of the `.Rmd` that's causing conflicts**: This is the nuclear option and goes against the philosophy of having standalone R Markdown files, but ¯\\\_(ツ)\_/¯. Use this incantation to unload any packages that are already loaded, then load the libraries you need:

        if (isTRUE(getOption('knitr.in.progress')) & !is.null(names(sessionInfo()$otherPkgs))) {
          invisible(suppressWarnings(sapply(paste0("package:", names(sessionInfo()$otherPkgs)),
                                            detach, character.only = TRUE, unload = TRUE)))
        }

- **Use an alternative system**: The [**workflowr**](https://jdblischak.github.io/workflowr/) package is designed to run each `.Rmd` in a separate environment, but it's also more complicated than building with **rmarkdown**. It uses its own system to build, commit to git, and publish sites and relies on its own folder structure.

- **Build a custom R Markdown site generator**: This is theoretically the best solution, but also the hardest (and I don't have time to figure it out). R Markdown can use a [custom site generator](https://rmarkdown.rstudio.com/rmarkdown_site_generators.html) when building the site (this is how `bookdown::bookdown_site()` works), and according to @yihui, it should be possible to use a new generator to render each `.Rmd` in a new session with `Rscript` or something similar. I've spent a couple hours messing with this, but it's hard and complicated and I gave up :). Even **workflowr** seems to not go this route, since it has its own `wflow_build()` function that knits its `.Rmd`s separately from `rmarkdown::render_site()`. 

My current solution is to just live with this and pretend that each `.Rmd` file does get its own new environment (since that's worked so well for me for so long). When I *do* run into problems ([like this](https://github.com/andrewheiss/ngo-crackdowns-philanthropy-pilot/blob/master/03_additional-analysis.Rmd)), I unload all the existing packages at the beginning of the `.Rmd` causing problems.

![](https://media.giphy.com/media/rdX5kzQ6Sbpwk/giphy.gif)
