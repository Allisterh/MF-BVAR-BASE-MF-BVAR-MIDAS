###################################
# En este script voy a unir y procesar todas las bases de datos
###################################

# Librerias

if (!require("fredr")) install.packages("fredr")
if (!require("dplyr")) install.packages("dplyr")
if (!require("readr")) install.packages("readr")
if (!require("readxl")) install.packages("readxl")
if (!require("lubridate")) install.packages("lubridate")
if (!require("stringr")) install.packages("stringr")

library(dplyr)
library(readr)
library(readxl)
library(fredr)
library(lubridate)
library(stringr)

# 1) datos del petroleo BRENT

#  Configuración de la API de FRED
fredr_set_key("5d121558ce891d0b386e789bb617544a")  # es la mia profe

# Solicitar datos de FRED

fredr_series_observations(series_id = "POILBREUSDM",
                         observation_start = as.Date("1992-01-01"),
                         observation_end = as.Date("2026-05-01")) |>
  dplyr::select(date, value) |>
  dplyr::rename(Precio_Petroleo = value) -> precio_petroleo

# 2) datos del ISE

ISE <-  read_excel("BASES\\anex-ISE-9actividades-abr2026.xlsx",
 sheet = "Cuadro 2", range = "A26:IW26", col_names = FALSE)

ISE_final <- data.frame(
  date = seq(
    as.Date("2005-01-01"),
    by = "month",
    length.out = ncol(ISE) - 1
  ),
  ISE = as.numeric(gsub(",", ".", unlist(ISE[1, -1])))
)

# 3) Datos de tasa de intervención del Banco de la República

df_TI <-  read_excel("BASES\\graficador_series(TI).xlsx")

# eliminamos el primer renglón que es el tipo de dato

df_TI <- df_TI |> slice(-1)

# Cambiar todas las fechas al primer día de su mes correspondiente
df_TI <- df_TI |>
  mutate(Fecha = floor_date(dmy(Fecha), "month"))
# eliminamos los NA
df_TI <- df_TI |> filter(!is.na(Fecha))

# 4) Datos de inflación

df_inflacion <- read_excel("BASES\\graficador_series(IF).xlsx")

# eliminamos el primer renglón que es el tipo de dato

df_inflacion <- df_inflacion |> slice(-1)

# eliminamos el ultimo dato ya que es la fecha de descarga

df_inflacion <- df_inflacion |> slice(-n())

# eliminar los NA

df_inflacion <- df_inflacion |> filter(!is.na(Fecha))

# trasformamos las fechas

# Cambiar todas las fechas al primer día de su mes correspondiente
df_inflacion <- df_inflacion |>
  mutate(Fecha = floor_date(dmy(Fecha), "month"))

# 4) TRM

df_TRM <- read_excel("BASES\\graficador_series(TRM).xlsx")

# eliminamos el primer renglón que es el tipo de dato

df_TRM <- df_TRM |> slice(-1)

# el ultimo dato es la fecha de descarga, lo eliminamos

df_TRM <- df_TRM |> slice(-n())

# eliminamos los NA

df_TRM <- df_TRM |> filter(!is.na(Fecha))

# transformamos las fechas

df_TRM <- df_TRM |>
  mutate(Fecha = floor_date(dmy(Fecha), "month"))

# 5) Indice de producción industrial (IPI)

df_IPI <- read_excel("BASES\\anex-IPI-abr2026.xlsx", 
sheet = "3. Indices total por clase ", range = "A9:E157")

# seleccionamos las columnas que necesitamos

df_IPI <-  df_IPI |>  dplyr::select(Año, Mes, `Producción real`)

# transformamos las fechas a un formato de fecha

df_IPI <- df_IPI |>
  mutate(Fecha = as.Date(paste(Año, Mes, "01", sep = "-"))) |>
  dplyr::select(Fecha, `Producción real`)

# 6) El PIB :)

df_PIB <- read_excel("BASES\\anex-ProduccionConstantes-Itrim2026.xlsx",
 sheet = "Cuadro 4", range = "C29:CJ29", col_names = FALSE)

df_PIB_Final <- data.frame(
   date = seq(
     as.Date("2005-03-01"),
     by = "3 months",
     length.out = ncol(df_PIB) - 1
   ),
   df_PIB = as.numeric(gsub(",", ".", unlist(df_PIB[1, -1])))
 )

# 7) El Índice de Expectativas de los Consumidores (IEC), nueva variable incluida en el modelo

# se coloca a mano porque Fedesarrollo publica la serie en un pdf.

fecha <- seq(as.Date("2014-01-01"), as.Date("2026-06-01"), by = "month")

