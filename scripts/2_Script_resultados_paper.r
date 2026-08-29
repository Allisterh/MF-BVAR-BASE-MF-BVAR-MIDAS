# ==============================================================================
# SCRIPT 4: RESULTADOS OFICIALES Y GRÁFICAS CLÁSICAS PARA PAPER (Q2-2026)
# Estilo: Clásico de libro / Journal académico
# Características: Ejes X e Y sólidos, cuadrícula tenue para ubicación,
# sin números flotantes, leyendas limpias y cortas sin recortes.
# ==============================================================================

library(readr)
library(dplyr)
library(mfbvar)
library(ggplot2)
library(lubridate)
library(scales)

# ------------------------------------------------------------------------------
# 1. CARGA Y PREPARACIÓN DE DATOS (2014-2026)
# ------------------------------------------------------------------------------
df <- read_csv("BASES/df_MF-BVAR.csv") %>% 
  filter(as.Date(date) >= as.Date("2014-01-01"))

df$logPrecio_Petroleo <- log(df$Precio_Petroleo)
df$logISE             <- log(df$ISE)
df$logIPI             <- log(df$IPI)
df$logTRM             <- log(df$TRM)
df$logTD              <- log(df$TD)
df$logICM             <- log(df$ICM)
df$logPIB             <- log(df$PIB)

# Desestacionalización STL
logIPI_obs <- na.omit(df$logIPI)
ipi_ts <- ts(logIPI_obs, start = c(2014, 1), frequency = 12)
stl_ipi <- stl(ipi_ts, s.window = "periodic")
df$logIPI[!is.na(df$logIPI)] <- as.numeric(stl_ipi$time.series[, "trend"] + stl_ipi$time.series[, "remainder"])

logICM_obs <- na.omit(df$logICM)
icm_ts <- ts(logICM_obs, start = c(2014, 1), frequency = 12)
stl_icm <- stl(icm_ts, s.window = "periodic")
df$logICM[!is.na(df$logICM)] <- as.numeric(stl_icm$time.series[, "trend"] + stl_icm$time.series[, "remainder"])

# ------------------------------------------------------------------------------
# 2. ESTIMACIÓN DEL MODELO PRINCIPAL MF-BVAR
# ------------------------------------------------------------------------------
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

persistencia <- c(1, 1, 1, 1, 0, 0, 0, 0, 1, 1)

prior_bvar <- set_prior(
  Y = Y,
  n_lags = 6,
  n_fcst = 3,
  n_reps = 20000,
  n_burnin = 10000,
  prior_Pi_AR1 = persistencia,
  lambda1 = 0.04,
  aggregation = "average"
)

set.seed(42)
modelo_bvar <- estimate_mfbvar(prior_bvar, prior = "minn")

# Extracción del PIB Mensual Latente
pib_latente_draws <- exp(modelo_bvar$Z[, 10, ])

df_latente <- data.frame(
  fecha = as.Date(df$date[1:nrow(pib_latente_draws)]),
  pib_mensual = apply(pib_latente_draws, 1, median),
  lower = apply(pib_latente_draws, 1, quantile, probs = 0.025),
  upper = apply(pib_latente_draws, 1, quantile, probs = 0.975),
  pib_obs = df$PIB[1:nrow(pib_latente_draws)]
)

# Pronóstico agregado Q2-2026
pred_bvar <- predict(modelo_bvar)
pred_pib <- filter(pred_bvar, variable == "logPIB")
fcst_q2_bvar_med <- exp(pred_pib$median[2])
fcst_q2_bvar_low <- exp(pred_pib$lower[2])
fcst_q2_bvar_upp <- exp(pred_pib$upper[2])

pib_obs_q1_2026 <- tail(na.omit(df$PIB), 1)     # 258,780.7 MM
pib_obs_q2_2025 <- tail(na.omit(df$PIB), 4)[1]  # 253,364.4 MM

crec_q_bvar <- ((fcst_q2_bvar_med / pib_obs_q1_2026) - 1) * 100
crec_y_bvar <- ((fcst_q2_bvar_med / pib_obs_q2_2025) - 1) * 100

# ------------------------------------------------------------------------------
# 3. ESTIMACIÓN DEL MODELO COMPARATIVO AR-MIDAS
# ------------------------------------------------------------------------------
df$dlogISE <- c(0, diff(df$logISE))
df$dlogICM <- c(0, diff(df$logICM))
df$year <- year(df$date)
df$quarter <- quarter(df$date)

df_q <- df %>%
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

df_q_train <- df_q %>% filter(!is.na(dlogPIB) & !is.na(dlogPIB_lag1))

modelo_midas <- lm(
  dlogPIB ~ dlogPIB_lag1 + dISE_m1 + dISE_m2 + dISE_m3 + dICM_m1 + dICM_m2 + dICM_m3, 
  data = df_q_train
)

