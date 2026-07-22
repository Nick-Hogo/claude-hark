// 这个组件负责展示单个会话的事件活跃度条。
const BAR_COLORS = {
  'pre-tool-use': 'from-cyan-400 via-blue-400 to-cyan-200',
  permission: 'from-amber-400 via-orange-400 to-yellow-200',
  notification: 'from-yellow-400 via-amber-300 to-yellow-100',
  elicitation: 'from-violet-400 via-fuchsia-400 to-violet-200',
};

// 渲染与事件数量成比例的活跃度条。
export default function ActivityBar({ count, max, event }) {
  const width = `${Math.max(4, Math.round((count / Math.max(1, max)) * 100))}%`;
  const color = BAR_COLORS[event] || 'from-slate-500 via-slate-400 to-slate-300';

  return (
    <div className="mt-4">
      <div className="mb-2 flex justify-between text-[0.65rem] font-black uppercase tracking-[0.22em] text-slate-500">
        <span>activity density</span>
        <span>{count}/{max}</span>
      </div>
      <div className="relative h-3 overflow-hidden rounded-full bg-slate-900 ring-1 ring-slate-700/70">
        <div className={`h-full rounded-full bg-gradient-to-r ${color} shadow-lg transition-all duration-700`} style={{ width }} />
        <div className="absolute inset-y-0 w-1/3 bg-gradient-to-r from-transparent via-white/20 to-transparent" style={{ animation: 'sweep 2.8s ease-in-out infinite' }} />
      </div>
    </div>
  );
}
