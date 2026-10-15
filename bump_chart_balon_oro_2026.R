# =============================================================================
# Balón de Oro 2026: sensibilidad del índice a los pesos (bump chart del top 10)
# Entrada : balon_oro_2026_30_nominados.csv  (sep ";", UTF-8 con BOM, "N/D" = dato no encontrado)
# Salida  : bump_chart_balon_oro_2026.png (1080x1350 px) + rankings_por_pesos.csv
# Requiere: tidyverse, ragg
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
})

# Carpeta del script (funciona con Rscript y con source()); si no, directorio actual
get_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", args[grepl("^--file=", args)])
  if (length(f)) return(dirname(normalizePath(f)))
  if (!is.null(sys.frame(1)$ofile)) return(dirname(normalizePath(sys.frame(1)$ofile)))
  getwd()
}
base_dir <- get_dir()

# ---- 1. Datos ---------------------------------------------------------------
raw <- read_delim(
  file.path(base_dir, "balon_oro_2026_30_nominados.csv"),
  delim = ";", na = c("N/D", ""), show_col_types = FALSE,
  locale = locale(encoding = "UTF-8")
)
stopifnot(nrow(raw) == 30)

num0 <- function(x) replace_na(as.numeric(x), 0)   # N/D cuenta como 0 (regla del modelo)

d <- raw |>
  transmute(
    jugador        = Jugador,
    pts_titulos    = num0(pts_titulos),
    min_club       = as.numeric(`Min. club`),
    ga             = num0(`Goles club`) + num0(`Asist. club`) +
                     num0(`Goles Mundial`) + num0(`Asist. Mundial`),
    premios_temp   = num0(pts_premios_temporada),
    ronda_mundial  = num0(pts_ronda_mundial),
    partidos_mund  = num0(partidos_mundial),
    min_mundial    = as.numeric(`Min. Mundial`),
    premios_mund   = num0(pts_premios_mundial),
    ga_mundial     = num0(`Goles Mundial`) + num0(`Asist. Mundial`)
  ) |>
  mutate(
    # Participación en títulos de club: minutos/3500 (tope 1); sin dato -> 1
    part_club = if_else(is.na(min_club), 1, pmin(1, min_club / 3500)),
    # Participación en el Mundial: minutos / (70% de los minutos posibles); sin dato -> 1
    part_mund = case_when(
      partidos_mund == 0 ~ 0,
      is.na(min_mundial) ~ 1,
      TRUE ~ pmin(1, min_mundial / (0.7 * partidos_mund * 90))
    ),
    titulos_aj = pts_titulos * part_club,
    mund_indiv = premios_mund + 0.5 * ga_mundial,
    # Pilares normalizados 0-100 frente al mejor de los 30
    P_titulos    = 100 * titulos_aj / max(titulos_aj),
    P_individual = 50 * ga / max(ga) + 50 * premios_temp / max(premios_temp),
    P_mundial    = 0.6 * ronda_mundial * part_mund + 40 * mund_indiv / max(mund_indiv)
  )

# ---- 2. Las 7 combinaciones de pesos (títulos / individual / Mundial) ---------
pesos <- tribble(
  ~combo,       ~w_t, ~w_i, ~w_m,
  "40/35/25",   0.40, 0.35, 0.25,   # caso base
  "30/40/30",   0.30, 0.40, 0.30,
  "50/30/20",   0.50, 0.30, 0.20,
  "34/33/33",   0.34, 0.33, 0.33,
  "25/50/25",   0.25, 0.50, 0.25,
  "30/35/35",   0.30, 0.35, 0.35,
  "40/25/35",   0.40, 0.25, 0.35
) |>
  mutate(combo_lab = if_else(row_number() == 1, paste0(combo, "\n(base)"), combo),
         combo_lab = factor(combo_lab, levels = combo_lab))

rankings <- pesos |>
  cross_join(d) |>
  mutate(indice = w_t * P_titulos + w_i * P_individual + w_m * P_mundial) |>
  group_by(combo_lab) |>
  mutate(rank = rank(-indice, ties.method = "first")) |>
  ungroup()

write_excel_csv2(
  rankings |> select(combo, jugador, indice, rank, P_titulos, P_individual, P_mundial) |>
    mutate(across(where(is.numeric), \(x) round(x, 1))) |> arrange(combo, rank),
  file.path(base_dir, "rankings_por_pesos.csv")
)

# Control en consola
rankings |> filter(rank <= 5) |> arrange(combo_lab, rank) |>
  group_by(combo) |>
  summarise(top5 = paste0(jugador, " (", round(indice, 1), ")", collapse = " > "), .groups = "drop") |>
  print(width = Inf)

# ---- 3. Bump chart del top 10 ------------------------------------------------
top10 <- rankings |> filter(rank <= 10)
jug_top <- unique(top10$jugador)

oro    <- "#C9A227"
yamal  <- "#A50044"   # granate blaugrana
gris   <- "#9AA3AE"

