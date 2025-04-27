const fs = require('fs-extra');
const path = require('path');
const express = require('express');
const moment = require('moment');
const cors = require('cors');

// Load configuration
const config = require('./config.json');

// Data file paths
const dataDir = path.join(__dirname, 'data');
const fpsDataFile = path.join(dataDir, 'fps_data.json');
const playersDataFile = path.join(dataDir, 'players_data.json');

// Initialize variables
let latestFPS = null;
let latestPlayerCount = null;

// Data storage for historical analysis
const dataStore = {
  fps: {
    raw: [], // Raw entries with timestamps
    hourly: {}, // Hourly averages
    daily: {}, // Daily averages
    weekly: {}, // Weekly averages
    monthly: {} // Monthly averages
  },
  players: {
    raw: [], // Raw entries with timestamps
    hourly: {}, // Hourly averages
    daily: {}, // Daily averages
    weekly: {}, // Weekly averages
    monthly: {} // Monthly averages
  },
  uptime: {
    serverStartTime: null, // When the latest folder was created (server start time)
    lastChecked: null     // Last time uptime was checked
  }
};

const maxRawDataPoints = 1000; // Maximum number of raw data points to store

// Ensure data directory exists
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
  console.log(`Created data directory: ${dataDir}`);
}

// Load data from JSON files if they exist
async function loadDataFromFiles() {
  try {
    if (fs.existsSync(fpsDataFile)) {
      const fpsData = await fs.readJson(fpsDataFile);
      dataStore.fps = fpsData;
      console.log(`Loaded FPS data from ${fpsDataFile}`);
      
      // Extract latest FPS if available
      if (dataStore.fps.raw && dataStore.fps.raw.length > 0) {
        latestFPS = dataStore.fps.raw[dataStore.fps.raw.length - 1].value;
      }
    } else {
      console.log(`No existing FPS data file found at ${fpsDataFile}. Will create on first save.`);
    }
    
    if (fs.existsSync(playersDataFile)) {
      const playersData = await fs.readJson(playersDataFile);
      dataStore.players = playersData;
      console.log(`Loaded players data from ${playersDataFile}`);
      
      // Extract latest player count if available
      if (dataStore.players.raw && dataStore.players.raw.length > 0) {
        latestPlayerCount = dataStore.players.raw[dataStore.players.raw.length - 1].value;
      }
    } else {
      console.log(`No existing players data file found at ${playersDataFile}. Will create on first save.`);
    }
    
    // Generate sample data if both files don't exist
    if (!fs.existsSync(fpsDataFile) && !fs.existsSync(playersDataFile)) {
      console.log('No data files found. Generating sample data...');
      generateSampleData();
      await saveDataToFiles();
      console.log('Sample data generated and saved.');
    }
  } catch (error) {
    console.error(`Error loading data from files: ${error.message}`);
  }
}

// Save data to JSON files
async function saveDataToFiles() {
  try {
    await fs.writeJson(fpsDataFile, dataStore.fps, { spaces: 2 });
    await fs.writeJson(playersDataFile, dataStore.players, { spaces: 2 });
    console.log(`Data saved to JSON files at ${new Date().toISOString()}`);
  } catch (error) {
    console.error(`Error saving data to files: ${error.message}`);
  }
}

// Create Express app
const app = express();

// Enable CORS for all routes
app.use(cors());

// Serve static files from the public directory
app.use(express.static(path.join(__dirname, 'public')));

// Serve the dashboard at the root URL
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Function to find the latest directory
async function findLatestDirectory(directoryPath) {
  try {
    if (!fs.existsSync(directoryPath)) {
      console.log(`Directory ${directoryPath} does not exist. Creating it...`);
      fs.mkdirSync(directoryPath, { recursive: true });
      return null;
    }

    const directories = (await fs.readdir(directoryPath, { withFileTypes: true }))
      .filter(dirent => dirent.isDirectory())
      .map(dirent => {
        const fullPath = path.join(directoryPath, dirent.name);
        return {
          name: dirent.name,
          path: fullPath,
          stats: fs.statSync(fullPath)
        };
      });

    if (directories.length === 0) {
      console.log(`No subdirectories found in ${directoryPath}`);
      return null;
    }

    // Sort by modification time (newest first)
    directories.sort((a, b) => b.stats.mtime.getTime() - a.stats.mtime.getTime());
    
    // Store the creation time of the latest directory as server start time if not set
    if (!dataStore.uptime.serverStartTime && directories[0]) {
      dataStore.uptime.serverStartTime = directories[0].stats.birthtime || directories[0].stats.mtime;
      console.log(`Server start time set to: ${dataStore.uptime.serverStartTime}`);
    }
    
    return directories[0];
  } catch (error) {
    console.error(`Error finding latest directory: ${error.message}`);
    return null;
  }
}

