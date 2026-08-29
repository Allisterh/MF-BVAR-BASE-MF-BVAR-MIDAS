# ==============================================================================
# SCRIPT 3: EVALUACION FUERA DE MUESTRA (8-QUARTER EXPANDING WINDOW)
# ==============================================================================
library(readr)
library(dplyr)
library(lubridate)
library(mfbvar)
library(forecast)

set.seed(42)

df <- read_csv("BASES/df_MF-BVAR.csv", show_col_types = FALSE) %>% 
  filter(as.Date(date) >= as.Date("2014-01-01"))

df$logPIB <- log(df$PIB)
df$logISE <- log(df$ISE)
df$logICM <- log(df$ICM)

q_ends <- which(!is.na(df$PIB))
n_eval_quarters <- 8
resultados <- data.frame(Fecha = character(), Obs = numeric(), BVAR = numeric(), MIDAS = numeric())

cat("Iniciando backtesting...\n")

for (i in n_eval_quarters:1) {
  eval_idx <- q_ends[length(q_ends) - i + 1]
  cut_idx <- q_ends[length(q_ends) - i]
  
  df_train <- df[1:cut_idx, ]
  df_test <- df[(cut_idx + 1):eval_idx, ]
  
  target_date <- as.character(df$date[eval_idx])
  actual_pib <- df$PIB[eval_idx]
  
  cat(sprintf("\n==> Trimestre: %s | Obs: %.1f\n", target_date, actual_pib))
  
  # MIDAS
  df_train_midas <- df_train
  df_train_midas$dlogISE <- c(0, diff(df_train_midas$logISE))
  df_train_midas$dlogICM <- c(0, diff(df_train_midas$logICM))
  
  df_q_midas <- df_train_midas %>%
    mutate(year = year(date), quarter = quarter(date)) %>%
    group_by(year, quarter) %>%
    summarise(
      logPIB = first(na.omit(logPIB)),
      dISE_m1 = dlogISE[1], dISE_m2 = dlogISE[2], dISE_m3 = dlogISE[3],
      dICM_m1 = dlogICM[1], dICM_m2 = dlogICM[2], dICM_m3 = dlogICM[3],
      .groups = "drop"
    ) %>%
    mutate(
      dlogPIB = c(NA, diff(logPIB)),
      dlogPIB_lag1 = lag(dlogPIB, 1)
    ) %>%
    filter(!is.na(dlogPIB) & !is.na(dlogPIB_lag1))
  
  modelo_midas <- lm(dlogPIB ~ dlogPIB_lag1 + dISE_m1 + dISE_m2 + dISE_m3 + dICM_m1 + dICM_m2 + dICM_m3, data = df_q_midas)
  
  ts_ise <- ts(na.omit(df_train_midas$dlogISE), frequency=12)
  ts_icm <- ts(na.omit(df_train_midas$dlogICM), frequency=12)
  fit_ise <- auto.arima(ts_ise, max.p=3, max.q=0, stationary=TRUE)
  fit_icm <- auto.arima(ts_icm, max.p=3, max.q=0, stationary=TRUE)
  fcst_ise <- forecast(fit_ise, h=2)$mean
  fcst_icm <- forecast(fit_icm, h=2)$mean
  
  dISE_q <- c(log(df_test$ISE[1]/df_train$ISE[nrow(df_train)]), as.numeric(fcst_ise))
  dICM_q <- c(log(df_test$ICM[1]/df_train$ICM[nrow(df_train)]), as.numeric(fcst_icm))
  
  new_data <- data.frame(
    dlogPIB_lag1 = tail(df_q_midas$dlogPIB, 1),
    dISE_m1 = dISE_q[1], dISE_m2 = dISE_q[2], dISE_m3 = dISE_q[3],
    dICM_m1 = dICM_q[1], dICM_m2 = dICM_q[2], dICM_m3 = dICM_q[3]
  )
  pred_midas_dlog <- predict(modelo_midas, newdata = new_data)
  pred_midas_pib <- exp(pred_midas_dlog + log(df_train$PIB[nrow(df_train)]))
  
  # MFBVAR
  df_bvar_env <- rbind(df_train, df_test)
  df_bvar_env$PIB[(nrow(df_bvar_env)-2):nrow(df_bvar_env)] <- NA 
  
  pib_q <- df_bvar_env$PIB[!is.na(df_bvar_env$PIB)]
  pib_q <- c(pib_q, NA)
  
  Y_eval <- list(
    logPrecio_Petroleo = ts(log(df_bvar_env$Precio_Petroleo), start = c(2014, 1), frequency = 12),
    logISE             = ts(log(df_bvar_env$ISE), start = c(2014, 1), frequency = 12),
    logIPI             = ts(log(df_bvar_env$IPI), start = c(2014, 1), frequency = 12),
    logTRM             = ts(log(df_bvar_env$TRM), start = c(2014, 1), frequency = 12),
    Tasa_Intervencion  = ts(df_bvar_env$Tasa_Intervencion, start = c(2014, 1), frequency = 12),
    ICC                = ts(df_bvar_env$ICC, start = c(2014, 1), frequency = 12),
    Inflacion          = ts(df_bvar_env$Inflacion, start = c(2014, 1), frequency = 12),
    logTD              = ts(log(df_bvar_env$TD), start = c(2014, 1), frequency = 12),
    logICM             = ts(log(df_bvar_env$ICM), start = c(2014, 1), frequency = 12),
    logPIB             = ts(log(pib_q), start = c(2014, 1), frequency = 4)
  )
  
  persistencia <- c(1, 1, 1, 1, 0, 0, 0, 0, 1, 1)
  prior_obj <- set_prior(
    Y = Y_eval,
    n_lags = 6,
    n_fcst = 0,
    n_burnin = 1000,
    n_reps = 1000,
    prior_Pi_AR1 = persistencia,
    lambda1 = 0.04,
    aggregation = "average"
  )
  
  invisible(capture.output(suppressMessages({
    mod_bvar <- estimate_mfbvar(prior_obj, prior = "minn")
  })))
  
  pred_bvar_log <- mean(mod_bvar$Z[nrow(df_bvar_env), 10, ])
  pred_bvar_pib <- exp(pred_bvar_log)
  
  resultados <- rbind(resultados, data.frame(
    Fecha = target_date, Obs = actual_pib, BVAR = pred_bvar_pib, MIDAS = as.numeric(pred_midas_pib)
  ))
  
  cat(sprintf("   BVAR: %.1f | MIDAS: %.1f\n", pred_bvar_pib, pred_midas_pib))
}