estilo <- tibble(jugador = jug_top) |>
  mutate(grupo = case_when(jugador == "Harry Kane"   ~ "Kane",
                           jugador == "Lamine Yamal" ~ "Yamal",
                           TRUE ~ "Resto"))
plot_df <- top10 |> left_join(estilo, by = "jugador") |>
  mutate(grupo = factor(grupo, levels = c("Resto", "Yamal", "Kane"))) |>
  arrange(grupo)   # Kane y Yamal se dibujan encima

cols   <- c(Kane = oro, Yamal = yamal, Resto = gris)
lwds   <- c(Kane = 2.6, Yamal = 2.0, Resto = 0.9)

# Para que las líneas se corten cuando un jugador sale del top 10:
# agrupamos por tramos consecutivos de combinaciones
plot_df <- plot_df |>
  group_by(jugador) |>
  arrange(as.integer(combo_lab), .by_group = TRUE) |>
  mutate(tramo = cumsum(c(1, diff(as.integer(combo_lab)) > 1))) |>
  ungroup() |>
  arrange(grupo)   # Kane y Yamal se dibujan encima

n_combo <- nlevels(pesos$combo_lab)
# Etiquetas cortas (apellido) para que no se corten en los márgenes
plot_df <- plot_df |> mutate(etiqueta = word(jugador, -1))
lab_izq <- plot_df |> filter(as.integer(combo_lab) == 1)
lab_der <- plot_df |> filter(as.integer(combo_lab) == n_combo)

p <- ggplot(plot_df, aes(x = combo_lab, y = rank,
                         group = interaction(jugador, tramo), colour = grupo)) +
  geom_line(aes(linewidth = grupo), lineend = "round") +
  geom_point(aes(size = grupo), shape = 21, fill = "white", stroke = 1.4) +
  geom_text(aes(label = rank), size = 2.6, colour = "grey20", fontface = "bold") +
  geom_text(data = lab_izq, aes(label = etiqueta), hjust = 1, nudge_x = -0.22,
            size = 3.4, fontface = "bold", show.legend = FALSE) +
  geom_text(data = lab_der, aes(label = etiqueta), hjust = 0, nudge_x = 0.22,
            size = 3.4, fontface = "bold", show.legend = FALSE) +
  scale_colour_manual(values = cols, guide = "none") +
  scale_fill_manual(values = cols, guide = "none") +
  scale_linewidth_manual(values = lwds, guide = "none") +
  scale_size_manual(values = c(Kane = 6.5, Yamal = 6, Resto = 5), guide = "none") +
  scale_y_reverse(breaks = 1:10, limits = c(10.4, 0.6), expand = c(0, 0)) +
  scale_x_discrete(expand = expansion(add = c(1.5, 1.6))) +
  coord_cartesian(clip = "off") +
  labs(
    title    = "Balón de Oro 2026:
¿cambia el ganador si cambian los pesos?",
    subtitle = paste0(
      "Posición en el top 10 del índice según 7 combinaciones de pesos\n",
      "(% títulos / % rendimiento individual / % Mundial). ",
      "Kane es 1.º en las 7."
    ),
    x = "Combinación de pesos (títulos / individual / Mundial)",
    y = NULL,
    caption = paste0(
      "Periodo: 3 ago 2025 – 19 jul 2026. Datos: Opta Analyst, Transfermarkt, FIFA, UEFA, ligas y clubes.\n",
      "Datos no encontrados = 0. Títulos ponderados por minutos jugados. Modelo propio, no oficial."
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.background    = element_rect(fill = "#FAFAF7", colour = NA),
    panel.background   = element_rect(fill = "#FAFAF7", colour = NA),
    panel.grid.minor   = element_blank(),
    panel.grid.major.x = element_line(colour = "grey88", linewidth = 0.4),
    panel.grid.major.y = element_blank(),
    plot.title         = element_text(face = "bold", size = 18, colour = "grey10", lineheight = 1.05),
    plot.subtitle      = element_text(size = 11.5, colour = "grey30", lineheight = 1.1,
                                      margin = margin(b = 14)),
    plot.caption       = element_text(size = 8.5, colour = "grey45", hjust = 0, lineheight = 1.1),
    plot.title.position   = "plot",
    plot.caption.position = "plot",
    axis.text.x        = element_text(size = 9.5, colour = "grey25", face = "bold"),
    axis.text.y        = element_text(size = 10, colour = "grey40"),
    axis.title         = element_text(size = 10, colour = "grey40"),
    plot.margin        = margin(24, 20, 18, 20)
  )

ggsave(
  file.path(base_dir, "bump_chart_balon_oro_2026.png"), p,
  width = 1080, height = 1350, units = "px", dpi = 150,
  device = ragg::agg_png, bg = "#FAFAF7"
)
message("PNG guardado en: ", file.path(base_dir, "bump_chart_balon_oro_2026.png"))
