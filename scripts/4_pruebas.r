# Script 4: Pruebas de evaluación fuera de muestra (OOS) y FEVD
# MF-BVAR Canónico vs. Benchmark U-MIDAS

library(readr)
library(dplyr)
library(lubridate)
library(mfbvar)
library(forecast)

set.seed(42)

df <- read_csv("BASES/df_MF-BVAR.csv", show_col_types = FALSE) %>%
  filter(as.Date(date) >= as.Date("2014-01-01"))

df$logPrecio_Petroleo <- log(df$Precio_Petroleo)
df$logISE             <- log(df$ISE)
df$logIPI             <- log(df$IPI)
df$logTRM             <- log(df$TRM)
df$logTD              <- log(df$TD)
df$logICM             <- log(df$ICM)
df$logPIB             <- log(df$PIB)

# Desestacionalización STL para manufactura y comercio minorista
stl_filter <- function(x) {
  s <- ts(na.omit(x), start = c(2014, 1), frequency = 12)
  d <- stl(s, s.window = "periodic")$time.series
  as.numeric(d[, "trend"] + d[, "remainder"])
}

df$logIPI[!is.na(df$logIPI)] <- stl_filter(df$logIPI)
df$logICM[!is.na(df$logICM)] <- stl_filter(df$logICM)

q_ends <- which(!is.na(df$PIB))
n_eval <- 8
oos_res <- vector("list", n_eval)

cat("Ejecutando backtesting fuera de muestra (P = 8 trimestres)...\n")

for (i in seq_len(n_eval)) {
  eval_idx <- q_ends[length(q_ends) - n_eval + i]
  cut_idx  <- q_ends[length(q_ends) - n_eval + i - 1]

  df_train <- df[1:cut_idx, ]
  df_test  <- df[(cut_idx + 1):eval_idx, ]

  target_date <- as.character(df$date[eval_idx])
  actual_pib  <- df$PIB[eval_idx]

  # Benchmark U-MIDAS: rezago autorregresivo + innovaciones mensuales de ISE e ICM
  df_train_midas <- df_train %>%
    mutate(
      dlogISE = c(0, diff(logISE)),
      dlogICM = c(0, diff(logICM)),
      year    = year(date),
      quarter = quarter(date)
    )

  df_q_midas <- df_train_midas %>%
    group_by(year, quarter) %>%
    summarise(
      logPIB  = first(na.omit(logPIB)),
      dISE_m1 = dlogISE[1], dISE_m2 = dlogISE[2], dISE_m3 = dlogISE[3],
      dICM_m1 = dlogICM[1], dICM_m2 = dlogICM[2], dICM_m3 = dlogICM[3],
      .groups = "drop"
    ) %>%
    mutate(
      dlogPIB      = c(NA, diff(logPIB)),
      dlogPIB_lag1 = lag(dlogPIB, 1)
    ) %>%
    filter(!is.na(dlogPIB) & !is.na(dlogPIB_lag1))

  mod_midas <- lm(dlogPIB ~ dlogPIB_lag1 + dISE_m1 + dISE_m2 + dISE_m3 + 
                            dICM_m1 + dICM_m2 + dICM_m3, data = df_q_midas)

  dISE_3m <- diff(log(c(df_train$ISE[nrow(df_train)], df_test$ISE)))
  dICM_3m <- diff(log(c(df_train$ICM[nrow(df_train)], df_test$ICM)))

  x_eval <- data.frame(
    dlogPIB_lag1 = tail(df_q_midas$dlogPIB, 1),
    dISE_m1 = dISE_3m[1], dISE_m2 = dISE_3m[2], dISE_m3 = dISE_3m[3],
    dICM_m1 = dICM_3m[1], dICM_m2 = dICM_3m[2], dICM_m3 = dICM_3m[3]
  )

  pred_midas <- exp(predict(mod_midas, newdata = x_eval) + log(df_train$PIB[nrow(df_train)]))

  # MF-BVAR con PIB no observado en el trimestre evaluado
  df_bvar_env <- rbind(df_train, df_test)
  df_bvar_env$PIB[(nrow(df_bvar_env) - 2):nrow(df_bvar_env)] <- NA

  pib_q <- c(df_bvar_env$PIB[!is.na(df_bvar_env$PIB)], NA)

  Y_eval <- list(
    logPrecio_Petroleo = ts(df_bvar_env$logPrecio_Petroleo, start = c(2014, 1), frequency = 12),
    logISE             = ts(df_bvar_env$logISE,             start = c(2014, 1), frequency = 12),
    logIPI             = ts(df_bvar_env$logIPI,             start = c(2014, 1), frequency = 12),
    logTRM             = ts(df_bvar_env$logTRM,             start = c(2014, 1), frequency = 12),
    Tasa_Intervencion  = ts(df_bvar_env$Tasa_Intervencion,  start = c(2014, 1), frequency = 12),
    ICC                = ts(df_bvar_env$ICC,                start = c(2014, 1), frequency = 12),
    Inflacion          = ts(df_bvar_env$Inflacion,          start = c(2014, 1), frequency = 12),
    logTD              = ts(df_bvar_env$logTD,              start = c(2014, 1), frequency = 12),
    logICM             = ts(df_bvar_env$logICM,             start = c(2014, 1), frequency = 12),
    logPIB             = ts(log(pib_q),                     start = c(2014, 1), frequency = 4)
  )

  prior_eval <- set_prior(
    Y = Y_eval,
    n_lags = 6,
    n_fcst = 0,
    n_burnin = 1000,
    n_reps = 1000,
    prior_Pi_AR1 = c(1, 1, 1, 1, 0, 0, 0, 0, 1, 1),
    lambda1 = 0.04,
    aggregation = "average"
  )

  invisible(capture.output(suppressMessages({
    mod_bvar <- estimate_mfbvar(prior_eval, prior = "minn")
  })))

  # Agregación trimestral consistente con aggregation = "average"
  t_end <- nrow(df_bvar_env)
  pib_latent_q <- (mod_bvar$Z[t_end, 10, ] + 
                   mod_bvar$Z[t_end - 1, 10, ] + 
                   mod_bvar$Z[t_end - 2, 10, ]) / 3
  pred_bvar <- exp(mean(pib_latent_q))

  oos_res[[i]] <- data.frame(
    Fecha = target_date,
    Obs   = actual_pib,
    BVAR  = pred_bvar,
    MIDAS = as.numeric(pred_midas)
  )
}

