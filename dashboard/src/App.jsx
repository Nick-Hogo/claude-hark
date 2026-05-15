import { useEffect, useMemo, useState } from 'react';
import EmptyState from './components/EmptyState.jsx';
import { KanbanTemplate } from './components/DesignTemplates.jsx';

function parseTime(value) {
  const time = value ? Date.parse(value) : 0;
  return Number.isFinite(time) ? time : 0;
}

function normalizeSessions(state) {
  return Object.entries(state.sessions || {}).map(([sessionId, session]) => {
    const hookEvents = Array.isArray(session.hookEvents) ? session.hookEvents : [];
    const latestAction = session.latestAction || {};
    const lastEventAt = hookEvents.reduce((latest, event) => Math.max(latest, parseTime(event.recordedAt)), 0);
    const latestActionAt = parseTime(latestAction.updatedAt);
    return {
      sessionId,
      alias: session.alias || {},
      description: session.description || {},
      latestAction,
      hookEvents,
      lastActiveAt: Math.max(lastEventAt, latestActionAt),
    };
  }).sort((left, right) => right.lastActiveAt - left.lastActiveAt);
}

function metricsFor(sessions) {
  const eventCount = sessions.reduce((total, session) => total + session.hookEvents.length, 0);
  const waitingPermissions = sessions.filter((session) => session.latestAction.event === 'permission').length;
  const waitingChoices = sessions.filter((session) => ['elicitation', 'stop', 'stop-failure'].includes(session.latestAction.event)).length;
  const activeSessions = sessions.filter((session) => Date.now() - session.lastActiveAt < 10 * 60 * 1000).length;
  return { eventCount, waitingPermissions, waitingChoices, activeSessions };
}

function latestGateKey(sessions) {
  return sessions
    .flatMap((session) => session.hookEvents.map((event) => ({ ...event, sessionId: session.sessionId })))
    .filter((event) => ['permission', 'elicitation'].includes(event.event))
    .sort((left, right) => parseTime(right.recordedAt) - parseTime(left.recordedAt))[0];
}

let audioContext;

function playItemChime() {
  const AudioContext = window.AudioContext || window.webkitAudioContext;
  if (!AudioContext) return;
  audioContext ||= new AudioContext();
  const now = audioContext.currentTime;
  const master = audioContext.createGain();
  master.gain.setValueAtTime(0.0001, now);
  master.gain.exponentialRampToValueAtTime(0.18, now + 0.02);
  master.gain.exponentialRampToValueAtTime(0.0001, now + 1.25);
  master.connect(audioContext.destination);

  [523.25, 659.25, 783.99, 1046.5, 1318.51].forEach((frequency, index) => {
    const start = now + index * 0.11;
    const oscillator = audioContext.createOscillator();
    const gain = audioContext.createGain();
    oscillator.type = index < 3 ? 'triangle' : 'sine';
    oscillator.frequency.setValueAtTime(frequency, start);
    gain.gain.setValueAtTime(0.0001, start);
    gain.gain.exponentialRampToValueAtTime(0.22, start + 0.018);
    gain.gain.exponentialRampToValueAtTime(0.0001, start + 0.36);
    oscillator.connect(gain);
    gain.connect(master);
    oscillator.start(start);
    oscillator.stop(start + 0.4);
  });
}

export default function App() {
  const [state, setState] = useState({ sessions: {} });
  const [statePath, setStatePath] = useState('');
  const [lastUpdated, setLastUpdated] = useState(null);
  const [error, setError] = useState('');
  const [soundEnabled, setSoundEnabled] = useState(() => window.localStorage.getItem('claude-hark-sound') === 'on');
  const [lastSoundKey, setLastSoundKey] = useState('');

  async function loadState() {
    try {
      const response = await fetch('/api/state', { cache: 'no-store' });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = await response.json();
      setState(data);
      setStatePath(data.statePath || '');
      setLastUpdated(new Date());
      setError('');
    } catch (loadError) {
      setError(loadError.message || 'Unable to load state');
    }
  }

  useEffect(() => {
    loadState();
  }, []);

  useEffect(() => {
    const timer = setInterval(loadState, 3000);
    return () => clearInterval(timer);
  }, []);

  const sessions = useMemo(() => normalizeSessions(state), [state]);
  const metrics = useMemo(() => metricsFor(sessions), [sessions]);
  const latestGate = useMemo(() => latestGateKey(sessions), [sessions]);

  useEffect(() => {
    const nextKey = latestGate ? `${latestGate.sessionId}:${latestGate.event}:${latestGate.recordedAt}` : '';
    if (!nextKey) return;
    if (!lastSoundKey) {
      setLastSoundKey(nextKey);
      return;
    }
    if (soundEnabled && nextKey !== lastSoundKey) playItemChime();
    setLastSoundKey(nextKey);
  }, [latestGate, lastSoundKey, soundEnabled]);

  const setSound = (enabled) => {
    window.localStorage.setItem('claude-hark-sound', enabled ? 'on' : 'off');
    setSoundEnabled(enabled);
    if (enabled) playItemChime();
  };

  const templateProps = { sessions, metrics, statePath, lastUpdated, error, soundEnabled, setSoundEnabled: setSound, playTestSound: playItemChime };

  return <KanbanTemplate {...templateProps} />;
}
