function labelFor(lastActiveAt) {
  if (!lastActiveAt) return { text: 'no signal', className: 'border-slate-600 bg-slate-800/80 text-slate-300' };
  const seconds = Math.max(0, Math.floor((Date.now() - lastActiveAt) / 1000));
  if (seconds < 60) return { text: 'active', className: 'border-emerald-300/40 bg-emerald-400/10 text-emerald-200' };
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return { text: `idle ${minutes}m`, className: 'border-slate-500/40 bg-slate-700/30 text-slate-300' };
  const hours = Math.floor(minutes / 60);
  return { text: `idle ${hours}h`, className: 'border-slate-500/40 bg-slate-700/30 text-slate-300' };
}

export default function StalenessBadge({ lastActiveAt, event }) {
  const badge = labelFor(lastActiveAt);
  const eventLabel = event || 'unknown';
  return (
    <div className="flex flex-col items-end gap-2">
      <span className={`rounded-full border px-3 py-1 text-[0.65rem] font-black uppercase tracking-[0.18em] ${badge.className}`}>{badge.text}</span>
      <span className="rounded-full border border-slate-700 bg-black/30 px-3 py-1 text-[0.65rem] font-bold uppercase tracking-[0.16em] text-slate-400">{eventLabel}</span>
    </div>
  );
}