df_q2_2026 <- df %>%
  filter(year == 2026 & quarter == 2) %>%
  summarise(
    dISE_m1 = dlogISE[1],
    dISE_m2 = ifelse(n() >= 2 & !is.na(dlogISE[2]), dlogISE[2], dlogISE[1]),
    dISE_m3 = ifelse(n() >= 3 & !is.na(dlogISE[3]), dlogISE[3], dlogISE[1]),
    dICM_m1 = dlogICM[1],
    dICM_m2 = ifelse(n() >= 2 & !is.na(dlogICM[2]), dlogICM[2], dlogICM[1]),
    dICM_m3 = ifelse(n() >= 3 & !is.na(dlogICM[3]), dlogICM[3], dlogICM[1])
  ) %>%
  mutate(dlogPIB_lag1 = tail(df_q_train$dlogPIB, 1))

pred_dlog_q2 <- predict(modelo_midas, newdata = df_q2_2026)
pib_obs_q1_log <- tail(df_q_train$logPIB, 1)
fcst_q2_midas <- exp(pib_obs_q1_log + pred_dlog_q2)

crec_q_midas <- ((fcst_q2_midas / pib_obs_q1_2026) - 1) * 100
crec_y_midas <- ((fcst_q2_midas / pib_obs_q2_2025) - 1) * 100

# ------------------------------------------------------------------------------
# 4. TABLAS FORMALES
# ------------------------------------------------------------------------------
print("=========================================================================")
print("=== TABLA 1: NOWCASTING DEL PIB Q2-2026 (MF-BVAR vs. AR-MIDAS) ==========")
print("=========================================================================")
tabla_nowcast <- data.frame(
  Modelo = c("MF-BVAR Canónico (10 Variables)", "AR-MIDAS (ISE + ICM)"),
  PIB_Q2_2026_Niveles = c(
    paste0(comma(round(fcst_q2_bvar_med, 1)), " [", comma(round(fcst_q2_bvar_low, 1)), " - ", comma(round(fcst_q2_bvar_upp, 1)), "]"),
    paste0(comma(round(fcst_q2_midas, 1)), " (Puntual)")
  ),
  Crec_Intertrimestral_Q = c(
    paste0("+", round(crec_q_bvar, 2), "%"),
    paste0("+", round(crec_q_midas, 2), "%")
  ),
  Crec_Interanual_Y = c(
    paste0("+", round(crec_y_bvar, 2), "%"),
    paste0("+", round(crec_y_midas, 2), "%")
  )
)
print(tabla_nowcast)

# ------------------------------------------------------------------------------
# 5. TEMA VISUAL CLÁSICO DE LIBRO (theme_classic base)
# ------------------------------------------------------------------------------
theme_paper <- function() {
  theme_classic(base_size = 12, base_family = "") %+replace%
    theme(
      # Fondo limpio
      plot.background  = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA),

      # Ejes sólidos negros
      axis.line   = element_line(color = "black", linewidth = 0.5),
      axis.ticks  = element_line(color = "black", linewidth = 0.4),
      axis.text   = element_text(color = "black", size = 10),
      axis.title  = element_text(color = "black", size = 11),
      axis.title.y = element_text(angle = 90, vjust = 0.5, margin = margin(r = 10)),
      axis.title.x = element_text(margin = margin(t = 10)),

      # Cuadrícula tenue para ubicarse (solo major, estilo textbook)
      panel.grid.major = element_line(color = "grey90", linewidth = 0.3),
      panel.grid.minor = element_blank(),

      # Títulos con espacio generoso para que nada se corte
      plot.title    = element_text(face = "bold", size = 13, hjust = 0.5,
                                   margin = margin(t = 5, b = 4)),
      plot.subtitle = element_text(size = 10, hjust = 0.5, color = "grey30",
                                   margin = margin(b = 10)),
      plot.caption  = element_text(size = 8.5, hjust = 0, color = "grey40",
                                   margin = margin(t = 12)),

      # Márgenes generosos del plot completo para evitar recortes
      plot.margin = margin(t = 15, r = 20, b = 10, l = 10),

      # Leyenda inferior, horizontal, con espacio suficiente
      legend.position   = "bottom",
      legend.direction  = "horizontal",
      legend.background = element_blank(),
      legend.title      = element_blank(),
      legend.text       = element_text(size = 10, color = "black"),
      legend.key        = element_blank(),
      legend.key.width  = unit(1.5, "cm"),
      legend.spacing.x  = unit(0.5, "cm"),
      legend.margin     = margin(t = 5, b = 5)
    )
}

# ------------------------------------------------------------------------------
# 6. FIGURA 1: PIB LATENTE IN-SAMPLE (toda la serie, 2014-2026)
# ------------------------------------------------------------------------------