oos_df <- bind_rows(oos_res) %>%
  mutate(
    err_BVAR  = Obs - BVAR,
    err_MIDAS = Obs - MIDAS,
    mape_BVAR = abs(err_BVAR / Obs) * 100,
    mape_MIDAS= abs(err_MIDAS / Obs) * 100
  )

rmse_bvar  <- sqrt(mean(oos_df$err_BVAR^2))
rmse_midas <- sqrt(mean(oos_df$err_MIDAS^2))
mae_bvar   <- mean(abs(oos_df$err_BVAR))
mae_midas  <- mean(abs(oos_df$err_MIDAS))
mape_bvar  <- mean(oos_df$mape_BVAR)
mape_midas <- mean(oos_df$mape_MIDAS)

dm_quad <- dm.test(oos_df$err_BVAR, oos_df$err_MIDAS, alternative = "less", h = 1, power = 2)
dm_abs  <- dm.test(oos_df$err_BVAR, oos_df$err_MIDAS, alternative = "less", h = 1, power = 1)

cat("\n--- Evaluación Fuera de Muestra (8 Trimestres: 2024Q2 - 2026Q1) ---\n")
print(data.frame(
  Modelo     = c("MF-BVAR", "U-MIDAS"),
  MAE        = c(round(mae_bvar, 1), round(mae_midas, 1)),
  MAPE       = c(paste0(round(mape_bvar, 2), "%"), paste0(round(mape_midas, 2), "%")),
  RMSFE      = c(round(rmse_bvar, 1), round(rmse_midas, 1)),
  Ratio      = c(round(rmse_bvar / rmse_midas, 3), "1.000"),
  Reduccion  = c(paste0("-", round((1 - rmse_bvar / rmse_midas) * 100, 1), "%"), "Baseline")
), row.names = FALSE)

cat(sprintf("\nTest de Diebold & Mariano (1995):\n"))
cat(sprintf("  Pérdida cuadrática: DM = %.3f (p-value = %.4f)\n", dm_quad$statistic, dm_quad$p.value))
cat(sprintf("  Pérdida absoluta:   DM = %.3f (p-value = %.4f)\n", dm_abs$statistic, dm_abs$p.value))

# FEVD a 12 meses
cat("\nEstimando modelo completo para descomposición de varianza (FEVD a 12 meses)...\n")

