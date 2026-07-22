// 这个组件负责把单个 hook 事件渲染成时间线胶囊。
const EVENT_STYLES = {
  'pre-tool-use': 'border-cyan-300/60 bg-cyan-300/15 text-cyan-100 shadow-cyan-950/80',
  permission: 'border-amber-300/70 bg-amber-300/15 text-amber-100 shadow-amber-950/80',
  notification: 'border-yellow-300/70 bg-yellow-300/15 text-yellow-100 shadow-yellow-950/80',
  elicitation: 'border-violet-300/70 bg-violet-300/15 text-violet-100 shadow-violet-950/80',
};

// 根据工具名选择事件图标。
function glyphFor(toolName = '?') {
  const names = { Edit: 'E', Write: 'W', Bash: 'B', Read: 'R', Grep: 'G', Glob: 'G' };
  return names[toolName] || toolName.slice(0, 1).toUpperCase() || '?';
}

// 将事件时间格式化为短时间文本。
function formatTime(value) {
  if (!value) return 'unknown time';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? value : date.toLocaleString();
}

// 渲染时间线中的单个事件胶囊。
export default function EventPill({ event, isLatest }) {
  const style = EVENT_STYLES[event.event] || 'border-slate-500/70 bg-slate-700/40 text-slate-100 shadow-slate-950/80';
  const shouldPulse = isLatest && (event.event === 'permission' || event.event === 'elicitation');

  return (
    <div className="group/pill relative z-10">
      <div
        className={`flex min-w-16 items-center gap-2 rounded-full border px-3 py-2 text-xs font-black shadow-lg backdrop-blur ${style}`}
        style={shouldPulse ? { animation: 'pulseRing 1.8s ease-in-out infinite' } : undefined}
      >
        <span className="grid h-6 w-6 place-items-center rounded-full bg-black/30 font-mono text-[0.7rem]">{glyphFor(event.toolName)}</span>
        <span className="max-w-24 truncate">{event.event || 'event'}</span>
      </div>
      <div className="pointer-events-none absolute bottom-full left-0 z-50 mb-3 w-80 translate-y-2 rounded-2xl border border-slate-700 bg-slate-950/95 p-4 text-left text-xs text-slate-300 opacity-0 shadow-2xl shadow-black/70 backdrop-blur transition group-hover/pill:translate-y-0 group-hover/pill:opacity-100">
        <div className="font-black uppercase tracking-[0.18em] text-slate-500">{event.toolName || 'unknown'} · {event.event || 'event'}</div>
        <div className="mt-2 text-sm font-semibold text-slate-100">{event.summary || 'No summary'}</div>
        <div className="mt-3 space-y-1 font-mono text-[0.7rem] text-slate-400">
          <div>target: {event.target || '-'}</div>
          <div>source: {event.source || '-'}</div>
          <div>time: {formatTime(event.recordedAt)}</div>
        </div>
      </div>
    </div>
  );
}
