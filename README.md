# Base de Datos y Modelos para el Nowcasting del PIB en Colombia (MF-BVAR vs. MIDAS)

## Descripción

Este repositorio contiene la base de datos macroeconómica de frecuencia mixta (mensual y trimestral) y los scripts de estimación para el *nowcasting* del Producto Interno Bruto (PIB) de Colombia. 

Se implementa un modelo **Mixed-Frequency Bayesian Vector Autoregression (MF-BVAR)** siguiendo la metodología de Schorfheide & Song (2015) y se compara contra un modelo **AR-MIDAS** (Ghysels et al., 2004) en tasas de crecimiento estacionarias.

---

## Estructura de Scripts (`scripts/`)

- **`1_Script_bases.r`**: Extrae, transforma y consolida las 10 series macroeconómicas y financieras oficiales, generando el archivo `BASES/df_MF-BVAR.csv`.
- **`2_Script_MF-BVAR.r`**: Estima el modelo principal MF-BVAR con prior de Minnesota automática y produce el nowcast del PIB del segundo trimestre de 2026 (crecimiento interanual proyectado del **3.48%**).
- **`3_Script_MIDAS.r`**: Estima el modelo comparativo AR-MIDAS sobre las variaciones mensuales de alta frecuencia (ISE, ICM) y genera el pronóstico de contraste.

---

## Variables del Modelo (`BASES/df_MF-BVAR.csv`)

### 1. `date`
- **Descripción:** Fecha de la observación mensual.
- **Frecuencia:** Mensual (`YYYY-MM-01`).

### 2. `Precio_Petroleo`
- **Descripción:** Precio promedio mensual del petróleo Brent.
- **Fuente:** Federal Reserve Economic Data (FRED) / EIA. Serie `POILBREUSDM`.
- **Unidad:** USD por barril.
- **Frecuencia:** Mensual.

### 3. `ISE`
- **Descripción:** Indicador de Seguimiento a la Economía.
- **Fuente:** DANE. Serie desestacionalizada y ajustada por efecto calendario.
- **Unidad:** Índice (2018 = 100).
- **Frecuencia:** Mensual.

### 4. `Tasa_Intervencion`
- **Descripción:** Tasa de interés de política monetaria fijada por la Junta Directiva del Banco de la República.
- **Fuente:** Banco de la República.
- **Unidad:** Porcentaje anual (%).
- **Frecuencia:** Mensual.

### 5. `Inflacion`
- **Descripción:** Variación anual del Índice de Precios al Consumidor (IPC).
- **Fuente:** DANE / Banco de la República.
- **Unidad:** Porcentaje anual (%).
- **Frecuencia:** Mensual.

### 6. `TRM`
- **Descripción:** Tasa Representativa del Mercado (Tipo de cambio nominal COP/USD).
- **Fuente:** Superintendencia Financiera / Banco de la República.
- **Unidad:** Pesos colombianos por dólar (COP/USD).
- **Frecuencia:** Mensual (promedio del mes).

### 7. `IPI`
- **Descripción:** Índice de Producción Industrial (Muestra Mensual Manufacturera con Enfoque Territorial - EMMET).
- **Fuente:** DANE.
- **Unidad:** Índice.
- **Frecuencia:** Mensual (desestacionalizado con STL).

### 8. `PIB`
- **Descripción:** Producto Interno Bruto real a precios constantes.
- **Fuente:** DANE (Cuentas Nacionales Trimestrales).
- **Unidad:** Miles de millones de pesos constantes encadenados.
- **Frecuencia:** Trimestral (registrado en el mes de cierre de trimestre con `NA` en los meses intermedios).

### 9. `TD`
- **Descripción:** Tasa de Desempleo (Desocupación) nacional.
- **Fuente:** DANE (Gran Encuesta Integrada de Hogares - GEIH).
- **Unidad:** Porcentaje (%).
- **Frecuencia:** Mensual.

### 10. `ICC`
- **Descripción:** Índice de Confianza del Consumidor.
- **Fuente:** Fedesarrollo (Encuesta de Opinión del Consumidor - EOC).
- **Unidad:** Balance neto (puntos).
- **Frecuencia:** Mensual.

### 11. `ICM`
- **Descripción:** Índice de Comercio al por Menor (Ventas reales del comercio minorista).
- **Fuente:** DANE (Encuesta Mensual de Comercio - EMC).
- **Unidad:** Índice (2018 = 100).
- **Frecuencia:** Mensual (desestacionalizado con STL).

---

## Período de Estudio

- **Muestra:** Enero de 2014 a Junio de 2026.
- **Corte de Información (*Nowcasting Information Set*):** 15 de julio de 2026 (publicación oficial del DANE de la EMC de mayo y del ICC de junio de Fedesarrollo).
