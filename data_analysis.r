# data_analysis.r

## Load Packages ---------------------------------------------------
library(tidyverse)
library(knitr)
library(ggpubr)

## Load Data ---------------------------------------------------
df <- read.csv("data_deposit/UB-ERI Gap Analysis – Responses - Responses.csv")

## Clean Data ---------------------------------------------------
# Remove duplicates
df <- df %>%
    select(-timestamp) %>%
    distinct()

## Analyze Section 2: Organization Information
# Determine which organizations participated and how many
unique_organizations <- nrow(df)
unique_organization_names <- unique(df$organizationName)
result_unique_organizations <- paste0(
    "Participating organizations totaled ",
    unique_organizations,
    ", including ",
    combine_words(unique_organization_names)
)

## Analyze Section 3: Biodiversity Monitoring Activities
# Determine the proportion of organizations that do biodiveristy monitoring, and which don't
proportion_does_biodiversity_monitoring <- round(mean(df$doesMonitoring == "Yes", na.rm = TRUE), 2)
organizations_do_not_do_biodiversity_monitoring <- filter(df, df$doesMonitoring == "No")$organizationName
result_proportion_does_biodiversity_monitoring <- paste0(
    "Proportion of organizations doing biodiversity monitoring is ",
    proportion_does_biodiversity_monitoring,
    ", with the following organizations reporting they do not participate in biodiversity monitoring: ",
    combine_words(organizations_do_not_do_biodiversity_monitoring)
)
# Examine monitoring areas for taxa
df_long_taxa <- select(df, monitoringAreas) %>%
    mutate(resp_id = row_number()) %>%
    separate_rows(monitoringAreas, sep = ";\\s*") %>%
    mutate(monitoringAreas = str_trim(monitoringAreas)) %>%
    filter(monitoringAreas != "")
levels_split_taxa <- str_split_fixed(df_long_taxa$monitoringAreas, " - ", 3)
df_long_taxa <- df_long_taxa %>%
    mutate(
        level1 = str_trim(levels_split_taxa[, 1]),
        level2 = str_trim(levels_split_taxa[, 2]),
        level3 = str_trim(levels_split_taxa[, 3]),
        depth  = 1 + (level2 != "") + (level3 != "")
    )
counts_taxa <- df_long_taxa %>%
    count(level1, level2, level3, depth, name = "n")
taxon_order <- c(
    "Birds", "Mammals", "Fish", "Marine Invertebrates",
    "Freshwater Macroinvertebrate", "Terrestrial Macroinvertebrates",
    "Amphibians", "Reptiles", "Plants", "Other"
)
subtaxon_order_mammals <- c(
    "Bats", "Marine mammals", "Primates",
    "Other small mammals (e.g., hispid cotton rats)",
    "Other medium-sized mammals (e.g., paca)",
    "Other large mammals (e.g., jaguars)"
)
subtaxon_order_fish <- c(
    "Freshwater fish", "Marine fish"
)
subtaxon_order_marine_invertebrates <- c(
    "Conch", "Crustaceans", "Mollusks",
    "Crabs", "Lobsters", "Corals", "Urchins",
    "Sea Cucumbers", "Other" # need to figure out how to handle other
)
subtaxon_order_terrestrial_macroinvertebrates <- c(
    "Agricultural Pest Insects (e.g., stem-borers)",
    "Disease Vector Insects (e.g., mosquitoes, screwworms)",
    "Butterflies", "Bees", "Other" # need to figure out how to handle other
)
subtaxon_order_reptiles <- c(
    "Snakes", "Crocodiles", "Turtles", "Other" # need to figure out how to handle other
)
subtaxon_order_plants <- c(
    "Mangroves", "Seaweed/Seagrass/Macroalgae", "Hardwood Trees",
    "Epiphytes", "Other" # need to figure out how to handle other
)

fun_build_rows <- function(counts_taxa, taxon_order, base_width = 0.9, shrink = 0.55) {
    rows <- list()
    for (t in taxon_order) {
        top_row <- counts_taxa %>% filter(level1 == t, depth == 1)
        if (nrow(top_row) == 0) next # skip taxa nobody selected
        rows[[length(rows) + 1]] <- tibble(
            category = t, n = top_row$n, depth = 1, width = base_width, family = t
        )
        children <- counts_taxa %>%
            filter(level1 == t, depth == 2) %>%
            arrange(desc(n))
        for (i in seq_len(nrow(children))) {
            child <- children$level2[i]
            rows[[length(rows) + 1]] <- tibble(
                category = child, n = children$n[i], depth = 2, width = base_width * shrink, family = t
            )
            grandchildren <- counts_taxa %>%
                filter(level1 == t, level2 == child, depth == 3) %>%
                arrange(desc(n))
            for (j in seq_len(nrow(grandchildren))) {
                rows[[length(rows) + 1]] <- tibble(
                    category = grandchildren$level3[j], n = grandchildren$n[j],
                    depth = 3, width = base_width * shrink^2, family = t
                )
            }
        }
    }
    bind_rows(rows)
}
df_long_taxa_plot <- fun_build_rows(counts_taxa, taxon_order) %>%
    mutate(depth = factor(depth))
var_family_gap <- 0.5
df_long_taxa_plot <- df_long_taxa_plot %>%
    mutate(
        touch_step = width / 2 + lag(width) / 2,
        step = case_when(
            row_number() == 1 ~ 0,
            family != lag(family) ~ touch_step + var_family_gap,
            TRUE ~ touch_step
        ),
        y_pos = -cumsum(step)
    )
result_plot_taxa <- ggplot(df_long_taxa_plot, aes(x = n, y = y_pos, width = width, fill = depth)) +
    geom_col(orientation = "y", color = "black") +
    scale_fill_manual(
        values = c("1" = "#382e6b", "2" = "#766da7", "3" = "#b1abd1"),
        guide = "none"
    ) +
    scale_y_continuous(
        breaks = df_long_taxa_plot$y_pos, labels = df_long_taxa_plot$category,
        expand = expansion(add = var_family_gap)
    ) +
    labs(
        x = "Number of responses", y = "Grouping"
    ) +
    theme_pubclean() +
    theme(axis.text = element_text(size = 22), axis.title = element_text(size = 25))
result_caption_plot_taxa <- paste0(
    "Figure 1. Bar chart of how many surveyed organizations (n = ",
    unique_organizations,
    ") survey each biodiversity grouping, with parent groupings attached to lower-level children groupings. "
)
ggsave("outputs/result_plot_taxa.jpeg", result_plot_taxa,
    units = "in", height = 23, width = 18
)







## Present Results
result_unique_organizations
result_proportion_does_biodiversity_monitoring
result_plot_taxa
result_caption_plot_taxa
