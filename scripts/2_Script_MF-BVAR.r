# ==============================================================================
# SCRIPT 2: MODELO PRINCIPAL MIXED-FREQUENCY BAYESIAN VAR (MF-BVAR)
# Objetivo: Nowcasting del PIB de Colombia (Q2-2026)
# Referencia: Schorfheide & Song (2015), "Real-Time Forecasting with a
# Mixed-Frequency VAR", Journal of Business & Economic Statistics.
# ==============================================================================

library(mfbvar)
library(dplyr)
library(ggplot2)
library(readr)
library(vars)

# 1. Carga de datos procesados (Muestra histórica 2014-2026)
df <- read_csv("BASES/df_MF-BVAR.csv") |> 
  dplyr::filter(as.Date(date) >= as.Date("2014-01-01"))

# Transformaciones logarítmicas de variables en niveles
df$logPrecio_Petroleo <- log(df$Precio_Petroleo)
df$logISE             <- log(df$ISE)
df$logIPI             <- log(df$IPI)
df$logTRM             <- log(df$TRM)
df$logTD              <- log(df$TD)
df$logICM             <- log(df$ICM)
df$logPIB             <- log(df$PIB)

# Desestacionalización de logIPI y logICM con STL para armonizar con PIB e ISE
logIPI_obs <- na.omit(df$logIPI)
ipi_ts <- ts(logIPI_obs, start = c(2014, 1), frequency = 12)
stl_ipi <- stl(ipi_ts, s.window = "periodic")
df$logIPI[!is.na(df$logIPI)] <- as.numeric(stl_ipi$time.series[, "trend"] + stl_ipi$time.series[, "remainder"])

logICM_obs <- na.omit(df$logICM)
icm_ts <- ts(logICM_obs, start = c(2014, 1), frequency = 12)
stl_icm <- stl(icm_ts, s.window = "periodic")
df$logICM[!is.na(df$logICM)] <- as.numeric(stl_icm$time.series[, "trend"] + stl_icm$time.series[, "remainder"])

