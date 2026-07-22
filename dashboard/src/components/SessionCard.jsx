// 这个组件负责展示单个 Claude Code 会话的概览卡片。
import ActivityBar from './ActivityBar.jsx';
import EventTimeline from './EventTimeline.jsx';
import StalenessBadge from './StalenessBadge.jsx';

// 将长 session id 压缩成短标签。
function shortId(sessionId) {
  return sessionId.length > 12 ? `${sessionId.slice(0, 8)}…${sessionId.slice(-4)}` : sessionId;
}

// 渲染包含摘要、时间线和最新动作的 session 卡片。
export default function SessionCard({ session, maxEvents }) {
  const title = session.alias.value || shortId(session.sessionId);
  const latest = session.latestAction || {};
  const latestEvent = session.hookEvents[session.hookEvents.length - 1];

  return (
    <article className="group relative overflow-hidden rounded-[1.75rem] border border-slate-700/70 bg-slate-950/70 p-5 shadow-2xl shadow-black/30 backdrop-blur-xl transition hover:border-cyan-300/30">
      <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-cyan-300/50 to-transparent opacity-0 transition group-hover:opacity-100" />
      <div className="absolute -right-24 -top-24 h-48 w-48 rounded-full bg-cyan-400/5 blur-3xl" />

      <header className="relative flex items-start justify-between gap-4">
        <div className="min-w-0">
          <h2 className="truncate text-2xl font-black tracking-[-0.04em] text-white">{title}</h2>
          <div className="mt-1 flex flex-wrap gap-2 text-[0.65rem] font-bold uppercase tracking-[0.18em] text-slate-500">
            <span>{shortId(session.sessionId)}</span>
            {session.alias.source && <span>alias:{session.alias.source}</span>}
            <span>{session.hookEvents.length} events</span>
          </div>
        </div>
        <StalenessBadge lastActiveAt={session.lastActiveAt} event={latest.event || latestEvent?.event} />
      </header>

      <div className="relative mt-5 rounded-2xl border border-slate-800 bg-black/25 p-4">
        <div className="mb-3 flex items-center justify-between gap-3 text-[0.65rem] font-black uppercase tracking-[0.22em] text-slate-500">
          <span>event timeline</span>
          <span>{latest.toolName || latestEvent?.toolName || 'idle'}</span>
        </div>
        <EventTimeline events={session.hookEvents} />
        <ActivityBar count={session.hookEvents.length} max={maxEvents} event={latest.event || latestEvent?.event} />
      </div>

      <footer className="relative mt-4 rounded-2xl border border-slate-800/80 bg-slate-900/45 p-4">
        <div className="text-[0.65rem] font-black uppercase tracking-[0.24em] text-slate-500">latest action</div>
        <p className="mt-2 text-sm leading-6 text-slate-200">{latest.summary || 'No latest action recorded yet.'}</p>
        {(latest.target || latest.source) && (
          <div className="mt-3 flex flex-wrap gap-2 text-xs text-slate-500">
            {latest.target && <span className="rounded-full bg-slate-800 px-2 py-1">target: {latest.target}</span>}
            {latest.source && <span className="rounded-full bg-slate-800 px-2 py-1">source: {latest.source}</span>}
          </div>
        )}
      </footer>
    </article>
  );
}