Y_full <- list(
  logPrecio_Petroleo = ts(df$logPrecio_Petroleo, start = c(2014, 1), frequency = 12),
  logISE             = ts(df$logISE,             start = c(2014, 1), frequency = 12),
  logIPI             = ts(df$logIPI,             start = c(2014, 1), frequency = 12),
  logTRM             = ts(df$logTRM,             start = c(2014, 1), frequency = 12),
  Tasa_Intervencion  = ts(df$Tasa_Intervencion,  start = c(2014, 1), frequency = 12),
  ICC                = ts(df$ICC,                start = c(2014, 1), frequency = 12),
  Inflacion          = ts(df$Inflacion,          start = c(2014, 1), frequency = 12),
  logTD              = ts(df$logTD,              start = c(2014, 1), frequency = 12),
  logICM             = ts(df$logICM,             start = c(2014, 1), frequency = 12),
  logPIB             = ts(na.omit(df$logPIB),    start = c(2014, 1), frequency = 4)
)

prior_full <- set_prior(
  Y = Y_full,
  n_lags = 6,
  n_fcst = 0,
  n_reps = 2000,
  n_burnin = 1000,
  prior_Pi_AR1 = c(1, 1, 1, 1, 0, 0, 0, 0, 1, 1),
  lambda1 = 0.04,
  aggregation = "average"
)

mod_fevd <- estimate_mfbvar(prior_full, prior = "minn")

calc_fevd_chol <- function(Pi_draw, Sigma_draw, n_vars = 10, n_lags = 6, horizon = 12) {
  F_mat <- matrix(0, n_vars * n_lags, n_vars * n_lags)
  for (l in seq_len(n_lags)) {
    F_mat[1:n_vars, (l - 1) * n_vars + seq_len(n_vars)] <- Pi_draw[, 1 + (l - 1) * n_vars + seq_len(n_vars)]
  }
  if (n_lags > 1) {
    F_mat[(n_vars + 1):(n_vars * n_lags), 1:(n_vars * (n_lags - 1))] <- diag(n_vars * (n_lags - 1))
  }

  P <- t(chol(Sigma_draw))
  J <- matrix(0, n_vars, n_vars * n_lags)
  J[1:n_vars, 1:n_vars] <- diag(n_vars)

  mse_decomp <- array(0, dim = c(n_vars, n_vars, horizon))
  F_s <- diag(n_vars * n_lags)
  for (s in seq_len(horizon)) {
    Theta_s <- (J %*% F_s %*% t(J)) %*% P
    mse_decomp[, , s] <- Theta_s^2
    F_s <- F_s %*% F_mat
  }

  cum_mse <- apply(mse_decomp, c(1, 2), sum)
  cum_mse / rowSums(cum_mse) * 100
}

n_draws <- dim(mod_fevd$Pi)[3]
fevd_draws <- array(0, dim = c(10, 10, n_draws))
for (d in seq_len(n_draws)) {
  fevd_draws[, , d] <- calc_fevd_chol(mod_fevd$Pi[, , d], mod_fevd$Sigma[, , d], 10, 6, 12)
}

fevd_mean <- apply(fevd_draws, c(1, 2), mean)

labels_dict <- c(
  "logPrecio_Petroleo" = "Precio del Petróleo (Brent)",
  "logISE"             = "Índice de Seguimiento a la Economía (ISE)",
  "logIPI"             = "Índice de Producción Industrial (IPI)",
  "logTRM"             = "Tasa Representativa del Mercado (TRM)",
  "Tasa_Intervencion"  = "Tasa de Intervención (BanRep)",
  "ICC"                = "Índice de Confianza del Consumidor (ICC)",
  "Inflacion"          = "Inflación (IPC)",
  "logTD"              = "Tasa de Desempleo (TD)",
  "logICM"             = "Índice de Comercio al por Menor (ICM)",
  "logPIB"             = "Inercia Propia / Shock del PIB"
)

fevd_table <- data.frame(
  Variable   = labels_dict[mod_fevd$names_col],
  Aporte_Pct = round(fevd_mean[10, ], 2)
) %>%
  arrange(desc(Aporte_Pct)) %>%
  mutate(Aporte_Acum = round(cumsum(Aporte_Pct), 2))

cat("\n--- Descomposición de Varianza a 12 Meses (FEVD - PIB) ---\n")
print(fevd_table, row.names = FALSE)
