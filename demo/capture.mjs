import {execFileSync, spawn} from 'node:child_process';
import {mkdirSync, writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';

// Native macOS capture only. Never substitutes data or renders application UI.
const output = fileURLToPath(new URL('../assets/captures/', import.meta.url));
mkdirSync(output, {recursive: true});
const apple = (body) => execFileSync('osascript', ['-e', `
tell application "System Events" to tell process "SeeUsage"
  ${body}
end tell`], {encoding: 'utf8'}).trim();
const panel = 'group 1 of pop over 1 of menu bar item 1 of menu bar 2';
apple(`if not (exists pop over 1 of menu bar item 1 of menu bar 2) then click menu bar item 1 of menu bar 2
delay 1
set value of scroll bar 1 of scroll area 1 of ${panel} to 0
delay 1`);
const bounds = apple(`get {position, size} of ${panel}`).split(',').map(Number);
if (bounds.length !== 4 || bounds.some((n) => !Number.isFinite(n))) {
  throw new Error('Could not determine the native panel bounds.');
}
console.log('Capturing native SeeUsage panel:', bounds);
const recording = spawn('screencapture', ['-x', '-v', '-V12', `-R${bounds.join(',')}`, `${output}quota-flow.mov`], {stdio: 'inherit'});
const done = new Promise((resolve, reject) => {
  recording.once('error', reject);
  recording.once('exit', (code) => code === 0 ? resolve() : reject(new Error(`Capture exited ${code}`)));
});
apple(`delay 3
click button 1 of ${panel}
delay 3
repeat with stepIndex from 1 to 24
  set value of scroll bar 1 of scroll area 1 of ${panel} to (stepIndex / 24)
  delay 0.025
end repeat`);
await done;
writeFileSync(`${output}capture.json`, JSON.stringify({
  capturedAt: new Date().toISOString(), bounds,
  source: 'SeeUsage native macOS popover, screencapture',
  actions: ['Open quota panel', 'Refresh quotas at approximately 3s', 'Scroll to Antigravity at approximately 6s'],
}, null, 2) + '\n');
console.log('Captured assets/captures/quota-flow.mov');
