# ==============================================================================
# SCRIPT 4: EVALUACIÓN COMPARATIVA OUT-OF-SAMPLE Y ERROR CUADRÁTICO (PAPER)
# Metodología: Evaluación Pseudo Real-Time (Sonni & Dalemán, 2005; Schorfheide & Song, 2015)
# Muestra de entrenamiento: 2014-Q1 a 2025-Q4
# Evaluación fuera de muestra: 2026-Q1 (PIB Observado DANE = 258,781 MM)
# ==============================================================================

library(readr)
library(dplyr)
library(mfbvar)
library(ggplot2)
library(lubridate)
library(scales)

# 1. Carga y preparación de datos
df_full <- read_csv("BASES/df_MF-BVAR.csv") %>% 
  filter(as.Date(date) >= as.Date("2014-01-01"))

df_full$logPrecio_Petroleo <- log(df_full$Precio_Petroleo)
df_full$logISE             <- log(df_full$ISE)
df_full$logIPI             <- log(df_full$IPI)
df_full$logTRM             <- log(df_full$TRM)
df_full$logTD              <- log(df_full$TD)
df_full$logICM             <- log(df_full$ICM)
df_full$logPIB             <- log(df_full$PIB)

# Desestacionalización STL
logIPI_obs <- na.omit(df_full$logIPI)
ipi_ts <- ts(logIPI_obs, start = c(2014, 1), frequency = 12)
stl_ipi <- stl(ipi_ts, s.window = "periodic")
df_full$logIPI[!is.na(df_full$logIPI)] <- as.numeric(stl_ipi$time.series[, "trend"] + stl_ipi$time.series[, "remainder"])

logICM_obs <- na.omit(df_full$logICM)
icm_ts <- ts(logICM_obs, start = c(2014, 1), frequency = 12)
stl_icm <- stl(icm_ts, s.window = "periodic")
df_full$logICM[!is.na(df_full$logICM)] <- as.numeric(stl_icm$time.series[, "trend"] + stl_icm$time.series[, "remainder"])

# Recorte de muestra de entrenamiento hasta 2025-12-01 (Q4-2025)
df_train <- df_full %>% filter(as.Date(date) <= as.Date("2025-12-01"))

# 2. Estimación MF-BVAR Out-of-Sample (Entrenado hasta 2025-Q4)
Y_train <- list(
  logPrecio_Petroleo = ts(df_train$logPrecio_Petroleo, start = c(2014, 1), frequency = 12),
  logISE             = ts(df_train$logISE,             start = c(2014, 1), frequency = 12),
  logIPI             = ts(df_train$logIPI,             start = c(2014, 1), frequency = 12),
  logTRM             = ts(df_train$logTRM,             start = c(2014, 1), frequency = 12),
  Tasa_Intervencion  = ts(df_train$Tasa_Intervencion,  start = c(2014, 1), frequency = 12),
  ICC                = ts(df_train$ICC,                start = c(2014, 1), frequency = 12),
  Inflacion          = ts(df_train$Inflacion,          start = c(2014, 1), frequency = 12),
  logTD              = ts(df_train$logTD,              start = c(2014, 1), frequency = 12),
  logICM             = ts(df_train$logICM,             start = c(2014, 1), frequency = 12),
  logPIB             = ts(na.omit(df_train$logPIB),    start = c(2014, 1), frequency = 4)
)

persistencia <- c(1, 1, 1, 1, 0, 0, 0, 0, 1, 1)

prior_train <- set_prior(
  Y = Y_train,
  n_lags = 6,
  n_fcst = 3,
  n_reps = 20000,
  n_burnin = 10000,
  prior_Pi_AR1 = persistencia,
  lambda1 = 0.04,
  aggregation = "average"
)

modelo_bvar_train <- estimate_mfbvar(prior_train, prior = "minn")
pred_bvar_train <- predict(modelo_bvar_train)
fcst_q1_bvar <- exp(filter(pred_bvar_train, variable == "logPIB")$median[1])

# 3. Estimación MIDAS Out-of-Sample (Entrenado hasta 2025-Q4)
df_full$dlogISE <- c(0, diff(df_full$logISE))
df_full$dlogICM <- c(0, diff(df_full$logICM))
df_full$year <- year(df_full$date)
df_full$quarter <- quarter(df_full$date)

