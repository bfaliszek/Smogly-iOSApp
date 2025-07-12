# Smogly Air Quality iOS App

A SwiftUI iOS application that displays air quality data from the Smogly API, featuring PM2.5 and PM10 measurements with an interactive map and datasource selection.

## Features

- **Interactive Map**: Displays air quality monitoring stations with color-coded annotations
- **Real-time Data**: Fetches air quality data from the Smogly API
- **Multiple Data Sources**: Support for various air quality data sources:
  - ALL (default)
  - GIOS
  - LUFTDATEN
  - LOOKO2
  - AWAIR_KATO
  - OPENAQ_LT
  - SYNGEOS
- **PM2.5 and PM10 Display**: Shows particulate matter measurements with color-coded indicators
- **Modern UI**: Built with SwiftUI for a native iOS experience
- **Error Handling**: Comprehensive error handling and user feedback

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.0+

## Installation

1. Clone the repository
2. Open `SmoglyAirQuality.xcodeproj` in Xcode
3. Select your target device or simulator
4. Build and run the project

## API Configuration

The app connects to the Smogly API at:
```
http://api.myopenair.com:5000/api/v1/airpollution
```

### API Parameters
- `lat`: Latitude (default: 50.172816 - Krakow, Poland)
- `long`: Longitude (default: 19.143306 - Krakow, Poland)
- `datasource`: Data source selection (default: ALL)

## Project Structure

```
SmoglyAirQuality/
├── AppDelegate.swift              # App lifecycle management
├── SceneDelegate.swift            # Scene management for SwiftUI
├── ContentView.swift              # Main UI with map and data display
├── AirQualityModels.swift         # Data models for API responses
├── AirQualityService.swift        # Network service for API calls
├── Info.plist                     # App configuration and permissions
└── Assets.xcassets/               # App icons and assets
```

## Key Components

### AirQualityService
Handles network requests to the Smogly API with proper error handling and async/await support.

### ContentView
Main view containing:
- Interactive MapKit map
- Air quality data cards
- Data source picker
- Refresh functionality

### AirQualityModels
Data structures for API responses including:
- `AirQualityResponse`: Main response wrapper
- `AirQualityData`: Individual station data
- `Measurement`: PM2.5 and PM10 measurements
- `DataSource`: Enum for available data sources

## Air Quality Index Colors

The app uses standard AQI color coding:

- **Green**: Good (PM2.5: 0-12, PM10: 0-54)
- **Yellow**: Moderate (PM2.5: 12-35.4, PM10: 54-154)
- **Orange**: Unhealthy for Sensitive Groups (PM2.5: 35.4-55.4, PM10: 154-254)
- **Red**: Unhealthy (PM2.5: 55.4-150.4, PM10: 254-354)
- **Purple**: Very Unhealthy (PM2.5: 150.4-250.4, PM10: 354-424)
- **Maroon**: Hazardous (PM2.5: 250.4+, PM10: 424+)

## Permissions

The app requests location permissions to show air quality data for the user's current location. This is configured in `Info.plist` with the key `NSLocationWhenInUseUsageDescription`.

## Network Security

The app includes `NSAppTransportSecurity` settings to allow HTTP connections to the Smogly API.

## Future Enhancements

- User location detection and automatic data fetching
- Historical data charts
- Push notifications for poor air quality
- Offline data caching
- Multiple location support
- Detailed station information

## License

This project is created for educational and demonstration purposes. 