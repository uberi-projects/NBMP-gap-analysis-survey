# data_analysis.r

## Load Packages ---------------------------------------------------
library(tidyverse)
library(knitr)
library(ggpubr)
library(ggtext)

## Load Data ---------------------------------------------------
df <- read.csv("data_deposit/UB-ERI Gap Analysis – Responses - Responses.csv")

## Define Functions ---------------------------------------------------
fun_clean_text <- function(x) {
    x <- str_trim(x)
    x <- na_if(x, "")
    str_to_title(x)
}

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
        depth  = 1 + (level2 != "") + (level3 != ""),
        level1 = fun_clean_text(level1),
        level2 = fun_clean_text(level2),
        level3 = fun_clean_text(level3)
    )
counts_taxa <- df_long_taxa %>%
    count(level1, level2, level3, depth, name = "n") %>%
    mutate(is_other = FALSE)
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
        cleaned <- fun_clean_text(df[[column]])
        cleaned <- cleaned[!is.na(cleaned)]
        if (length(cleaned) == 0) next
        response_counts <- tibble(response = cleaned) %>% count(response, name = "n")
        if (is.na(level2)) {
            if (is_new_taxon) {
                rows[[length(rows) + 1]] <- tibble(
                    level1 = level1, level2 = "", level3 = "", depth = 1, n = length(cleaned),
                    is_other = TRUE
                )
            }
            rows[[length(rows) + 1]] <- tibble(
                level1 = level1, level2 = response_counts$response, level3 = "",
                depth = 2, n = response_counts$n, is_other = TRUE
            )
        } else {
            rows[[length(rows) + 1]] <- tibble(
                level1 = level1, level2 = level2, level3 = response_counts$response,
                depth = 3, n = response_counts$n, is_other = TRUE
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
    "Bats", "Marine Mammals", "Primates",
    "Other Small Mammals (E.g., Hispid Cotton Rat)",
    "Other Medium-Sized Mammals (E.g., Paca)",
    "Other Large Mammals (E.g., Jaguars)"
)
subtaxon_order_fish <- c(
    "Freshwater Fish", "Marine Fish"
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
            category = t, n = top_row$n, depth = 1, width = base_width, family = t,
            is_other = top_row$is_other
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
                category = child, n = children$n[i], depth = 2, width = base_width * shrink, family = t,
                is_other = children$is_other[i]
            )
            grandchildren <- counts_taxa %>%
                filter(level1 == t, level2 == child, depth == 3) %>%
                arrange(desc(n))
            for (j in seq_len(nrow(grandchildren))) {
                rows[[length(rows) + 1]] <- tibble(
                    category = grandchildren$level3[j], n = grandchildren$n[j],
                    depth = 3, width = base_width * shrink^2, family = t,
                    is_other = grandchildren$is_other[j]
                )
            }
        }
    }
    bind_rows(rows)
}
df_long_taxa_plot <- fun_build_rows(counts_taxa, taxon_order, subtaxon_orders) %>%
    mutate(
        depth = factor(depth),
        fill_group = if_else(is_other, paste0("other_", depth), as.character(depth))
    )
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
result_plot_taxa <- ggplot(df_long_taxa_plot, aes(x = n, y = y_pos, width = width, fill = fill_group)) +
    geom_col(orientation = "y", color = "black") +
    scale_fill_manual(
        values = c(
            "1" = "#382e6b", "2" = "#766da7", "3" = "#b1abd1",
            "other_1" = "#456b2e", "other_2" = "#729a5a", "other_3" = "#b4cca6"
        ),
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
    ") survey each biodiversity grouping, with parent groupings attached to lower-level children groupings. ",
    " Indigo bars are selected options from the survey, and green are custom responses supplied by the surveyed organization."
)
ggsave("outputs/result_plot_taxa.jpeg", result_plot_taxa,
    units = "in", height = 23, width = 18
)

