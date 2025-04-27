# FPS Monitor

This Node.js application monitors log files for FPS data and exposes an API endpoint to retrieve the latest and average FPS values.

## Features

- Automatically finds and monitors the latest directory in the logs folder
- Extracts FPS values from console.log files
- Calculates average FPS
- Provides an API endpoint to retrieve FPS data
- Configurable via config.json

## Configuration

You can configure the application by editing the `config.json` file:

```json
{
  "logDir": "logs",          // Directory containing log folders
  "logFileName": "console.log", // Name of the log file to monitor
  "updateInterval": 5000,    // How often to check for new data (in milliseconds)
  "port": 3000               // Port for the API server
}
```

## Installation

1. Make sure you have Node.js installed
2. Install dependencies:
   ```
   npm install
   ```

## Usage

1. Start the application:
   ```
   npm start
   ```

2. Access the API endpoint:
   ```
   GET http://localhost:3000/api/fps
   ```

## API Response Example

```json
{
  "latestFPS": 88.2,
  "averageFPS": "92.45",
  "timestamp": "2025-04-27 11:50:22",
  "values": [95.1, 94.2, 92.8, 89.5, 90.1, 92.8, 95.3, 96.0, 91.5, 88.2]
}
```
