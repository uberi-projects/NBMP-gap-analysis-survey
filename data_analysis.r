# data_analysis.r

## Load Packages ---------------------------------------------------
library(tidyverse)
library(knitr)
library(ggpubr)
library(ggtext)
library(tidygraph)
library(ggraph)

## Load Data ---------------------------------------------------
df <- read.csv("data_deposit/UB-ERI Gap Analysis – Responses - Cleaned.csv")

## Clean Data ---------------------------------------------------
# Drop invalid UTF-8 byte sequences
df <- df %>%
    mutate(across(where(is.character), ~ iconv(., from = "UTF-8", to = "UTF-8", sub = "")))
# Remove duplicates
df <- df %>%
    select(-timestamp) %>%
    distinct()

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
    vapply(x, function(val) {
        if (is.na(val) || str_trim(val) == "") {
            return(FALSE)
        }
        opts <- str_trim(str_split(val, ";")[[1]])
        any(opts != "No")
    }, logical(1))
}
fun_domain_status <- function(x) {
    case_when(
        is.na(x) | str_trim(x) == "" ~ "Not Asked",
        x == "Yes" ~ "Yes",
        TRUE ~ "No"
    )
}
fun_domain_status_multiselect <- function(x) {
    case_when(
        is.na(x) | str_trim(x) == "" ~ "Not Asked",
        fun_any_not_no(x) ~ "Yes",
        TRUE ~ "No"
    )
}
fun_parse_start_year <- function(years_text) {
    vapply(years_text, function(val) {
        if (is.na(val) || str_trim(val) == "") {
            return(NA_integer_)
        }
        nums <- as.integer(str_extract_all(val, "\\d{4}")[[1]])
        if (length(nums) == 0) {
            return(NA_integer_)
        }
        min(nums)
    }, integer(1), USE.NAMES = FALSE)
}
fun_parse_end_year <- function(years_text, current_year) {
    vapply(years_text, function(val) {
        if (is.na(val) || str_trim(val) == "") {
            return(NA_integer_)
        }
        nums <- as.integer(str_extract_all(val, "\\d{4}")[[1]])
        if (str_detect(str_to_lower(val), "present|onwards|ongoing")) {
            return(max(c(nums, current_year)))
        }
        if (length(nums) == 0) {
            return(NA_integer_)
        }
        max(nums)
    }, integer(1), USE.NAMES = FALSE)
}
fun_build_long_term_monitoring_timeline <- function(df_long, group_col, axis_label) {
    df_summary <- df_long %>%
        filter(!is.na(startYear) & !is.na(endYear)) %>%
        group_by({{ group_col }}) %>%
        summarise(
            startYear = min(startYear),
            endYear = max(endYear),
            nProjects = n(),
            status = case_when(
                any(ongoing == "Yes") ~ "Yes",
                any(ongoing == "No") ~ "No",
                TRUE ~ "Unclear"
            ),
            .groups = "drop"
        ) %>%
        arrange(desc(startYear)) %>%
        mutate({{ group_col }} := fct_inorder({{ group_col }}))
    plot <- ggplot(df_summary, aes(
        y = {{ group_col }}, x = startYear, xend = endYear, yend = {{ group_col }}, color = status
    )) +
        geom_segment(linewidth = 6) +
        scale_color_manual(
            values = c("Yes" = "#382e6b", "No" = "#b1abd1", "Unclear" = "#999999"),
            name = "Any Ongoing Project?"
        ) +
        scale_x_continuous(
            breaks = scales::pretty_breaks(n = 5),
            labels = scales::label_number(big.mark = "")
        ) +
        scale_y_discrete(labels = fun_wrap_two_lines) +
        labs(x = "Year", y = axis_label) +
        theme_pubclean() +
        theme(
            axis.text.y = element_text(size = 14),
            axis.text.x = element_text(size = 16),
            axis.title = element_text(size = 18),
            legend.text = element_text(size = 14),
            legend.title = element_text(size = 16)
        )
    list(data = df_summary, plot = plot)
}

## Set Fig/Table Number Variable ---------------------------------------------------
fig_num <- 0
table_num <- 0

## Analyze Section 2: Organization Information
# Determine which organizations participated and how many
unique_organization_names <- unique(df$organizationName)
unique_organizations <- length(unique_organization_names)
result_unique_organizations <- paste0(
    "Participating organizations totaled ",
    unique_organizations,
    ", including ",
    combine_words(unique_organization_names), "."
)