## Analyze Section 4: Ecosystems
# Examine monitoring ecosystems
ecosystems_order <- c(
    "Open Sea", "Deep Reef", "Coral Reef", "Lagoon",
    "Sparse Algae", "Seagrass", "Mangrove And Littoral Forest", "Urban",
    "Agricultural Areas", "Riparian", "Wetland", "Shrubland",
    "Broad-Leaved Forest", "Pine Forest", "Savannah"
)
df_ecosystems <- df %>%
    select(ecosystems) %>%
    separate_rows(ecosystems, sep = ";\\s*") %>%
    mutate(ecosystems = fun_clean_text(ecosystems)) %>%
    filter(!is.na(ecosystems)) %>%
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
# Investigate types of data collected on ecosystem health
ecosystem_health_fixed_order <- c(
    "Species Richness", "Presence/Absence Of Indicator Or Target Species", "Population Size",
    "Freshwater Water Quality", "Marine Water Quality", "Air Quality", "Soil Quality",
    "Nutrient Content/Levels", "Habitat Structure", "Habitat Patch Size", "Connectivity",
    "Presence Of Diseases", "Extent Of Diseases", "Productivity", "Harvest Quotas"
)
df_ecosystem_health <- df %>%
    select(ecosystemHealthData) %>%
    separate_rows(ecosystemHealthData, sep = ";\\s*") %>%
    mutate(ecosystemHealthData = fun_clean_text(ecosystemHealthData)) %>%
    filter(!is.na(ecosystemHealthData), ecosystemHealthData != "Other") %>%
    group_by(ecosystemHealthData) %>%
    summarise(n = n(), .groups = "drop") %>%
    mutate(is_other = FALSE)
ecosystem_health_other <- fun_clean_text(df$ecosystemHealthDataOther)
ecosystem_health_other <- ecosystem_health_other[!is.na(ecosystem_health_other)]
df_ecosystem_health_other <- tibble(ecosystemHealthData = ecosystem_health_other) %>%
    count(ecosystemHealthData, name = "n") %>%
    mutate(is_other = TRUE)
df_ecosystem_health <- bind_rows(df_ecosystem_health, df_ecosystem_health_other) %>%
    mutate(ecosystemHealthData = if_else(ecosystemHealthData == "No", "None", ecosystemHealthData))
ecosystem_health_order <- rev(c(
    ecosystem_health_fixed_order,
    sort(unique(df_ecosystem_health_other$ecosystemHealthData)),
    "None"
))
df_ecosystem_health <- df_ecosystem_health %>%
    mutate(
        ecosystemHealthData = factor(ecosystemHealthData, levels = ecosystem_health_order),
        fill_category = case_when(
            ecosystemHealthData == "None" ~ "none",
            is_other ~ "other",
            TRUE ~ "normal"
        )
    )
result_plot_ecosystem_health <- ggplot(df_ecosystem_health, aes(x = n, y = ecosystemHealthData, fill = fill_category)) +
    geom_col(orientation = "y", color = "black") +
    scale_fill_manual(
        values = c("normal" = "#382e6b", "other" = "#456b2e", "none" = "#6b4b2e"),
        guide = "none"
    ) +
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
    unique_organizations,
    ") collect different types of ecosystem health data.",
    " Indigo bars are selected options from the survey, and green are custom responses supplied by the surveyed organization."
)
ggsave("outputs/result_plot_ecosystem_health.jpeg", result_plot_ecosystem_health,
    units = "in", height = 23, width = 18
)
# See how many organizations study degraded habitats
num_does_habitat_restoration_studying <- round(sum(df$habitatRestoration == "Yes", na.rm = TRUE), 2)
organizations_do_habitat_restoration_studying <- filter(df, df$habitatRestoration == "Yes")$organizationName
result_num_does_habitat_restoration_studying <- paste0(
    "The number of organizations collecting data on restoration of degraded habitats is ",
    num_does_habitat_restoration_studying,
    ", including: ",
    combine_words(organizations_do_habitat_restoration_studying)
)
# Investigate types of data collected on pollution
pollution_fixed_order <- c(
    "Water Pollution", "Air Pollution", "Noise Pollution",
    "Light Pollution", "Thermal Pollution"
)
df_pollution <- df %>%
    select(pollutionData) %>%
    separate_rows(pollutionData, sep = ";\\s*") %>%
    mutate(pollutionData = fun_clean_text(pollutionData)) %>%
    filter(!is.na(pollutionData), pollutionData != "Other") %>%
    group_by(pollutionData) %>%
    summarise(n = n(), .groups = "drop") %>%
    mutate(is_other = FALSE)
pollution_other <- fun_clean_text(df$pollutionDataOther)
pollution_other <- pollution_other[!is.na(pollution_other)]
df_pollution_other <- tibble(pollutionData = pollution_other) %>%
    count(pollutionData, name = "n") %>%
    mutate(is_other = TRUE)
