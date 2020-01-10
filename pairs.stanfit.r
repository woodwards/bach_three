# This file is part of RStan
# Copyright (C) 2012, 2013, 2014, 2015, 2016, 2017 Trustees of Columbia University
# Copyright (C) 1995-2012 The R Core Team
# Some parts  Copyright (C) 1999 Dr. Jens Oehlschlaegel-Akiyoshi
#
# RStan is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# RStan is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

pairs.stanfit <-
  function(x, labels = NULL, panel = NULL, ...,
           lower.panel = NULL, upper.panel = NULL, diag.panel = NULL,
           text.panel = NULL, label.pos = 0.5 + 1 / 3,
           cex.labels = NULL, font.labels = 1,
           row1attop = TRUE, gap = 1, log = "",
           pars = NULL, condition = "accept_stat__", include = TRUE) {
    gsp <- get_sampler_params(x, inc_warmup = FALSE)
    if (is.null(pars)) {
      pars <- dimnames(x)[[3]]
      arr <- round(rstan::extract(x, pars = pars, permuted = FALSE), digits = 12)
      if ("energy__" %in% colnames(gsp[[1]])) {
        dims <- dim(arr)
        dims[3] <- dims[3] + 1L
        nms <- dimnames(arr)
        nms$parameters <- c(nms$parameters, "energy__")
        E <- sapply(gsp, FUN = function(y) y[, "energy__"])
        arr <- array(c(c(arr), c(E)), dim = dims, dimnames = nms)
      }
    }
    else if (!include) {
      incl_energy <- !any(pars == "energy__")
      pars <- setdiff(x@sim$pars_oi, pars)
      arr <- round(rstan::extract(x, pars = pars, permuted = FALSE), digits = 12)
      if (incl_energy && "energy__" %in% colnames(gsp[[1]])) {
        dims <- dim(arr)
        dims[3] <- dims[3] + 1L
        nms <- dimnames(arr)
        nms$parameters <- c(nms$parameters, "energy__")
        E <- sapply(gsp, FUN = function(y) y[, "energy__"])
        arr <- array(c(c(arr), c(E)), dim = dims, dimnames = nms)
      }
    }
    else {
      arr <- round(rstan::extract(x, pars = pars, permuted = FALSE), digits = 12)
    }
    sims <- nrow(arr)
    chains <- ncol(arr)
    varying <- apply(arr, 3, FUN = function(y) length(unique(c(y))) > 1)
    if (any(!varying)) {
      message(
        "the following parameters were dropped because they are constant\n",
        paste(names(varying)[!varying], collapse = " ")
      )
      arr <- arr[, , varying, drop = FALSE]
    }
    dupes <- duplicated(arr, MARGIN = 3)
    if (any(dupes)) {
      message(
        "the following parameters were dropped because they are duplicative\n",
        paste(dimnames(arr)[[3]][dupes], collapse = " ")
      )
      arr <- arr[, , !dupes, drop = FALSE]
    }
    divergent__ <- matrix(c(sapply(gsp, FUN = function(y) y[, "divergent__"])),
      nrow = sims * chains, ncol = dim(arr)[3]
    )
    max_td <- x@stan_args[[1]]$control
    if (is.null(max_td)) {
      max_td <- 10
    } else {
      max_td <- max_td$max_treedepth
      if (is.null(max_td)) max_td <- 10
    }
    hit <- matrix(c(sapply(gsp, FUN = function(y) y[, "treedepth__"] >= max_td)),
      nrow = sims * chains, ncol = dim(arr)[3]
    )

    if (is.list(condition)) {
      if (length(condition) != 2) stop("if a list, 'condition' must be of length 2")
      arr <- arr[, c(condition[[1]], condition[[2]]), , drop = FALSE]
      k <- length(condition[[1]])
      mark <- c(rep(TRUE, sims * k), rep(FALSE, sims * length(condition[[2]])))
    }
    else if (is.logical(condition)) {
      stopifnot(length(condition) == (sims * chains))
      mark <- !condition
    }
    else if (is.character(condition)) {
      condition <- match.arg(condition,
        several.ok = FALSE,
        choices = c(
          "accept_stat__", "stepsize__", "treedepth__",
          "n_leapfrog__", "divergent__", "energy__",
          "lp__"
        )
      )
      if (condition == "lp__") {
        mark <- simplify2array(get_logposterior(x, inc_warmup = FALSE))
      } else {
        mark <- sapply(gsp, FUN = function(y) y[, condition])
      }

      if (condition == "divergent__") {
        mark <- as.logical(mark)
      } else {
        mark <- c(mark) >= median(mark)
      }
      if (length(unique(mark)) == 1) {
        stop(paste(condition, "is constant so it cannot be used as a condition"))
      }
    }
    else if (!is.null(condition)) {
      if (all(condition == as.integer(condition))) {
        arr <- arr[, condition, , drop = FALSE]
        k <- ncol(arr) %/% 2
        mark <- c(rep(FALSE, sims * k), rep(TRUE, sims * (chains - k)))
      }
      else if (condition > 0 && condition < 1) {
        mark <- rep(1:sims > (condition * sims), times = chains)
      }
      else {
        stop("'condition' must be an integer (vector) or a number between 0 and 1 exclusive")
      }
    }
    else {
      k <- ncol(arr) %/% 2
      mark <- c(rep(FALSE, sims * k), rep(TRUE, sims * (chains - k)))
    }

    x <- apply(arr, MARGIN = "parameters", FUN = function(y) y)
    nc <- ncol(x)

    if (isTRUE(log)) {
      xl <- apply(x >= 0, 2, FUN = all)
      if ("lp__" %in% names(xl)) xl["lp__"] <- FALSE
    }
    else if (is.numeric(log)) {
      xl <- log
    } else {
      xl <- grepl("x", log)
    }

    if (is.numeric(xl) || any(xl)) {
      x[, xl] <- log(x[, xl])
      colnames(x)[xl] <- paste("log", colnames(x)[xl], sep = "-")
    }
    if (is.null(lower.panel)) {
      if (!is.null(panel)) {
        lower.panel <- panel
      } else {
        lower.panel <- function(x, y, ...) {
          dots <- list(...)
          dots$x <- x[!mark]
          dots$y <- y[!mark]
          if (is.null(mc$nrpoints) && !identical(condition, "divergent__")) {
            dots$nrpoints <- Inf
            dots$col <- ifelse(divergent__[!mark] == 1, "red",
              ifelse(hit[!mark] == 1, "yellow", NA_character_)
            )
          }
          dots$add <- TRUE
          do.call(smoothScatter, args = dots)
        }
      }
    }
    if (is.null(upper.panel)) {
      if (!is.null(panel)) {
        upper.panel <- panel
      } else {
        upper.panel <- function(x, y, ...) {
          dots <- list(...)
          dots$x <- x[mark]
          dots$y <- y[mark]
          if (is.null(mc$nrpoints) && !identical(condition, "divergent__")) {
            dots$nrpoints <- Inf
            dots$col <- ifelse(divergent__[mark] == 1, "red",
              ifelse(hit[mark] == 1, "yellow", NA_character_)
            )
          }
          dots$add <- TRUE
          do.call(smoothScatter, args = dots)
        }
      }
    }
    if (is.null(diag.panel)) {
      diag.panel <- function(x, ...) {
        usr <- par("usr")
        on.exit(par(usr))
        par(usr = c(usr[1:2], 0, 1.5))
        h <- hist(x, plot = FALSE)
        breaks <- h$breaks
        y <- h$counts
        y <- y / max(y)
        nB <- length(breaks)
        rect(breaks[-nB], 0, breaks[-1], y, col = "cyan", ...)
      }
    }
    if (is.null(panel)) panel <- points

    if (is.null(text.panel)) {
      textPanel <- function(x = 0.5, y = 0.5, txt, cex, font) {
        text(x, y, txt, cex = cex, font = font)
      }
    } else {
      textPanel <- text.panel
    }
    if (is.null(labels)) labels <- colnames(x)

    mc <- match.call(expand.dots = TRUE)
    mc[1] <- call("pairs")
    mc$x <- x
    mc$labels <- labels
    mc$panel <- panel
    mc$lower.panel <- lower.panel
    mc$upper.panel <- upper.panel
    mc$diag.panel <- diag.panel
    mc$text.panel <- textPanel
    mc$log <- ""
    mc$condition <- NULL
    mc$pars <- NULL
    mc$include <- NULL
    eval(mc)
  }