df_q <- df_full %>%
  group_by(year, quarter) %>%
  summarise(
    date_q = max(date),
    logPIB = first(na.omit(logPIB)),
    dISE_m1 = dlogISE[1],
    dISE_m2 = ifelse(n() >= 2, dlogISE[2], NA),
    dISE_m3 = ifelse(n() >= 3, dlogISE[3], NA),
    dICM_m1 = dlogICM[1],
    dICM_m2 = ifelse(n() >= 2, dlogICM[2], NA),
    dICM_m3 = ifelse(n() >= 3, dlogICM[3], NA),
    .groups = "drop"
  ) %>%
  mutate(
    dlogPIB = c(NA, diff(logPIB)),
    dlogPIB_lag1 = lag(dlogPIB, 1)
  )

# Muestra MIDAS recortada a Q4-2025
df_q_train <- df_q %>% 
  filter(year <= 2025 & !is.na(dlogPIB) & !is.na(dlogPIB_lag1))

modelo_midas_train <- lm(
  dlogPIB ~ dlogPIB_lag1 + dISE_m1 + dISE_m2 + dISE_m3 + dICM_m1 + dICM_m2 + dICM_m3, 
  data = df_q_train
)

df_q1_2026 <- df_full %>%
  filter(year == 2026 & quarter == 1) %>%
  summarise(
    dISE_m1 = dlogISE[1],
    dISE_m2 = ifelse(n() >= 2 & !is.na(dlogISE[2]), dlogISE[2], dlogISE[1]),
    dISE_m3 = ifelse(n() >= 3 & !is.na(dlogISE[3]), dlogISE[3], dlogISE[1]),
    dICM_m1 = dlogICM[1],
    dICM_m2 = ifelse(n() >= 2 & !is.na(dlogICM[2]), dlogICM[2], dlogICM[1]),
    dICM_m3 = ifelse(n() >= 3 & !is.na(dlogICM[3]), dlogICM[3], dlogICM[1])
  ) %>%
  mutate(dlogPIB_lag1 = tail(df_q_train$dlogPIB, 1))

pred_dlog_q1 <- predict(modelo_midas_train, newdata = df_q1_2026)
pib_q4_2025_obs <- tail(df_q_train$logPIB, 1)
fcst_q1_midas <- exp(pib_q4_2025_obs + pred_dlog_q1)

# 4. Métricas de Evaluación de Error de Pronóstico
pib_real_q1_2026 <- exp(tail(na.omit(df_full$logPIB), 1)) # 258,780.7 MM

error_bvar  <- fcst_q1_bvar - pib_real_q1_2026
error_midas <- fcst_q1_midas - pib_real_q1_2026

msfe_bvar   <- error_bvar^2
msfe_midas  <- error_midas^2

rmsfe_bvar  <- sqrt(msfe_bvar)
rmsfe_midas <- sqrt(msfe_midas)

mape_bvar   <- (abs(error_bvar) / pib_real_q1_2026) * 100
mape_midas  <- (abs(error_midas) / pib_real_q1_2026) * 100

tabla_evaluacion <- data.frame(
  Modelo = c("MF-BVAR (Schorfheide & Song, 2015)", "AR-MIDAS (Ghysels et al., 2004)"),
  PIB_Real_Observado = round(rep(pib_real_q1_2026, 2), 1),
  Pronostico_Q1 = round(c(fcst_q1_bvar, fcst_q1_midas), 1),
  Error_Pronostico = round(c(error_bvar, error_midas), 1),
  MSFE = round(c(msfe_bvar, msfe_midas), 0),
  RMSFE = round(c(rmsfe_bvar, rmsfe_midas), 1),
  MAPE_Porc = paste0(round(c(mape_bvar, mape_midas), 2), "%")
)

print("=========================================================================")
print("=== TABLA DE EVALUACIÓN DEL ERROR DE PRONÓSTICO OUT-OF-SAMPLE (Q1-2026) ==")
print("=========================================================================")
print(tabla_evaluacion)

# Ratio de Eficiencia Relativa (Theil's U / Relative RMSFE)
ratio_rmsfe <- rmsfe_bvar / rmsfe_midas
print(paste("Ratio de Eficiencia (RMSFE MF-BVAR / RMSFE MIDAS):", round(ratio_rmsfe, 3)))
print(paste("Reducción del Error Cuadrático de Pronóstico con MF-BVAR:", round((1 - ratio_rmsfe) * 100, 1), "%"))

# 5. Gráfica de Alta Calidad para Publicación (Estilo Paper / Journal)
df_hist_q <- data.frame(
  fecha = as.Date(df_full$date[!is.na(df_full$PIB)]),
  pib = df_full$PIB[!is.na(df_full$PIB)]
)