df_pollution <- bind_rows(df_pollution, df_pollution_other) %>%
    mutate(pollutionData = if_else(pollutionData == "No", "None", pollutionData))
pollution_order <- rev(c(
    pollution_fixed_order,
    sort(unique(df_pollution_other$pollutionData)),
    "None"
))
df_pollution <- df_pollution %>%
    mutate(
        pollutionData = factor(pollutionData, levels = pollution_order),
        fill_category = case_when(
            pollutionData == "None" ~ "none",
            is_other ~ "other",
            TRUE ~ "normal"
        )
    )
result_plot_pollution <- ggplot(df_pollution, aes(x = n, y = pollutionData, fill = fill_category)) +
    geom_col(orientation = "y", color = "black") +
    scale_fill_manual(
        values = c("normal" = "#382e6b", "other" = "#456b2e", "none" = "#6b4b2e"),
        guide = "none"
    ) +
    labs(
        x = "Number of responses", y = "Pollution Data"
    ) +
    theme_pubclean() +
    theme(
        axis.text.y = element_text(size = 22),
        axis.text.x = element_text(size = 22),
        axis.title = element_text(size = 25)
    )
result_caption_plot_pollution <- paste0(
    "Figure 4. Bar chart of how many surveyed organizations (n = ",
    unique_organizations, ") collect different types of pollution data.",
    " Indigo bars are selected options from the survey, and green are custom responses supplied by the surveyed organization."
)
ggsave("outputs/result_plot_pollution.jpeg", result_plot_pollution,
    units = "in", height = 23, width = 18
)
# See how many organizations study invasive species
num_does_invasive_species_studying <- round(sum(df$invasiveSpecies == "Yes", na.rm = TRUE), 2)
df_invasives <- df %>%
    select(organizationName, invasiveSpecies, invasiveSpeciesWhich) %>%
    filter(invasiveSpecies == "Yes") %>%
    mutate(organizationsAndSpecies = paste0(organizationName, " (", invasiveSpeciesWhich, ")"))
result_num_does_invasive_species_studying <- paste0(
    "The number of organizations collecting data on invasive species is ",
    num_does_invasive_species_studying,
    ", including: ",
    combine_words(df_invasives$organizationsAndSpecies)
)
# Investigate types of data collected on ecosystem services
ecosystem_services_fixed_order <- c(
    "Access To Clean Water (Potable Water, River, Streams)",
    "Access To Forest Products (Wood, Game Meat, Medicinal Plants, Etc.)",
    "Access To Marine Products", "Eco-Businesses", "Carbon Stocks",
    "Shoreline Protection"
)
df_ecosystem_services <- df %>%
    select(ecosystemServicesTypes) %>%
    separate_rows(ecosystemServicesTypes, sep = ";\\s*") %>%
    mutate(ecosystemServicesTypes = fun_clean_text(ecosystemServicesTypes)) %>%
    filter(!is.na(ecosystemServicesTypes), ecosystemServicesTypes != "Other") %>%
    group_by(ecosystemServicesTypes) %>%
    summarise(n = n(), .groups = "drop") %>%
    mutate(is_other = FALSE)
ecosystem_services_other <- fun_clean_text(df$ecosystemServicesOther)
ecosystem_services_other <- ecosystem_services_other[!is.na(ecosystem_services_other)]
df_ecosystem_services_other <- tibble(ecosystemServicesTypes = ecosystem_services_other) %>%
    count(ecosystemServicesTypes, name = "n") %>%
    mutate(is_other = TRUE)
df_ecosystem_services_none <- tibble(
    ecosystemServicesTypes = "None",
    n = sum(df$ecosystemServices == "No", na.rm = TRUE),
    is_other = FALSE
)
df_ecosystem_services <- bind_rows(df_ecosystem_services, df_ecosystem_services_other, df_ecosystem_services_none)
ecosystem_services_order <- rev(c(
    ecosystem_services_fixed_order,
    sort(unique(df_ecosystem_services_other$ecosystemServicesTypes)),
    "None"
))
df_ecosystem_services <- df_ecosystem_services %>%
    mutate(
        ecosystemServicesTypes = factor(ecosystemServicesTypes, levels = ecosystem_services_order),
        fill_category = case_when(
            ecosystemServicesTypes == "None" ~ "none",
            is_other ~ "other",
            TRUE ~ "normal"
        )
    )
