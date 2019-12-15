# lpp

Work in progress android app that shows the bus arrival time for Ljubljana public transport. Works via 
 data.lpp public api.

## Features
Loads all the existing route groups, then displays specific routes from said route groups. Stations from
routes are then shown in a new screen. Upon clicking a station, bus departures get loaded, which come from
a predetermined timetable. Live bus arrivals are simultaneously searched for, but seldom found, due to inconsistent
api calls.

## Todo
- [ ] Filter out bad/nonexistent routes
- [ ] Route search 
- [ ] Station search 
- [ ] better route naming
- [ ] show alternative routes on station
- [ ] testing
- [ ] optional notifications
- [ ] theming

## Setup
Clone the project, then import it in Android Studio/preferred IDE then run. Should work both on Android and iOS 
without issues.

# Contribution
Any feedback / contributors would be very welcome. 
