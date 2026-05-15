import EventPill from './EventPill.jsx';

export default function EventTimeline({ events }) {
  const sortedEvents = [...events].sort((left, right) => Date.parse(left.recordedAt || 0) - Date.parse(right.recordedAt || 0));

  if (sortedEvents.length === 0) {
    return <div className="rounded-xl border border-dashed border-slate-700 px-4 py-6 text-center text-sm text-slate-500">No hook events recorded.</div>;
  }

  return (
    <div className="timeline-scroll overflow-x-auto pb-3">
      <div className="relative flex min-w-max items-center gap-3 py-2 pr-4">
        <div className="absolute left-5 right-5 top-1/2 h-px -translate-y-1/2 bg-gradient-to-r from-cyan-500/40 via-slate-600 to-amber-500/40" />
        {sortedEvents.map((event, index) => (
          <EventPill key={`${event.recordedAt || 'event'}-${index}`} event={event} isLatest={index === sortedEvents.length - 1} />
        ))}
      </div>
    </div>
  );
}