## Analyze Section 3: Biodiversity Monitoring Activities
# Determine the proportion of organizations that do biodiveristy monitoring, and which don't
proportion_does_biodiversity_monitoring <- round(mean(df$doesMonitoring == "Yes", na.rm = TRUE), 2)
organizations_do_not_do_biodiversity_monitoring <- filter(df, df$doesMonitoring == "No")$organizationName
result_proportion_does_biodiversity_monitoring <- paste0(
    "Proportion of organizations doing biodiversity monitoring is ",
    proportion_does_biodiversity_monitoring,
    ", with the following organizations reporting they do not participate in biodiversity monitoring: ",
    combine_words(organizations_do_not_do_biodiversity_monitoring), "."
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
        level3 = fun_clean_text(level3),
        level2 = str_remove(level2, regex("\\s*\\(e\\.g\\.[^)]*\\)$", ignore_case = TRUE))
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
        response_counts <- tibble(response = df[[column]]) %>%
            filter(!is.na(response), str_trim(response) != "") %>%
            # Respondents sometimes list multiple write-in answers separated by commas;
            # treat each as its own response rather than one combined string.
            separate_rows(response, sep = ",\\s*") %>%
            mutate(response = fun_clean_text(response)) %>%
            filter(!is.na(response)) %>%
            count(response, name = "n")
        if (nrow(response_counts) == 0) next
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
    "Other Small Mammals",
    "Other Medium-Sized Mammals",
    "Other Large Mammals"
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
# Investigate long-term monitoring projects
current_year <- as.integer(format(Sys.Date(), "%Y"))
df_long_term_monitoring <- df %>%
    select(organizationName, starts_with("lt")) %>%
    pivot_longer(
        cols = -organizationName,
        names_to = c(".value", "projectRow"),
        names_pattern = "^lt(Species|Sites|Years|Methods|Ongoing)_(\\d+)$"
    ) %>%
    filter(if_any(c(Species, Sites, Years, Methods, Ongoing), ~ !is.na(.) & str_trim(.) != "")) %>%
    transmute(
        organizationName,
        speciesTaxa = str_trim(Species),
        location = str_trim(Sites),
        years = str_trim(Years),
        methods = str_trim(Methods),
        ongoing = case_when(
            str_detect(str_to_lower(Ongoing), "^yes") ~ "Yes",
            str_detect(str_to_lower(Ongoing), "^no") ~ "No",
            TRUE ~ "Unclear"
        ),
        startYear = fun_parse_start_year(Years),
        endYear = fun_parse_end_year(Years, current_year)
    )
result_df_long_term_monitoring_projects <- df_long_term_monitoring %>%
    arrange(organizationName, startYear) %>%
    transmute(
        Organization = organizationName,
        `Species / Taxa` = speciesTaxa,
        `Location(s)` = location,
        `Year(s)` = years,
        Methods = methods,
        `Still Ongoing?` = ongoing
    )
write.csv(result_df_long_term_monitoring_projects, "outputs/result_df_long_term_monitoring_projects.csv")
n_long_term_monitoring_projects <- df_long_term_monitoring %>%
    filter(!is.na(startYear) & !is.na(endYear)) %>%
    nrow()
df_research_projects <- df %>%
    select(organizationName, starts_with("rr")) %>%
    pivot_longer(
        cols = -organizationName,
        names_to = c(".value", "projectRow"),
        names_pattern = "^rr(Species|Sites|Years|Methods)_(\\d+)$"
    ) %>%
    filter(if_any(c(Species, Sites, Years, Methods), ~ !is.na(.) & str_trim(.) != "")) %>%
    transmute(
        organizationName,
        speciesTaxa = str_trim(Species),
        location = str_trim(Sites),
        years = str_trim(Years),
        methods = str_trim(Methods),
        startYear = fun_parse_start_year(Years),
        endYear = fun_parse_end_year(Years, current_year)
    )
result_df_research_projects <- df_research_projects %>%
    arrange(organizationName) %>%
    transmute(
        Organization = organizationName,
        `Species / Taxa` = speciesTaxa,
        `Location(s)` = location,
        `Year(s)` = years,
        Methods = methods
    )
write.csv(result_df_research_projects, "outputs/result_df_research_projects.csv")
bar_height <- 0.9
family_gap <- 0.6
df_org_long_term <- df_long_term_monitoring %>%
    filter(!is.na(startYear) & !is.na(endYear)) %>%
    group_by(organizationName) %>%
    summarise(
        startYear = min(startYear),
        endYear = max(endYear),
        .groups = "drop"
    ) %>%
    mutate(category = "Long-Term Monitoring")
df_org_research <- df_research_projects %>%
    filter(!is.na(startYear) & !is.na(endYear)) %>%
    group_by(organizationName) %>%
    summarise(
        startYear = min(startYear),
        endYear = max(endYear),
        .groups = "drop"
    ) %>%
    mutate(category = "One-Off Research")
org_order <- bind_rows(df_org_long_term, df_org_research) %>%
    group_by(organizationName) %>%
    summarise(minStartYear = min(startYear), .groups = "drop") %>%
    arrange(desc(minStartYear)) %>%
    pull(organizationName)
df_org_timeline <- bind_rows(df_org_long_term, df_org_research) %>%
    mutate(
        organizationName = factor(organizationName, levels = org_order),
        category = factor(category, levels = c("Long-Term Monitoring", "One-Off Research"))
    ) %>%
    arrange(organizationName, category) %>%
    mutate(
        step = case_when(
            row_number() == 1 ~ 0,
            organizationName != lag(organizationName) ~ bar_height + family_gap,
            TRUE ~ bar_height
        ),
        y_pos = -cumsum(step)
    ) %>%
    group_by(organizationName) %>%
    mutate(rowLabel = if_else(row_number() == 1, as.character(organizationName), "")) %>%
    ungroup()
result_plot_long_term_monitoring_orgs <- ggplot(df_org_timeline, aes(
    xmin = startYear, xmax = endYear,
    ymin = y_pos - bar_height / 2, ymax = y_pos + bar_height / 2,
    fill = category
)) +
    geom_rect(color = "black") +
    scale_fill_manual(
        values = c("Long-Term Monitoring" = "#382e6b", "One-Off Research" = "#c97a2b"),
        name = "Category"
    ) +
    scale_x_continuous(
        breaks = scales::pretty_breaks(n = 5),
        labels = scales::label_number(big.mark = "")
    ) +
    scale_y_continuous(
        breaks = df_org_timeline$y_pos, labels = df_org_timeline$rowLabel,
        expand = expansion(add = family_gap)
    ) +
    labs(x = "Year", y = NULL) +
    theme_pubclean() +
    theme(
        axis.text.y = element_text(size = 14),
        axis.text.x = element_text(size = 16),
        axis.title = element_text(size = 18),
        legend.text = element_text(size = 14),
        legend.title = element_text(size = 16)
    )
fig_num <- fig_num + 1
result_caption_plot_long_term_monitoring_orgs <- paste0(
    "Figure ", fig_num, ". Timeline of biodiversity monitoring and research, by organization."
)
ggsave("outputs/result_plot_long_term_monitoring_orgs.jpeg", result_plot_long_term_monitoring_orgs,
    units = "in", height = 10, width = 12
)
long_term_monitoring_timeline_taxon <- fun_build_long_term_monitoring_timeline(
    df_long_term_monitoring %>%
        separate_rows(speciesTaxa, sep = ",\\s*") %>%
        mutate(speciesTaxa = fun_clean_text(speciesTaxa)),
    speciesTaxa, "Species / Taxon"
)
result_plot_long_term_monitoring_taxa <- long_term_monitoring_timeline_taxon$plot
fig_num <- fig_num + 1
result_caption_plot_long_term_monitoring_taxa <- paste0(
    "Figure ", fig_num, ". Timeline of long-term biodiversity monitoring, by species/taxon monitored (n = ",
    n_long_term_monitoring_projects, " projects). Each bar spans that taxon's earliest reported project ",
    "start year to its latest end year, and is colored by whether it has at least one still-ongoing project."
)
ggsave("outputs/result_plot_long_term_monitoring_taxa.jpeg", result_plot_long_term_monitoring_taxa,
    units = "in", height = 18, width = 14
)
long_term_monitoring_timeline_method <- fun_build_long_term_monitoring_timeline(
    df_long_term_monitoring %>%
        separate_rows(methods, sep = ",\\s*") %>%
        mutate(methods = fun_clean_text(methods)),
    methods, "Method"
)
result_plot_long_term_monitoring_methods <- long_term_monitoring_timeline_method$plot
fig_num <- fig_num + 1
result_caption_plot_long_term_monitoring_methods <- paste0(
    "Figure ", fig_num, ". Timeline of long-term biodiversity monitoring, by method used (n = ",
    n_long_term_monitoring_projects, " projects). Each bar spans that method's earliest reported project ",
    "start year to its latest end year, and is colored by whether it has at least one still-ongoing project."
)
ggsave("outputs/result_plot_long_term_monitoring_methods.jpeg", result_plot_long_term_monitoring_methods,
    units = "in", height = 16, width = 14
)
long_term_monitoring_timeline_location <- fun_build_long_term_monitoring_timeline(
    df_long_term_monitoring %>%
        separate_rows(location, sep = ",\\s*") %>%
        mutate(location = fun_clean_text(location)),
    location, "Location"
)
result_plot_long_term_monitoring_locations <- long_term_monitoring_timeline_location$plot
fig_num <- fig_num + 1
result_caption_plot_long_term_monitoring_locations <- paste0(
    "Figure ", fig_num, ". Timeline of long-term biodiversity monitoring, by location (n = ",
    n_long_term_monitoring_projects, " projects). Each bar spans that location's earliest reported ",
    "project start year to its latest end year, and is colored by whether it has at least one still-ongoing ",
    "project."
)
ggsave("outputs/result_plot_long_term_monitoring_locations.jpeg", result_plot_long_term_monitoring_locations,
    units = "in", height = 16, width = 14
)
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
    combine_words(organizations_do_comm_services_relations_studying), "."
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
    combine_words(organizations_do_engagement), "."
)
# Map communities most often engaged with
df_engagement_edges <- df %>%
    select(organizationName, communityEngagement, engagementCommunities) %>%
    filter(communityEngagement == "Yes", !is.na(engagementCommunities), engagementCommunities != "") %>%
    separate_rows(engagementCommunities, sep = "\\s*[,\n]\\s*") %>%
    mutate(engagementCommunities = str_trim(engagementCommunities)) %>%
    filter(engagementCommunities != "") %>%
    transmute(from = organizationName, to = engagementCommunities)
