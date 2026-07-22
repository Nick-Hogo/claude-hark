// 这个组件负责展示 dashboard 顶部标题、状态路径和刷新信息。
// 渲染 dashboard 顶部标题、刷新时间和状态路径。
export default function TopBar({ statePath, lastUpdated, autoRefresh, setAutoRefresh, onRefresh, error }) {
  return (
    <header className="overflow-hidden rounded-[2rem] border border-cyan-300/20 bg-slate-950/70 p-5 shadow-2xl shadow-cyan-950/40 backdrop-blur-xl md:p-6">
      <div className="relative">
        <div className="absolute -inset-x-10 -top-5 h-px bg-gradient-to-r from-transparent via-cyan-300/70 to-transparent" />
        <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <div className="text-[0.65rem] font-black uppercase tracking-[0.42em] text-cyan-300/80">agent flight recorder</div>
            <h1 className="mt-2 text-4xl font-black tracking-[-0.06em] text-white md:text-6xl">
              Claude-Hark<span className="text-cyan-300">.</span>
            </h1>
            <p className="mt-3 max-w-3xl text-sm leading-6 text-slate-400">
              Live local dashboard for Claude Code hook state, grouped by session and rendered as event timelines.
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-3 text-xs">
            <button
              type="button"
              onClick={() => setAutoRefresh(!autoRefresh)}
              className={`rounded-full border px-4 py-2 font-bold uppercase tracking-[0.2em] transition ${
                autoRefresh
                  ? 'border-emerald-300/40 bg-emerald-400/10 text-emerald-200'
                  : 'border-slate-600 bg-slate-900 text-slate-400'
              }`}
            >
              {autoRefresh ? 'auto refresh on' : 'auto refresh off'}
            </button>
            <button
              type="button"
              onClick={onRefresh}
              className="rounded-full border border-cyan-300/30 bg-cyan-300/10 px-4 py-2 font-bold uppercase tracking-[0.2em] text-cyan-100 transition hover:bg-cyan-300/20"
            >
              refresh
            </button>
          </div>
        </div>
        <div className="mt-5 grid gap-2 rounded-2xl border border-slate-700/60 bg-black/30 p-3 text-xs text-slate-400 lg:grid-cols-[1fr_auto]">
          <div className="truncate font-mono">state: <span className="text-slate-200">{statePath || 'resolving...'}</span></div>
          <div className="font-mono">updated: <span className="text-slate-200">{lastUpdated ? lastUpdated.toLocaleTimeString() : 'never'}</span></div>
        </div>
        {error && <div className="mt-3 rounded-xl border border-red-400/30 bg-red-500/10 px-3 py-2 text-sm text-red-200">{error}</div>}
      </div>
    </header>
  );
}
