import {execFileSync} from 'node:child_process';
import {existsSync, mkdirSync} from 'node:fs';
import {fileURLToPath} from 'node:url';

process.chdir(fileURLToPath(new URL('.', import.meta.url)));
const cli = fileURLToPath(new URL('node_modules/@remotion/cli/remotion-cli.js', import.meta.url));
const run = (...args) => execFileSync(process.execPath, [cli, ...args], {stdio: 'inherit'});
const chrome = process.env.REMOTION_BROWSER_EXECUTABLE;
const browser = chrome ? [`--browser-executable=${chrome}`] : [];
if (!existsSync('../assets/captures/quota-flow.mov')) throw new Error('Run npm run capture first.');
mkdirSync('../assets/.work', {recursive: true});
run('render', 'src/index.jsx', 'SeeUsageDemo', '../assets/seeusage-demo.mp4',
  '--public-dir=../assets', '--codec=h264', '--crf=18', '--pixel-format=yuv420p', '--concurrency=2', ...browser);

// Reuse Remotion's bundled FFmpeg. No separate video/GIF dependency required.
run('ffmpeg', '-v', 'error', '-y', '-i', '../assets/seeusage-demo.mp4',
  '-vf', 'scale=900:600:flags=lanczos', '-r', '12', '-frames:v', '156', '-an', '-c:v', 'libx264', '-crf', '16', '../assets/.work/gif-input.mp4');
run('ffmpeg', '-v', 'error', '-y', '-i', '../assets/.work/gif-input.mp4',
  '-filter_complex', '[0:v]split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=none:diff_mode=rectangle',
  '-frames:v', '156', '-loop', '0', '../assets/seeusage-demo.gif');