// Function to extract FPS value from log line
function extractFPS(line) {
  const match = line.match(/FPS:\s+(\d+\.\d+|\d+)/);
  if (match && match[1]) {
    return parseFloat(match[1]);
  }
  return null;
}

// Function to extract player count from log line
function extractPlayerCount(line) {
  const match = line.match(/Player:\s+(\d+)/);
  if (match && match[1]) {
    return parseInt(match[1], 10);
  }
  return null;
}

// Function to update the data store with new entries
function updateDataStore(type, value) {
  if (value === null) return;
  
  const now = moment();
  const timestamp = now.format('YYYY-MM-DD HH:mm:ss');
  
  // Add to raw data with timestamp
  dataStore[type].raw.push({
    value,
    timestamp,
    unix: now.valueOf() // Unix timestamp for easier calculations
  });
  
  // Keep raw data within limit
  if (dataStore[type].raw.length > maxRawDataPoints) {
    dataStore[type].raw.shift();
  }
  
  // Update hourly data
  const hourKey = now.format('YYYY-MM-DD HH');
  if (!dataStore[type].hourly[hourKey]) {
    dataStore[type].hourly[hourKey] = {
      sum: 0,
      count: 0,
      min: value,
      max: value,
      timestamp: now.format('YYYY-MM-DD HH:00:00')
    };
  }
  
  const hourData = dataStore[type].hourly[hourKey];
  hourData.sum += value;
  hourData.count++;
  hourData.min = Math.min(hourData.min, value);
  hourData.max = Math.max(hourData.max, value);
  hourData.avg = hourData.sum / hourData.count;
  
  // Update daily data
  const dayKey = now.format('YYYY-MM-DD');
  if (!dataStore[type].daily[dayKey]) {
    dataStore[type].daily[dayKey] = {
      sum: 0,
      count: 0,
      min: value,
      max: value,
      timestamp: now.format('YYYY-MM-DD 00:00:00')
    };
  }
  
  const dayData = dataStore[type].daily[dayKey];
  dayData.sum += value;
  dayData.count++;
  dayData.min = Math.min(dayData.min, value);
  dayData.max = Math.max(dayData.max, value);
  dayData.avg = dayData.sum / dayData.count;
  
  // Update weekly data
  const weekKey = now.format('YYYY-[W]WW'); // Year-Week format
  if (!dataStore[type].weekly[weekKey]) {
    dataStore[type].weekly[weekKey] = {
      sum: 0,
      count: 0,
      min: value,
      max: value,
      timestamp: now.startOf('week').format('YYYY-MM-DD 00:00:00')
    };
  }
  
  const weekData = dataStore[type].weekly[weekKey];
  weekData.sum += value;
  weekData.count++;
  weekData.min = Math.min(weekData.min, value);
  weekData.max = Math.max(weekData.max, value);
  weekData.avg = weekData.sum / weekData.count;
  
  // Update monthly data
  const monthKey = now.format('YYYY-MM');
  if (!dataStore[type].monthly[monthKey]) {
    dataStore[type].monthly[monthKey] = {
      sum: 0,
      count: 0,
      min: value,
      max: value,
      timestamp: now.startOf('month').format('YYYY-MM-DD 00:00:00')
    };
  }
  
  const monthData = dataStore[type].monthly[monthKey];
  monthData.sum += value;
  monthData.count++;
  monthData.min = Math.min(monthData.min, value);
  monthData.max = Math.max(monthData.max, value);
  monthData.avg = monthData.sum / monthData.count;
}