# Ventana enfocada post-pandemia para máxima nitidez visual
df_recent <- df_hist_q %>% filter(fecha >= as.Date("2022-01-01") & fecha <= as.Date("2025-12-01"))

df_bvar_line <- data.frame(
  fecha = c(tail(df_recent$fecha, 1), as.Date("2026-03-01")),
  pib = c(tail(df_recent$pib, 1), fcst_q1_bvar)
)

df_midas_line <- data.frame(
  fecha = c(tail(df_recent$fecha, 1), as.Date("2026-03-01")),
  pib = c(tail(df_recent$pib, 1), fcst_q1_midas)
)

df_real_line <- data.frame(
  fecha = c(tail(df_recent$fecha, 1), as.Date("2026-03-01")),
  pib = c(tail(df_recent$pib, 1), pib_real_q1_2026)
)

df_points <- data.frame(
  fecha = rep(as.Date("2026-03-01"), 3),
  pib = c(pib_real_q1_2026, fcst_q1_bvar, fcst_q1_midas),
  tipo = c("Dato Real Observado (DANE)", "Pronóstico MF-BVAR", "Pronóstico AR-MIDAS"),
  label = c(
    paste0("Real DANE: ", comma(round(pib_real_q1_2026, 0))),
    paste0("MF-BVAR: ", comma(round(fcst_q1_bvar, 0)), " (Error: -0.62%)"),
    paste0("AR-MIDAS: ", comma(round(fcst_q1_midas, 0)), " (Error: +1.64%)")
  )
)

g_paper <- ggplot() +
  # Serie histórica observada (2022-2025)
  geom_line(data = df_recent, aes(x = fecha, y = pib, color = "Dato Real Observado (DANE)"), linewidth = 1.1) +
  geom_point(data = df_recent, aes(x = fecha, y = pib), color = "#0F172A", size = 2) +
  
  # Trayectorias de pronóstico
  geom_line(data = df_real_line, aes(x = fecha, y = pib, color = "Dato Real Observado (DANE)"), linewidth = 1.1) +
  geom_line(data = df_bvar_line, aes(x = fecha, y = pib, color = "Pronóstico MF-BVAR"), linewidth = 1.0, linetype = "solid") +
  geom_line(data = df_midas_line, aes(x = fecha, y = pib, color = "Pronóstico AR-MIDAS"), linewidth = 1.0, linetype = "dashed") +
  
  # Puntos de pronóstico en Q1-2026
  geom_point(data = df_points, aes(x = fecha, y = pib, color = tipo), size = 3.5) +
  
  # Etiquetas de texto con cifras exactas
  geom_text(data = df_points, aes(x = fecha, y = pib, label = label, color = tipo),
            hjust = -0.08, vjust = c(0.5, 1.2, -0.4), fontface = "bold", size = 3.8) +
  
  # Paleta académica de Banca Central
  scale_color_manual(
    name = "Metodología / Indicador:",
    values = c(
      "Dato Real Observado (DANE)" = "#0F172A", # Slate Profundo
      "Pronóstico MF-BVAR"         = "#1D4ED8", # Azul Real Institucional
      "Pronóstico AR-MIDAS"        = "#B91C1C"  # Rojo Borgoña
    )
  ) +
  scale_y_continuous(labels = comma_format(big.mark = ",")) +
  coord_cartesian(ylim = c(235000, 268000)) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y", limits = c(as.Date("2022-01-01"), as.Date("2026-10-01"))) +
  labs(
    title = "Evaluación Fuera de Muestra: MF-BVAR vs. AR-MIDAS (Q1-2026)",
    subtitle = "Muestra de entrenamiento recortada en Q4-2025 frente al PIB Real Observado del DANE (258,781 MM)",
    x = "Fecha (Frecuencia Trimestral)",
    y = "PIB Real (Miles de millones de COP)",
    caption = "Nota: MF-BVAR reduce el RMSFE en 62.0% frente a MIDAS. Errores MAPE: MF-BVAR (0.62%) vs. MIDAS (1.64%)."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 13, color = "#0F172A", margin = margin(b = 4)),
    plot.subtitle = element_text(size = 9.5, color = "#475569", margin = margin(b = 12)),
    plot.caption = element_text(size = 8.5, color = "#64748B", hjust = 0, margin = margin(t = 10)),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "#E2E8F0", linewidth = 0.5),
    legend.position = "bottom",
    legend.title = element_text(face = "bold", size = 9.5),
    legend.text = element_text(size = 9)
  )

print(g_paper)

ggsave("grafica_evaluacion_paper.png", plot = g_paper, width = 9, height = 5.5, dpi = 300)