result_plot_ecosystem_services <- ggplot(df_ecosystem_services, aes(x = n, y = ecosystemServicesTypes, fill = fill_category)) +
    geom_col(orientation = "y", color = "black") +
    scale_fill_manual(
        values = c("normal" = "#382e6b", "other" = "#456b2e", "none" = "#6b4b2e"),
        guide = "none"
    ) +
    labs(
        x = "Number of responses", y = "Ecosystem Services Data"
    ) +
    theme_pubclean() +
    theme(
        axis.text.y = element_text(size = 22),
        axis.text.x = element_text(size = 22),
        axis.title = element_text(size = 25)
    )
result_caption_plot_ecosystem_services <- paste0(
    "Figure 5. Bar chart of how many surveyed organizations (n = ",
    unique_organizations, ") collect different types of ecosystem services data.",
    " Indigo bars are selected options from the survey, and green are custom responses supplied by the surveyed organization."
)
ggsave("outputs/result_plot_ecosystem_services.jpeg", result_plot_ecosystem_services,
    units = "in", height = 23, width = 18
)
# See how many organizations study relationship between communities and ecosystem services
num_does_comm_services_relations_studying <- round(sum(df$communityEcosystemServices == "Yes", na.rm = TRUE), 2)
organizations_do_comm_services_relations_studying <- filter(df, df$communityEcosystemServices == "Yes")$organizationName
result_num_does_comm_services_relations_studying <- paste0(
    "The number of organizations collecting data on relationship between communities and ecosystem services is ",
    num_does_comm_services_relations_studying,
    ", including: ",
    combine_words(organizations_do_comm_services_relations_studying)
)
# See how many organizations study climate resiliency
num_does_climate_resiliency <- round(sum(df$climateResiliency == "Yes, ecosystems" | df$climateResiliency == "Yes, communities", na.rm = TRUE), 2)
organizations_do_climate_resiliency_ecosystems <- filter(df, df$climateResiliency == "Yes, ecosystems")$organizationName
organizations_do_climate_resiliency_communities <- filter(df, df$climateResiliency == "Yes, communities")$organizationName
result_num_does_climate_resiliency <- paste0(
    "The number of organizations collecting data on climate resiliency is ",
    num_does_climate_resiliency,
    ", including: ",
    combine_words(organizations_do_climate_resiliency_communities),
    " focused on communities, and: ",
    combine_words(organizations_do_climate_resiliency_ecosystems),
    " focused on ecosystems."
)

## Analyze Section 7: Enforcement
# See how many organizations do enforcement
num_does_enforcement <- round(sum(df$doesEnforcement == "Yes", na.rm = TRUE), 2)
organizations_do_enforcement <- filter(df, df$doesEnforcement == "Yes")$organizationName
result_num_does_enforcement <- paste0(
    "The number of organizations doing enforcement is ",
    num_does_enforcement,
    ", including: ",
    combine_words(organizations_do_enforcement)
)
# Examine enforcement activities
df_long_enforcement <- select(df, enforcementActivities) %>%
    mutate(resp_id = row_number()) %>%
    separate_rows(enforcementActivities, sep = ";\\s*") %>%
    mutate(enforcementActivities = str_trim(enforcementActivities)) %>%
    filter(enforcementActivities != "")
levels_split_enforcement <- str_split_fixed(df_long_enforcement$enforcementActivities, ":\\s*", 2)
df_long_enforcement <- df_long_enforcement %>%
    mutate(
        level1 = fun_clean_text(levels_split_enforcement[, 1]),
        level2 = fun_clean_text(levels_split_enforcement[, 2]),
        has_child = levels_split_enforcement[, 2] != ""
    )
