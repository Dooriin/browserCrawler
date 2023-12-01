const fs = require("fs");
const readline = require("readline");

// Create a read stream from your JSON Lines file
const readStream = fs.createReadStream("crawls/collections/moodys/pages/pages.jsonl");

// Create an interface to read each line
const lineReader = readline.createInterface({
  input: readStream
});

// Create a write stream to output the non-200 status URLs
const writeStream = fs.createWriteStream("crawls/collections/moodys/pages/non200statusUrls.txt");

lineReader.on('line', function (line) {
  try {
    // Parse the JSON line
    const jsonLine = JSON.parse(line);

    // Check if statusCode is not 200 and not null
    if (jsonLine.statusCode !== 200 && jsonLine.statusCode != null) {
      // Write the URL to the file, followed by a newline
      writeStream.write(jsonLine.url + '\n');
    }
  } catch (error) {
    console.error('Error parsing JSON line:', error);
  }
});

lineReader.on('close', function () {
  console.log('All lines have been processed.');
  writeStream.end();
});

writeStream.on('finish', function () {
  console.log('URLs with non-200 and non-null status have been written to non200NonNullStatusUrls.txt');
});

// Handle errors for read stream
readStream.on('error', function (err) {
  console.error('Error reading file:', err);
});

// Handle errors for write stream
writeStream.on('error', function (err) {
  console.error('Error writing file:', err);
});