graph_engagement <- as_tbl_graph(df_engagement_edges, directed = TRUE) %>%
    activate(nodes) %>%
    mutate(
        is_respondent = name %in% df_engagement_edges$from,
        node_degree = centrality_degree()
    )
result_plot_engagement_network <- ggraph(graph_engagement, layout = "fr") +
    geom_edge_link(
        color = "#b1abd1", alpha = 0.7, edge_width = 1,
        arrow = grid::arrow(length = unit(6, "mm"), type = "closed"),
        end_cap = circle(3, "mm")
    ) +
    geom_node_point(aes(size = node_degree, color = is_respondent)) +
    geom_node_text(aes(label = name), repel = TRUE, size = 6, max.overlaps = 20) +
    scale_color_manual(
        values = c("TRUE" = "#382e6b", "FALSE" = "#456b2e"),
        guide = "none"
    ) +
    scale_size_continuous(range = c(3, 10), guide = "none") +
    theme_void()
fig_num <- fig_num + 1
result_caption_plot_engagement_network <- paste0(
    "Figure ", fig_num, ". Network diagram of communities engaged by surveyed organizations (n = ",
    length(unique(df_engagement_edges$from)),
    " surveyed organizations reporting at least one engaged community).",
    " Arrows point from the surveyed organization to the engaged community.",
    " Indigo nodes are surveyed organizations and green nodes are communities named by respondents.",
    " Node size reflects number of reported connections."
)
ggsave("outputs/result_plot_engagement_network.jpeg", result_plot_engagement_network,
    units = "in", height = 18, width = 18
)
# Investigate types of community engagement most often done
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
df_collaboration_edges <- df %>%
    select(organizationName, collaboration, collaborationOrgsList) %>%
    filter(collaboration == "Yes", !is.na(collaborationOrgsList), collaborationOrgsList != "") %>%
    separate_rows(collaborationOrgsList, sep = "\\s*[,\n]\\s*") %>%
    mutate(collaborationOrgsList = str_trim(collaborationOrgsList)) %>%
    filter(collaborationOrgsList != "") %>%
    transmute(from = organizationName, to = collaborationOrgsList)
graph_collaboration <- as_tbl_graph(df_collaboration_edges, directed = FALSE) %>%
    activate(nodes) %>%
    mutate(
        is_respondent = name %in% df_collaboration_edges$from,
        node_degree = centrality_degree()
    )
result_plot_collaboration_network <- ggraph(graph_collaboration, layout = "fr") +
    geom_edge_link(color = "#b1abd1", alpha = 0.5) +
    geom_node_point(aes(size = node_degree, color = is_respondent)) +
    geom_node_text(aes(label = name), repel = TRUE, size = 5, max.overlaps = 20) +
    scale_color_manual(
        values = c("TRUE" = "#382e6b", "FALSE" = "#456b2e"),
        guide = "none"
    ) +
    scale_size_continuous(range = c(3, 10), guide = "none") +
    theme_void()
fig_num <- fig_num + 1
result_caption_plot_collaboration_network <- paste0(
    "Figure ", fig_num, ". Network diagram of reported collaborations between organizations (n = ",
    length(unique(df_collaboration_edges$from)),
    " surveyed organizations reporting at least one collaboration).",
    " Indigo nodes are surveyed organizations and green nodes are external collaborators named by respondents.",
    " Node size reflects number of reported connections."
)
ggsave("outputs/result_plot_collaboration_network.jpeg", result_plot_collaboration_network,
    units = "in", height = 18, width = 18
)
# Examine major challenges for data collection
organizations_report_challenges <- filter(df, !is.na(challenges) & str_trim(challenges) != "")$organizationName
df_challenges <- df %>%
    select(challenges) %>%
    separate_rows(challenges, sep = ",\\s*") %>%
    mutate(challenges = fun_clean_text(challenges)) %>%
    filter(!is.na(challenges), challenges != "") %>%
    count(challenges, name = "n") %>%
    mutate(challenges = fct_reorder(challenges, n))
result_plot_challenges <- ggplot(df_challenges, aes(x = n, y = challenges)) +
    geom_col(orientation = "y", color = "black", fill = "#382e6b") +
    labs(
        x = "Number of responses", y = "Challenge"
    ) +
    theme_pubclean() +
    theme(
        axis.text.y = element_text(size = 22),
        axis.text.x = element_text(size = 22),
        axis.title = element_text(size = 25)
    )
fig_num <- fig_num + 1
result_caption_plot_challenges <- paste0(
    "Figure ", fig_num, ". Bar chart of major challenges to data collection reported by surveyed organizations (n = ",
    length(organizations_report_challenges), ")."
)
ggsave("outputs/result_plot_challenges.jpeg", result_plot_challenges,
    units = "in", height = 23, width = 18
)

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
df_complementary_software <- df %>%
    select(complementarySoftware) %>%
    separate_rows(complementarySoftware, sep = "[;,]\\s*") %>%
    mutate(complementarySoftware = na_if(str_trim(complementarySoftware), "")) %>%
    filter(!is.na(complementarySoftware)) %>%
    count(complementarySoftware, name = "n") %>%
    arrange(-n) %>%
    mutate(complementarySoftwareCount = paste0(complementarySoftware, " (", n, ")"))