enforcement_family_order <- c(
    "Vehicle Patrols", "Foot Patrols", "Boat Patrols", "Risk-Based Patrols",
    "Camera Traps And Audio Sensors", "Technological Surveillance",
    "Prevention", "Detection", "Incident Response", "Demarcation",
    "Joint Operations", "Compliance"
)
fun_build_enforcement_rows <- function(df_long, family_order, base_width = 0.9, shrink = 0.55) {
    rows <- list()
    for (fam in family_order) {
        children <- df_long %>%
            filter(level1 == fam, has_child) %>%
            count(level2, name = "n") %>%
            arrange(desc(n))
        if (nrow(children) == 0) {
            top_n <- df_long %>%
                filter(level1 == fam, !has_child) %>%
                nrow()
            if (top_n == 0) next
            rows[[length(rows) + 1]] <- tibble(
                category = fam, n = top_n, depth = 1, width = base_width, family = fam
            )
        } else {
            top_n <- df_long %>%
                filter(level1 == fam, has_child) %>%
                distinct(resp_id) %>%
                nrow()
            rows[[length(rows) + 1]] <- tibble(
                category = fam, n = top_n, depth = 1, width = base_width, family = fam
            )
            for (i in seq_len(nrow(children))) {
                rows[[length(rows) + 1]] <- tibble(
                    category = children$level2[i], n = children$n[i], depth = 2,
                    width = base_width * shrink, family = fam
                )
            }
        }
    }
    bind_rows(rows)
}
df_long_enforcement_plot <- fun_build_enforcement_rows(df_long_enforcement, enforcement_family_order)
var_family_gap_enforcement <- 0.5
df_long_enforcement_plot <- df_long_enforcement_plot %>%
    mutate(
        touch_step = width / 2 + lag(width) / 2,
        step = case_when(
            row_number() == 1 ~ 0,
            family != lag(family) ~ touch_step + var_family_gap_enforcement,
            TRUE ~ touch_step
        ),
        y_pos = -cumsum(step)
    )
label_size_pt_enforcement <- c("1" = 22, "2" = 18)
df_long_enforcement_plot <- df_long_enforcement_plot %>%
    mutate(
        depth = factor(depth),
        category_label = paste0(
            "<span style='font-size:", label_size_pt_enforcement[as.character(depth)], "pt'>",
            category, "</span>"
        )
    )
result_plot_enforcement_activities <- ggplot(df_long_enforcement_plot, aes(x = n, y = y_pos, width = width, fill = depth)) +
    geom_col(orientation = "y", color = "black") +
    scale_fill_manual(
        values = c("1" = "#382e6b", "2" = "#766da7"),
        guide = "none"
    ) +
    scale_y_continuous(
        breaks = df_long_enforcement_plot$y_pos, labels = df_long_enforcement_plot$category_label,
        expand = expansion(add = var_family_gap_enforcement)
    ) +
    labs(
        x = "Number of responses", y = "Enforcement Activity"
    ) +
    theme_pubclean() +
    theme(
        axis.text.y = element_markdown(size = 22),
        axis.text.x = element_text(size = 22),
        axis.title = element_text(size = 25)
    )
result_caption_plot_enforcement_activities <- paste0(
    "Figure 6. Bar chart of enforcement activities (n = ",
    length(organizations_do_enforcement), ") done by those that do enforcement,",
    " with parent groupings (e.g., Incident Response) attached to lower-level children groupings.",
    " Parent bars reflect the number of organizations selecting at least one child activity in that grouping."
)
ggsave("outputs/result_plot_enforcement_activities.jpeg", result_plot_enforcement_activities,
    units = "in", height = 23, width = 18
)
# Examine illegal activities encountered
illegal_activities_order <- c(
    "Wildlife Extraction", "Illegal Wildlife Trade Or Possession", "Illegal Clearing",
    "Illegal Logging", "Polluting/Dumping", "Fires (Illegal)",
    "Squatters/Development/Trespassing", "Illegal Mineral Extraction"
)
wildlife_extraction_children_order <- c(
    "Hunting", "Taking Live Animals", "Freshwater Fishing", "Marine Fishing (Finfish)",
    "Conch Harvesting", "Lobster Harvesting", "Sea Cucumber Harvesting"
)
df_long_illegal_activities <- select(df, illegalActivities) %>%
    separate_rows(illegalActivities, sep = ";\\s*") %>%
    mutate(illegalActivities = fun_clean_text(illegalActivities)) %>%
    filter(!is.na(illegalActivities)) %>%
    mutate(
        level1 = if_else(illegalActivities %in% wildlife_extraction_children_order, "Wildlife Extraction", illegalActivities),
        level2 = if_else(illegalActivities %in% wildlife_extraction_children_order, illegalActivities, ""),
        depth  = 1 + (level2 != "")
    )
counts_illegal_activities <- df_long_illegal_activities %>%
    count(level1, level2, depth, name = "n")