// Function to get the latest values from the log file
async function getLatestValues(logFilePath) {
  try {
    if (!fs.existsSync(logFilePath)) {
      console.log(`Log file ${logFilePath} does not exist`);
      return { fps: null, playerCount: null };
    }

    const fileContent = await fs.readFile(logFilePath, 'utf8');
    const lines = fileContent.split('\n');
    
    // Extract FPS data
    const fpsLines = lines.filter(line => line.includes('FPS:'));
    if (fpsLines.length > 0) {
      const lastFpsLine = fpsLines[fpsLines.length - 1];
      const fps = extractFPS(lastFpsLine);
      
      if (fps !== null) {
        latestFPS = fps;
        updateDataStore('fps', fps);
      }
    }
    
    // Extract Player Count data
    const playerLines = lines.filter(line => line.includes('Player:'));
    if (playerLines.length > 0) {
      const lastPlayerLine = playerLines[playerLines.length - 1];
      const playerCount = extractPlayerCount(lastPlayerLine);
      
      if (playerCount !== null) {
        latestPlayerCount = playerCount;
        updateDataStore('players', playerCount);
      }
    }
    
    return { fps: latestFPS, playerCount: latestPlayerCount };
  } catch (error) {
    console.error(`Error reading log file: ${error.message}`);
    return { fps: null, playerCount: null };
  }
}

// Function to calculate average FPS
function calculateAverageFPS() {
  const fpsData = dataStore.fps.raw;
  if (fpsData.length === 0) return null;
  
  const sum = fpsData.reduce((total, item) => total + item.value, 0);
  return (sum / fpsData.length).toFixed(2);
}

// Function to calculate average player count
function calculateAveragePlayerCount() {
  const playerData = dataStore.players.raw;
  if (playerData.length === 0) return null;
  
  const sum = playerData.reduce((total, item) => total + item.value, 0);
  return (sum / playerData.length).toFixed(0);
}

// Start monitoring function
async function startMonitoring() {
  const latestDir = await findLatestDirectory(config.logDir);
  
  if (!latestDir) {
    console.log('No log directory found. Will check again in the next interval.');
    return;
  }
  
  console.log(`Monitoring the latest directory: ${latestDir.name}`);
  
  const logFilePath = path.join(latestDir.path, config.logFileName);
  const values = await getLatestValues(logFilePath);
  
  if (values.fps !== null) {
    console.log(`Latest FPS: ${values.fps}`);
  }
  
  if (values.playerCount !== null) {
    console.log(`Latest Player Count: ${values.playerCount}`);
  }
  
  // Save data immediately after each update
  await saveDataToFiles();
}

// API endpoint for getting the latest FPS data
app.get('/api/fps', (req, res) => {
  const timeframe = req.query.timeframe || 'raw'; // Default to raw data
  const limit = parseInt(req.query.limit, 10) || 10; // Default to 10 items
  
  let data = [];
  let labels = [];
  
  switch(timeframe) {
    case 'hourly':
      data = Object.values(dataStore.fps.hourly)
        .sort((a, b) => moment(a.timestamp).valueOf() - moment(b.timestamp).valueOf())
        .slice(-limit);
      labels = data.map(d => moment(d.timestamp).format('MM-DD HH:mm'));
      break;
    case 'daily':
      data = Object.values(dataStore.fps.daily)
        .sort((a, b) => moment(a.timestamp).valueOf() - moment(b.timestamp).valueOf())
        .slice(-limit);
      labels = data.map(d => moment(d.timestamp).format('MM-DD'));
      break;
    case 'weekly':
      data = Object.values(dataStore.fps.weekly)
        .sort((a, b) => moment(a.timestamp).valueOf() - moment(b.timestamp).valueOf())
        .slice(-limit);
      labels = data.map(d => moment(d.timestamp).format('MM-DD'));
      break;
    case 'monthly':
      data = Object.values(dataStore.fps.monthly)
        .sort((a, b) => moment(a.timestamp).valueOf() - moment(b.timestamp).valueOf())
        .slice(-limit);
      labels = data.map(d => moment(d.timestamp).format('YYYY-MM'));
      break;
    case 'raw':
    default:
      data = dataStore.fps.raw.slice(-limit);
      labels = data.map(d => moment(d.timestamp).format('HH:mm:ss'));
      break;
  }
  
  let values = [];
  let minValues = [];
  let maxValues = [];
  
  if (timeframe !== 'raw') {
    values = data.map(d => d.avg);
    minValues = data.map(d => d.min);
    maxValues = data.map(d => d.max);
  } else {
    values = data.map(d => d.value);
  }
  
  const response = {
    latestFPS,
    averageFPS: calculateAverageFPS(),
    timestamp: moment().format('YYYY-MM-DD HH:mm:ss'),
    values: values,
    labels: labels,
    timeframe: timeframe
  };
  
  if (timeframe !== 'raw') {
    response.minValues = minValues;
    response.maxValues = maxValues;
  }
  
  res.json(response);
});