g1 <- ggplot(df_latente, aes(x = fecha)) +
  geom_ribbon(aes(ymin = lower, ymax = upper, fill = "Intervalo al 95%"),
              alpha = 0.18) +
  geom_line(aes(y = pib_mensual, color = "PIB mensual latente"),
            linewidth = 0.6) +
  geom_point(aes(y = pib_obs, color = "PIB trimestral observado"),
             size = 1.5, na.rm = TRUE) +
  scale_color_manual(
    values = c("PIB mensual latente"      = "#1B365D",
               "PIB trimestral observado" = "#B22222")
  ) +
  scale_fill_manual(values = c("Intervalo al 95%" = "#7BAFD4")) +
  scale_y_continuous(labels = comma_format(big.mark = ",")) +
  scale_x_date(date_breaks = "2 years", date_labels = "%Y") +
  labs(
    title    = "PIB mensual latente de Colombia (2014-2026)",
    subtitle = "Filtro de Kalman del modelo MF-BVAR con 10 variables",
    x = NULL,
    y = "Miles de millones de pesos\n(COP constantes)",
    caption  = "Fuente: Cálculos de los autores con datos del DANE y Banco de la República."
  ) +
  theme_paper() +
  guides(color = guide_legend(order = 1),
         fill  = guide_legend(order = 2))

ggsave("grafica_pib_mensual_latente_paper.png", plot = g1,
       width = 10, height = 5.5, dpi = 300, bg = "white")

# ------------------------------------------------------------------------------
# 7. FIGURA 2: COMPARACIÓN NOWCASTING Q2-2026
# ------------------------------------------------------------------------------
df_obs_q <- data.frame(
  fecha = as.Date(df$date[!is.na(df$PIB)]),
  pib   = df$PIB[!is.na(df$PIB)]
)

df_bvar_line <- data.frame(
  fecha = c(tail(df_obs_q$fecha, 1), as.Date("2026-06-01")),
  pib   = c(tail(df_obs_q$pib, 1), fcst_q2_bvar_med),
  lower = c(tail(df_obs_q$pib, 1), fcst_q2_bvar_low),
  upper = c(tail(df_obs_q$pib, 1), fcst_q2_bvar_upp)
)

df_midas_line <- data.frame(
  fecha = c(tail(df_obs_q$fecha, 1), as.Date("2026-06-01")),
  pib   = c(tail(df_obs_q$pib, 1), fcst_q2_midas)
)

g2 <- ggplot() +
  geom_ribbon(data = df_bvar_line,
              aes(x = fecha, ymin = lower, ymax = upper,
                  fill = "Intervalo al 95%"),
              alpha = 0.18) +
  geom_line(data = df_obs_q,
            aes(x = fecha, y = pib, color = "PIB observado"),
            linewidth = 0.6) +
  geom_point(data = df_obs_q,
             aes(x = fecha, y = pib, color = "PIB observado"),
             size = 1.3) +
  geom_line(data = df_bvar_line,
            aes(x = fecha, y = pib, color = "MF-BVAR"),
            linewidth = 0.7) +
  geom_point(data = tail(df_bvar_line, 1),
             aes(x = fecha, y = pib, color = "MF-BVAR"),
             size = 2.5) +
  geom_line(data = df_midas_line,
            aes(x = fecha, y = pib, color = "AR-MIDAS"),
            linewidth = 0.7, linetype = "dashed") +
  geom_point(data = tail(df_midas_line, 1),
             aes(x = fecha, y = pib, color = "AR-MIDAS"),
             size = 2.5) +
  scale_color_manual(
    values = c("PIB observado" = "black",
               "MF-BVAR"       = "#1B365D",
               "AR-MIDAS"      = "#B22222")
  ) +
  scale_fill_manual(values = c("Intervalo al 95%" = "#7BAFD4")) +
  scale_y_continuous(labels = comma_format(big.mark = ",")) +
  scale_x_date(date_breaks = "2 years", date_labels = "%Y") +
  labs(
    title    = "Nowcasting del PIB de Colombia (Q2-2026)",
    subtitle = "Comparación fuera de muestra: MF-BVAR vs. AR-MIDAS",
    x = NULL,
    y = "Miles de millones de pesos\n(COP constantes)",
    caption  = "Fuente: Cálculos de los autores con datos del DANE y Banco de la República."
  ) +
  theme_paper() +
  guides(color = guide_legend(order = 1),
         fill  = guide_legend(order = 2))

ggsave("grafica_nowcast_comparativo_q2_2026.png", plot = g2,
       width = 10, height = 5.5, dpi = 300, bg = "white")

print("=== GRÁFICAS GENERADAS CON ÉXITO ===")

# :)