fun_build_illegal_activity_rows <- function(counts, category_order, subcategory_order = NULL, base_width = 0.9, shrink = 0.55) {
    rows <- list()
    for (cat in category_order) {
        top_row <- counts %>% filter(level1 == cat, depth == 1)
        if (nrow(top_row) == 0) next # skip activities nobody selected
        rows[[length(rows) + 1]] <- tibble(
            category = cat, n = top_row$n, depth = 1, width = base_width, family = cat
        )
        children <- counts %>% filter(level1 == cat, depth == 2)
        if (!is.null(subcategory_order)) {
            children <- children %>% arrange(match(level2, subcategory_order), desc(n))
        } else {
            children <- children %>% arrange(desc(n))
        }
        for (i in seq_len(nrow(children))) {
            rows[[length(rows) + 1]] <- tibble(
                category = children$level2[i], n = children$n[i], depth = 2,
                width = base_width * shrink, family = cat
            )
        }
    }
    bind_rows(rows)
}
df_long_illegal_activities_plot <- fun_build_illegal_activity_rows(
    counts_illegal_activities, illegal_activities_order, wildlife_extraction_children_order
)
var_family_gap_illegal_activities <- 0.5
df_long_illegal_activities_plot <- df_long_illegal_activities_plot %>%
    mutate(
        touch_step = width / 2 + lag(width) / 2,
        step = case_when(
            row_number() == 1 ~ 0,
            family != lag(family) ~ touch_step + var_family_gap_illegal_activities,
            TRUE ~ touch_step
        ),
        y_pos = -cumsum(step)
    )
label_size_pt_illegal_activities <- c("1" = 22, "2" = 18)
df_long_illegal_activities_plot <- df_long_illegal_activities_plot %>%
    mutate(
        depth = factor(depth),
        category_label = paste0(
            "<span style='font-size:", label_size_pt_illegal_activities[as.character(depth)], "pt'>",
            category, "</span>"
        )
    )
result_plot_illegal_activities <- ggplot(df_long_illegal_activities_plot, aes(x = n, y = y_pos, width = width, fill = depth)) +
    geom_col(orientation = "y", color = "black") +
    scale_fill_manual(
        values = c("1" = "#382e6b", "2" = "#766da7"),
        guide = "none"
    ) +
    scale_y_continuous(
        breaks = df_long_illegal_activities_plot$y_pos, labels = df_long_illegal_activities_plot$category_label,
        expand = expansion(add = var_family_gap_illegal_activities)
    ) +
    labs(
        x = "Number of responses", y = "Illegal Activity"
    ) +
    theme_pubclean() +
    theme(
        axis.text.y = element_markdown(size = 22),
        axis.text.x = element_text(size = 22),
        axis.title = element_text(size = 25)
    )
result_caption_plot_illegal_activities <- paste0(
    "Figure 7. Bar chart of illegal activities (n = ",
    length(organizations_do_enforcement), ") encountered by those that do enforcement,",
    " with parent groupings (e.g., Wildlife Extraction) attached to lower-level children groupings."
)
ggsave("outputs/result_plot_illegal_activities.jpeg", result_plot_illegal_activities,
    units = "in", height = 23, width = 18
)
# See how many organizations collect patrol data
num_does_patrol_data <- round(sum(df$patrolDataTools != "No" & !is.na(df$patrolDataTools) & df$patrolDataTools != ""), 2)
df_patrol <- df %>%
    select(organizationName, patrolDataTools, patrolDataToolsOtherSpecify) %>%
    filter(patrolDataTools != "No" & !is.na(patrolDataTools) & patrolDataTools != "") %>%
    mutate(
        toolsUsed = map2_chr(patrolDataTools, patrolDataToolsOtherSpecify, function(tools, other) {
            tools_split <- str_remove(str_split(tools, ";\\s*")[[1]], "^Yes,\\s*")
            tools_split <- if_else(tools_split == "Other", other, tools_split)
            paste(tools_split, collapse = ", ")
        }),
        organizationsAndTools = paste0(organizationName, " (", toolsUsed, ")")
    )
result_num_does_patrol_data <- paste0(
    "The number of organizations collecting patrol data using apps is ",
    num_does_patrol_data,
    ", including: ",
    combine_words(df_patrol$organizationsAndTools),
    "."
)

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
result_plot_ecosystem_health
result_caption_plot_ecosystem_health
result_num_does_habitat_restoration_studying
result_plot_pollution
result_caption_plot_pollution
result_num_does_invasive_species_studying
result_plot_ecosystem_services
result_caption_plot_ecosystem_services
result_num_does_comm_services_relations_studying
result_num_does_climate_resiliency
result_num_does_enforcement
result_plot_enforcement_activities
result_plot_enforcement_activities
result_plot_illegal_activities
result_caption_plot_illegal_activities
result_num_does_patrol_data