// API endpoint for getting the latest player count data
app.get('/api/players', (req, res) => {
  const timeframe = req.query.timeframe || 'raw'; // Default to raw data
  const limit = parseInt(req.query.limit, 10) || 10; // Default to 10 items
  
  let data = [];
  let labels = [];
  
  switch(timeframe) {
    case 'hourly':
      data = Object.values(dataStore.players.hourly)
        .sort((a, b) => moment(a.timestamp).valueOf() - moment(b.timestamp).valueOf())
        .slice(-limit);
      labels = data.map(d => moment(d.timestamp).format('MM-DD HH:mm'));
      break;
    case 'daily':
      data = Object.values(dataStore.players.daily)
        .sort((a, b) => moment(a.timestamp).valueOf() - moment(b.timestamp).valueOf())
        .slice(-limit);
      labels = data.map(d => moment(d.timestamp).format('MM-DD'));
      break;
    case 'weekly':
      data = Object.values(dataStore.players.weekly)
        .sort((a, b) => moment(a.timestamp).valueOf() - moment(b.timestamp).valueOf())
        .slice(-limit);
      labels = data.map(d => moment(d.timestamp).format('MM-DD'));
      break;
    case 'monthly':
      data = Object.values(dataStore.players.monthly)
        .sort((a, b) => moment(a.timestamp).valueOf() - moment(b.timestamp).valueOf())
        .slice(-limit);
      labels = data.map(d => moment(d.timestamp).format('YYYY-MM'));
      break;
    case 'raw':
    default:
      data = dataStore.players.raw.slice(-limit);
      labels = data.map(d => moment(d.timestamp).format('HH:mm:ss'));
      break;
  }
  
  let values = [];
  let minValues = [];
  let maxValues = [];
  
  if (timeframe !== 'raw') {
    values = data.map(d => d.avg);
    minValues = data.map(d => d.min);
    maxValues = data.map(d => d.max);
  } else {
    values = data.map(d => d.value);
  }
  
  const response = {
    latestPlayerCount,
    averagePlayerCount: calculateAveragePlayerCount(),
    timestamp: moment().format('YYYY-MM-DD HH:mm:ss'),
    values: values,
    labels: labels,
    timeframe: timeframe
  };
  
  if (timeframe !== 'raw') {
    response.minValues = minValues;
    response.maxValues = maxValues;
  }
  
  res.json(response);
});

// API endpoint for getting server uptime
app.get('/api/uptime', (req, res) => {
  const now = new Date();
  dataStore.uptime.lastChecked = now;
  
  // If we don't have a server start time yet
  if (!dataStore.uptime.serverStartTime) {
    return res.json({
      status: 'unknown',
      message: 'Server start time not detected yet',
      uptime: {
        seconds: 0,
        minutes: 0,
        hours: 0,
        days: 0
      },
      startTime: null,
      currentTime: now.toISOString()
    });
  }
  
  // Calculate uptime in milliseconds
  const uptimeMs = now.getTime() - dataStore.uptime.serverStartTime.getTime();
  
  // Convert to seconds, minutes, hours, days
  const seconds = Math.floor(uptimeMs / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);
  
  // Format for display
  const formattedUptime = {
    seconds: seconds % 60,
    minutes: minutes % 60,
    hours: hours % 24,
    days: days,
    totalSeconds: seconds,
    totalMinutes: minutes,
    totalHours: hours
  };
  
  // Create human-readable string
  let uptimeString = '';
  if (days > 0) uptimeString += `${days} days, `;
  if (hours % 24 > 0) uptimeString += `${hours % 24} hours, `;
  if (minutes % 60 > 0) uptimeString += `${minutes % 60} minutes, `;
  uptimeString += `${seconds % 60} seconds`;
  
  res.json({
    status: 'online',
    message: `Server has been online for ${uptimeString}`,
    uptime: formattedUptime,
    uptimeString: uptimeString,
    startTime: dataStore.uptime.serverStartTime.toISOString(),
    currentTime: now.toISOString()
  });
});