result_complementary_software <- paste0(
    "Organizations reported using a range of complementary software to operate and process data from their technological survey equipment, with reported software by number of responses including: ",
    combine_words(df_complementary_software$complementarySoftwareCount), "."
)
# Examine missing data processing software and subscriptions
num_missing_software <- round(sum(
    df$missingSoftwareEquipment != "No" & !is.na(df$missingSoftwareEquipment) & df$missingSoftwareEquipment != ""
), 2)
df_missing_software <- df %>%
    select(missingSoftwareEquipment) %>%
    separate_rows(missingSoftwareEquipment, sep = "[;,]\\s*") %>%
    mutate(missingSoftwareEquipment = na_if(str_trim(missingSoftwareEquipment), "")) %>%
    filter(!is.na(missingSoftwareEquipment), str_to_lower(missingSoftwareEquipment) != "no") %>%
    count(missingSoftwareEquipment, name = "n") %>%
    arrange(-n) %>%
    mutate(missingSoftwareEquipmentCount = paste0(missingSoftwareEquipment, " (", n, ")"))
result_missing_software <- paste0(
    "The number of organizations reporting missing complementary software, equipment, or technology (e.g. online subscriptions) needed to increase the success of their monitoring and research is ",
    num_missing_software,
    ", with reported needs by number of responses including: ",
    combine_words(df_missing_software$missingSoftwareEquipmentCount), "."
)
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
undigitized_data_responses <- df %>%
    filter(!is.na(undigitizedData), str_trim(undigitizedData) != "") %>%
    pull(undigitizedData)
result_undigitized_data <- paste0(
    "Surveyed organizations reported the following undigitized data: ",
    combine_words(undigitized_data_responses), "."
)

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
    "."
)
# See if participants publish their reports
num_does_report_publish <- round(sum(df$publishOnline == "Yes", na.rm = TRUE), 2)
organizations_do_report_publish <- filter(df, df$publishOnline == "Yes")$organizationName
result_num_does_report_publish <- paste0(
    "The number of organizations that publish their reports online is ",
    num_does_report_publish,
    ", including: ",
    combine_words(organizations_do_report_publish), "."
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
num_does_data_share <- round(sum(df$shareData == "Yes", na.rm = TRUE), 2)
num_does_data_share_no <- round(sum(df$shareData == "No", na.rm = TRUE), 2)
df_data_share_edges <- df %>%
    select(organizationName, shareData, shareDataWhom) %>%
    filter(shareData == "Yes", !is.na(shareDataWhom), shareDataWhom != "") %>%
    separate_rows(shareDataWhom, sep = "\\s*[,\n]\\s*") %>%
    mutate(shareDataWhom = str_trim(shareDataWhom)) %>%
    filter(shareDataWhom != "") %>%
    transmute(from = organizationName, to = shareDataWhom)
graph_data_share <- as_tbl_graph(df_data_share_edges, directed = TRUE) %>%
    activate(nodes) %>%
    mutate(
        is_respondent = name %in% df_data_share_edges$from,
        node_degree = centrality_degree()
    )
result_plot_data_share_network <- ggraph(graph_data_share, layout = "fr") +
    geom_edge_link(
        color = "#b1abd1", alpha = 0.7, edge_width = 1,
        arrow = grid::arrow(length = unit(6, "mm"), type = "closed"),
        end_cap = circle(3, "mm")
    ) +
    geom_node_point(aes(size = node_degree, color = is_respondent)) +
    geom_node_text(aes(label = name), repel = TRUE, size = 8, max.overlaps = 20) +
    scale_color_manual(
        values = c("TRUE" = "#382e6b", "FALSE" = "#456b2e"),
        guide = "none"
    ) +
    scale_size_continuous(range = c(3, 10), guide = "none") +
    theme_void()
fig_num <- fig_num + 1
result_caption_plot_data_share_network <- paste0(
    "Figure ", fig_num, ". Network diagram of reported data sharing between organizations (n = ",
    length(unique(df_data_share_edges$from)),
    " surveyed organizations reporting that they share data outside their organization).",
    " Arrows point from the surveyed organization to the recipient of their shared data.",
    " Indigo nodes are surveyed organizations and green nodes are external recipients named by respondents.",
    " Node size reflects number of reported connections."
)
ggsave("outputs/result_plot_data_share_network.jpeg", result_plot_data_share_network,
    units = "in", height = 18, width = 18
)
# See if participants share datasets to repositories
num_does_data_share_repository <- round(sum(df$onlineRepos == "Yes", na.rm = TRUE), 2)
num_does_data_share_repository_no <- round(sum(df$onlineRepos == "No", na.rm = TRUE), 2)
df_data_share_repository <- df %>%
    select(onlineReposWhichOnes) %>%
    separate_rows(onlineReposWhichOnes, sep = "[;,]\\s*") %>%
    mutate(onlineReposWhichOnes = na_if(str_trim(onlineReposWhichOnes), "")) %>%
    filter(!is.na(onlineReposWhichOnes)) %>%
    count(onlineReposWhichOnes, name = "n") %>%
    arrange(-n) %>%
    mutate(onlineReposWhichOnesCount = paste0(onlineReposWhichOnes, " (", n, ")"))
result_num_data_share_repository <- paste0(
    "The number of organizations reporting that they share data to online repositories is ",
    num_does_data_share_repository,
    ", with reported repositories by number of responses including: ",
    combine_words(df_data_share_repository$onlineReposWhichOnesCount), "."
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
        num_does_data_share,
        num_does_data_share_repository
    ),
    no = c(
        num_does_report_writing_no,
        num_does_report_submission_no,
        num_does_report_publish_no,
        num_does_paper_publish_no,
        filter(df_data_dashboard, publicDashboard == "No")$n,
        num_does_data_share_no,
        num_does_data_share_repository_no
    )
) %>%
    mutate(
        Yes = paste0(yes, " - ", round(yes / (yes + no) * 100, 1), "%"),
        No = paste0(no, " - ", round(no / (yes + no) * 100, 1), "%")
    ) %>%
    select(`Sharing Method`, Yes, No)
table_num <- table_num + 1
result_caption_table_data_sharing_collated <- paste0(
    "Table ", table_num, ". Summary of how many surveyed organizations report doing each type of data sharing activity, ",
    "with the number and percentage of respondents answering yes and no for each activity."
)
write.csv(result_df_data_sharing_collated, "outputs/result_df_data_sharing_collated.csv")

## Analyze Section 13: National Biodiversity Coordination
# See if participants are involved in national working groups
num_does_working_group_member <- round(sum(df$workingGroupsInvolved == "Yes", na.rm = TRUE), 2)
df_working_group_member_identities <- df %>%
    select(workingGroupsListText) %>%
    separate_rows(workingGroupsListText, sep = "[;,]\\s*") %>%
    mutate(workingGroupsListText = na_if(str_trim(workingGroupsListText), "")) %>%
    filter(!is.na(workingGroupsListText)) %>%
    count(workingGroupsListText, name = "n") %>%
    arrange(-n) %>%
    mutate(workingGroupsListTextCount = paste0(workingGroupsListText, " (", n, ")"))
