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
fun_wrap_two_lines <- function(labels) {
    vapply(labels, function(label) {
        if (is.na(label) || !str_detect(label, "\\s")) {
            return(label)
        }
        words <- str_split(label, " ")[[1]]
        # length of the label if joined through each word, used to find the midpoint word
        cum_len <- cumsum(nchar(words) + 1) - 1
        split_after <- which.min(abs(cum_len - nchar(label) / 2))
        split_after <- max(1, min(split_after, length(words) - 1))
        paste0(
            paste(words[seq_len(split_after)], collapse = " "), "\n",
            paste(words[(split_after + 1):length(words)], collapse = " ")
        )
    }, character(1), USE.NAMES = FALSE)
}
fun_any_not_no <- function(x) {
    # TRUE if a response contains any option other than "No"
    vapply(x, function(val) {
        if (is.na(val) || str_trim(val) == "") {
            return(FALSE)
        }
        opts <- str_trim(str_split(val, ";")[[1]])
        any(opts != "No")
    }, logical(1))
}

## Clean Data ---------------------------------------------------
# Remove duplicates
df <- df %>%
    select(-timestamp) %>%
    distinct()

## Set Figure Number Variable ---------------------------------------------------
fig_num <- 0

## Analyze Section 2: Organization Information
# Determine which organizations participated and how many
unique_organization_names <- unique(df$organizationName)
unique_organizations <- length(unique_organization_names)
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
    "marineFishOther", "Fish", "Marine Fish", FALSE
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
                # General write-in responses stand on their own as level 1 categories,
                # rather than nesting under a generic "Other" summary bar.
                rows[[length(rows) + 1]] <- tibble(
                    level1 = response_counts$response, level2 = "", level3 = "",
                    depth = 1, n = response_counts$n, is_other = TRUE
                )
            } else {
                rows[[length(rows) + 1]] <- tibble(
                    level1 = level1, level2 = response_counts$response, level3 = "",
                    depth = 2, n = response_counts$n, is_other = TRUE
                )
            }
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
        if (t == "Other") {
            # Expand the "Other" placeholder into standalone bars for each
            # general write-in response, rather than a single nested bar.
            other_rows <- counts_taxa %>%
                filter(depth == 1, is_other, !(level1 %in% taxon_order)) %>%
                arrange(desc(n))
            for (i in seq_len(nrow(other_rows))) {
                rows[[length(rows) + 1]] <- tibble(
                    category = other_rows$level1[i], n = other_rows$n[i], depth = 1,
                    width = base_width, family = other_rows$level1[i], is_other = TRUE
                )
            }
            next
        }
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
fig_num <- fig_num + 1
result_caption_plot_taxa <- paste0(
    "Figure ", fig_num, ". Bar chart of how many surveyed organizations (n = ",
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
fig_num <- fig_num + 1
result_caption_plot_ecosystems <- paste0(
    "Figure ", fig_num, ". Bar chart of how many surveyed organizations (n = ",
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
fig_num <- fig_num + 1
result_caption_plot_ecosystem_health <- paste0(
    "Figure ", fig_num, ". Bar chart of how many surveyed organizations (n = ",
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
fig_num <- fig_num + 1
result_caption_plot_pollution <- paste0(
    "Figure ", fig_num, ". Bar chart of how many surveyed organizations (n = ",
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
fig_num <- fig_num + 1
result_caption_plot_ecosystem_services <- paste0(
    "Figure ", fig_num, ". Bar chart of how many surveyed organizations (n = ",
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
fig_num <- fig_num + 1
result_caption_plot_enforcement_activities <- paste0(
    "Figure ", fig_num, ". Bar chart of enforcement activities (n = ",
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
fig_num <- fig_num + 1
result_caption_plot_illegal_activities <- paste0(
    "Figure ", fig_num, ". Bar chart of illegal activities (n = ",
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
df_patrol_datatypes <- df %>%
    select(patrolDataTypes) %>%
    separate_rows(patrolDataTypes, sep = ";\\s*") %>%
    mutate(patrolDataTypes = fun_clean_text(patrolDataTypes)) %>%
    filter(!is.na(patrolDataTypes), patrolDataTypes != "") %>%
    count(patrolDataTypes, name = "n") %>%
    arrange(-n) %>%
    mutate(patrolDataTypesCount = paste0(patrolDataTypes, " (", n, ")"))
result_num_does_patrol_data <- paste0(
    "The number of organizations collecting patrol data using apps is ",
    num_does_patrol_data,
    ", including: ",
    combine_words(df_patrol$organizationsAndTools),
    ". Data collected varies by organization, with reported data collected by number of responses including: ",
    combine_words(df_patrol_datatypes$patrolDataTypesCount), "."
)

## Analyze Section 8: Mainstreaming
# See how many organizations do engagement
num_does_engagement <- round(sum(df$communityEngagement == "Yes", na.rm = TRUE), 2)
organizations_do_engagement <- filter(df, df$communityEngagement == "Yes")$organizationName
result_num_does_engagement <- paste0(
    "The number of organizations doing community engagement is ",
    num_does_engagement,
    ", including: ",
    combine_words(organizations_do_engagement)
)
# Map communities most often engaged with
# TO DO: Requires manual data cleaning for question 18
# Investigate types of community engagement most often done
# TO DO: This requires a lot of cleaning in the data
engagement_types_fixed_order <- c(
    "Education On Fire Management", "Illegal Wildlife Trade",
    "Protected Areas And Ecosystem Benefits", "Community Governance And Participation",
    "Project Development And Implementation"
)
df_engagement_types <- df %>%
    select(engagementTypes) %>%
    separate_rows(engagementTypes, sep = ";\\s*") %>%
    mutate(engagementTypes = fun_clean_text(engagementTypes)) %>%
    filter(!is.na(engagementTypes), engagementTypes != "Other") %>%
    group_by(engagementTypes) %>%
    summarise(n = n(), .groups = "drop") %>%
    mutate(is_other = FALSE)
engagement_types_other <- fun_clean_text(df$engagementTypesOther)
engagement_types_other <- engagement_types_other[!is.na(engagement_types_other)]
df_engagement_types_other <- tibble(engagementTypes = engagement_types_other) %>%
    count(engagementTypes, name = "n") %>%
    mutate(is_other = TRUE)
df_engagement_types <- bind_rows(df_engagement_types, df_engagement_types_other)
engagement_types_order <- rev(c(
    engagement_types_fixed_order,
    sort(unique(df_engagement_types_other$engagementTypes))
))
df_engagement_types <- df_engagement_types %>%
    mutate(
        engagementTypes = factor(engagementTypes, levels = engagement_types_order),
        fill_category = if_else(is_other, "other", "normal")
    )
result_plot_engagement_types <- ggplot(df_engagement_types, aes(x = n, y = engagementTypes, fill = fill_category)) +
    geom_col(orientation = "y", color = "black") +
    scale_fill_manual(
        values = c("normal" = "#382e6b", "other" = "#456b2e"),
        guide = "none"
    ) +
    scale_y_discrete(labels = fun_wrap_two_lines) +
    labs(
        x = "Number of responses", y = "Engagement Type"
    ) +
    theme_pubclean() +
    theme(
        axis.text.y = element_text(size = 22),
        axis.text.x = element_text(size = 22),
        axis.title = element_text(size = 25)
    )
fig_num <- fig_num + 1
result_caption_plot_engagement_types <- paste0(
    "Figure ", fig_num, ". Bar chart of how many surveyed organizations (n = ",
    length(organizations_do_engagement), ") most often do different types of community engagement.",
    " Indigo bars are selected options from the survey, and green are custom responses supplied by the surveyed organization."
)
ggsave("outputs/result_plot_engagement_types.jpeg", result_plot_engagement_types,
    units = "in", height = 23, width = 18
)

## Analyze Section 9: Collaboration & Challenges
# See how many organizations do collaboration
num_does_collaboration <- round(sum(df$collaboration == "Yes", na.rm = TRUE), 2)
organizations_do_collaboration <- filter(df, df$collaboration == "Yes")$organizationName
result_num_does_collaboration <- paste0(
    "The number of organizations doing collaboration is ",
    num_does_collaboration,
    ", including: ",
    combine_words(organizations_do_collaboration)
)
# Make connection diagram between organizations that collaborate
# TO DO: Requires manual data cleaning for question 20
# Examine major challenges for data collection
# TO DO: Requires manual data cleaning for question 21

## Analyze Section 10: Technology & Skill Gaps
# Determine how many participants are seeing the section
num_sees_section10 <- length(with(
    df,
    doesMonitoring %in% "Yes" |
        fun_any_not_no(ecosystemHealthData) |
        habitatRestoration %in% "Yes" |
        fun_any_not_no(pollutionData) |
        invasiveSpecies %in% "Yes" |
        ecosystemServices %in% "Yes" |
        communityEcosystemServices %in% "Yes" |
        fun_any_not_no(climateResiliency)
))
# Investigate types of data tools most often used
# TO DO: This requires a lot of cleaning in the data
data_tools_fixed_order <- c(
    "Printed Datasheets", "Smart",
    "Kobotoolbox", "Survey123"
)
df_data_tools <- df %>%
    select(dataTools) %>%
    separate_rows(dataTools, sep = ";\\s*") %>%
    mutate(dataTools = fun_clean_text(dataTools)) %>%
    filter(!is.na(dataTools), dataTools != "Other") %>%
    group_by(dataTools) %>%
    summarise(n = n(), .groups = "drop") %>%
    mutate(is_other = FALSE)
data_tools_other <- fun_clean_text(df$dataToolsOther)
data_tools_other <- data_tools_other[!is.na(data_tools_other)]
df_data_tools_other <- tibble(dataTools = data_tools_other) %>%
    count(dataTools, name = "n") %>%
    mutate(is_other = TRUE)
df_data_tools <- bind_rows(df_data_tools, df_data_tools_other)
data_tools_order <- rev(c(
    data_tools_fixed_order,
    sort(unique(df_data_tools_other$dataTools))
))
df_data_tools <- df_data_tools %>%
    mutate(
        dataTools = factor(dataTools, levels = data_tools_order),
        fill_category = if_else(is_other, "other", "normal")
    )
result_plot_data_tools <- ggplot(df_data_tools, aes(x = n, y = dataTools, fill = fill_category)) +
    geom_col(orientation = "y", color = "black") +
    scale_fill_manual(
        values = c("normal" = "#382e6b", "other" = "#456b2e"),
        guide = "none"
    ) +
    scale_y_discrete(labels = fun_wrap_two_lines) +
    labs(
        x = "Number of responses", y = "Tool Type"
    ) +
    theme_pubclean() +
    theme(
        axis.text.y = element_text(size = 22),
        axis.text.x = element_text(size = 22),
        axis.title = element_text(size = 25)
    )
fig_num <- fig_num + 1
result_caption_plot_data_tools <- paste0(
    "Figure ", fig_num, ". Bar chart of how many surveyed organizations (n = ",
    num_sees_section10, ") use certain data collection tools.",
    " Indigo bars are selected options from the survey, and green are custom responses supplied by the surveyed organization."
)
ggsave("outputs/result_plot_data_tools.jpeg", result_plot_data_tools,
    units = "in", height = 23, width = 18
)
# Investigate technological gaps
# TO DO: This requires a lot of cleaning in the data
tech_gaps_fixed_order <- c(
    "Lack Of Smart Devices", "Lack Of Survey Equipment",
    "Lack Of Drones For Mapping", "Lack Of Cloud Storage"
)
counts_tech_gaps <- df %>%
    select(techGaps) %>%
    separate_rows(techGaps, sep = ";\\s*") %>%
    mutate(techGaps = fun_clean_text(techGaps)) %>%
    filter(!is.na(techGaps)) %>%
    count(techGaps, name = "n") %>%
    transmute(level1 = techGaps, level2 = "", level3 = "", depth = 1, n, is_other = FALSE)
tech_gaps_other_field_map <- tribble(
    ~column, ~level1, ~level2, ~is_new_taxon,
    "techGapsOther", "Other", NA_character_, TRUE,
    "surveyEquipmentSpecify", "Lack Of Survey Equipment", NA_character_, FALSE
)
counts_tech_gaps <- bind_rows(counts_tech_gaps, fun_build_other_counts(df, tech_gaps_other_field_map))
tech_gaps_order <- c(tech_gaps_fixed_order, "Other", "None")
df_tech_gaps_plot <- fun_build_rows(counts_tech_gaps, tech_gaps_order) %>%
    mutate(
        depth = factor(depth),
        fill_group = case_when(
            category == "None" ~ "none",
            is_other ~ paste0("other_", depth),
            TRUE ~ as.character(depth)
        )
    )
df_tech_gaps_plot <- df_tech_gaps_plot %>%
    mutate(
        touch_step = width / 2 + lag(width) / 2,
        step = case_when(
            row_number() == 1 ~ 0,
            family != lag(family) ~ touch_step + var_family_gap,
            TRUE ~ touch_step
        ),
        y_pos = -cumsum(step)
    )
df_tech_gaps_plot <- df_tech_gaps_plot %>%
    mutate(category_label = paste0(
        "<span style='font-size:", label_size_pt[as.character(depth)], "pt'>",
        str_replace_all(fun_wrap_two_lines(category), "\n", "<br>"), "</span>"
    ))
result_plot_tech_gaps <- ggplot(df_tech_gaps_plot, aes(x = n, y = y_pos, width = width, fill = fill_group)) +
    geom_col(orientation = "y", color = "black") +
    scale_fill_manual(
        values = c(
            "1" = "#382e6b", "2" = "#766da7",
            "other_1" = "#456b2e", "other_2" = "#729a5a",
            "none" = "#6b4b2e"
        ),
        guide = "none"
    ) +
    scale_y_continuous(
        breaks = df_tech_gaps_plot$y_pos, labels = df_tech_gaps_plot$category_label,
        expand = expansion(add = var_family_gap)
    ) +
    labs(
        x = "Number of responses", y = "Technological Gap"
    ) +
    theme_pubclean() +
    theme(
        axis.text.y = element_markdown(size = 22),
        axis.text.x = element_text(size = 22),
        axis.title = element_text(size = 25)
    )
fig_num <- fig_num + 1
result_caption_plot_tech_gaps <- paste0(
    "Figure ", fig_num, ". Bar chart of how many surveyed organizations (n = ",
    num_sees_section10,
    ") report different technological gaps, with taxon-specific free-text responses nested under their related gap and general write-in gaps shown as their own standalone bars. ",
    " Indigo bars are selected options from the survey, and green are custom responses supplied by the surveyed organization."
)
ggsave("outputs/result_plot_tech_gaps.jpeg", result_plot_tech_gaps,
    units = "in", height = 23, width = 18
)
# Examine data processing software
# TO DO: Requires manual data cleaning for question 24
# Examine missing data processing software and subscriptions
# TO DO: Requires manual data cleaning for question 25
# Examine technical/training skill gaps
# TO DO: This requires a lot of cleaning in the data
skill_gaps_fixed_order <- c(
    "Limited Data Analysis Skills", "Limited Gis Access", "Limited Technical Support",
    "High Staff Turnover Leading To Constant Retraining Needs",
    "Limited Technical Report Writing Skills",
    "Limited Skills For Publishing In Peer-Review Journals",
    "Limited Project Development And Management Skills"
)
counts_skill_gaps <- df %>%
    select(skillGaps) %>%
    separate_rows(skillGaps, sep = ";\\s*") %>%
    mutate(skillGaps = fun_clean_text(skillGaps)) %>%
    filter(!is.na(skillGaps)) %>%
    count(skillGaps, name = "n") %>%
    transmute(level1 = skillGaps, level2 = "", level3 = "", depth = 1, n, is_other = FALSE)
skill_gaps_other_field_map <- tribble(
    ~column, ~level1, ~level2, ~is_new_taxon,
    "skillGapsOther", "Other", NA_character_, TRUE
)
counts_skill_gaps <- bind_rows(counts_skill_gaps, fun_build_other_counts(df, skill_gaps_other_field_map))
skill_gaps_order <- c(skill_gaps_fixed_order, "Other", "None")
df_skill_gaps_plot <- fun_build_rows(counts_skill_gaps, skill_gaps_order) %>%
    mutate(
        depth = factor(depth),
        fill_group = case_when(
            category == "None" ~ "none",
            is_other ~ paste0("other_", depth),
            TRUE ~ as.character(depth)
        )
    )
df_skill_gaps_plot <- df_skill_gaps_plot %>%
    mutate(
        touch_step = width / 2 + lag(width) / 2,
        step = case_when(
            row_number() == 1 ~ 0,
            family != lag(family) ~ touch_step + var_family_gap,
            TRUE ~ touch_step
        ),
        y_pos = -cumsum(step)
    )
df_skill_gaps_plot <- df_skill_gaps_plot %>%
    mutate(category_label = paste0(
        "<span style='font-size:", label_size_pt[as.character(depth)], "pt'>",
        str_replace_all(fun_wrap_two_lines(category), "\n", "<br>"), "</span>"
    ))
result_plot_skill_gaps <- ggplot(df_skill_gaps_plot, aes(x = n, y = y_pos, width = width, fill = fill_group)) +
    geom_col(orientation = "y", color = "black") +
    scale_fill_manual(
        values = c(
            "1" = "#382e6b", "2" = "#766da7",
            "other_1" = "#456b2e", "other_2" = "#729a5a",
            "none" = "#6b4b2e"
        ),
        guide = "none"
    ) +
    scale_y_continuous(
        breaks = df_skill_gaps_plot$y_pos, labels = df_skill_gaps_plot$category_label,
        expand = expansion(add = var_family_gap)
    ) +
    labs(
        x = "Number of responses", y = "Skill Gap"
    ) +
    theme_pubclean() +
    theme(
        axis.text.y = element_markdown(size = 22),
        axis.text.x = element_text(size = 22),
        axis.title = element_text(size = 25)
    )
fig_num <- fig_num + 1
result_caption_plot_skill_gaps <- paste0(
    "Figure ", fig_num, ". Bar chart of how many surveyed organizations (n = ",
    num_sees_section10,
    ") report different technical/training skill gaps.",
    " Indigo bars are selected options from the survey, and green are custom responses supplied by the surveyed organization."
)
ggsave("outputs/result_plot_skill_gaps.jpeg", result_plot_skill_gaps,
    units = "in", height = 23, width = 18
)
# Investigate training by staff needed
# TO DO: This requires a lot of cleaning in the data
training_needs_fixed_order <- c(
    "Technical Training", "Research And Monitoring Development", "Equipment Operation",
    "Software", "Data Cleaning And Entering (For Existing Databases Or Systems)",
    "Data Interpretation And Analysis", "Technical And Scientific Report Writing"
)
df_long_training_needs <- select(df, trainingNeeds) %>%
    separate_rows(trainingNeeds, sep = ";\\s*") %>%
    mutate(trainingNeeds = str_trim(trainingNeeds)) %>%
    filter(trainingNeeds != "")
levels_split_training_needs <- str_split_fixed(df_long_training_needs$trainingNeeds, " - ", 2)
df_long_training_needs <- df_long_training_needs %>%
    mutate(
        level1 = str_trim(levels_split_training_needs[, 1]),
        level2 = str_trim(levels_split_training_needs[, 2]),
        level3 = "",
        depth  = 1 + (level2 != ""),
        level1 = fun_clean_text(level1),
        level2 = fun_clean_text(level2),
        level3 = fun_clean_text(level3)
    )
counts_training_needs <- df_long_training_needs %>%
    count(level1, level2, level3, depth, name = "n") %>%
    mutate(is_other = FALSE)
training_needs_other_field_map <- tribble(
    ~column, ~level1, ~level2, ~is_new_taxon,
    "trainingNeedsOther", "Other", NA_character_, TRUE,
    "technicalTrainingSpecify", "Technical Training", NA_character_, FALSE
)
counts_training_needs <- bind_rows(counts_training_needs, fun_build_other_counts(df, training_needs_other_field_map))
subtaxon_order_software <- c(
    "Data Processing Software", "Data Analysis Software",
    "Geospatial Software", "Equipment Operation Software"
)
training_needs_order <- c(training_needs_fixed_order, "Other", "None")
df_training_needs_plot <- fun_build_rows(
    counts_training_needs, training_needs_order,
    subtaxon_orders = list("Software" = subtaxon_order_software)
) %>%
    mutate(
        depth = factor(depth),
        fill_group = case_when(
            category == "None" ~ "none",
            is_other ~ paste0("other_", depth),
            TRUE ~ as.character(depth)
        )
    )
df_training_needs_plot <- df_training_needs_plot %>%
    mutate(
        touch_step = width / 2 + lag(width) / 2,
        step = case_when(
            row_number() == 1 ~ 0,
            family != lag(family) ~ touch_step + var_family_gap,
            TRUE ~ touch_step
        ),
        y_pos = -cumsum(step)
    )
df_training_needs_plot <- df_training_needs_plot %>%
    mutate(category_label = paste0(
        "<span style='font-size:", label_size_pt[as.character(depth)], "pt'>",
        str_replace_all(fun_wrap_two_lines(category), "\n", "<br>"), "</span>"
    ))
result_plot_training_needs <- ggplot(df_training_needs_plot, aes(x = n, y = y_pos, width = width, fill = fill_group)) +
    geom_col(orientation = "y", color = "black") +
    scale_fill_manual(
        values = c(
            "1" = "#382e6b", "2" = "#766da7",
            "other_1" = "#456b2e", "other_2" = "#729a5a",
            "none" = "#6b4b2e"
        ),
        guide = "none"
    ) +
    scale_y_continuous(
        breaks = df_training_needs_plot$y_pos, labels = df_training_needs_plot$category_label,
        expand = expansion(add = var_family_gap)
    ) +
    labs(
        x = "Number of responses", y = "Training Need"
    ) +
    theme_pubclean() +
    theme(
        axis.text.y = element_markdown(size = 22),
        axis.text.x = element_text(size = 22),
        axis.title = element_text(size = 25)
    )
fig_num <- fig_num + 1
result_caption_plot_training_needs <- paste0(
    "Figure ", fig_num, ". Bar chart of how many surveyed organizations (n = ",
    num_sees_section10,
    ") report different staff training needs.",
    " Indigo bars are selected options from the survey, and green are custom responses supplied by the surveyed organization."
)
ggsave("outputs/result_plot_training_needs.jpeg", result_plot_training_needs,
    units = "in", height = 23, width = 18
)

## Analyze Section 11: Data Management
# Determine how many participants are seeing the section
num_sees_section11 <- length(with(
    df,
    doesMonitoring %in% "Yes" |
        fun_any_not_no(ecosystemHealthData) |
        habitatRestoration %in% "Yes" |
        fun_any_not_no(pollutionData) |
        invasiveSpecies %in% "Yes" |
        ecosystemServices %in% "Yes" |
        communityEcosystemServices %in% "Yes" |
        fun_any_not_no(climateResiliency)
))
# Investigate how data is digitized
digitization_fixed_order <- c("Excel/Google Sheets", "Data Portals")
counts_digitization <- df %>%
    select(digitization) %>%
    separate_rows(digitization, sep = ";\\s*") %>%
    mutate(digitization = fun_clean_text(digitization)) %>%
    filter(!is.na(digitization)) %>%
    count(digitization, name = "n") %>%
    transmute(level1 = digitization, level2 = "", level3 = "", depth = 1, n, is_other = FALSE)
digitization_other_field_map <- tribble(
    ~column, ~level1, ~level2, ~is_new_taxon,
    "digitizationPortals", "Data Portals", NA_character_, FALSE
)
counts_digitization <- bind_rows(counts_digitization, fun_build_other_counts(df, digitization_other_field_map))
digitization_order <- digitization_fixed_order
df_digitization_plot <- fun_build_rows(counts_digitization, digitization_order) %>%
    mutate(
        depth = factor(depth),
        fill_group = if_else(is_other, paste0("other_", depth), as.character(depth))
    )
df_digitization_plot <- df_digitization_plot %>%
    mutate(
        touch_step = width / 2 + lag(width) / 2,
        step = case_when(
            row_number() == 1 ~ 0,
            family != lag(family) ~ touch_step + var_family_gap,
            TRUE ~ touch_step
        ),
        y_pos = -cumsum(step)
    )
df_digitization_plot <- df_digitization_plot %>%
    mutate(category_label = paste0(
        "<span style='font-size:", label_size_pt[as.character(depth)], "pt'>",
        str_replace_all(fun_wrap_two_lines(category), "\n", "<br>"), "</span>"
    ))
result_plot_digitization <- ggplot(df_digitization_plot, aes(x = n, y = y_pos, width = width, fill = fill_group)) +
    geom_col(orientation = "y", color = "black") +
    scale_fill_manual(
        values = c(
            "1" = "#382e6b", "2" = "#766da7",
            "other_1" = "#456b2e", "other_2" = "#729a5a"
        ),
        guide = "none"
    ) +
    scale_y_continuous(
        breaks = df_digitization_plot$y_pos, labels = df_digitization_plot$category_label,
        expand = expansion(add = var_family_gap)
    ) +
    labs(
        x = "Number of responses", y = "Digitization Method"
    ) +
    theme_pubclean() +
    theme(
        axis.text.y = element_markdown(size = 22),
        axis.text.x = element_text(size = 22),
        axis.title = element_text(size = 25)
    )
fig_num <- fig_num + 1
result_caption_plot_digitization <- paste0(
    "Figure ", fig_num, ". Bar chart of how many surveyed organizations (n = ",
    num_sees_section11,
    ") digitize their monitoring data using each method.",
    " Indigo bars are selected options from the survey, and green are custom responses supplied by the surveyed organization."
)
ggsave("outputs/result_plot_digitization.jpeg", result_plot_digitization,
    units = "in", height = 23, width = 18
)
# Explore whether data is still undigitized
# TO DO: Requires manual data cleaning for question 29

## Analyze Section 12: Data Sharing
# Determine how many participants are seeing the section
num_sees_section12 <- length(with(
    df,
    doesMonitoring %in% "Yes" |
        fun_any_not_no(ecosystemHealthData) |
        habitatRestoration %in% "Yes" |
        fun_any_not_no(pollutionData) |
        invasiveSpecies %in% "Yes" |
        ecosystemServices %in% "Yes" |
        communityEcosystemServices %in% "Yes" |
        fun_any_not_no(climateResiliency)
))
# See if participants submit their reports to the GoB
num_does_report_submission <- round(sum(df$govReports == "Yes" | df$govReports == "No", na.rm = TRUE), 2)
organizations_do_report_submission <- filter(df, df$govReports == "Yes")$organizationName
organizations_do_no_report_submission <- filter(df, df$govReports == "No")$organizationName
organizations_do_no_report_at_all <- filter(df, df$govReports == "We do not do reporting")$organizationName
result_num_does_report_submission <- paste0(
    "The number of organizations that do reporting is ",
    num_does_report_submission,
    ". Organizations that submit their reports to the Government of Belize include: ",
    combine_words(organizations_do_report_submission),
    ". Organizations that do not submit their reports to the Government of Belize include: ",
    combine_words(organizations_do_no_report_submission),
    ". Organizations that do no report writing include: ",
    combine_words(organizations_do_no_report_at_all)
)
# See if participants publish their reports
num_does_report_publish <- round(sum(df$publishOnline == "Yes", na.rm = TRUE), 2)
organizations_do_report_publish <- filter(df, df$publishOnline == "Yes")$organizationName
result_num_does_report_publish <- paste0(
    "The number of organizations that publish their reports online is ",
    num_does_report_publish,
    ", including: ",
    combine_words(organizations_do_report_publish)
)
# See how often participants publish their reports
df_publish_freq <- df %>%
    select(organizationName, publishOnlineFrequency) %>%
    group_by(publishOnlineFrequency) %>%
    summarize(n = n()) %>%
    filter(publishOnlineFrequency != "") %>%
    mutate(publishFreqCombo = paste0(n, " responded ", publishOnlineFrequency))
result_freq_publish_online <- paste0(
    "These organizations were then asked how frequently they publish these reports. ",
    combine_words(df_publish_freq$publishFreqCombo), "."
)
# See if participants publish their papers
num_does_paper_publish <- round(sum(df$publishPapers == "Yes", na.rm = TRUE), 2)
organizations_do_paper_publish <- filter(df, df$publishPapers == "Yes")$organizationName
result_num_does_paper_publish <- paste0(
    "The number of organizations that publish peer-reviewed papers is ",
    num_does_paper_publish,
    ", including: ",
    combine_words(organizations_do_paper_publish)
)
# See how often participants publish peer-reviewed papers
df_paper_publish_freq <- df %>%
    select(organizationName, publishPapersFrequency) %>%
    group_by(publishPapersFrequency) %>%
    summarize(n = n()) %>%
    filter(publishPapersFrequency != "") %>%
    mutate(publishFreqCombo = paste0(n, " responded ", publishPapersFrequency))
result_freq_publish_paper <- paste0(
    "These organizations were then asked how frequently they publish these papers. ",
    combine_words(df_paper_publish_freq$publishFreqCombo), "."
)
# See if participants have a public data dashboard
df_data_dashboard <- df %>%
    select(organizationName, publicDashboard) %>%
    group_by(publicDashboard) %>%
    summarize(n = n()) %>%
    filter(publicDashboard != "")
result_num_data_dashboard <- paste0(
    "Organizations were asked whether they have a public data dashboard which their data can be viewed on. ",
    filter(df_data_dashboard, publicDashboard == "Yes")$n,
    " responded that they do, and ",
    filter(df_data_dashboard, publicDashboard == "No")$n,
    " responded that they do not."
)
# See if participants share datasets to organizations
# TO DO: Requires manual data cleaning for question 34
df_data_share <- df %>%
    select(organizationName, shareData) %>%
    group_by(shareData) %>%
    summarize(n = n()) %>%
    filter(shareData != "")
df_data_share_recipients <- df %>%
    select(shareDataWhom) %>%
    group_by(shareDataWhom) %>%
    summarise(n = n()) %>%
    filter(shareDataWhom != "") %>%
    mutate(shareDataWhomQuote = paste0('"', shareDataWhom, '"'))
data_share_recipients <- combine_words(unique(df_data_share_recipients$shareDataWhomQuote))
result_num_data_share <- paste0(
    "Organizations were asked whether they share data outside their organization. ",
    filter(df_data_share, shareData == "Yes")$n,
    " responded that they do, and ",
    filter(df_data_share, shareData == "No")$n,
    " responded that they do not. Responses on who the data is shared to include: ",
    data_share_recipients
)
# See if participants share datasets to repositories
# TO DO: Requires manual data cleaning for question 35
df_data_share_repository <- df %>%
    select(organizationName, onlineRepos) %>%
    group_by(onlineRepos) %>%
    summarize(n = n()) %>%
    filter(onlineRepos != "")
df_data_share_repository_identities <- df %>%
    select(onlineReposWhichOnes) %>%
    group_by(onlineReposWhichOnes) %>%
    summarise(n = n()) %>%
    filter(onlineReposWhichOnes != "") %>%
    mutate(onlineReposWhichOnesQuote = paste0('"', onlineReposWhichOnes, '"'))
data_share_repository_identities <- combine_words(unique(df_data_share_repository_identities$onlineReposWhichOnesQuote))
result_num_data_share_repository <- paste0(
    "Organizations were asked whether they share data to any repositories. ",
    filter(df_data_share_repository, onlineRepos == "Yes")$n,
    " responded that they do, and ",
    filter(df_data_share_repository, onlineRepos == "No")$n,
    " responded that they do not. Responses on which repositories are shared to includes: ",
    data_share_repository_identities
)
# Organize data sharing responses
num_does_report_writing_no <- sum(df$govReports == "We do not do reporting", na.rm = TRUE)
num_does_report_submission_no <- length(organizations_do_no_report_submission)
num_does_report_publish_no <- sum(df$publishOnline == "No", na.rm = TRUE)
num_does_paper_publish_no <- sum(df$publishPapers == "No", na.rm = TRUE)
result_df_data_sharing_collated <- tibble(
    `Sharing Method` = c(
        "Writing Reports",
        "Submitting Reports to the GoB",
        "Publishing Reports",
        "Publishing Papers",
        "Using Public Dashboard",
        "Sharing Data Directly with Others",
        "Share Data on Repositories"
    ),
    yes = c(
        num_does_report_submission,
        length(organizations_do_report_submission),
        num_does_report_publish,
        num_does_paper_publish,
        filter(df_data_dashboard, publicDashboard == "Yes")$n,
        filter(df_data_share, shareData == "Yes")$n,
        filter(df_data_share_repository, onlineRepos == "Yes")$n
    ),
    no = c(
        num_does_report_writing_no,
        num_does_report_submission_no,
        num_does_report_publish_no,
        num_does_paper_publish_no,
        filter(df_data_dashboard, publicDashboard == "No")$n,
        filter(df_data_share, shareData == "No")$n,
        filter(df_data_share_repository, onlineRepos == "No")$n
    )
) %>%
    mutate(
        Yes = paste0(yes, " - ", round(yes / (yes + no) * 100, 1), "%"),
        No = paste0(no, " - ", round(no / (yes + no) * 100, 1), "%")
    ) %>%
    select(`Sharing Method`, Yes, No)
write.csv(result_df_data_sharing_collated, "outputs/result_df_data_sharing_collated.csv")

## Analyze Section 13: National Biodiversity Coordination
# See if participants are involved in national working groups
# TO DO: Requires manual data cleaning for question 37
df_working_group_member <- df %>%
    select(organizationName, workingGroupsInvolved) %>%
    group_by(workingGroupsInvolved) %>%
    summarize(n = n()) %>%
    filter(workingGroupsInvolved != "")
df_working_group_member_identities <- df %>%
    select(workingGroupsListText) %>%
    group_by(workingGroupsListText) %>%
    summarise(n = n()) %>%
    filter(workingGroupsListText != "") %>%
    mutate(workingGroupsListTextQuote = paste0('"', workingGroupsListText, '"'))
working_group_member_identities <- combine_words(unique(df_working_group_member_identities$workingGroupsListTextQuote))
result_num_working_group_member <- paste0(
    "Organizations were asked whether they are involved in any biodiversity national working groups. ",
    filter(df_working_group_member, workingGroupsInvolved == "Yes")$n,
    " responded that they do, and ",
    filter(df_working_group_member, workingGroupsInvolved == "No")$n,
    " responded that they do not. Responses on which working groups includes: ",
    working_group_member_identities
)
# See which organizations lead which national working groups
df_working_group_leader <- df %>%
    filter(workingGroupsLeading != "No" & workingGroupsLeading != "") %>%
    select(organizationName, workingGroupsLeading, workingGroupsLeadingListText) %>%
    mutate(workingGroupLeaderOrgs = paste0(organizationName, " leads ", workingGroupsLeadingListText))
result_working_group_leaders <- paste0(
    "Some organizations run these working groups. ",
    combine_words(df_working_group_leader$workingGroupLeaderOrgs),
    "."
)
# See if participants are involved in task forces
# TO DO: Requires manual data cleaning for question 39
df_task_force_member <- df %>%
    select(organizationName, taskForceInvolved) %>%
    group_by(taskForceInvolved) %>%
    summarize(n = n()) %>%
    filter(taskForceInvolved != "")
df_task_force_member_identities <- df %>%
    select(taskForceListText) %>%
    group_by(taskForceListText) %>%
    summarise(n = n()) %>%
    filter(taskForceListText != "") %>%
    mutate(taskForceListTextQuote = paste0('"', taskForceListText, '"'))
task_force_member_identities <- combine_words(unique(df_task_force_member_identities$taskForceListTextQuote))
result_num_task_force_member <- paste0(
    "Organizations were asked whether they are involved in any biodiversity task forces. ",
    filter(df_task_force_member, taskForceInvolved == "Yes")$n,
    " responded that they do, and ",
    filter(df_task_force_member, taskForceInvolved == "No")$n,
    " responded that they do not. Responses on which task forces includes: ",
    task_force_member_identities
)

## Analyze Section 14: Significance & Interest
# List species of cultural significance
# TO DO: Requires manual data cleaning for question 40
df_species_culturally_significant <- df %>%
    select(culturalSpecies) %>%
    filter(culturalSpecies != "No" & culturalSpecies != "")
list_species_culturally_significant <- combine_words(df_species_culturally_significant$culturalSpecies)
result_list_species_culturally_significant <- paste0(
    "Species of cultural significance to Belize were reported as ",
    list_species_culturally_significant,
    "."
)
# List species of economical significance
# TO DO: Requires manual data cleaning for question 40
df_species_economically_significant <- df %>%
    select(economicSpecies) %>%
    filter(economicSpecies != "No" & economicSpecies != "")
list_species_economically_significant <- combine_words(df_species_economically_significant$economicSpecies)
result_list_species_economically_significant <- paste0(
    "Species of economic significance to Belize were reported as ",
    list_species_economically_significant,
    "."
)
# Investigate specific species concerns
# TO DO
# List species of future interest
# TO DO: Requires manual data cleaning for question 43
df_species_future_interest <- df %>%
    select(futureMonitoring) %>%
    filter(futureMonitoring != "No" & futureMonitoring != "")
list_species_future_interest <- combine_words(df_species_future_interest$futureMonitoring)
result_list_species_future_interest <- paste0(
    "Species of future monitoring interest to organizations were reported as ",
    list_species_future_interest,
    "."
)
# List species of monitoring gap
# TO DO: Requires manual data cleaning for question 44
df_species_monitoring_gap <- df %>%
    select(speciesMonitoringGap) %>%
    filter(speciesMonitoringGap != "No" & speciesMonitoringGap != "")
list_species_monitoring_gap <- combine_words(df_species_monitoring_gap$speciesMonitoringGap)
result_list_species_monitoring_gap <- paste0(
    "Species with a significant monitoring gap were reported as ",
    list_species_monitoring_gap,
    "."
)
# List species of monitoring importance
# TO DO: Requires manual data cleaning for question 44
df_species_monitoring_importance <- df %>%
    select(speciesMonitoringImportance) %>%
    filter(speciesMonitoringImportance != "No" & speciesMonitoringImportance != "")
list_species_monitoring_importance <- combine_words(df_species_monitoring_importance$speciesMonitoringImportance)
result_list_species_monitoring_importance <- paste0(
    "Species with a significant monitoring importance were reported as ",
    list_species_monitoring_importance,
    "."
)
# List area of monitoring gap
# TO DO: Requires manual data cleaning for question 44
df_area_monitoring_gap <- df %>%
    select(areaMonitoringGap) %>%
    filter(areaMonitoringGap != "No" & areaMonitoringGap != "")
list_area_monitoring_gap <- combine_words(df_area_monitoring_gap$areaMonitoringGap)
result_list_area_monitoring_gap <- paste0(
    "Areas with a significant monitoring gap were reported as ",
    list_area_monitoring_gap,
    "."
)
# List area of monitoring importance
# TO DO: Requires manual data cleaning for question 44
df_area_monitoring_importance <- df %>%
    select(areaMonitoringImportance) %>%
    filter(areaMonitoringImportance != "No" & areaMonitoringImportance != "")
list_area_monitoring_importance <- combine_words(df_area_monitoring_importance$areaMonitoringImportance)
result_list_area_monitoring_importance <- paste0(
    "Areas with a significant monitoring importance were reported as ",
    list_area_monitoring_importance,
    "."
)

## Present Results
cat(result_unique_organizations)
cat(result_proportion_does_biodiversity_monitoring)
result_plot_taxa
cat(result_caption_plot_taxa)
result_plot_ecosystems
cat(result_caption_plot_ecosystems)
result_plot_ecosystem_health
cat(result_caption_plot_ecosystem_health)
cat(result_num_does_habitat_restoration_studying)
result_plot_pollution
cat(result_caption_plot_pollution)
cat(result_num_does_invasive_species_studying)
result_plot_ecosystem_services
cat(result_caption_plot_ecosystem_services)
cat(result_num_does_comm_services_relations_studying)
cat(result_num_does_climate_resiliency)
cat(result_num_does_enforcement)
result_plot_enforcement_activities
cat(result_caption_plot_enforcement_activities)
result_plot_illegal_activities
cat(result_caption_plot_illegal_activities)
cat(result_num_does_patrol_data)
cat(result_num_does_engagement)
result_plot_engagement_types
cat(result_caption_plot_engagement_types)
cat(result_num_does_collaboration)
result_plot_data_tools
cat(result_caption_plot_data_tools)
result_plot_tech_gaps
cat(result_caption_plot_tech_gaps)
result_plot_skill_gaps
cat(result_caption_plot_skill_gaps)
result_plot_training_needs
cat(result_caption_plot_training_needs)
result_plot_digitization
cat(result_caption_plot_digitization)
cat(result_num_does_report_submission)
cat(result_num_does_report_publish)
cat(result_freq_publish_online)
cat(result_num_does_paper_publish)
cat(result_freq_publish_paper)
cat(result_num_data_dashboard)
cat(result_num_data_share)
result_df_data_sharing_collated
cat(result_num_working_group_member)
cat(result_working_group_leaders)
cat(result_num_task_force_member)
cat(result_list_species_culturally_significant)
cat(result_list_species_economically_significant)
cat(result_list_species_future_interest)
cat(result_list_species_monitoring_gap)
cat(result_list_species_monitoring_importance)
cat(result_list_area_monitoring_gap)
cat(result_list_area_monitoring_importance)
