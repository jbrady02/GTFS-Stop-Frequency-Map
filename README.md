![A screenshot of SEPTA Metro and bus service frequency between 6:00 AM and 9:00 PM on November 15, 2023](https://github.com/jbrady02/GTFS-Stop-Frequency-Map/assets/89806788/7cdd994f-6743-45bf-90ec-50cb66a38dd0)
# GTFS-Stop-Frequency-Map
This uses R to analyzes GTFS transit data, calculating and visually presenting the service frequency at stops during a specified time range. The interactive Leaflet map showcases stop locations with color-coded markers indicating transit frequency.
# Arguments
When running with Rscript, you must include 4 arguments:\
1 - Calculate the transit service frequency after this time inclusive.\
2 - Calculate the transit service frequency before this time exclusive. This should be in HH:MM:SS format and times may be greater than 23:59:59.\
3 - The date that the transit service frequency should be calculated on. This should be in YYYY-MM-DD format.\
4 - The file path, in quotes, containing the GTFS data.
For example, `Rscript gtfs_stop_frequency_map.R 06:00:00 21:00:00 2023-10-13 "C:/Data/bus"` calculates the transit service frequency for all stops in the `bus` directory on October 13, 2023 from 6:00 AM to 9:00 PM.\
For late-night trips occurring at or after midnight, if they belong to the previous service day, use a time greater than 23:59:59 to correctly handle the transition to the next day.\
If these arguments are not given, the program will ask the user for them.
# Requirements
This script requires the tidyverse, htmlwidgets, and leaflet packages.\
Run `install.packages(c("tidyverse", "htmlwidgets", "leaflet"))` to install the required packages.
# Input
A folder containing GTFS Schedule files is required. [Transitland](https://www.transit.land/feeds) contains transit feeds that you can download. **Please note that this script ignores frequencies.txt.** If your GTFS Schedule folder contains frequencies.txt, some stops may have false frequency.
# Output
This outputs an interactive Leaflet map that shows stop locations with color-coded markers indicating transit frequency.
## Key
| Color      | Frequency               |
| ---------- | ----------------------- |
| Dark green | 6 <= trips per hour     |
| Green      | 4 <= trips per hour < 6 |
| Yellow     | 3 <= trips per hour < 4 |
| Orange     | 2 <= trips per hour < 3 |
| Red        | 1 <= trips per hour < 2 |
| Dark red   | 0 <= trips per hour < 1 |
| Black      | 0 trips                 |