result_num_working_group_member <- paste0(
    "The number of organizations reporting that they are involved in a biodiversity national working group is ",
    num_does_working_group_member,
    ", with reported working groups by number of responses including: ",
    combine_words(df_working_group_member_identities$workingGroupsListTextCount), "."
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
num_does_task_force_member <- round(sum(df$taskForceInvolved == "Yes", na.rm = TRUE), 2)
df_task_force_member_identities <- df %>%
    select(taskForceListText) %>%
    separate_rows(taskForceListText, sep = "[;,]\\s*") %>%
    mutate(taskForceListText = na_if(str_trim(taskForceListText), "")) %>%
    filter(!is.na(taskForceListText)) %>%
    count(taskForceListText, name = "n") %>%
    arrange(-n) %>%
    mutate(taskForceListTextCount = paste0(taskForceListText, " (", n, ")"))
result_num_task_force_member <- paste0(
    "The number of organizations reporting that they are involved in a biodiversity task force is ",
    num_does_task_force_member,
    ", with reported task forces by number of responses including: ",
    combine_words(df_task_force_member_identities$taskForceListTextCount), "."
)

## Analyze Section 14: Significance & Interest
# List species of cultural significance
num_species_culturally_significant <- round(sum(
    df$culturalSpecies != "No" & !is.na(df$culturalSpecies) & df$culturalSpecies != ""
), 2)
df_species_culturally_significant <- df %>%
    select(culturalSpecies) %>%
    separate_rows(culturalSpecies, sep = "[;,]\\s*") %>%
    mutate(culturalSpecies = na_if(str_trim(culturalSpecies), "")) %>%
    filter(!is.na(culturalSpecies), str_to_lower(culturalSpecies) != "no") %>%
    count(culturalSpecies, name = "n") %>%
    arrange(-n) %>%
    mutate(culturalSpeciesCount = paste0(culturalSpecies, " (", n, ")"))
result_list_species_culturally_significant <- paste0(
    "The number of organizations reporting species of cultural significance to Belize is ",
    num_species_culturally_significant,
    ", with reported species by number of responses including: ",
    combine_words(df_species_culturally_significant$culturalSpeciesCount), "."
)
# List species of economic significance
num_species_economically_significant <- round(sum(
    df$economicSpecies != "No" & !is.na(df$economicSpecies) & df$economicSpecies != ""
), 2)
df_species_economically_significant <- df %>%
    select(economicSpecies) %>%
    separate_rows(economicSpecies, sep = "[;,]\\s*") %>%
    mutate(economicSpecies = na_if(str_trim(economicSpecies), "")) %>%
    filter(!is.na(economicSpecies), str_to_lower(economicSpecies) != "no") %>%
    count(economicSpecies, name = "n") %>%
    arrange(-n) %>%
    mutate(economicSpeciesCount = paste0(economicSpecies, " (", n, ")"))
result_list_species_economically_significant <- paste0(
    "The number of organizations reporting species of economic significance to Belize is ",
    num_species_economically_significant,
    ", with reported species by number of responses including: ",
    combine_words(df_species_economically_significant$economicSpeciesCount), "."
)
# Investigate specific species concerns
df_community_concerns <- df %>%
    select(organizationName, starts_with("cc")) %>%
    pivot_longer(
        cols = -organizationName,
        names_to = c(".value", "concernRow"),
        names_pattern = "^cc(Community|District|Species|Reason)_(\\d+)$"
    ) %>%
    filter(if_any(c(Community, District, Species, Reason), ~ !is.na(.) & str_trim(.) != "")) %>%
    transmute(
        organizationName,
        community = str_trim(Community),
        district = str_trim(District),
        speciesConcern = str_trim(Species),
        reason = str_trim(Reason)
    )
result_df_community_concerns <- df_community_concerns %>%
    arrange(organizationName) %>%
    transmute(
        Organization = organizationName,
        Community = community,
        District = district,
        `Species / Taxa` = speciesConcern,
        Reason = reason
    )
write.csv(result_df_community_concerns, "outputs/result_df_community_concerns.csv")
df_concern_matrix <- df_community_concerns %>%
    filter(!is.na(speciesConcern), speciesConcern != "", !is.na(district), district != "") %>%
    separate_rows(district, sep = "[;,]\\s*") %>%
    separate_rows(speciesConcern, sep = "[;,]\\s*") %>%
    mutate(
        speciesConcern = fun_clean_text(speciesConcern),
        district = fun_clean_text(district)
    ) %>%
    filter(!is.na(speciesConcern), !is.na(district)) %>%
    count(district, speciesConcern, name = "n")
species_concern_order <- df_concern_matrix %>%
    group_by(speciesConcern) %>%
    summarise(n = sum(n), .groups = "drop") %>%
    arrange(n) %>%
    pull(speciesConcern)
district_concern_order <- df_concern_matrix %>%
    group_by(district) %>%
    summarise(n = sum(n), .groups = "drop") %>%
    arrange(desc(n)) %>%
    pull(district)
df_concern_matrix <- df_concern_matrix %>%
    mutate(
        speciesConcern = factor(speciesConcern, levels = species_concern_order),
        district = factor(district, levels = district_concern_order)
    )
result_plot_concern_matrix <- ggplot(df_concern_matrix, aes(x = district, y = speciesConcern, fill = n)) +
    geom_tile(color = "black") +
    scale_fill_gradient(low = "#b1abd1", high = "#382e6b", name = "Number of\nResponses") +
    scale_y_discrete(labels = fun_wrap_two_lines) +
    labs(
        x = "District", y = "Species / Taxon of Concern"
    ) +
    theme_pubclean() +
    theme(
        axis.text.y = element_text(size = 22),
        axis.text.x = element_text(size = 22),
        axis.title = element_text(size = 25),
        legend.text = element_text(size = 14),
        legend.title = element_text(size = 16)
    )
fig_num <- fig_num + 1
result_caption_plot_concern_matrix <- paste0(
    "Figure ", fig_num, ". Heatmap of species/taxa of concern to communities by district, as reported by surveyed organizations (n = ",
    length(unique(df_community_concerns$organizationName)),
    "). Cell color reflects the number of responses reporting that species/taxon of concern within that district; ",
    "blank cells indicate no reported concern for that combination."
)
ggsave("outputs/result_plot_concern_matrix.jpeg", result_plot_concern_matrix,
    units = "in", height = 23, width = 18
)
# List species of future interest
df_species_future_interest <- df %>%
    select(organizationName, futureMonitoring) %>%
    mutate(futureMonitoring = na_if(str_trim(futureMonitoring), "")) %>%
    filter(!is.na(futureMonitoring), str_to_lower(futureMonitoring) != "no") %>%
    mutate(futureMonitoringQuote = paste0(organizationName, ': "', futureMonitoring, '"'))
result_list_species_future_interest <- paste0(
    "Organizations reported the following regarding species of future monitoring interest: ",
    combine_words(df_species_future_interest$futureMonitoringQuote), "."
)
# List species of monitoring gap
# TO DO: Requires manual data cleaning for question 44
num_species_monitoring_gap <- round(sum(
    df$speciesMonitoringGap != "No" & !is.na(df$speciesMonitoringGap) & df$speciesMonitoringGap != ""
), 2)
df_species_monitoring_gap <- df %>%
    select(speciesMonitoringGap) %>%
    separate_rows(speciesMonitoringGap, sep = "[;,]\\s*") %>%
    mutate(speciesMonitoringGap = na_if(str_trim(speciesMonitoringGap), "")) %>%
    filter(!is.na(speciesMonitoringGap), str_to_lower(speciesMonitoringGap) != "no") %>%
    count(speciesMonitoringGap, name = "n") %>%
    arrange(-n) %>%
    mutate(speciesMonitoringGapCount = paste0(speciesMonitoringGap, " (", n, ")"))
result_list_species_monitoring_gap <- paste0(
    "The number of organizations reporting a significant species monitoring gap is ",
    num_species_monitoring_gap,
    ", with reported species by number of responses including: ",
    combine_words(df_species_monitoring_gap$speciesMonitoringGapCount), "."
)
# List species of monitoring importance
# TO DO: Requires manual data cleaning for question 44
num_species_monitoring_importance <- round(sum(
    df$speciesMonitoringImportance != "No" & !is.na(df$speciesMonitoringImportance) & df$speciesMonitoringImportance != ""
), 2)
df_species_monitoring_importance <- df %>%
    select(speciesMonitoringImportance) %>%
    separate_rows(speciesMonitoringImportance, sep = "[;,]\\s*") %>%
    mutate(speciesMonitoringImportance = na_if(str_trim(speciesMonitoringImportance), "")) %>%
    filter(!is.na(speciesMonitoringImportance), str_to_lower(speciesMonitoringImportance) != "no") %>%
    count(speciesMonitoringImportance, name = "n") %>%
    arrange(-n) %>%
    mutate(speciesMonitoringImportanceCount = paste0(speciesMonitoringImportance, " (", n, ")"))
result_list_species_monitoring_importance <- paste0(
    "The number of organizations reporting a significant species monitoring importance is ",
    num_species_monitoring_importance,
    ", with reported species by number of responses including: ",
    combine_words(df_species_monitoring_importance$speciesMonitoringImportanceCount), "."
)
# List area of monitoring gap
# TO DO: Requires manual data cleaning for question 44
num_area_monitoring_gap <- round(sum(
    df$areaMonitoringGap != "No" & !is.na(df$areaMonitoringGap) & df$areaMonitoringGap != ""
), 2)
df_area_monitoring_gap <- df %>%
    select(areaMonitoringGap) %>%
    separate_rows(areaMonitoringGap, sep = "[;,]\\s*") %>%
    mutate(areaMonitoringGap = na_if(str_trim(areaMonitoringGap), "")) %>%
    filter(!is.na(areaMonitoringGap), str_to_lower(areaMonitoringGap) != "no") %>%
    count(areaMonitoringGap, name = "n") %>%
    arrange(-n) %>%
    mutate(areaMonitoringGapCount = paste0(areaMonitoringGap, " (", n, ")"))
result_list_area_monitoring_gap <- paste0(
    "The number of organizations reporting a significant area monitoring gap is ",
    num_area_monitoring_gap,
    ", with reported areas by number of responses including: ",
    combine_words(df_area_monitoring_gap$areaMonitoringGapCount), "."
)
# List area of monitoring importance
# TO DO: Requires manual data cleaning for question 44
num_area_monitoring_importance <- round(sum(
    df$areaMonitoringImportance != "No" & !is.na(df$areaMonitoringImportance) & df$areaMonitoringImportance != ""
), 2)
df_area_monitoring_importance <- df %>%
    select(areaMonitoringImportance) %>%
    separate_rows(areaMonitoringImportance, sep = "[;,]\\s*") %>%
    mutate(areaMonitoringImportance = na_if(str_trim(areaMonitoringImportance), "")) %>%
    filter(!is.na(areaMonitoringImportance), str_to_lower(areaMonitoringImportance) != "no") %>%
    count(areaMonitoringImportance, name = "n") %>%
    arrange(-n) %>%
    mutate(areaMonitoringImportanceCount = paste0(areaMonitoringImportance, " (", n, ")"))
result_list_area_monitoring_importance <- paste0(
    "The number of organizations reporting a significant area monitoring importance is ",
    num_area_monitoring_importance,
    ", with reported areas by number of responses including: ",
    combine_words(df_area_monitoring_importance$areaMonitoringImportanceCount), "."
)

## Final Section: Overall Analysis ---------------------------------------------------
# Compare domain coverage across organizations
domain_order <- c(
    "Biodiversity Monitoring", "Ecosystem Health Data", "Habitat Restoration",
    "Pollution Data", "Invasive Species", "Ecosystem Services",
    "Community-Ecosystem Service Relations", "Climate Resiliency",
    "Enforcement", "Community Engagement", "Collaboration",
    "Reports To GoB", "Publishes Reports Online", "Publishes Peer-Reviewed Papers",
    "Public Data Dashboard", "Shares Data Directly", "Shares Data To Repositories",
    "National Working Group Member", "National Task Force Member"
)
df_domain_coverage <- df %>%
    transmute(
        organizationName,
        `Biodiversity Monitoring` = fun_domain_status(doesMonitoring),
        `Ecosystem Health Data` = fun_domain_status_multiselect(ecosystemHealthData),
        `Habitat Restoration` = fun_domain_status(habitatRestoration),
        `Pollution Data` = fun_domain_status_multiselect(pollutionData),
        `Invasive Species` = fun_domain_status(invasiveSpecies),
        `Ecosystem Services` = fun_domain_status(ecosystemServices),
        `Community-Ecosystem Service Relations` = fun_domain_status(communityEcosystemServices),
        `Climate Resiliency` = fun_domain_status_multiselect(climateResiliency),
        `Enforcement` = fun_domain_status(doesEnforcement),
        `Community Engagement` = fun_domain_status(communityEngagement),
        `Collaboration` = fun_domain_status(collaboration),
        `Reports To GoB` = fun_domain_status(govReports),
        `Publishes Reports Online` = fun_domain_status(publishOnline),
        `Publishes Peer-Reviewed Papers` = fun_domain_status(publishPapers),
        `Public Data Dashboard` = fun_domain_status(publicDashboard),
        `Shares Data Directly` = fun_domain_status(shareData),
        `Shares Data To Repositories` = fun_domain_status(onlineRepos),
        `National Working Group Member` = fun_domain_status(workingGroupsInvolved),
        `National Task Force Member` = fun_domain_status(taskForceInvolved)
    ) %>%
    pivot_longer(-organizationName, names_to = "domain", values_to = "status")
org_domain_order <- df_domain_coverage %>%
    group_by(organizationName) %>%
    summarise(nYes = sum(status == "Yes"), .groups = "drop") %>%
    arrange(desc(nYes)) %>%
    pull(organizationName)
df_domain_coverage <- df_domain_coverage %>%
    mutate(
        organizationName = factor(organizationName, levels = org_domain_order),
        domain = factor(domain, levels = rev(domain_order)),
        status = factor(status, levels = c("Yes", "No", "Not Asked"))
    )
result_plot_domain_coverage <- ggplot(df_domain_coverage, aes(x = organizationName, y = domain, fill = status)) +
    geom_tile(color = "white", linewidth = 0.5) +
    scale_fill_manual(
        values = c("Yes" = "#382e6b", "No" = "#d9d6ea", "Not Asked" = "#f2f2f2"),
        name = "Reported?"
    ) +
    scale_x_discrete(labels = fun_wrap_two_lines) +
    labs(x = "Organization", y = "Domain") +
    theme_pubclean() +
    theme(
        axis.text.x = element_text(size = 11, angle = 45, hjust = 1),
        axis.text.y = element_text(size = 14),
        axis.title = element_text(size = 18),
        legend.text = element_text(size = 14),
        legend.title = element_text(size = 16),
        panel.grid = element_blank()
    )
fig_num <- fig_num + 1
result_caption_plot_domain_coverage <- paste0(
    "Figure ", fig_num, ". Heatmap of monitoring, enforcement, mainstreaming, and data-sharing domain coverage by organization (n = ",
    unique_organizations,
    "). Organizations are ordered left to right by total number of domains reported, and domains are ordered top ",
    "to bottom to match their order of appearance in the survey. Grey tiles indicate the organization was not ",
    "asked or did not reach that question due to survey skip logic."
)
ggsave("outputs/result_plot_domain_coverage.jpeg", result_plot_domain_coverage,
    units = "in", height = 10, width = 16
)
# Compare species/taxa of interest ("important") to species/taxa actually studied
important_categories <- c(
    "Culturally Significant", "Economically Significant", "Community Concern",
    "Monitoring Gap", "Monitoring Importance"
)
fun_build_variant_map <- function(df_lookup) {
    df_lookup %>%
        separate_rows(raw_variants, sep = ";\\s*") %>%
        transmute(variant = str_to_upper(str_trim(raw_variants)), mapped_level1, mapped_level2)
}
fun_build_other_studied <- function(df, other_field_map) {
    rows <- list()
    for (i in seq_len(nrow(other_field_map))) {
        column <- other_field_map$column[i]
        level1 <- other_field_map$level1[i]
        level2 <- other_field_map$level2[i]
        is_new_taxon <- other_field_map$is_new_taxon[i]
        responses <- df %>%
            transmute(organizationName, response = .data[[column]]) %>%
            filter(!is.na(response), str_trim(response) != "") %>%
            separate_rows(response, sep = ",\\s*") %>%
            mutate(response = fun_clean_text(response)) %>%
            filter(!is.na(response))
        if (nrow(responses) == 0) next
        if (is_new_taxon) {
            rows[[length(rows) + 1]] <- responses %>%
                transmute(organizationName, text = str_to_upper(response), mapped_level1 = response, mapped_level2 = "")
        } else if (is.na(level2)) {
            rows[[length(rows) + 1]] <- responses %>%
                transmute(organizationName, text = str_to_upper(response), mapped_level1 = level1, mapped_level2 = "")
        } else {
            rows[[length(rows) + 1]] <- responses %>%
                transmute(organizationName, text = str_to_upper(response), mapped_level1 = level1, mapped_level2 = level2)
        }
    }
    bind_rows(rows)
}
fun_count_matches <- function(mapped_level1_i, mapped_level2_i, raw_variants_i, df_studied) {
    variants_i <- str_to_upper(str_trim(str_split(raw_variants_i, ";\\s*")[[1]]))
    exact_orgs <- df_studied %>%
        filter(text %in% variants_i) %>%
        distinct(organizationName) %>%
        pull(organizationName)
    inexact_orgs <- df_studied %>%
        filter(mapped_level1 == mapped_level1_i, mapped_level2 == mapped_level2_i, !(text %in% variants_i)) %>%
        distinct(organizationName) %>%
        pull(organizationName)
    tibble(n_exact = length(exact_orgs), n_inexact = length(inexact_orgs))
}
df_studied_checkbox <- df %>%
    select(organizationName, monitoringAreas) %>%
    separate_rows(monitoringAreas, sep = ";\\s*") %>%
    mutate(monitoringAreas = str_trim(monitoringAreas)) %>%
    filter(monitoringAreas != "")
levels_split_studied <- str_split_fixed(df_studied_checkbox$monitoringAreas, " - ", 3)
df_studied_checkbox <- df_studied_checkbox %>%
    mutate(
        level1 = fun_clean_text(str_trim(levels_split_studied[, 1])),
        level2 = fun_clean_text(str_trim(levels_split_studied[, 2])),
        level2 = str_remove(level2, regex("\\s*\\(e\\.g\\.[^)]*\\)$", ignore_case = TRUE))
    ) %>%
    transmute(
        organizationName,
        text = str_to_upper(coalesce(level2, level1)),
        mapped_level1 = level1,
        mapped_level2 = coalesce(level2, "")
    )
df_studied_lookup <- read.csv("data_deposit/studied_taxa_lookup.csv")
df_studied_variant_map <- fun_build_variant_map(df_studied_lookup)
df_studied_projects <- bind_rows(
    df_long_term_monitoring %>% transmute(organizationName, speciesTaxa),
    df_research_projects %>% transmute(organizationName, speciesTaxa)
) %>%
    filter(!is.na(speciesTaxa), speciesTaxa != "") %>%
    separate_rows(speciesTaxa, sep = "[;,]\\s*") %>%
    mutate(text = str_to_upper(fun_clean_text(speciesTaxa))) %>%
    filter(!is.na(text)) %>%
    distinct(organizationName, text) %>%
    left_join(df_studied_variant_map, by = c("text" = "variant")) %>%
    filter(!is.na(mapped_level1)) %>%
    transmute(organizationName, text, mapped_level1, mapped_level2 = coalesce(mapped_level2, ""))
df_studied_other <- fun_build_other_studied(df, other_field_map)
df_studied_all <- bind_rows(df_studied_checkbox, df_studied_projects, df_studied_other)
df_species_lookup <- read.csv("data_deposit/species_taxa_lookup.csv")
df_important_species <- df_species_lookup %>%
    separate_rows(source_categories, sep = ";\\s*") %>%
    mutate(source_categories = str_trim(source_categories)) %>%
    filter(source_categories %in% important_categories) %>%
    distinct(species_text, source_categories, mapped_level1, mapped_level2, match_type, raw_variants)
df_important_species <- df_important_species %>%
    mutate(
        counts = pmap(
            list(match_type, mapped_level1, mapped_level2, raw_variants),
            function(match_type_i, mapped_level1_i, mapped_level2_i, raw_variants_i) {
                if (match_type_i == "Unmapped") {
                    tibble(n_exact = NA_integer_, n_inexact = NA_integer_)
                } else {
                    fun_count_matches(mapped_level1_i, mapped_level2_i, raw_variants_i, df_studied_all)
                }
            }
        )
    ) %>%
    unnest(counts) %>%
    mutate(
        total_matches = coalesce(n_exact, 0L) + coalesce(n_inexact, 0L),
        cell_type = case_when(
            match_type == "Unmapped" ~ "Inapplicable",
            n_exact > 0 & n_inexact > 0 ~ "Both",
            n_exact > 0 ~ "Exact Only",
            n_inexact > 0 ~ "Inexact Only",
            TRUE ~ "No Match"
        )
    )
species_order <- df_important_species %>%
    distinct(species_text) %>%
    arrange(desc(species_text)) %>%
    pull(species_text)
df_important_species <- df_important_species %>%
    mutate(
        species_text = factor(species_text, levels = species_order),
        y_pos = as.integer(species_text),
        source_categories = factor(source_categories, levels = important_categories),
        x_pos = as.integer(source_categories)
    )
cell_half_width <- 0.45
cell_half_height <- 0.45
df_cells_both <- df_important_species %>%
    filter(cell_type == "Both") %>%
    {
        bind_rows(
            transmute(., species_text, y_pos, x_pos,
                xmin = x_pos - cell_half_width, xmax = x_pos,
                ymin = y_pos - cell_half_height, ymax = y_pos + cell_half_height,
                fill_value = n_exact, fill_type = "Exact"
            ),
            transmute(., species_text, y_pos, x_pos,
                xmin = x_pos, xmax = x_pos + cell_half_width,
                ymin = y_pos - cell_half_height, ymax = y_pos + cell_half_height,
                fill_value = n_inexact, fill_type = "Inexact"
            )
        )
    }
df_cells_single <- df_important_species %>%
    filter(cell_type != "Both") %>%
    transmute(
        species_text, y_pos, x_pos,
        xmin = x_pos - cell_half_width, xmax = x_pos + cell_half_width,
        ymin = y_pos - cell_half_height, ymax = y_pos + cell_half_height,
        fill_value = case_when(
            cell_type == "Exact Only" ~ n_exact,
            cell_type == "Inexact Only" ~ n_inexact,
            TRUE ~ NA_real_
        ),
        fill_type = case_when(
            cell_type == "Exact Only" ~ "Exact",
            cell_type == "Inexact Only" ~ "Inexact",
            cell_type == "No Match" ~ "No Match",
            cell_type == "Inapplicable" ~ "Inapplicable"
        )
    )
pal_exact <- scales::col_numeric(palette = c("#e5e1f0", "#382e6b"), domain = c(0, unique_organizations))
pal_inexact <- scales::col_numeric(palette = c("#e1f0e3", "#2e6b45"), domain = c(0, unique_organizations))
df_cells_final <- bind_rows(df_cells_both, df_cells_single) %>%
    mutate(
        hex_color = case_when(
            fill_type == "Exact" ~ pal_exact(fill_value),
            fill_type == "Inexact" ~ pal_inexact(fill_value),
            fill_type == "No Match" ~ "#ffffff",
            fill_type == "Inapplicable" ~ "#bfbfbf",
            TRUE ~ "#ffffff"
        )
    )
result_plot_important_vs_studied <- ggplot(df_cells_final) +
    geom_rect(
        aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = hex_color),
        color = "grey50", linewidth = 0.15
    ) +
    scale_fill_identity() +
    scale_x_continuous(
        breaks = seq_along(important_categories), labels = important_categories,
        expand = expansion(add = 0.6), position = "top"
    ) +
    scale_y_continuous(
        breaks = seq_along(species_order), labels = species_order,
        expand = expansion(add = 0.6)
    ) +
    labs(x = NULL, y = "Species / Taxon of Interest") +
    theme_pubclean() +
    theme(
        axis.text.x = element_text(size = 14),
        axis.text.y = element_text(size = 15),
        axis.title = element_text(size = 18),
        panel.grid = element_blank()
    )