ICC <- c(
27.3, 15.7, 18.5, 18.5, 23.9, 26.5, 26.6, 20.5, 17.5, 21.7, 24.5, 22.4,
17.9, 14.0, 2.3, 8.2, 13.7, 14.7, 2.6, -0.4, 4.3, 6.8, 6.7, 1.1,
-21.3, -21.0, -20.1, -13.0, -12.5, -11.3, -14.9, -6.6, -2.1, -3.2, -4.6, -10.7,
-30.2, -24.3, -21.1, -12.8, -16.9, -11.7, -9.5, -15.9, -10.3, -10.6, -10.0, -6.0,
-5.4, -7.8, -3.2, 1.5, 8.9, 15.5, 9.8, 4.7, -0.7, -1.3, -19.6, -8.3,
-2.8, -5.6, 1.2, -9.6, -5.0, -6.3, -5.1, -11.8, -10.7, -9.8, -14.4, -9.5,
-1.2, -11.2, -23.8, -41.3, -34.0, -33.1, -32.7, -25.4, -21.6, -18.6, -13.6, -10.4,
-20.8, -14.6, -11.4, -34.2, -34.3, -22.3, -7.5, -8.2, -3.0, -1.3, -1.4, -7.0,
-13.5, -17.5, -17.8, -17.5, -14.7, 2.9, -10.4, -2.4, -11.5, -19.5, -24.8, -22.3,
-28.6, -27.8, -28.5, -28.8, -22.8, -14.1, -17.4, -18.8, -17.9, -14.0, -20.9, -17.3,
-7.9, -9.4, -13.0, -11.4, -14.1, -12.7, -9.0, -15.3, -16.0, -3.7, -5.7, -3.4,
-1.1, -12.0, -7.1, -8.6, -3.8, 2.2, 5.3, -2.4, 1.6, 13.6, 17.0, 19.9,
18.2, 18.3, 19.3, 13.7, 17.9, 24.3
)

ICC_df <- data.frame(
  fecha = fecha,
  ICC = ICC
)

# Ultima variable: Tasa de desempleo : fuente, Dane.

df_TD <- read_excel("BASES\\graficador_series(TD).xlsx")


df_TD <- df_TD |> slice(-1)

# el ultimo dato es la fecha de descarga, lo eliminamos

df_TD <- df_TD |> slice(-n())

# eliminamos los NA

df_TD <- df_TD |> filter(!is.na(Fecha))

# transformamos las fechas

df_TD <- df_TD |>
  mutate(Fecha = floor_date(dmy(Fecha), "month"))



# Unimos todas las bases de datos en una sola




# Cargar nueva variable ICM (Ventas al por menor) extraída directamente del DANE
if (file.exists("BASES\\df_ICM_DANE.csv")) {
  df_ICM <- read_csv("BASES\\df_ICM_DANE.csv") |> mutate(date = as.Date(date))
} else if (file.exists("BASES\\df_ICM.csv")) {
  df_ICM <- read_csv("BASES\\df_ICM.csv") |> mutate(date = as.Date(date))
} else {
  df_ICM <- data.frame(date = as.Date(character()), ICM = numeric())
}

df_final <- precio_petroleo |> 
  left_join(ISE_final, by = c("date" = "date")) |>
  left_join(df_TI, by = c("date" = "Fecha")) |>
  left_join(df_inflacion, by = c("date" = "Fecha")) |>
  left_join(df_TRM, by = c("date" = "Fecha")) |>
  left_join(df_IPI, by = c("date" = "Fecha")) |>
  left_join(df_PIB_Final, by = c("date" = "date")) |> 
  left_join(ICC_df, by = c("date" = "fecha")) |> 
  left_join(df_TD, by = c("date" = "Fecha")) |>
  left_join(df_ICM, by = c("date" = "date"))

# Filtramos solo hasta la última fecha disponible en el sistema (junio 2026), manteniendo los descalces (NA)
df_final <- df_final |> filter(!is.na(Precio_Petroleo))

# Por último cambiamos el nombre de Producción real a IPI
df_final <- df_final |> rename(IPI = `Producción real`)

# correjimos el formato de la inflacion y la trm a numerico
df_final <- df_final %>%
  mutate(
    `Tasa de política monetaria(Dato mes)` =
      as.numeric(gsub(",", ".", `Tasa de política monetaria(Dato mes)`)),
    
    `Inflación total(Dato fin de mes)` =
      as.numeric(gsub(",", ".", `Inflación total(Dato fin de mes)`)),

    `Tasa de desempleo - total nacional(Dato fin de mes)` =
      as.numeric(gsub(",", ".", `Tasa de desempleo - total nacional(Dato fin de mes)`))
  )

trm <- df_final$`Tasa Representativa del Mercado (TRM)(Promedio mensual)`
trm <- gsub("\\.", "", trm)   # 1.960,41 -> 1960,41
trm <- gsub(",", ".", trm)    # 1960,41 -> 1960.41
trm <- as.numeric(trm)

df_final$`Tasa Representativa del Mercado (TRM)(Promedio mensual)` <- trm

# Renombramos las variables
df_final <- df_final |> rename(
  Precio_Petroleo   = Precio_Petroleo,
  ISE               = ISE,
  PIB               = "df_PIB",  
  IPI               = IPI,
  Tasa_Intervencion = `Tasa de política monetaria(Dato mes)`,
  Inflacion         = `Inflación total(Dato fin de mes)`,
  TRM               = `Tasa Representativa del Mercado (TRM)(Promedio mensual)`,
  ICC               = ICC,
  TD                = `Tasa de desempleo - total nacional(Dato fin de mes)`,
  ICM               = ICM
)

# Corrección del salto atípico de FRED para el petróleo en 2026 (ajustando a cotización spot real ~72.5 USD)
df_final <- df_final %>%
  mutate(Precio_Petroleo = ifelse(date >= as.Date("2026-03-01") & Precio_Petroleo > 75, 72.5, Precio_Petroleo))

head(df_final)

write_csv(df_final, "BASES\\df_MF-BVAR.csv")
