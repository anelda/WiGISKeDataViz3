#' Get pregnancy data provided by WiGISKe -
#' http://wigis.co.ke/project/visualizing-teenage-pregnancy-and-related-factors/
#'
#' @param csv_file A link to a CSV file online or a path to a local CSV file as character string.
#' @return A tibble containing a cleaned up version of the pregnancy data
#' @importFrom readr read_csv
#' @importFrom magrittr "%>%"
#' @importFrom rlang .data
#' @importFrom janitor clean_names
#' @importFrom dplyr rename relocate select mutate case_when
#' @importFrom tidyr separate
#' @importFrom stringr str_remove
#' @importFrom lubridate as_date
#' @examples
#' ken_preg <- get_pregnancy_data(csv_file = "https://tinyurl.com/y35htfoj")
#' @author Anelda van der Walt
#' @export
get_pregnancy_data <- function(csv_file){
  # Read data from a copy of the original GS to help with permission settings
  gs_preg <- readr::read_csv(csv_file)

  preg_columns <- gs_preg %>%
    # Clean column names
    janitor::clean_names() %>%
    dplyr::rename(percentage_pregnant_women_as_adolescents = "of_pregnant_women_adolescents_10_19_years",
                  estimated_adolescent_abortions_after_first_anc = "estimated_post_abortion") %>%
    # Reorder columns to help me see what is there and what relates to what
    dplyr::relocate(.data$adolescents_15_19_years_with_pregnancy, .after="adolescents_10_14_years_with_pregnancy") %>%
    dplyr::relocate(.data$prop_of_monthly_anc_visit_by_preg_adolescent, .after="adolescent_family_planning_uptake_15_19_yrs") %>%
    dplyr::relocate(.data$estimated_adolescent_abortions_after_first_anc, .after="prop_of_monthly_anc_visit_by_preg_adolescent") %>%
    # Drop unnecessary columns
    dplyr::select(-c(.data$periodname, .data$periodcode, .data$perioddescription,
                     .data$orgunitlevel1, .data$organisationunitid, .data$organisationunitname,
                     .data$organisationunitdescription))
  # Remove duplicate use of the words County, Sub County and Ward
  # to allow for joining with other datasets based on name of admin level
  preg_clean <- preg_columns %>%
    dplyr::mutate(orgunitlevel2 = stringr::str_remove(.data$orgunitlevel2, " County"),
                  orgunitlevel3 = stringr::str_remove(.data$orgunitlevel3, " Sub County"),
                  orgunitlevel4 = stringr::str_remove(.data$orgunitlevel4, " Ward")) %>%
    # Country = Admin level 0
    # Counties = Admin level 1 (incorrectly labeled as level 2 in data)
    # Sub counties = Admin level 2 (incorrectly labeled as level 3 in data)
    # Ward = Admin level 3 (incorrectly labeled as level 4 in data)
    dplyr::rename(orgunitlevel1 = .data$orgunitlevel2,
                  orgunitlevel2 = .data$orgunitlevel3,
                  orgunitlevel3 = .data$orgunitlevel4) %>%
    # Fix county names to correspond with other data sets
    dplyr::mutate(orgunitlevel1 = dplyr::case_when(.data$orgunitlevel1 == "Muranga" ~ "Murang'a",
                                     TRUE ~ as.character(.data$orgunitlevel1))) %>%
    # Change NAs to 0 where data is available either for 10-14yrs or 15-19 yrs and can be checked against total (adolescents_pregnancy)
    dplyr::mutate(adolescents_10_14_years_with_pregnancy = dplyr::case_when(.data$adolescent_pregnancy - .data$adolescents_15_19_years_with_pregnancy == 0 ~ 0,
                                                              TRUE ~ as.numeric(.data$adolescents_10_14_years_with_pregnancy)),
           adolescents_15_19_years_with_pregnancy = dplyr::case_when(.data$adolescent_pregnancy - .data$adolescents_10_14_years_with_pregnancy == 0 ~ 0,
                                                              TRUE ~ as.numeric(.data$adolescents_15_19_years_with_pregnancy))) %>%
    # Change NAs to 0 where data is available for family planning uptake in either the 10-14yr bracket or the 15-19yr bracket.
    # Assume 0 where no observation is entered for one of two columns but an observation is available for the other
   dplyr::mutate(adolescent_family_planning_uptake_10_14_yrs = dplyr::case_when((is.na(.data$adolescent_family_planning_uptake_10_14_yrs) & !is.na(.data$adolescent_family_planning_uptake_15_19_yrs)) ~ 0,
                                                                   TRUE ~ as.numeric(.data$adolescent_family_planning_uptake_10_14_yrs)),
           adolescent_family_planning_uptake_15_19_yrs = dplyr::case_when((is.na(.data$adolescent_family_planning_uptake_15_19_yrs) & !is.na(.data$adolescent_family_planning_uptake_10_14_yrs)) ~ 0,
                                                                   TRUE ~ as.numeric(.data$adolescent_family_planning_uptake_15_19_yrs)))


  preg_final <- preg_clean %>%
    # Separate year from quarter to allow for time series analysis
    tidyr::separate(col = .data$periodid, into = c("year", "quarter"), sep = "Q") %>%
    # Change character into numeric
    dplyr::mutate(year = as.numeric(.data$year)) %>%
    # Add dates based on quarter data
    dplyr::mutate(month = dplyr::case_when(.data$quarter == 1 ~ 1,
                                           .data$quarter == 2 ~ 4,
                                           .data$quarter == 3 ~ 7,
                                           .data$quarter == 4 ~ 10),
                  day = 1) %>%
    # Convert date to Date format
    dplyr::mutate(date = lubridate::as_date(paste(.data$year, .data$month, .data$day, sep="-"))) %>%
    dplyr::relocate(.data$month, .after = "year") %>%
    dplyr::relocate(.data$day, .after = "month") %>%
    dplyr::relocate(.data$date, .after = "quarter")

  return(preg_final)
}