resultados <- resultados %>%
  mutate(
    err_BVAR = Obs - BVAR,
    err_MIDAS = Obs - MIDAS,
    mape_BVAR = abs(err_BVAR / Obs) * 100,
    mape_MIDAS = abs(err_MIDAS / Obs) * 100
  )

rmse_bvar <- sqrt(mean(resultados$err_BVAR^2))
rmse_midas <- sqrt(mean(resultados$err_MIDAS^2))

mae_bvar <- mean(abs(resultados$err_BVAR))
mae_midas <- mean(abs(resultados$err_MIDAS))

mape_bvar_avg <- mean(resultados$mape_BVAR)
mape_midas_avg <- mean(resultados$mape_MIDAS)

cat("\n================ METRICAS 8 TRIMESTRES ================\n")
cat(sprintf("RMSE BVAR: %.1f | RMSE MIDAS: %.1f\n", rmse_bvar, rmse_midas))
cat(sprintf("MAPE BVAR: %.2f%% | MAPE MIDAS: %.2f%%\n", mape_bvar_avg, mape_midas_avg))
cat(sprintf("MAE BVAR: %.1f | MAE MIDAS: %.1f\n", mae_bvar, mae_midas))
cat("=========================================================\n")

write.csv(resultados, "BASES/resultados_oos_8q.csv", row.names=FALSE)
