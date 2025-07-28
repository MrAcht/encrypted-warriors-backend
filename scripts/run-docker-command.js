const { execSync } = require("child_process");
const path = require("path");

// Get the current working directory of the project
const currentDir = process.cwd();

// Find the separator '--' to split Docker options from the Hardhat command
const sepIndex = process.argv.indexOf('--');
let dockerOptions = [];
let hardhatArgs = [];
if (sepIndex !== -1) {
  dockerOptions = process.argv.slice(2, sepIndex);
  hardhatArgs = process.argv.slice(sepIndex + 1);
} else {
  hardhatArgs = process.argv.slice(2);
}

if (hardhatArgs.length === 0) {
  console.error("Error: No Hardhat command provided to run-docker-command.js");
  process.exit(1);
}

// Build the Docker command
const dockerCmd = [
  "docker run --rm",
  ...dockerOptions,
  `-v ${JSON.stringify(currentDir)}:/app`,
  "fhevm-hardhat-env",
  ...hardhatArgs
].join(' ');

console.log(`Executing: ${dockerCmd}`);

try {
  execSync(dockerCmd, { stdio: "inherit" });
} catch (error) {
  console.error(`Failed to execute Docker command: ${error.message}`);
  process.exit(error.status || 1);
}