fig_num <- fig_num + 1
result_caption_plot_important_vs_studied <- paste0(
    "Figure ", fig_num, ". Heatmap comparing species/taxa of reported interest against whether any surveyed ",
    "organization (n = ", unique_organizations, ") actually studies that taxon, combining standard taxa ",
    "selections, long-term monitoring projects, and one-off research projects as evidence of study. Violet ",
    "(left half of a cell, where both are present) indicates an exact match, in which the same species/taxon ",
    "name appears in the studied data, with darker violet reflecting more organizations. Green (right half) ",
    "indicates an inexact match, in which the species/taxon falls within a broader studied taxonomic group, ",
    "with darker green reflecting more organizations. White indicates no match found in studied data, and ",
    "grey indicates the species/taxon cannot be described by the survey's taxonomy at all. Species/taxa are ",
    "ordered top to bottom alphabetically."
)
ggsave("outputs/result_plot_important_vs_studied.jpeg", result_plot_important_vs_studied,
    units = "in", height = 24, width = 20
)

## Present Results
cat(result_unique_organizations)
cat(result_proportion_does_biodiversity_monitoring)
result_plot_taxa
cat(result_caption_plot_taxa)
result_plot_ecosystems
cat(result_caption_plot_ecosystems)
result_df_long_term_monitoring_projects
result_plot_long_term_monitoring_orgs
cat(result_caption_plot_long_term_monitoring_orgs)
result_plot_long_term_monitoring_taxa
cat(result_caption_plot_long_term_monitoring_taxa)
result_plot_long_term_monitoring_methods
cat(result_caption_plot_long_term_monitoring_methods)
result_plot_long_term_monitoring_locations
cat(result_caption_plot_long_term_monitoring_locations)
result_df_research_projects
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
result_plot_engagement_network
cat(result_caption_plot_engagement_network)
result_plot_engagement_types
cat(result_caption_plot_engagement_types)
cat(result_num_does_collaboration)
result_plot_collaboration_network
cat(result_caption_plot_collaboration_network)
result_plot_challenges
cat(result_caption_plot_challenges)
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
result_plot_data_share_network
cat(result_caption_plot_data_share_network)
cat(result_num_data_share_repository)
result_df_data_sharing_collated
cat(result_caption_table_data_sharing_collated)
cat(result_num_working_group_member)
cat(result_working_group_leaders)
cat(result_num_task_force_member)
cat(result_list_species_culturally_significant)
cat(result_list_species_economically_significant)
result_df_community_concerns
result_plot_concern_matrix
cat(result_caption_plot_concern_matrix)
cat(result_list_species_future_interest)
cat(result_list_species_monitoring_gap)
cat(result_list_species_monitoring_importance)
cat(result_list_area_monitoring_gap)
cat(result_list_area_monitoring_importance)
result_plot_domain_coverage
cat(result_caption_plot_domain_coverage)
result_plot_important_vs_studied
cat(result_caption_plot_important_vs_studied)
