# Description: This calculates the transit service frequency that stops receive.
# 
# Arguments (required when running with Rscript):
# - 1: Calculate the transit service frequency after this time inclusive.
# - 2: Calculate the transit service frequency before this time exclusive.
#   This should be in HH:MM:SS format. For late-night trips occurring at or 
#   after midnight, if they belong to the previous service day, use a time 
#   greater than 23:59:59 to correctly handle the transition to the next day.
# - 3: The date that the transit service frequency should be calculated on.
#   This should be in YYYY-MM-DD format.
# - 4: The file path, in quotes, containing the GTFS data.
# - If these arguments are not given, the program will ask the user for them.
#
# Output: An Leaflet map widget viewable on a web browser containing points at
# the stop locations which show the transit service frequency for that stop.
#
# Example usage:
# Rscript gtfs_stop_frequency_map.R 06:00:00 21:00:00 2023-10-13 "C:/Data/bus"
# This script requires the tidyverse, htmlwidgets, and leaflet packages.
# install.packages(c("tidyverse", "htmlwidgets", "leaflet"))
# You can get transit feeds here: https://www.transit.land/feeds
# Unzip the folder so that the only files within the folder are .txt files.
# Please note that this script ignores frequencies.txt.


library(tidyverse)
library(htmlwidgets)
library(leaflet)

get_arguments_from_user <- function() {
  # Ask the user for the arguments, format and return arguments
  print("Please enter the start time (format: HH:MM:SS)")
  start_time = gsub(":", "", readline("Start time: "))
  print("Please enter the end time (format: HH:MM:SS)")
  end_time = gsub(":", "", readline("End time: "))
  print("Please enter the sample date (format: YYYY-MM-DD)")
  date_str = readline("Sample date: ")
  date = date_str
  date_str = gsub("-", "", date_str)
  print("Please enter the file path of the directory containing the GTFS data")
  source = gsub("\"", "", readline("File path: "))
  return(list(start_time, end_time, date_str, date, source))
}

get_arguments_from_command_line <- function(arguments) {
  # Format and return command line arguments
  start_time = as.integer(gsub(":", "", arguments[1]))
  end_time = as.integer(gsub(":", "", arguments[2]))
  date_str =  gsub("-", "", arguments[3])
  date = arguments[3]
  source = arguments[4]
  return(list(start_time, end_time, date_str, date, source))
}

get_time_amount <- function(start_time, end_time) {
  # Get the amount of time between start_time and end_time in hours
  return(((as.integer(end_time / 10000) * 3600 + 
             as.integer(end_time %% 10000 / 100) * 60 +
             end_time %% 100) -
            (as.integer(start_time / 10000) * 3600 + 
               as.integer(start_time %% 10000 / 100) * 60 +
               start_time %% 100)) / 3600)
}

stop_if_invalid_arguments <- function(start_time, end_time, date) {
  # If arguments are not valid, stop running the script
  if (is.na(start_time) | (is.na(end_time)) | (is.na(date))) {
    stop("Code execution stopped because the arguments were invalid.")
  }
}

make_service_counter <- function(stops) {
  # Make the stop counter data frame
  counter_stop_id = c()
  counter_count = c()
  for (index in 1:length(stops$stop_id)) {
    counter_stop_id = append(counter_stop_id, stops$stop_id[index])
    counter_count = append(counter_count, 0)
  }
  return(data.frame(stop_id = counter_stop_id, count = counter_count))
}

get_service_ids <- function(date, date_str, calendar_dates, calendar) {
  # Get service_ids that run on date
  exceptions_add = which(
    date_str == calendar_dates$date & calendar_dates$exception_type == 1)
  exceptions_remove = which(
    date_str == calendar_dates$date & calendar_dates$exception_type == 2)
  service_ids = calendar_dates$service_id[exceptions_add]
  service_ids_remove = calendar_dates$service_id[exceptions_remove]
  day_of_week = tolower(weekdays(date))
  if (!is.null(calendar)) {
    for (index in 1:length(calendar$service_id)) {
      if (calendar[[day_of_week]][index] == 1) {
        # Verify service_id is within valid date range
        if (calendar$start_date[index] <= date_str && 
            date_str <= calendar$end_date[index]) {
          service_ids = append(service_ids, calendar$service_id[index])
        }
      }
    }
  }
  # Remove trips that are not running on that day due to exception
  return(setdiff(service_ids, service_ids_remove))
}

get_valid_trips <- function(trips, service_ids) {
  # Get list of valid trips
  valid_trips = c()
  for (index in 1:length(trips$service_id)) {
    if (trips$service_id[index] %in% service_ids) {
      valid_trips = append(valid_trips, trips$trip_id[index])
    }
  }
  return(valid_trips)
}