// Generate sample data for testing
function generateSampleData() {
  const now = moment();
  
  // Generate some FPS data
  for (let i = 0; i < 100; i++) {
    const timestamp = moment(now).subtract(i * 10, 'minutes').format('YYYY-MM-DD HH:mm:ss');
    const unix = moment(timestamp).valueOf();
    const value = Math.floor(60 + Math.random() * 40); // Random value between 60-100
    
    dataStore.fps.raw.push({ value, timestamp, unix });
  }
  
  // Generate some player count data
  for (let i = 0; i < 100; i++) {
    const timestamp = moment(now).subtract(i * 10, 'minutes').format('YYYY-MM-DD HH:mm:ss');
    const unix = moment(timestamp).valueOf();
    const value = Math.floor(1 + Math.random() * 10); // Random value between 1-10
    
    dataStore.players.raw.push({ value, timestamp, unix });
  }
  
  // Set the latest values
  if (dataStore.fps.raw.length > 0) {
    latestFPS = dataStore.fps.raw[0].value;
  }
  
  if (dataStore.players.raw.length > 0) {
    latestPlayerCount = dataStore.players.raw[0].value;
  }
  
  // Process the raw data to generate hourly/daily/weekly/monthly aggregates
  processHistoricalData('fps');
  processHistoricalData('players');
}

// Process historical data to generate aggregates
function processHistoricalData(type) {
  const rawData = dataStore[type].raw;
  
  // Clear existing aggregates
  dataStore[type].hourly = {};
  dataStore[type].daily = {};
  dataStore[type].weekly = {};
  dataStore[type].monthly = {};
  
  // Process each raw data point
  for (const dataPoint of rawData) {
    const time = moment(dataPoint.timestamp);
    const value = dataPoint.value;
    
    // Update hourly data
    const hourKey = time.format('YYYY-MM-DD HH');
    if (!dataStore[type].hourly[hourKey]) {
      dataStore[type].hourly[hourKey] = {
        sum: 0,
        count: 0,
        min: value,
        max: value,
        timestamp: time.format('YYYY-MM-DD HH:00:00')
      };
    }
    
    const hourData = dataStore[type].hourly[hourKey];
    hourData.sum += value;
    hourData.count++;
    hourData.min = Math.min(hourData.min, value);
    hourData.max = Math.max(hourData.max, value);
    hourData.avg = hourData.sum / hourData.count;
    
    // Update daily data
    const dayKey = time.format('YYYY-MM-DD');
    if (!dataStore[type].daily[dayKey]) {
      dataStore[type].daily[dayKey] = {
        sum: 0,
        count: 0,
        min: value,
        max: value,
        timestamp: time.format('YYYY-MM-DD 00:00:00')
      };
    }
    
    const dayData = dataStore[type].daily[dayKey];
    dayData.sum += value;
    dayData.count++;
    dayData.min = Math.min(dayData.min, value);
    dayData.max = Math.max(dayData.max, value);
    dayData.avg = dayData.sum / dayData.count;
    
    // Update weekly data
    const weekKey = time.format('YYYY-[W]WW');
    if (!dataStore[type].weekly[weekKey]) {
      dataStore[type].weekly[weekKey] = {
        sum: 0,
        count: 0,
        min: value,
        max: value,
        timestamp: moment(time).startOf('week').format('YYYY-MM-DD 00:00:00')
      };
    }
    
    const weekData = dataStore[type].weekly[weekKey];
    weekData.sum += value;
    weekData.count++;
    weekData.min = Math.min(weekData.min, value);
    weekData.max = Math.max(weekData.max, value);
    weekData.avg = weekData.sum / weekData.count;
    
    // Update monthly data
    const monthKey = time.format('YYYY-MM');
    if (!dataStore[type].monthly[monthKey]) {
      dataStore[type].monthly[monthKey] = {
        sum: 0,
        count: 0,
        min: value,
        max: value,
        timestamp: moment(time).startOf('month').format('YYYY-MM-DD 00:00:00')
      };
    }
    
    const monthData = dataStore[type].monthly[monthKey];
    monthData.sum += value;
    monthData.count++;
    monthData.min = Math.min(monthData.min, value);
    monthData.max = Math.max(monthData.max, value);
    monthData.avg = monthData.sum / monthData.count;
  }
}

// Start the server
app.listen(config.port, async () => {
  console.log(`FPS Monitor API server running on port ${config.port}`);
  console.log(`Configuration: ${JSON.stringify(config, null, 2)}`);
  
  // Load existing data from files
  await loadDataFromFiles();
  
  // Initial check
  startMonitoring();
  
  // Set up periodic monitoring
  setInterval(startMonitoring, config.updateInterval);
  
  // Set up periodic saving of data (every 30 seconds)
  const saveInterval = 30 * 1000; // 30 seconds in milliseconds
  setInterval(saveDataToFiles, saveInterval);
  console.log(`Data will be saved to JSON files every 30 seconds`);
});
