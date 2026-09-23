# data_analysis.r

## Load Packages ---------------------------------------------------
library(tidyverse)
library(knitr)
library(ggpubr)
library(ggtext)

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
fun_clean_other <- function(x) {
    x <- str_trim(x)
    x <- na_if(x, "")
    str_to_title(x)
}
other_field_map <- tribble(
    ~column, ~level1, ~level2, ~is_new_taxon,
    "monitoringAreasOther", "Other", NA_character_, TRUE,
    "marineInvertebratesOther", "Marine Invertebrates", NA_character_, FALSE,
    "terrestrialInvertebratesOther", "Terrestrial Macroinvertebrates", NA_character_, FALSE,
    "reptilesOther", "Reptiles", NA_character_, FALSE,
    "plantsOther", "Plants", NA_character_, FALSE,
    "freshwaterMacroSpecify", "Freshwater Macroinvertebrate", NA_character_, FALSE,
    "amphibiansSpecify", "Amphibians", NA_character_, FALSE,
    "marineFishOther", "Fish", "Marine fish", FALSE
)
fun_build_other_counts <- function(df, other_field_map) {
    rows <- list()
    for (i in seq_len(nrow(other_field_map))) {
        column <- other_field_map$column[i]
        level1 <- other_field_map$level1[i]
        level2 <- other_field_map$level2[i]
        is_new_taxon <- other_field_map$is_new_taxon[i]
        cleaned <- fun_clean_other(df[[column]])
        cleaned <- cleaned[!is.na(cleaned)]
        if (length(cleaned) == 0) next
        response_counts <- tibble(response = cleaned) %>% count(response, name = "n")
        if (is.na(level2)) {
            if (is_new_taxon) {
                rows[[length(rows) + 1]] <- tibble(
                    level1 = level1, level2 = "", level3 = "", depth = 1, n = length(cleaned)
                )
            }
            rows[[length(rows) + 1]] <- tibble(
                level1 = level1, level2 = response_counts$response, level3 = "",
                depth = 2, n = response_counts$n
            )
        } else {
            rows[[length(rows) + 1]] <- tibble(
                level1 = level1, level2 = level2, level3 = response_counts$response,
                depth = 3, n = response_counts$n
            )
        }
    }
    bind_rows(rows)
}
counts_taxa <- bind_rows(counts_taxa, fun_build_other_counts(df, other_field_map))
taxon_order <- c(
    "Birds", "Mammals", "Fish", "Marine Invertebrates",
    "Freshwater Macroinvertebrate", "Terrestrial Macroinvertebrates",
    "Amphibians", "Reptiles", "Plants", "Other"
)
subtaxon_order_mammals <- c(
    "Bats", "Marine mammals", "Primates",
    "Other small mammals (e.g., hispid cotton rat)",
    "Other medium-sized mammals (e.g., paca)",
    "Other large mammals (e.g., jaguars)"
)
subtaxon_order_fish <- c(
    "Freshwater fish", "Marine fish"
)
subtaxon_order_marine_invertebrates <- c(
    "Conch", "Crustaceans", "Mollusks",
    "Crabs", "Lobsters", "Corals", "Urchins",
    "Sea Cucumbers"
)
subtaxon_order_terrestrial_macroinvertebrates <- c(
    "Agricultural Pest Insects",
    "Disease Vector Insects",
    "Butterflies", "Bees"
)
subtaxon_order_reptiles <- c(
    "Snakes", "Crocodiles", "Turtles"
)
subtaxon_order_plants <- c(
    "Mangroves", "Seaweed/Seagrass/Macroalgae", "Hardwood Trees",
    "Epiphytes"
)
subtaxon_orders <- list(
    "Mammals" = subtaxon_order_mammals,
    "Fish" = subtaxon_order_fish,
    "Marine Invertebrates" = subtaxon_order_marine_invertebrates,
    "Terrestrial Macroinvertebrates" = subtaxon_order_terrestrial_macroinvertebrates,
    "Reptiles" = subtaxon_order_reptiles,
    "Plants" = subtaxon_order_plants
)
fun_build_rows <- function(counts_taxa, taxon_order, subtaxon_orders = list(), base_width = 0.9, shrink = 0.55) {
    rows <- list()
    for (t in taxon_order) {
        top_row <- counts_taxa %>% filter(level1 == t, depth == 1)
        if (nrow(top_row) == 0) next # skip taxa nobody selected
        rows[[length(rows) + 1]] <- tibble(
            category = t, n = top_row$n, depth = 1, width = base_width, family = t
        )
        children <- counts_taxa %>% filter(level1 == t, depth == 2)
        subtaxon_order <- subtaxon_orders[[t]]
        if (!is.null(subtaxon_order)) {
            children <- children %>% arrange(match(level2, subtaxon_order), desc(n))
        } else {
            children <- children %>% arrange(desc(n))
        }
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
df_long_taxa_plot <- fun_build_rows(counts_taxa, taxon_order, subtaxon_orders) %>%
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
label_size_pt <- c("1" = 22, "2" = 18, "3" = 14)
df_long_taxa_plot <- df_long_taxa_plot %>%
    mutate(category_label = paste0(
        "<span style='font-size:", label_size_pt[as.character(depth)], "pt'>",
        category, "</span>"
    ))
result_plot_taxa <- ggplot(df_long_taxa_plot, aes(x = n, y = y_pos, width = width, fill = depth)) +
    geom_col(orientation = "y", color = "black") +
    scale_fill_manual(
        values = c("1" = "#382e6b", "2" = "#766da7", "3" = "#b1abd1"),
        guide = "none"
    ) +
    scale_y_continuous(
        breaks = df_long_taxa_plot$y_pos, labels = df_long_taxa_plot$category_label,
        expand = expansion(add = var_family_gap)
    ) +
    labs(
        x = "Number of responses", y = "Grouping"
    ) +
    theme_pubclean() +
    theme(
        axis.text.y = element_markdown(size = 22),
        axis.text.x = element_text(size = 22),
        axis.title = element_text(size = 25)
    )
result_caption_plot_taxa <- paste0(
    "Figure 1. Bar chart of how many surveyed organizations (n = ",
    unique_organizations,
    ") survey each biodiversity grouping, with parent groupings attached to lower-level children groupings. "
)
ggsave("outputs/result_plot_taxa.jpeg", result_plot_taxa,
    units = "in", height = 23, width = 18
)

## Analyze Section 4: Ecosystems
# Examine monitoring ecosystems
ecosystems_order <- c(
    "Open Sea", "Deep Reef", "Coral Reef", "Lagoon",
    "Sparse Algae", "Seagrass", "Mangrove and littoral forest", "Urban",
    "Agricultural Areas", "Riparian", "Wetland", "Shrubland",
    "Broad-leaved Forest", "Pine Forest", "Savannah"
)
df_ecosystems <- df %>%
    select(ecosystems) %>%
    separate_rows(ecosystems, sep = ";\\s*") %>%
    mutate(ecosystems = str_trim(ecosystems)) %>%
    filter(ecosystems != "") %>%
    group_by(ecosystems) %>%
    summarise(n = n(), .groups = "drop") %>%
    mutate(ecosystems = factor(ecosystems, levels = ecosystems_order))
result_plot_ecosystems <- ggplot(df_ecosystems, aes(x = n, y = ecosystems)) +
    geom_col(orientation = "y", color = "black", fill = "#382e6b") +
    labs(
        x = "Number of responses", y = "Ecosystem"
    ) +
    theme_pubclean() +
    theme(
        axis.text.y = element_text(size = 22),
        axis.text.x = element_text(size = 22),
        axis.title = element_text(size = 25)
    )
result_caption_plot_ecosystems <- paste0(
    "Figure 2. Bar chart of how many surveyed organizations (n = ",
    unique_organizations, ") survey each ecosystem."
)
ggsave("outputs/result_plot_ecosystems.jpeg", result_plot_ecosystems,
    units = "in", height = 23, width = 18
)

## Analyze Section 5: Research Projects
# TO DO

## Analyze Section 6: Ecosystem Health
# TO DO
df_ecosystem_health <- df %>%
    select(ecosystemHealthData) %>%
    separate_rows(ecosystemHealthData, sep = ";\\s*") %>%
    mutate(ecosystemHealthData = str_trim(ecosystemHealthData)) %>%
    filter(ecosystemHealthData != "") %>%
    group_by(ecosystemHealthData) %>%
    summarise(n = n(), .groups = "drop")
result_plot_ecosystem_health <- ggplot(df_ecosystem_health, aes(x = n, y = ecosystemHealthData)) +
    geom_col(orientation = "y", color = "black", fill = "#382e6b") +
    labs(
        x = "Number of responses", y = "Ecosystem Health Data"
    ) +
    theme_pubclean() +
    theme(
        axis.text.y = element_text(size = 22),
        axis.text.x = element_text(size = 22),
        axis.title = element_text(size = 25)
    )
result_caption_plot_ecosystem_health <- paste0(
    "Figure 3. Bar chart of how many surveyed organizations (n = ",
    unique_organizations, ") collect different types of ecosystem health data."
)
ggsave("outputs/result_plot_ecosystem_health.jpeg", result_plot_ecosystem_health,
    units = "in", height = 23, width = 18
)

## Analyze Section 7: Enforcement
# TO DO

## Analyze Section 8: Mainstreaming
# TO DO

## Analyze Section 9: Collaboration & Challenges
# TO DO

## Analyze Section 10: Technology & Skill Gaps
# TO DO

## Analyze Section 11: Data Management
# TO DO

## Analyze Section 12: Data Sharing
# TO DO

## Analyze Section 13: National Biodiversity Coordination
# TO DO

## Analyze Section 14: Significance & Interest
# TO DO

## Present Results
result_unique_organizations
result_proportion_does_biodiversity_monitoring
result_plot_taxa
result_caption_plot_taxa
result_plot_ecosystems
result_caption_plot_ecosystems
