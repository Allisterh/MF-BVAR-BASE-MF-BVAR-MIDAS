# ==============================================================================
# SCRIPT 3: MODELO COMPARATIVO MIDAS EN TASAS DE CRECIMIENTO (AR-MIDAS)
# Objetivo: Pronóstico comparativo del PIB de Colombia (Q2-2026)
# Referencias: Ghysels et al. (2004); Foroni, Marcellino & Schumacher (2015),
# "Unrestricted MIDAS for Nowcasting with Mixed Frequency Data", Journal of Applied Econometrics.
# ==============================================================================

library(readr)
library(dplyr)
library(ggplot2)
library(lubridate)

# 1. Carga de datos procesados (Muestra histórica 2014-2026)
df <- read_csv("BASES/df_MF-BVAR.csv") %>% 
  filter(as.Date(date) >= as.Date("2014-01-01"))

df$logPIB <- log(df$PIB)
df$logISE <- log(df$ISE)
df$logICM <- log(df$ICM)

# Desestacionalización STL del ICM
icm_ts <- ts(na.omit(df$logICM), start = c(2014, 1), frequency = 12)
stl_icm <- stl(icm_ts, s.window = "periodic")
df$logICM[!is.na(df$logICM)] <- as.numeric(stl_icm$time.series[, "trend"] + stl_icm$time.series[, "remainder"])

# Tasas de crecimiento (Diferencias logarítmicas mensuales)
df$dlogISE <- c(0, diff(df$logISE))
df$dlogICM <- c(0, diff(df$logICM))

df$year <- year(df$date)
df$quarter <- quarter(df$date)

# 2. Agrupación de variaciones mensuales de alta frecuencia (M1, M2, M3) en frecuencia trimestral
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

# Muestra de estimación
df_q_train <- df_q %>% filter(!is.na(dlogPIB) & !is.na(dlogPIB_lag1))

# 3. Estimación del modelo AR-MIDAS en tasas de crecimiento
modelo_midas <- lm(dlogPIB ~ dlogPIB_lag1 + dISE_m1 + dISE_m2 + dISE_m3 + dICM_m1 + dICM_m2 + dICM_m3, data = df_q_train)

print("=== RESUMEN MODELO COMPARATIVO AR-MIDAS ===")
print(summary(modelo_midas))

# 4. Pronóstico Q2-2026 con MIDAS
df_q2_2026 <- df %>%
  filter(year(date) == 2026 & quarter(date) == 2) %>%
  summarise(
    dISE_m1 = dlogISE[1],
    dISE_m2 = ifelse(n() >= 2 & !is.na(dlogISE[2]), dlogISE[2], dlogISE[1]),
    dISE_m3 = ifelse(n() >= 3 & !is.na(dlogISE[3]), dlogISE[3], dlogISE[1]),
    dICM_m1 = dlogICM[1],
    dICM_m2 = ifelse(n() >= 2 & !is.na(dlogICM[2]), dlogICM[2], dlogICM[1]),
    dICM_m3 = ifelse(n() >= 3 & !is.na(dlogICM[3]), dlogICM[3], dlogICM[1])
  ) %>%
  mutate(dlogPIB_lag1 = tail(df_q_train$dlogPIB, 1))

pred_dlogPIB_q2 <- predict(modelo_midas, newdata = df_q2_2026)
pib_q1_2026_observed <- tail(df_q_train$logPIB, 1)
pib_q2_2026_midas <- exp(pib_q1_2026_observed + pred_dlogPIB_q2)

# Tasa de crecimiento interanual proyectada (Q2-2026 vs Q2-2025)
pib_real_obs <- na.omit(exp(df$logPIB))
pib_q2_2025 <- tail(pib_real_obs, 4)[1]
tasa_interanual_midas <- ((pib_q2_2026_midas / pib_q2_2025) - 1) * 100

print("=== RESULTADOS MODELO MIDAS ===")
print(paste("PIB Q2-2026 Proyectado (MIDAS):", round(pib_q2_2026_midas, 1), "MM"))
print(paste("Tasa de Crecimiento Interanual (Q2-2026 vs Q2-2025):", round(tasa_interanual_midas, 2), "%"))

# 5. Gráfica de Empalme Trimestral Observado vs Pronóstico MIDAS Q2-2026
df_trimestral <- data.frame(
  fecha = as.Date(df$date[!is.na(df$logPIB)]),
  pib = exp(df$logPIB[!is.na(df$logPIB)])
)

df_pronostico_linea <- data.frame(
  fecha = c(tail(df_trimestral$fecha, 1), as.Date("2026-06-01")),
  pib_mediana = c(tail(df_trimestral$pib, 1), pib_q2_2026_midas)
)

g2 <- ggplot() +
  geom_line(data = df_trimestral, aes(x = fecha, y = pib, color = "Histórico Trimestral Observado"), linewidth = 1) +
  geom_point(data = df_trimestral, aes(x = fecha, y = pib), color = "#1E293B", size = 1.8) +
  geom_line(data = df_pronostico_linea, aes(x = fecha, y = pib_mediana, color = "Pronóstico MIDAS (Q2-2026)"), linewidth = 1.1, linetype = "dashed") +
  geom_point(data = tail(df_pronostico_linea, 1), aes(x = fecha, y = pib_mediana, color = "Pronóstico MIDAS (Q2-2026)"), size = 3) +
  scale_color_manual(name = "Referencias:", values = c("Histórico Trimestral Observado" = "#1E293B", "Pronóstico MIDAS (Q2-2026)" = "#D97706")) +
  scale_y_continuous(labels = scales::comma) +
  labs(title = "PIB Trimestral Observado y Pronóstico Q2-2026 (Modelo Comparativo: AR-MIDAS)", x = "Fecha", y = "PIB Real (Precios Constantes)") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

print(g2)

ggsave("pib_trimestral_pronostico_midas.png", plot = g2, width = 8, height = 5, dpi = 300)
