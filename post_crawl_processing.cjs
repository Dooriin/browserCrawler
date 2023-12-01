const fs = require('fs');
const path = require('path');
const http = require('http');
const https = require('https');

// Determine the base directory. Adjust this as necessary.
// For example, if this script is in the root of your project, you might use `__dirname`.
const baseDirectory = __dirname;

let requestDelay = 1000; // Initial delay between requests in milliseconds (1 second)
const maxDelay = 10000; // Maximum delay (10 seconds)
const delayIncrement = 1000; // Increment to increase delay (1 second)

// Paths to input and output files, relative to the base directory
const pagesFilePath = path.join(baseDirectory, "crawls/collections/moodys/pages/pages.jsonl");
const utilReportFilePath = path.join(baseDirectory, "endpoints/Util_Report_URLs.txt");
const v3URLsFilePath = path.join(baseDirectory, "endpoints/V3_URLs.txt");
const outputDirectory = path.join(baseDirectory, "crawls/collections/moodys/pages");

// Function to read JSONL file
function readJSONLFile(filePath) {
  const lines = fs.readFileSync(filePath, "utf8").split("\n");
  return lines.filter(line => line.trim()).map(line => JSON.parse(line));
}

// Function to save to CSV
function saveToCSV(filePath, headers, data) {
  const csvData = data.map(row => headers.map(header => row[header]).join(',')).join('\n');

  // Ensure the directory exists
  const dir = path.dirname(filePath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  fs.writeFileSync(filePath, headers.join(',') + '\n' + csvData);
}

// Function to check the status code of a URL with rate limiting
// Global variables to manage rate limiting

// Function to check the status code of a URL with rate limiting
function checkStatusCode(url) {
  return new Promise((resolve, reject) => {
    setTimeout(() => {
      const callback = response => {
        // If the status code is 429 (Too Many Requests), increase the delay
        if (response.statusCode === 429) {
          requestDelay = Math.min(requestDelay + delayIncrement, maxDelay);
          console.log(`Rate limit hit, increasing delay to ${requestDelay}ms`);
        } else {
          // Reset delay on successful request
          requestDelay = 1000;
        }
        resolve({ url, statusCode: response.statusCode });
      };

      const req = url.startsWith("https") ? https.get(url, callback) : http.get(url, callback);
      req.on("error", (err) => {
        // Handle network or other errors
        console.error(`Error requesting ${url}: ${err.message}`);
        resolve({ url, statusCode: "Error" });
      });
      req.end();
    }, requestDelay);
  });
}

// Function to process URL file
async function processURLFile(filePath, outputFileName) {
  const endpoints = fs.readFileSync(filePath, "utf8").split("\n").filter(line => line.trim());
  const statusResults = await Promise.all(endpoints.map(checkStatusCode));
  saveToCSV(path.join(outputDirectory, outputFileName), ["url", "statusCode"], statusResults);
}

// Main function to generate CSV files
async function generateCSVFiles() {
  // Process pages.jsonl for the first two requirements
  const data = readJSONLFile(pagesFilePath);
  saveToCSV(path.join(outputDirectory, "all_pages.csv"), ["url", "statusCode", "refererUrl"], data.map(({ url, statusCode, refererUrl }) => ({ url, statusCode, refererUrl: refererUrl || "N/A" })));
  saveToCSV(path.join(outputDirectory, "non_200_pages.csv"), ["url", "statusCode", "refererUrl"], data.filter(item => item.statusCode !== 200).map(({ url, statusCode, refererUrl }) => ({ url, statusCode, refererUrl: refererUrl || "N/A" })));

  // Process Util_Report_URLs.txt and V3_URLs.txt
  await processURLFile(utilReportFilePath, "util_report_status.csv");
  await processURLFile(v3URLsFilePath, "v3_urls_status.csv");
}

generateCSVFiles();
