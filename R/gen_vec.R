#' Vector Error Correction Model Input
#' 
#' \code{gen_vec} produces the input for the estimation of a vector error correction (VEC) model.
#' 
#' @param data a time-series object of endogenous variables.
#' @param p an integer of the lag order of the series (levels) in the VAR.
#' @param exogen an optional time-series object of external regressors.
#' @param s an optional integer of the lag order of the exogenous variables of the series
#' (levels) in the VAR.
#' @param const a character specifying whether a constant term enters the error correction
#' term (\code{"restricted"}) or the non-cointegration term as an \code{"unrestricted"} variable.
#' If \code{NULL} (default) no constant term will be added.
#' @param trend a character specifying whether a trend term enters the error correction
#' term (\code{"restricted"}) or the non-cointegration term as an \code{"unrestricted"} variable.
#' If \code{NULL} (default) no constant term will be added.
#' @param seasonal a character specifying whether seasonal dummies should be included in the error
#' correction term (\code{"restricted"}) or in the non-cointegreation term as \code{"unrestricted"}
#' variables. If \code{NULL} (default) no seasonal terms will be added. The amount of dummy variables depends
#' on the frequency of the time-series object provided in \code{data}.
#' 
#' @details The function produces the variable matrices of a vector error correction (VEC)
#' model, which can also include exogenous variables:
#' \deqn{\Delta y_t = \Pi w_t + \sum_{i=1}^{p-1} \Gamma_i \Delta y_{t - i} + 
#' \sum_{i=0}^{s-1} \Upsilon_i \Delta x_{t - i} +
#' C^{UR} d^{UR}_t + u_t,}
#' where
#' \eqn{\Delta y_t} is a \eqn{K \times 1} vector of differenced endogenous variables,
#' \eqn{w_t} is a \eqn{(K + M + N^{R}) \times 1} vector of cointegration variables,
#' \eqn{\Pi} is a \eqn{K \times (K + M + N^{R})} matrix of cointegration parameters,
#' \eqn{\Gamma_i} is a \eqn{K \times K} coefficient matrix of endogenous variables,
#' \eqn{\Delta x_t} is a \eqn{M \times 1} vector of differenced exogenous regressors,
#' \eqn{\Upsilon_i} is a \eqn{K \times M} coefficient matrix of exogenous regressors,
#' \eqn{d^{UR}_t} is a \eqn{N \times 1} vector of deterministic terms, and
#' \eqn{C^{UR}} is a \eqn{K \times N^{UR}} coefficient matrix of deterministic terms
#' that do not enter the cointegration term.
#' \eqn{p} is the lag order of endogenous variables and \eqn{s} is the lag
#' order of exogenous variables of the corresponding VAR model.
#' \eqn{u_t} is a \eqn{K \times 1} error term.
#' 
#' In matrix notation the above model can be re-written as
#' \deqn{Y = \Pi W + \Gamma X + U,}
#' where
#' \eqn{Y} is a \eqn{K \times T} matrix of differenced endogenous variables,
#' \eqn{W} is a \eqn{(K + M + N^{R}) \times T} matrix of variables in the cointegration term,
#' \eqn{X} is a \eqn{(K(p - 1) + Ms + N^{UR}) \times T} matrix of differenced regressor variables
#' and unrestricted deterministic terms. \eqn{U} is a \eqn{K \times T} matrix of errors.
#' 
#' @return A list containing the following elements:
#' \item{Y}{a matrix of differenced dependent variables.}
#' \item{W}{a matrix of variables in the cointegration term.}
#' \item{X}{a matrix of non-cointegration regressors.}
#' 
#' @examples 
#' data("e6")
#' data <- gen_vec(e6, p = 4, const = "unrestricted", season = "unrestricted")
#' 
#' @references
#' 
#' Lütkepohl, H. (2007). \emph{New introduction to multiple time series analysis} (2nd ed.). Berlin: Springer.
#' 
#' @export
gen_vec <- function(data, p = 2, exogen = NULL, s = 2, const = NULL, trend = NULL, seasonal = NULL) {
  if (!is.null(const)) {
    if (!const %in% c("restricted", "unrestricted")) {
      stop("Specified value for argument 'const' is not valid.")
    }
  }
  if (!is.null(trend)) {
    if (!trend %in% c("restricted", "unrestricted")) {
      stop("Specified value for argument 'trend' is not valid.")
    }
  }
  if (!is.null(seasonal)) {
    if (!seasonal %in% c("restricted", "unrestricted")) {
      stop("Specified value for argument 'seasonal' is not valid.")
    }
  }
  if (!"ts" %in% class(data)) {
    stop("Argument 'data' must be an object of class 'ts'.")
  }
  if (p < 1) {
    stop("Argument 'p' must be at least 1.")
  }
  if (is.null(dimnames(data))) {
    tsp_temp <- stats::tsp(data)
    data <- stats::ts(as.matrix(data), class = c("mts", "ts", "matrix"))
    stats::tsp(data) <- tsp_temp
    dimnames(data)[[2]] <- "y"
  }
  data_name <- dimnames(data)[[2]]
  k <- NCOL(data)
  
  model <- NULL
  model$endogenous <- list("variables" = dimnames(data)[[2]],
                           "lags" = 1)
  model$type <- "VEC"
  
  diff_y <- diff(data)
  temp_name <- paste("d.", data_name, sep = "")
  temp <- diff_y
  
  temp <- cbind(temp, stats::lag(data, -1))
  temp_name <- c(temp_name, paste("l.", data_name, sep = ""))
  n_ect <- k
  
  if (!is.null(exogen)) {
    if (!"ts" %in% class(exogen)) {
      stop("Argument 'exogen' must be an object of class 'ts'.")
    }
    if (is.null(dimnames(exogen))) {
      tsp_temp <- stats::tsp(exogen)
      exogen <- stats::ts(as.matrix(exogen), class = c("mts", "ts", "matrix"))
      stats::tsp(exogen) <- tsp_temp
      dimnames(exogen)[[2]] <- "x"
    }
    exog_name <- dimnames(exogen)[[2]]
    temp <- cbind(temp, stats::lag(exogen, -1))
    temp_name <- c(temp_name, paste("l.", exog_name, sep = ""))
    n_ect <- n_ect + NCOL(exogen)
  }
  
  # Lags of differenced endogenous variables
  if (p > 1) {
    for (i in 1:(p - 1)) {
      temp <- cbind(temp, stats::lag(diff_y, -i))
      temp_name <- c(temp_name, paste("d", data_name, i, sep = "."))
    }
    model$endogenous$lags <- p
  }
  
  # Lags of exogenous variables
  if (!is.null(exogen)) {
    diff_exog <- diff(exogen)
    temp <- cbind(temp, diff_exog)
    temp_name <- c(temp_name, paste("d", exog_name, 0, sep = "."))
    if (s >= 2) {
      for (i in 1:(s - 1)) {
        temp <- cbind(temp, stats::lag(diff_exog, -i))
        temp_name <- c(temp_name, paste("d", exog_name, i, sep = "."))
      } 
    }
    model$exogen <- list("variables" = dimnames(exogen)[[2]],
                         "lags" = s)
  }
  
  temp <- stats::na.omit(temp)
  t <- nrow(temp)
  ts_info <- stats::tsp(temp)
  
  y <- matrix(temp[, 1:k], t)
  y_names <- temp_name[1:k]
  ect <- matrix(temp[, k + 1:n_ect], t)
  ect_names <- temp_name[k + 1:n_ect]
  x <- matrix(temp[, -(1:(k + n_ect))], t)
  x_names <- temp_name[-(1:(k + n_ect))]
  
  det_name_r <- NULL
  det_name_ur <- NULL
  
  if (!is.null(const)) {
    if (const == "restricted") {
      ect <- cbind(ect, 1)
      ect_names <- c(ect_names, "const") 
      det_name_r <- c(det_name_r, "const") 
      n_ect <- n_ect + 1
    }
    
    if (const == "unrestricted") {
      x <- cbind(x, 1)
      x_names <- c(x_names, "const")
      det_name_ur <- c(det_name_ur, "const") 
    }
  }
  
  if (!is.null(trend)) {
    if (trend == "restricted") {
      ect <- cbind(ect, 1:t)
      ect_names <- c(ect_names, "trend")
      det_name_r <- c(det_name_r, "trend") 
      n_ect <- n_ect + 1
    }
    
    if (trend == "unrestricted") {
      x <- cbind(x, 1:t)
      x_names <- c(x_names, "trend")
      det_name_ur <- c(det_name_ur, "trend") 
    }
  }
  
  if(!is.null(seasonal)) {
    freq <- stats::frequency(data)
    if (freq == 1) {
      warning("The frequency of the provided data is 1. No seasonal dummmies are generated.")
    } else {
      pos <- which(floor(stats::time(temp)) == stats::time(temp))[1]
      pos <- rep(1:freq, 2)[pos:(pos + (freq - 2))]
      seas <- NULL
      s_name <- NULL
      for (i in 1:(freq - 1)) {
        s_temp <- rep(0, freq)
        s_temp[pos[i]] <- 1
        seas <- cbind(seas, rep(s_temp, length.out = t))
        s_name <- c(s_name, paste("season.", i, sep = ""))
      }
    }
    
    if (seasonal == "restricted") {
      ect <- cbind(ect, seas)
      ect_names <- c(ect_names, s_name)
      det_name_r <- c(det_name_r, s_name)
      n_ect <- n_ect + freq - 1
    }
    
    if (seasonal == "unrestricted") {
      x <- cbind(x, seas)
      x_names <- c(x_names, s_name)
      det_name_ur <- c(det_name_ur, s_name) 
    }
  }
  
  if (length(det_name_r) > 0) {
    model$deterministic$restricted <- det_name_r
  }
  if (length(det_name_ur) > 0) {
    model$deterministic$unrestricted <- det_name_ur
  }
  
  temp <- cbind(y, ect, x)
  
  y <- matrix(t(temp[, 1:k]), k, dimnames = list(y_names, NULL))
  attr(y, "ts_info") <- ts_info
  
  ect <- matrix(t(temp[, k + 1:n_ect]), n_ect,
                dimnames = list(ect_names, NULL))
  
  if (length(x_names) > 0) {
    x <- matrix(t(temp[, -(1:(k + n_ect))]), length(x_names),
                dimnames = list(x_names, NULL)) 
  } else {
    x <- NULL
  }
  
  result <- list("Y" = y,
                 "W" = ect,
                 "X" = x,
                 "model" = model)
  
  class(result) <- append("bvarmodel", class(result))
  return(result)
}