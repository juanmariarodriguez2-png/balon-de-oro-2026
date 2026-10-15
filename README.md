# ⚽ Predicción del Balón de Oro 2026 con datos

Modelo propio para estimar quién ganará el Balón de Oro 2026 (gala del 26 de octubre de 2026, Londres), a partir de las estadísticas de los 30 nominados durante el periodo evaluado (3 de agosto de 2025 – 19 de julio de 2026).

![Ranking del modelo](img/ranking_balon_oro_2026.png)

## Resultado

| # | Jugador | Índice (0-100) |
|---|---|---|
| 1 | **Harry Kane** | **65,9** |
| 2 | Michael Olise | 57,4 |
| 3 | Ousmane Dembélé | 56,2 |
| 4 | Khvicha Kvaratskhelia | 52,3 |
| 5 | Vitinha | 52,2 |
| 6 | Lionel Messi | 52,1 |
| 7 | Lamine Yamal | 50,1 |

**Mi apuesta personal: Lamine Yamal.** El modelo mide rendimiento y títulos, pero el premio lo votan 100 periodistas, y la narrativa y la visibilidad mediática no aparecen en ninguna estadística.

## Metodología

El índice combina tres bloques, cada uno normalizado de 0 a 100 frente al mejor de los 30 nominados:

1. **Títulos (40%)**: cada trofeo puntúa según su peso (Champions 10, liga top-5 6, copa nacional 3, Intercontinental 2, supercopas 1), multiplicado por la participación del jugador (minutos / 3.500, con tope en 1).
2. **Rendimiento individual (35%)**: 50% goles + asistencias (club y Mundial) y 50% premios de la temporada.
3. **Mundial 2026 (25%)**: 60% ronda alcanzada ajustada por minutos, 40% premios del torneo más 0,5 puntos por gol o asistencia.

Los datos no encontrados cuentan como 0 y están señalados en el CSV. La conducta deportiva no se puntúa porque no hay datos comparables.

## Análisis de sensibilidad

¿Cambia el ganador si cambian los pesos? El script en R recalcula el ranking con 7 combinaciones distintas (títulos / individual / Mundial). Kane es 1.º en las 7; Yamal oscila entre el 9.º y el 5.º puesto y sube cuando el Mundial pesa más.

![Bump chart de sensibilidad](img/bump_chart_balon_oro_2026.png)

## Archivos

| Archivo | Contenido |
|---|---|
| `balon_oro_2026_30_nominados.csv` | Datos de los 30 nominados (separador `;`) y puntuaciones intermedias |
| `bump_chart_balon_oro_2026.R` | Script de R: calcula el índice con las 7 combinaciones y genera el gráfico |
| `rankings_por_pesos.csv` | Salida del script: índice y posición de cada jugador en cada combinación |
| `informe_prediccion.md` | Informe completo con la comparación frente a casas de apuestas y las fuentes |

## Cómo reproducirlo

```r
install.packages(c("tidyverse", "ragg"))
```

```bash
Rscript bump_chart_balon_oro_2026.R
```

El script lee el CSV de su misma carpeta y genera `bump_chart_balon_oro_2026.png` y `rankings_por_pesos.csv`.

## Limitaciones

- No mide el juego sin balón ni la construcción (por eso Rodri, mejor jugador del Mundial, queda 21.º).
- Algunas cifras varían según la fuente (por ejemplo, las asistencias de Olise: 26 Opta, 29 Bundesliga, 31 Transfermarkt); se ha usado Opta.
- Modelo propio y no oficial, con fines de análisis.

## Fuentes

Opta Analyst, FIFA, UEFA, Transfermarkt y webs oficiales de ligas y clubes. Referencias completas en `informe_prediccion.md`.

---

**Juan Rodríguez** · Economía + Data Science, CUNEF
