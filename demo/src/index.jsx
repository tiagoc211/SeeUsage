import React from 'react';
import {AbsoluteFill, Composition, Easing, OffthreadVideo, interpolate, registerRoot, staticFile, useCurrentFrame} from 'remotion';

const colors = {bg: '#0e0d18', text: '#f5f0ff', muted: '#b4a8cc', accent: '#c084fc'};
const ease = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.inOut(Easing.cubic)};
const ramp = (frame, start, end, from = 0, to = 1) => interpolate(frame, [start, end], [from, to], ease);
const chapters = [
  {start: 0, end: 69, label: 'YOUR AI USAGE, TOGETHER', title: <>AI quotas.<br/>At a glance.</>, detail: <>Codex + Antigravity<br/>in your macOS menu bar.</>},
  {start: 69, end: 177, label: 'CODEX · MULTIPLE PROFILES', title: <>Every profile.<br/>One place.</>, detail: <>5-hour and weekly quotas.<br/>Refresh in a click.</>},
  {start: 177, end: 351, label: 'ANTIGRAVITY · MODEL QUOTAS', title: <>Gemini. Claude.<br/>Right here.</>, detail: <>See what’s left.<br/>Know when it resets.</>},
];

function Demo() {
  const frame = useCurrentFrame();
  const stageOpacity = 1 - ramp(frame, 339, 354);
  const panelScale = ramp(frame, 0, 28, 0.985, 1);
  const cursorOpacity = ramp(frame, 54, 61) * (1 - ramp(frame, 99, 108));
  const cursorX = ramp(frame, 54, 80, 1090, 998);
  const cursorY = ramp(frame, 54, 80, 238, 94);

  return <AbsoluteFill style={{backgroundColor: colors.bg, color: colors.text, fontFamily: 'SFMono-Regular, Menlo, monospace'}}>
    <AbsoluteFill style={{opacity: stageOpacity}}>
      <div style={{position: 'absolute', left: 64, top: 64, fontSize: 25, fontWeight: 600, letterSpacing: -0.6}}>
        <span style={{color: colors.accent}}>$</span> seeusage
      </div>
      {chapters.map(({start, end, label, title, detail}) => <div key={start} style={{
        position: 'absolute', left: 64, top: 263, width: 490,
        opacity: (start === 0 ? 1 : ramp(frame, start, start + 10)) * (1 - ramp(frame, end - 10, end)),
        transform: `translateY(${start === 0 ? 0 : ramp(frame, start, start + 14, 7, 0)}px)`,
      }}>
        <div style={{fontSize: 13, letterSpacing: 1.4, color: colors.accent, marginBottom: 25}}>{label}</div>
        <div style={{fontSize: 45, lineHeight: 1.18, fontWeight: 600, letterSpacing: -2}}>{title}</div>
        <div style={{fontSize: 19, lineHeight: 1.65, color: colors.muted, marginTop: 28}}>{detail}</div>
      </div>)}
      <div style={{position: 'absolute', left: 64, bottom: 64, color: colors.muted, fontSize: 12, letterSpacing: 1.3}}>NATIVE macOS · OPEN SOURCE</div>

      {/* The entire application interface is the original native screen recording.
          The rounded crop removes desktop pixels outside the popover corners. */}
      <div style={{position: 'absolute', left: 570, top: 62, width: 544, height: 676.324,
        borderRadius: 31, overflow: 'hidden', transform: `scale(${panelScale})`,
        boxShadow: '0 0 0 1px #322b45', opacity: ramp(frame, 0, 12, 0.94, 1)}}>
        <OffthreadVideo src={staticFile('captures/quota-flow.mov')} trimBefore={6} muted
          style={{width: '100%', height: '100%', objectFit: 'cover'}} />
      </div>

      {/* Editorial cursor follows the refresh performed in the source recording. */}
      <svg width="25" height="31" viewBox="0 0 25 31" style={{position: 'absolute', left: cursorX, top: cursorY, opacity: cursorOpacity}}>
        <path d="M2 2 L2 24 L8 18 L13 28 L18 25 L13 16 L22 16 Z" fill="#f5f0ff" stroke="#0e0d18" strokeWidth="2" strokeLinejoin="round"/>
      </svg>
      {frame >= 82 && frame < 94 && <div style={{position: 'absolute', left: 998, top: 94,
        width: ramp(frame, 82, 94, 8, 30), height: ramp(frame, 82, 94, 8, 30),
        border: `1px solid ${colors.accent}`, borderRadius: '50%', transform: 'translate(-50%, -50%)',
        opacity: 1 - ramp(frame, 82, 94)}}/>}
    </AbsoluteFill>

    <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', opacity: ramp(frame, 345, 360)}}>
      <div style={{fontSize: 54, fontWeight: 600, letterSpacing: -2}}><span style={{color: colors.accent}}>$</span> seeusage</div>
      <div style={{fontSize: 17, color: colors.muted, marginTop: 25, letterSpacing: 1}}>OPEN SOURCE · NATIVE macOS</div>
    </AbsoluteFill>
  </AbsoluteFill>;
}

registerRoot(() => <Composition id="SeeUsageDemo" component={Demo} width={1200} height={800} fps={30} durationInFrames={390}/>);