# 2. Estructuración del objeto de series de tiempo de frecuencias mixtas (ts)
Y <- list(
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

# 3. Selección de rezagos (Criterios de Información VAR)
vars_mensuales <- na.omit(df[, c("logPrecio_Petroleo", "logISE", "logIPI", "logTRM", 
                                 "Tasa_Intervencion", "ICC", "Inflacion", "logTD", "logICM")])
prueba_rezagos <- VARselect(vars_mensuales, lag.max = 6, type = "const")
print("=== Criterios de Selección de Rezagos VAR ===")
print(prueba_rezagos$selection)

n_lags <- 6

# 4. Hiperparámetros del Prior de Minnesota
# lambda1 controla la contracción global hacia el paseo aleatorio
lambda1 <- 0.04

# Persistencia prior AR(1) según Schorfheide & Song (2015):
# 1 para variables en niveles no estacionarias (Petróleo, ISE, IPI, TRM, ICM, PIB)
# 0 para tasas, índices balanceados y variables de media revertible (Tasa Intervención, ICC, Inflación, Desempleo)
persistencia <- c(1, 1, 1, 1, 0, 0, 0, 0, 1, 1)

# 5. Configuración y estimación del MF-BVAR
prior_obj <- set_prior(
  Y = Y,
  n_lags = n_lags,
  n_fcst = 3,
  n_reps = 20000,
  n_burnin = 10000,
  prior_Pi_AR1 = persistencia,
  lambda1 = lambda1,
  aggregation = "average"
)

modelo_bvar <- estimate_mfbvar(prior_obj, prior = "minn")

# 6. Extracción de resultados posteriores y pronóstico del PIB
pib_draws <- exp(modelo_bvar$Z[, 10, ])

df_pib_latente <- data.frame(
  fecha = as.Date(df$date),
  pib_mensual = apply(pib_draws, 1, median),
  lower_95 = apply(pib_draws, 1, quantile, probs = 0.025),
  upper_95 = apply(pib_draws, 1, quantile, probs = 0.975),
  pib_trimestral = exp(df$logPIB)
)

pronostico <- predict(modelo_bvar)
pronostico_pib <- filter(pronostico, variable == "logPIB")
pronostico_pib$median <- exp(pronostico_pib$median)
pronostico_pib$lower  <- exp(pronostico_pib$lower)
pronostico_pib$upper  <- exp(pronostico_pib$upper)

# Tasa de crecimiento interanual proyectada (Q2-2026 vs Q2-2025)
pib_real_obs <- na.omit(exp(df$logPIB))
pib_q2_2025 <- tail(pib_real_obs, 4)[1]   # Q2-2025 observado (253,364.4 MM)
pib_q2_2026 <- pronostico_pib$median[2]  # Pronóstico Q2-2026 (262,181 MM)
tasa_interanual <- ((pib_q2_2026 / pib_q2_2025) - 1) * 100

print("=== RESULTADOS DEL MODELO MF-BVAR ===")
print(pronostico_pib)
print(paste("PIB Q2-2026 Proyectado (Mediana):", round(pib_q2_2026, 1), "MM"))
print(paste("Tasa de Crecimiento Interanual (Q2-2026 vs Q2-2025):", round(tasa_interanual, 2), "%"))

# 7. Gráfica 1: PIB Mensual Latente con bandas de credibilidad al 95%
g1 <- ggplot(df_pib_latente, aes(x = fecha)) +
  geom_ribbon(aes(ymin = lower_95, ymax = upper_95, fill = "Banda de Incertidumbre (95%)"), alpha = 0.20) +
  geom_line(aes(y = pib_mensual, color = "PIB Mensual Latente"), linewidth = 1) +
  geom_point(aes(y = pib_trimestral, color = "PIB Trimestral Observado"), size = 2, na.rm = TRUE) +
  scale_color_manual(name = "Leyenda:", values = c("PIB Mensual Latente" = "#1E40AF", "PIB Trimestral Observado" = "#EF4444")) +
  scale_fill_manual(name = "", values = c("Banda de Incertidumbre (95%)" = "#93C5FD")) +
  scale_y_continuous(labels = scales::comma) +
  labs(title = "PIB Mensual Latente con Bandas de Incertidumbre (95%)", x = "Fecha", y = "PIB Real (Precios Constantes)") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

print(g1)

# 8. Gráfica 2: Evolución del PIB Trimestral Observado y Pronóstico Q2-2026
df_trimestral <- data.frame(
  fecha = as.Date(df$date[!is.na(df$logPIB)]),
  pib = exp(df$logPIB[!is.na(df$logPIB)])
)

df_pronostico_linea <- data.frame(
  fecha = c(tail(df_trimestral$fecha, 1), pronostico_pib$fcst_date[2]),
  pib_mediana = c(tail(df_trimestral$pib, 1), pronostico_pib$median[2]),
  lower = c(tail(df_trimestral$pib, 1), pronostico_pib$lower[2]),
  upper = c(tail(df_trimestral$pib, 1), pronostico_pib$upper[2])
)

g2 <- ggplot() +
  geom_ribbon(data = df_pronostico_linea, aes(x = fecha, ymin = lower, ymax = upper, fill = "Banda 95% Pronóstico"), alpha = 0.25) +
  geom_line(data = df_trimestral, aes(x = fecha, y = pib, color = "Histórico Trimestral Observado"), linewidth = 1) +
  geom_point(data = df_trimestral, aes(x = fecha, y = pib), color = "#1E293B", size = 1.8) +
  geom_line(data = df_pronostico_linea, aes(x = fecha, y = pib_mediana, color = "Pronóstico MF-BVAR (Q2-2026)"), linewidth = 1.1) +
  geom_point(data = tail(df_pronostico_linea, 1), aes(x = fecha, y = pib_mediana, color = "Pronóstico MF-BVAR (Q2-2026)"), size = 3) +
  scale_color_manual(name = "Referencias:", values = c("Histórico Trimestral Observado" = "#1E293B", "Pronóstico MF-BVAR (Q2-2026)" = "#2563EB")) +
  scale_fill_manual(name = "", values = c("Banda 95% Pronóstico" = "#60A5FA")) +
  scale_y_continuous(labels = scales::comma) +
  labs(title = "PIB Trimestral Observado y Pronóstico Q2-2026", x = "Fecha", y = "PIB Real (Precios Constantes)") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

print(g2)

ggsave("pib_trimestral_pronostico.png", plot = g2, width = 8, height = 5, dpi = 300)