count_trips_by_stop <- function(
    stop_times, start_time, end_time, stop_id, service_count, valid_trips) {
  # Count number of trips a stop receives during the given hours and minutes
  print("Counting number of trips a stop receives. This may take a while.")
  for (index in 1:length(stop_times$trip_id)) {
    if (index %% 10000 == 0) { # Get completion status
      print(paste0((index / length(stop_times$trip_id)) * 100, "%"))
    }
    if (stop_times$trip_id[index] %in% valid_trips &&
        start_time <= as.integer(
          gsub(":", "", stop_times$departure_time[index])) &&
        end_time > as.integer(
          gsub(":", "", stop_times$departure_time[index]))) {
      stop_id = stop_times$stop_id[index]
      service_count$count = ifelse(service_count$stop_id == stop_id,
                                   service_count$count + 1, service_count$count)
    }
  }
  return(service_count$count)
}

calculate_service_frequency <- function(service_count, time_amount) {
  # Calculate the transit service frequency
  for (index in 1:length(service_count$stop_id)) {
    service_count$frequency[index] = service_count$count[index] / time_amount
  }
  return(service_count$frequency)
}

create_map <- function(stops, service_count) {
  # Create the Leaflet map widget
  print("Creating the map. This may take a while.")
  map = leaflet(stops) %>%
    addTiles() # Add default OpenStreetMap map tiles
  for (index in 1:length(service_count$stop_id)) {
    if (index %% 1000 == 0) { # Get completion status
      print(paste0((index / length(service_count$stop_id)) * 100, "%"))
    }
    if (service_count$frequency[index] >= 6) {
      marker_color = "darkgreen"
    } else if (service_count$frequency[index] >= 4) {
      marker_color = "green"
    } else if (service_count$frequency[index] >= 3) {
      marker_color = "yellow"
    } else if (service_count$frequency[index] >= 2) {
      marker_color = "orange"
    } else if (service_count$frequency[index] >= 1) {
      marker_color = "red"
    } else if (service_count$frequency[index] > 0) {
      marker_color = "darkred"
    } else {
      marker_color = "black"
    }
    map = map %>% 
      addCircleMarkers(stops$stop_lon[index], stops$stop_lat[index], 
                       popup = paste(stops$stop_name[index], 
                                     paste(substr(
                                       service_count$frequency[index], 0, 5), 
                                       "trips per hour"), 
                                     paste("Total trips:", 
                                           service_count$count[index]), 
                                     sep = "<br>"), 
                       color = marker_color)
  }
  return(map)
}

save_map <- function(map) {
  # Save the Leaflet map widget to a HTML file
  print("Map was created successfully. Please wait for the map to save.")
  dir.create(file.path(getwd(), "Output"), showWarnings = FALSE)
  saveWidget(map, file = "Output/map.html", selfcontained = FALSE)
  paste0("Map was saved successfully to ", file.path(getwd(), "Output"), ".")
}

main <- function() {
  # Get input and coordinate functions
  
  # Get the time range, sample date, and location(s) of the GTFS data
  arguments = commandArgs(trailingOnly = TRUE)
  if (length(arguments) != 4) {
    input = get_arguments_from_user()
  } else {
    input = get_arguments_from_command_line(arguments)
  }
  start_time = as.integer(input[1])
  end_time = as.integer(input[2])
  date_str = toString(input[3])
  date = as.POSIXlt(toString(input[4]))
  source = toString(input[5])
  rm(input)
  
  time_amount = get_time_amount(start_time, end_time)
  stop_if_invalid_arguments(start_time, end_time, date)
  
  # Get the data files
  print(paste0("Retrieving data from ", source, "."))
  if (file.exists(paste(source, "/calendar.txt", sep = ""))) {
    calendar = read_csv(paste(source, "/calendar.txt", sep = ""))
  }
  if (file.exists(paste(source, "/calendar_dates.txt", sep = ""))) {
    calendar_dates = read_csv(paste(source, "/calendar_dates.txt", sep = ""))
  }
  if (file.exists(paste(source, "/frequencies.txt", sep = ""))) {
    cat("Reading of frequencies.txt is not supported.",
        "Some stops may show 0 trips.\n")
  }
  stop_times = read_csv(paste(source, "/stop_times.txt", sep = ""))
  stops = read_csv(paste(source, "/stops.txt", sep = ""))
  trips = read_csv(paste(source, "/trips.txt", sep = ""))
  
  service_count = make_service_counter(stops)
  service_ids = get_service_ids(date, date_str, calendar_dates, calendar)
  valid_trips = get_valid_trips(trips, service_ids)
  service_count$count = count_trips_by_stop(
    stop_times, start_time, end_time, stop_id, service_count, valid_trips)
  service_count$frequency = calculate_service_frequency(
    service_count, time_amount)
  map = create_map(stops, service_count)
  save_map(map)
}

main()