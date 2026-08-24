# Repositorio de Fuentes Bibliográficas y Documentos Metodológicos

Este directorio contiene los enlaces oficiales, repositorios académicos, versiones *Working Paper* y documentos en PDF correspondientes a las fuentes teóricas y econométricas empleadas en la sección de **Metodología** del paper de *Nowcasting* con **MF-BVAR** y **AR-MIDAS**.

---

## 1. Kuzin, Marcellino & Schumacher (2011)
* **Título:** *MIDAS vs. Mixed-Frequency VAR: Investigating the Forecasting Performance for Euro Area GDP*
* **Publicación:** *Journal of Applied Econometrics*, 26(2), 214–242 (2011).
* **Versión Working Paper:** *MIDAS vs. mixed-frequency VAR: Nowcasting GDP in the Euro Area*, Deutsche Bundesbank Discussion Paper No. 07/2009 / EUI Working Paper ECO2009/32.
* **Rol Metodológico:** Establece la comparación teórica y empírica entre modelos uniecuacionales de datos mixtos (MIDAS) y sistemas multivariados autorregresivos de espacio de estados (MF-VAR).
* **Enlaces:**
  * [DOI Oficial (Wiley)](https://doi.org/10.1002/jae.1154)
  * [Repositorio EconStor / Bundesbank](https://www.econstor.eu/handle/10419/27661)
  * [Repositorio Cadmus EUI](https://cadmus.eui.eu/handle/1814/12382)
  * [Ficha RePEc / IDEAS](https://ideas.repec.org/p/eui/euiwps/eco2009-32.html)

---

## 2. Ankargren & Jonéus (2020) / Ankargren, Yang & Camden (2017)
* **Título:** *Simulation-Based Inference for Mixed-Frequency Bayesian VARs* / *mfbvar: Mixed-Frequency Bayesian Vector Autoregressions in R*
* **Publicación:** *Journal of Statistical Computation and Simulation*, 90(18), 3350–3375 (2020) & Department of Statistics, Uppsala University Working Paper (2017:2).
* **Rol Metodológico:** Fundamentación del algoritmo MCMC, el muestreador de Gibbs con prior de Minnesota conjugado (MNIW) y la paquetería computacional base `mfbvar` empleada en el código.
* **Enlaces:**
  * [DOI Oficial (Taylor & Francis)](https://doi.org/10.1080/00949655.2020.1802511)
  * [Repositorio Uppsala University DiVA](https://www.diva-portal.org/smash/record.jsf?pid=diva2%3A1159981)
  * [Repositorio Oficial en GitHub](https://github.com/ankargren/mfbvar)
  * [Documentación Oficial en CRAN](https://cran.r-project.org/package=mfbvar)

---

## 3. Mariano & Murasawa (2003)
* **Título:** *A New Monthly Index of Coincident Economic Indicators*
* **Publicación:** *Journal of Applied Econometrics*, 18(4), 427–443 (2003).
* **Versión Working Paper:** *A New Coincident Index of Business Cycles Based on Monthly and Quarterly Series*, SMU Economics & Statistics Working Paper Series No. 18-2002.
* **Rol Metodológico:** Deducción rigurosa de la restricción de agregación temporal geométrica en niveles / media aritmética en logaritmos ($\log(PIB_{Q,t}) = \frac{1}{3}\sum_{i=0}^2 \log(PIB_{M,t-i}^*)$).
* **Enlaces:**
  * [DOI Oficial (Wiley)](https://doi.org/10.1002/jae.695)
  * [Repositorio Institucional SMU InK](https://ink.library.smu.edu.sg/soe_research/1708/)
  * [Ficha RePEc / IDEAS](https://ideas.repec.org/a/jae/japmet/v18y2003i4p427-443.html)

---

## 4. Clements & Galvão (2008)
* **Título:** *Macroeconomic Forecasting with Mixed-Frequency Data: Forecasting Output Growth in the United States*
* **Publicación:** *Journal of Business & Economic Statistics*, 26(4), 546–554 (2008).
* **Versión Working Paper:** Queen Mary University of London Working Paper No. 598.
* **Rol Metodológico:** Formulación del modelo autorregresivo MIDAS (AR-MIDAS) y el tratamiento de la persistencia trimestral junto a flujos mensuales.
* **Enlaces:**
  * [DOI Oficial (Taylor & Francis)](https://doi.org/10.1198/073500108000000015)
  * [Repositorio CentAUR (University of Reading)](https://centaur.reading.ac.uk/id/eprint/34032/)
  * [Ficha RePEc / IDEAS](https://ideas.repec.org/p/qmw/qmwecw/wp598.html)
  * *Referencia Complementaria U-MIDAS:* [Foroni, Marcellino & Schumacher (2015) JRSS-A](https://doi.org/10.1111/rssa.12074) | [Bundesbank WP en EconStor](https://www.econstor.eu/handle/10419/46077)

---

## 5. Bańbura, Giannone & Reichlin (2010)
* **Título:** *Large Bayesian Vector Auto Regressions*
* **Publicación:** *Journal of Applied Econometrics*, 25(1), 71–92 (2010).
* **Versión Working Paper:** European Central Bank (ECB) Working Paper No. 966 (2008).
* **Rol Metodológico:** Justificación teórica de la contracción bayesiana (*shrinkage*) con el prior de Minnesota para controlar la sobreparametrización en sistemas VAR de dimensión media y alta ($N=10$, $p=6$).
* **Archivos Locales:**
  * PDF disponible en: `fuentes/Banbura_Giannone_Reichlin_2008_LargeBVAR.pdf`
* **Enlaces:**
  * [DOI Oficial (Wiley)](https://doi.org/10.1002/jae.1137)
  * [PDF Oficial ECB Working Paper](https://www.ecb.europa.eu/pub/pdf/scpwps/ecbwp966.pdf)
  * [Ficha RePEc / IDEAS](https://ideas.repec.org/p/ecb/ecbwps/20080966.html)

---

## 6. Carter & Kohn (1994) / Giannone, Reichlin & Small (2008)
* **Título 1 (Algoritmo de Estados Latentes):** Carter, C. K., & Kohn, R. (1994). *On Gibbs Sampling for State Space Models*. *Biometrika*, 81(3), 541–553.
  * **Rol Metodológico:** Algoritmo *Forward Filtering Backward Smoothing* (FFBS) para la extracción exacta del vector de estados latentes dentro del Gibbs Sampler.
  * **Enlaces:** [DOI Oficial Biometrika](https://doi.org/10.1093/biomet/81.3.541) | [JSTOR](https://www.jstor.org/stable/2337125)
* **Título 2 (Nowcasting en Tiempo Real):** Giannone, D., Reichlin, L., & Small, D. (2008). *Nowcasting: The Real-Time Informational Content of Macroeconomic Data*. *Journal of Monetary Economics*, 55(4), 665–676 (FEDS Working Paper 2005-42).
  * **Rol Metodológico:** Marco analítico formal para resolver el problema de asincronía en el calendario de publicaciones macroeconómicas (*ragged edge*).
  * **Archivos Locales:**
    * PDF disponible en: `fuentes/Giannone_Reichlin_Small_2006_Nowcasting.pdf`
  * **Enlaces:** [DOI Oficial (Elsevier)](https://doi.org/10.1016/j.jmoneco.2008.05.010) | [Ficha RePEc / IDEAS](https://ideas.repec.org/a/eee/moneco/v55y2008i4p665-676.html)
