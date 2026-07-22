// 这个组件集合负责渲染 dashboard 的多种视图模板和任务板详情页。
import React from 'react';
import { LANGUAGES, useI18n } from '../i18n.jsx';

// 将长 session id 压缩成短标签。
function shortId(sessionId) {
  return sessionId.length > 10 ? sessionId.slice(0, 10) : sessionId;
}

// 将时间值格式化为界面可读文本。
function timeLabel(value, t) {
  if (!value) return t('common.noActivity');
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? t('common.unknown') : date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

const TASK_EVENTS = new Set(['permission', 'elicitation']);
const ACTIVE_EVENTS = new Set(['user-prompt-submit', 'pre-tool-use', 'post-tool-use', 'post-tool-use-failure']);
const REVIEW_EVENTS = new Set(['stop', 'stop-failure']);

// 返回不同事件类型对应的背景色类名。
function eventColor(event) {
  return {
    'user-prompt-submit': 'bg-[#6f97b8]',
    'pre-tool-use': 'bg-[#6f97b8]',
    'post-tool-use': 'bg-[#5f8f55]',
    'post-tool-use-failure': 'bg-[#c65343]',
    permission: 'bg-[#c47c31]',
    notification: 'bg-[#d0a33a]',
    elicitation: 'bg-[#8b69ad]',
    stop: 'bg-[#7d8a8d]',
    'stop-failure': 'bg-[#c65343]',
  }[event] || 'bg-stone-400';
}

// 返回不同事件类型对应的文字色类名。
function eventText(event) {
  return {
    'user-prompt-submit': 'text-[#426f99]',
    'pre-tool-use': 'text-[#426f99]',
    'post-tool-use': 'text-[#4f7448]',
    'post-tool-use-failure': 'text-[#9f3f34]',
    permission: 'text-[#a8611d]',
    notification: 'text-[#9b741b]',
    elicitation: 'text-[#76509f]',
    stop: 'text-[#5d6b6e]',
    'stop-failure': 'text-[#9f3f34]',
  }[event] || 'text-stone-600';
}

// 返回不同事件类型对应的浅色标签样式。
function eventWash(event) {
  return {
    'user-prompt-submit': 'bg-[#e9f0f4] text-[#426f99]',
    'pre-tool-use': 'bg-[#e9f0f4] text-[#426f99]',
    'post-tool-use': 'bg-[#e8f1df] text-[#4f7448]',
    'post-tool-use-failure': 'bg-[#f5dfd9] text-[#9f3f34]',
    permission: 'bg-[#f6e7d2] text-[#a8611d]',
    notification: 'bg-[#f7edcf] text-[#9b741b]',
    elicitation: 'bg-[#eee7f4] text-[#76509f]',
    stop: 'bg-[#e7ecec] text-[#5d6b6e]',
    'stop-failure': 'bg-[#f5dfd9] text-[#9f3f34]',
  }[event] || 'bg-stone-100 text-stone-600';
}

// 根据最新事件判断 session 应进入哪个看板分栏。
function sessionPanel(session) {
  const event = session.latestAction.event;
  if (TASK_EVENTS.has(event)) return 'quests';
  if (ACTIVE_EVENTS.has(event)) return 'active';
  if (REVIEW_EVENTS.has(event)) return 'archive';
  return session.latestAction.summary ? 'active' : 'archive';
}

// 将 sessions 按任务板状态分组。
function sessionsByState(sessions) {
  return {
    quests: sessions.filter((session) => sessionPanel(session) === 'quests'),
    active: sessions.filter((session) => sessionPanel(session) === 'active'),
    archive: sessions.filter((session) => sessionPanel(session) === 'archive'),
  };
}

// 提取最近几个需要用户响应的关键事件。
function keystonesFor(sessions) {
  return sessions
    .flatMap((session) => session.hookEvents.map((event) => ({ ...event, session })))
    .filter((event) => ['permission', 'elicitation'].includes(event.event))
    .sort((left, right) => Date.parse(right.recordedAt || 0) - Date.parse(left.recordedAt || 0))
    .slice(0, 4);
}

// 将开始和结束时间转换成简短持续时间。
function durationLabel(start, end) {
  if (!start || !end) return null;
  const delta = Math.max(0, end - start);
  const minutes = Math.floor(delta / 60000);
  if (minutes < 1) return '< 1m';
  if (minutes < 60) return `${minutes}m`;
  return `${Math.floor(minutes / 60)}h ${minutes % 60}m`;
}

// 根据 hook 历史计算单个 session 的统计属性。
function sessionStats(session) {
  const events = session.hookEvents || [];
  const times = events.map((event) => Date.parse(event.recordedAt || '')).filter(Number.isFinite);
  const firstAt = times.length ? Math.min(...times) : 0;
  const lastAt = times.length ? Math.max(...times) : 0;
  const byEvent = (name) => events.filter((event) => event.event === name).length;
  const byTool = (name) => events.filter((event) => event.toolName === name).length;
  const queryCount = events.filter((event) => ['Grep', 'Glob', 'Read', 'WebSearch', 'WebFetch'].includes(event.toolName) || String(event.toolName || '').startsWith('mcp__')).length;
  return {
    eventCount: events.length,
    gates: byEvent('permission') + byEvent('elicitation'),
    fileOps: byTool('Edit') + byTool('Write'),
    commands: byTool('Bash'),
    queries: queryCount,
    preflight: byEvent('pre-tool-use'),
    duration: durationLabel(firstAt, lastAt),
    firstAt,
    lastAt,
  };
}

// 根据统计属性生成雷达图坐标。
function radarPoints(stats) {
  const axes = [
    ['Activity', Math.min(stats.eventCount / 20, 1)],
    ['Gates', Math.min(stats.gates / 8, 1)],
    ['Files', Math.min(stats.fileOps / 10, 1)],
    ['Commands', Math.min(stats.commands / 8, 1)],
    ['Queries', Math.min(stats.queries / 8, 1)],
    ['Preflight', Math.min(stats.preflight / 12, 1)],
  ];
  const center = 80;
  const radius = 58;
  const points = axes.map(([, value], index) => {
    const angle = -Math.PI / 2 + (index * Math.PI * 2) / axes.length;
    return [center + Math.cos(angle) * radius * value, center + Math.sin(angle) * radius * value];
  });
  const outline = axes.map(([,], index) => {
    const angle = -Math.PI / 2 + (index * Math.PI * 2) / axes.length;
    return [center + Math.cos(angle) * radius, center + Math.sin(angle) * radius];
  });
  return { axes, points, outline };
}

// 汇总最近 28 天的 hook 活动日历数据。
function activityCalendar(sessions) {
  const today = new Date();
  const month = today.getMonth();
  const start = new Date(today);
  start.setDate(today.getDate() - today.getDay() - 21);
  const counts = new Map();
  sessions.forEach((session) => {
    session.hookEvents.forEach((event) => {
      const date = new Date(event.recordedAt || '');
      if (Number.isNaN(date.getTime())) return;
      const key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
      counts.set(key, (counts.get(key) || 0) + 1);
    });
  });
  const maxCount = Math.max(1, ...counts.values());
  const days = Array.from({ length: 28 }, (_, index) => {
    const date = new Date(start);
    date.setDate(start.getDate() + index);
    const key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
    const count = counts.get(key) || 0;
    return {
      key,
      count,
      intensity: count / maxCount,
      label: date.getDate(),
      inMonth: date.getMonth() === month,
      isToday: date.toDateString() === today.toDateString(),
    };
  });
  return {
    title: today.toLocaleDateString('en-US', { month: 'long', year: 'numeric' }),
    days,
  };
}

// 返回 session 的展示标题。
function sessionTitle(session) {
  return session.alias.value || shortId(session.sessionId);
}

// 返回 session 最新动作摘要或本地化占位文本。
function latestSummary(session, t) {
  return session.latestAction.summary || t('common.noSummary');
}

// 返回 session 的可选描述文本。
function sessionDescription(session) {
  return session.description?.value || '';
}

// 读取事件中用于详情面板的 display 对象。
function eventDisplay(event) {
  return event.display && typeof event.display === 'object' ? event.display : {};
}

// 过滤列表中的空展示项。
function nonEmptyItems(value) {
  return Array.isArray(value) ? value.filter(Boolean) : [];
}

// 渲染左侧 session 索引列表并处理选择。
function SessionList({ sessions, selectedId, onSelect, collapsed, setCollapsed }) {
  const { t } = useI18n();
  return (
    <aside className="rounded-[2rem] bg-[#fff8e9]/90 p-4 shadow-[0_18px_60px_rgba(88,64,39,0.08)] ring-1 ring-[#e9dcc4] lg:sticky lg:top-6 lg:self-start">
      <button type="button" onClick={() => setCollapsed(!collapsed)} className="flex w-full items-center justify-between text-left">
        <span className="font-serif text-lg font-semibold text-stone-800">{t('board.sessionIndex')}</span>
        <span className="rounded-full bg-[#eadcc3] px-3 py-1 text-xs font-semibold text-stone-500">{collapsed ? t('board.show') : t('board.hide')}</span>
      </button>
      {!collapsed && (
        <div className="mt-4 max-h-[30rem] space-y-1.5 overflow-y-auto pr-1 quest-scroll">
          {sessions.map((session) => (
            <button
              key={session.sessionId}
              type="button"
              onClick={() => onSelect(session.sessionId)}
              className={`group w-full rounded-[1.25rem] px-3 py-3 text-left transition ${selectedId === session.sessionId ? 'bg-stone-900 text-[#fff8e9] shadow-lg shadow-stone-900/10' : 'text-stone-700 hover:bg-[#f2e5cf]'}`}
            >
              <div className="flex items-start gap-3">
                <span className={`mt-1 h-2.5 w-2.5 rounded-full ${eventColor(session.latestAction.event)}`} />
                <div className="min-w-0 flex-1">
                  <div className="truncate text-sm font-bold">{sessionTitle(session)}</div>
                  <div className="mt-1 text-xs opacity-60">{session.hookEvents.length} {t('common.events')} · {t(`events.${t(`events.${session.latestAction.event || 'idle'}`)}`)}</div>
                </div>
              </div>
            </button>
          ))}
        </div>
      )}
    </aside>
  );
}

// 渲染单个 session 的详情页和事件日志。
function SessionDetailPage({ session, onBack }) {
  const { t } = useI18n();
  if (!session) return null;
  const events = [...session.hookEvents].sort((left, right) => Date.parse(right.recordedAt || 0) - Date.parse(left.recordedAt || 0));
  const stats = sessionStats(session);
  const [expanded, setExpanded] = React.useState(() => new Set([0]));
  // 切换详情页中单个事件的展开状态。
  const toggle = (index) => {
    setExpanded((current) => {
      const next = new Set(current);
      if (next.has(index)) next.delete(index);
      else next.add(index);
      return next;
    });
  };

  return (
    <main className="quest-surface min-h-screen px-5 py-8 text-stone-950 md:px-8">
      <div className="mx-auto max-w-6xl">
        <button type="button" onClick={onBack} className="mb-8 rounded-full bg-stone-900 px-5 py-3 text-sm font-semibold text-[#fff8e8] shadow-[0_12px_30px_rgba(41,37,36,0.18)] transition hover:-translate-x-1 hover:bg-stone-800">{t('detail.back')}</button>
        <header className="mb-8 rounded-[2.25rem] bg-[#fff8e9]/92 p-5 shadow-[0_24px_80px_rgba(88,64,39,0.10)] ring-1 ring-[#eadfca] md:p-7">
          <div className="grid gap-6 lg:grid-cols-[1fr_auto_24rem] lg:items-center">
            <div className="text-left">
              <div className="text-xs font-bold uppercase tracking-[0.34em] text-[#9a7a4d]">{t('detail.eyebrow')}</div>
              <h1 className="mt-3 max-w-4xl font-serif text-5xl font-semibold leading-[0.92] tracking-[-0.045em] text-stone-950 md:text-7xl">{sessionTitle(session)}</h1>
              <div className="mt-4 flex flex-wrap gap-2 text-xs font-bold uppercase tracking-[0.16em] text-stone-500">
                <span className="rounded-full bg-[#f1e2c8] px-3 py-1">{t('detail.sessionName')}: {sessionTitle(session)}</span>
                {session.alias.source && <span className="rounded-full bg-[#f1e2c8] px-3 py-1">alias:{session.alias.source}</span>}
                {session.description?.source && <span className="rounded-full bg-[#f1e2c8] px-3 py-1">description:{session.description.source}</span>}
              </div>
              {sessionDescription(session) && <p className="mt-4 max-w-2xl text-base leading-7 text-stone-700">{sessionDescription(session)}</p>}
              <p className="mt-3 max-w-2xl text-sm leading-6 text-stone-500">{latestSummary(session, t)}</p>
            </div>
            <div className="hidden h-full min-h-64 border-l border-dashed border-[#d8c7aa] lg:block" />
            <AttributePanel session={session} stats={stats} embedded />
          </div>
        </header>

        <section className="rounded-[2.25rem] bg-[#fffaf0]/92 p-4 shadow-[0_24px_80px_rgba(88,64,39,0.10)] ring-1 ring-[#eadfca] md:p-7">
          <div className="mb-5 flex flex-wrap items-end justify-between gap-3 border-b border-[#eadfca] pb-4">
            <div>
              <div className="font-serif text-2xl font-semibold text-stone-900">{t('detail.logTitle')}</div>
              <div className="mt-1 text-sm text-stone-500">{t('detail.logSubtitle', { count: events.length })}</div>
            </div>
            <span className={`rounded-full px-3 py-1 text-xs font-bold uppercase tracking-[0.18em] ${eventWash(session.latestAction.event)}`}>{t(`events.${t(`events.${session.latestAction.event || 'idle'}`)}`)}</span>
          </div>

          <div className="space-y-1">
            {events.map((event, index) => {
              const isCurrent = index === 0;
              const isGate = ['permission', 'elicitation'].includes(event.event);
              const isOpen = expanded.has(index);
              return (
                <article key={`${event.recordedAt}-${index}`} className="relative">
                  {index > 0 && <div className="ml-6 py-1 text-lg leading-none text-[#c6b597]">↓</div>}
                  <button type="button" onClick={() => toggle(index)} className={`w-full rounded-[1.65rem] p-4 text-left transition md:p-5 ${isCurrent ? 'bg-[#fff3d7] shadow-[0_14px_40px_rgba(180,112,36,0.12)] ring-1 ring-[#dfbe86]' : 'bg-[#f7f0e3] hover:bg-[#f4ead9]'}`}>
                    <div className="flex gap-4">
                      <div className={`grid h-11 w-11 shrink-0 place-items-center rounded-full text-sm font-black text-white shadow-sm ${isCurrent ? eventColor(event.event) : 'bg-[#c7b99f]'}`}>{isCurrent ? '!' : '✓'}</div>
                      <div className="min-w-0 flex-1">
                        <div className="flex flex-wrap items-center justify-between gap-3">
                          <span className={`text-xs font-black uppercase tracking-[0.18em] ${isCurrent ? eventText(event.event) : 'text-stone-400'}`}>{isGate ? t('detail.gateCheck') : t('detail.questStep')}</span>
                          <span className="font-mono text-xs text-stone-400">{timeLabel(event.recordedAt, t)}</span>
                        </div>
                        <p className={`mt-2 text-base leading-7 ${isCurrent ? 'font-medium text-stone-800' : 'text-stone-400 line-through decoration-[#c8baa2] decoration-2'}`}>{event.summary || t('common.noSummary')}</p>
                        <div className="mt-3 flex flex-wrap items-center gap-2 text-xs text-stone-500">
                          <span className="rounded-full bg-white/70 px-2.5 py-1 font-semibold">{event.toolName || 'unknown'}</span>
                          <span className="truncate rounded-full bg-white/70 px-2.5 py-1">{event.target || '-'}</span>
                        </div>
                      </div>
                      <div className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-white/65 text-lg font-semibold text-stone-400">{isOpen ? '−' : '+'}</div>
                    </div>
                  </button>
                  {isOpen && <EventDetail event={event} />}
                </article>
              );
            })}
          </div>
        </section>
      </div>
    </main>
  );
}

// 渲染单个 hook 事件的结构化详情。
function EventDetail({ event }) {
  const { t } = useI18n();
  const display = eventDisplay(event);
  const details = nonEmptyItems(display.details);
  const review = nonEmptyItems(display.review);
  return (
    <div className="ml-14 mt-2 space-y-4 rounded-[1.35rem] bg-[#fffdfa] p-4 text-sm leading-6 text-stone-600 shadow-sm ring-1 ring-[#eee2cf]">
      <div>
        <DetailRow label={t('common.event')} value={event.event || '-'} />
        <DetailRow label={t('common.tool')} value={event.toolName || '-'} />
        <DetailRow label={t('common.target')} value={event.target || '-'} />
        <DetailRow label={t('common.source')} value={event.source || '-'} />
        <DetailRow label={t('common.recorded')} value={event.recordedAt || '-'} />
      </div>
      {(display.title || display.purpose || details.length || display.suggestion || review.length || display.renderedBody || display.aiInput) && (
        <section className="rounded-[1.1rem] bg-[#f8efe0] p-4 ring-1 ring-[#eadfca]">
          <div className="text-xs font-black uppercase tracking-[0.18em] text-[#a8611d]">{t('detail.aiJudgment')}</div>
          {display.title && <div className="mt-2 font-serif text-lg font-semibold text-stone-900">{display.title}</div>}
          {display.purpose && <DetailRow label={t('detail.purpose')} value={display.purpose} compact />}
          {display.summary && <DetailRow label={t('detail.summary')} value={display.summary} compact />}
          {details.length > 0 && <DetailList label={t('detail.details')} items={details} />}
          {display.suggestion && <DetailRow label={t('detail.suggestion')} value={display.suggestion} compact />}
          {review.length > 0 && <DetailList label={t('detail.review')} items={review} />}
          {display.renderedBody && <DetailBlock label={t('detail.renderedBody')} value={display.renderedBody} />}
          {display.aiInput && <DetailBlock label={t('detail.aiInput')} value={display.aiInput} />}
        </section>
      )}
    </div>
  );
}

// 渲染详情区域中的单行键值信息。
function DetailRow({ label, value, compact = false }) {
  return (
    <div className={`grid gap-2 border-b border-[#f0e5d3] py-1 last:border-0 ${compact ? 'sm:grid-cols-[6rem_1fr]' : 'sm:grid-cols-[5rem_1fr]'}`}>
      <span className="font-bold uppercase tracking-[0.14em] text-stone-400">{label}</span>
      <span className="break-words text-stone-700">{value}</span>
    </div>
  );
}

// 渲染详情区域中的列表型信息。
function DetailList({ label, items }) {
  return (
    <div className="grid gap-2 border-b border-[#f0e5d3] py-2 last:border-0 sm:grid-cols-[6rem_1fr]">
      <span className="font-bold uppercase tracking-[0.14em] text-stone-400">{label}</span>
      <ul className="list-disc space-y-1 pl-4 text-stone-700">
        {items.map((item, index) => <li key={`${item}-${index}`}>{item}</li>)}
      </ul>
    </div>
  );
}

// 渲染详情区域中的多行文本块。
function DetailBlock({ label, value }) {
  return (
    <div className="border-b border-[#f0e5d3] py-2 last:border-0">
      <div className="font-bold uppercase tracking-[0.14em] text-stone-400">{label}</div>
      <pre className="mt-2 max-h-72 overflow-auto whitespace-pre-wrap rounded-[0.85rem] bg-white/70 p-3 font-mono text-xs leading-5 text-stone-700">{value}</pre>
    </div>
  );
}

// 渲染 session 的统计属性和雷达图。
function AttributePanel({ session, stats, embedded = false }) {
  const { t } = useI18n();
  const radar = radarPoints(stats);
  const polygon = radar.points.map(([x, y]) => `${x},${y}`).join(' ');
  const outline = radar.outline.map(([x, y]) => `${x},${y}`).join(' ');
  return (
    <section className={embedded ? 'rounded-[1.75rem] bg-[#f8eedc] p-5 ring-1 ring-[#eadfca]' : 'rounded-[2rem] bg-[#fff8e9] p-5 shadow-[0_18px_60px_rgba(88,64,39,0.10)] ring-1 ring-[#eadfca]'}>
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="font-serif text-xl font-semibold text-stone-900">{t('detail.attributes')}</div>
          <div className="mt-1 text-xs font-semibold uppercase tracking-[0.18em] text-stone-400">{t('detail.hookDerived')}</div>
        </div>
        <div className={`rounded-full px-3 py-1 text-xs font-bold ${eventWash(session.latestAction.event)}`}>{t(`events.${t(`events.${session.latestAction.event || 'idle'}`)}`)}</div>
      </div>
      <div className="mt-5 grid grid-cols-[9rem_1fr] gap-4">
        <svg viewBox="0 0 160 160" className="h-36 w-36 overflow-visible">
          <polygon points={outline} fill="#fffdf8" stroke="#dfd1ba" strokeWidth="1.5" />
          {radar.outline.map(([x, y], index) => (
            <line key={radar.axes[index][0]} x1="80" y1="80" x2={x} y2={y} stroke="#eadfca" strokeWidth="1" />
          ))}
          <polygon points={polygon} fill="rgba(196, 124, 49, 0.22)" stroke="#c47c31" strokeWidth="2.5" />
          {radar.points.map(([x, y], index) => <circle key={index} cx={x} cy={y} r="3" fill="#292524" />)}
        </svg>
        <div className="grid content-center gap-2 text-sm">
          <Stat label={t('detail.stats.events')} value={stats.eventCount} />
          <Stat label={t('detail.stats.runtime')} value={stats.duration || t('detail.stats.notEnoughData')} />
          <Stat label={t('detail.stats.queries')} value={stats.queries} />
          <Stat label={t('detail.stats.commands')} value={stats.commands} />
          <Stat label={t('detail.stats.tokens')} value={t('detail.stats.notCaptured')} muted />
          <Stat label={t('detail.stats.cost')} value={t('detail.stats.notCaptured')} muted />
        </div>
      </div>
    </section>
  );
}

// 渲染属性面板中的单个统计项。
function Stat({ label, value, muted }) {
  return (
    <div className="flex justify-between gap-3 border-b border-[#eee2cf] pb-1">
      <span className="text-stone-400">{label}</span>
      <span className={muted ? 'text-stone-300' : 'font-semibold text-stone-800'}>{value}</span>
    </div>
  );
}

// 渲染任务详情页中的行动建议卡片。
function QuestAction({ title, detail, tone }) {
  const tones = {
    amber: 'bg-[#fff3d7] text-[#7a4516] ring-[#dfbe86]',
    emerald: 'bg-[#e8f1df] text-[#3f5f32] ring-[#cedfbd]',
    zinc: 'bg-[#efe7d8] text-stone-700 ring-[#ded0b9]',
  };
  return (
    <div className={`rounded-[1.55rem] p-4 shadow-sm ring-1 ${tones[tone]}`}>
      <div className="font-serif text-lg font-semibold tracking-[-0.02em]">{title}</div>
      <div className="mt-1 text-sm leading-6 opacity-70">{detail}</div>
    </div>
  );
}

// 渲染日志账本风格的 dashboard 模板。
export function LedgerTemplate({ sessions, metrics, statePath, lastUpdated }) {
  const { t } = useI18n();
  return (
    <main className="min-h-screen bg-[#f7f2e8] text-zinc-950">
      <div className="mx-auto max-w-6xl px-5 py-10 md:px-8">
        <header className="border-b border-zinc-300 pb-8">
          <div className="text-sm uppercase tracking-[0.32em] text-zinc-500">Claude-Hark session ledger</div>
          <div className="mt-4 grid gap-6 lg:grid-cols-[1fr_auto] lg:items-end">
            <h1 className="max-w-3xl text-5xl font-semibold leading-[0.95] tracking-[-0.06em] md:text-7xl">Agent activity, written like a logbook.</h1>
            <div className="text-right font-mono text-xs text-zinc-500">
              <div>{sessions.length} {t('common.sessions')} / {metrics.eventCount} {t('common.events')}</div>
              <div>{lastUpdated ? lastUpdated.toLocaleTimeString() : t('common.never')}</div>
            </div>
          </div>
          <div className="mt-5 truncate rounded-full bg-white/60 px-4 py-2 font-mono text-xs text-zinc-500">{statePath}</div>
        </header>

        <section className="divide-y divide-zinc-300">
          {sessions.map((session, index) => (
            <article key={session.sessionId} className="grid gap-5 py-7 lg:grid-cols-[8rem_1fr]">
              <div className="font-mono text-sm text-zinc-400">#{String(index + 1).padStart(2, '0')}<br />{timeLabel(session.lastActiveAt, t)}</div>
              <div>
                <div className="flex flex-wrap items-baseline justify-between gap-3">
                  <h2 className="text-3xl font-semibold tracking-[-0.04em]">{sessionTitle(session)}</h2>
                  <span className={`text-sm font-semibold ${eventText(session.latestAction.event)}`}>{t(`events.${session.latestAction.event || 'idle'}`)}</span>
                </div>
                <p className="mt-2 max-w-3xl text-lg leading-7 text-zinc-700">{latestSummary(session, t)}</p>
                <div className="mt-5 flex items-center gap-1 overflow-x-auto pb-2">
                  {session.hookEvents.map((event, eventIndex) => (
                    <div key={`${event.recordedAt}-${eventIndex}`} className="group relative flex items-center">
                      <div className={`h-3 rounded-full ${eventColor(event.event)}`} style={{ width: `${Math.max(28, Math.min(110, (event.summary || '').length * 2))}px` }} />
                      <div className="pointer-events-none absolute bottom-6 left-0 z-10 w-72 rounded-2xl bg-zinc-950 p-3 text-xs text-white opacity-0 shadow-xl transition group-hover:opacity-100">
                        <b>{event.toolName}</b> · {event.target}<br />{event.summary}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </article>
          ))}
        </section>
      </div>
    </main>
  );
}

// 渲染河流时间线风格的 dashboard 模板。
export function RiverTemplate({ sessions, metrics }) {
  const { t } = useI18n();
  return (
    <main className="min-h-screen overflow-hidden bg-[#eef7f0] text-[#1f3328]">
      <div className="pointer-events-none fixed -left-32 top-20 h-96 w-96 rounded-full bg-emerald-200/70 blur-3xl" />
      <div className="pointer-events-none fixed -right-24 top-48 h-80 w-80 rounded-full bg-sky-200/70 blur-3xl" />
      <div className="relative mx-auto max-w-6xl px-5 py-10 md:px-8">
        <header className="mb-10 max-w-4xl">
          <div className="text-sm font-semibold uppercase tracking-[0.28em] text-emerald-700/70">session river</div>
          <h1 className="mt-4 text-5xl font-medium leading-none tracking-[-0.07em] md:text-7xl">Watch each agent stream bend through tools and decisions.</h1>
          <p className="mt-5 text-lg text-emerald-950/60">{sessions.length} {t('common.sessions')} / {metrics.eventCount} {t('common.events')}</p>
        </header>

        <section className="space-y-7">
          {sessions.map((session) => (
            <article key={session.sessionId} className="rounded-[2rem] bg-white/55 p-5 shadow-sm backdrop-blur md:p-7">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <h2 className="text-2xl font-semibold tracking-[-0.04em]">{sessionTitle(session)}</h2>
                  <p className="mt-1 text-sm text-emerald-950/50">{latestSummary(session, t)}</p>
                </div>
                <span className="rounded-full bg-emerald-950 px-3 py-1 text-xs font-semibold text-emerald-50">{t(`events.${session.latestAction.event || 'idle'}`)}</span>
              </div>
              <div className="mt-6 flex min-h-24 items-center gap-2 overflow-x-auto">
                {session.hookEvents.map((event, index) => (
                  <div key={`${event.recordedAt}-${index}`} className="group relative flex items-center gap-2">
                    <div className={`h-12 w-12 rounded-full ${eventColor(event.event)} opacity-80 shadow-lg`} />
                    {index < session.hookEvents.length - 1 && <div className="h-2 w-16 rounded-full bg-emerald-900/10" />}
                    <div className="pointer-events-none absolute top-16 z-10 w-72 rounded-3xl bg-white p-4 text-sm text-emerald-950 opacity-0 shadow-xl transition group-hover:opacity-100">
                      <div className="font-semibold">{event.toolName} · {event.target}</div>
                      <div className="mt-1 text-emerald-950/60">{event.summary}</div>
                    </div>
                  </div>
                ))}
              </div>
            </article>
          ))}
        </section>
      </div>
    </main>
  );
}

// 在任务板和 session 详情页之间切换。
export function KanbanTemplate({ sessions, metrics, soundEnabled, setSoundEnabled, playTestSound }) {
  const columns = sessionsByState(sessions);
  const keystones = keystonesFor(sessions);
  const [selectedId, setSelectedId] = React.useState(null);
  const selectedSession = sessions.find((session) => session.sessionId === selectedId);

  if (selectedSession) {
    return <SessionDetailPage session={selectedSession} onBack={() => setSelectedId(null)} />;
  }

  return <KanbanBoard sessions={sessions} metrics={metrics} columns={columns} keystones={keystones} setSelected={setSelectedId} soundEnabled={soundEnabled} setSoundEnabled={setSoundEnabled} playTestSound={playTestSound} />;
}

// 渲染三栏任务板、关键节点和活动日历。
function KanbanBoard({ sessions, metrics, columns, keystones, setSelected, soundEnabled, setSoundEnabled, playTestSound }) {
  const { language, setLanguage, t } = useI18n();
  const [collapsed, setCollapsed] = React.useState(false);
  const calendarDays = activityCalendar(sessions);
  const columnMeta = [
    ['quests', ...t('board.columns.quests'), 'from-[#fff4d9] to-[#f7e4bd] text-[#6f421b]'],
    ['active', ...t('board.columns.active'), 'from-[#edf4e4] to-[#dce9d1] text-[#405f35]'],
    ['archive', ...t('board.columns.archive'), 'from-[#eef2f2] to-[#dde6e7] text-[#465b5f]'],
  ];

  return (
    <main className="quest-surface min-h-screen px-5 py-8 text-stone-950 md:px-8">
      <div className="mx-auto max-w-7xl">
        <header className="mb-8 grid gap-5 lg:grid-cols-[1fr_auto] lg:items-center">
          <div>
            <div className="text-xs font-bold uppercase tracking-[0.34em] text-[#9a7a4d]">{t('board.eyebrow')}</div>
            <h1 className="mt-3 max-w-4xl font-serif text-5xl font-semibold leading-[0.92] tracking-[-0.045em] text-stone-950 md:text-7xl">{t('board.title')}</h1>
            <p className="mt-5 max-w-2xl text-base leading-7 text-stone-600">{t('board.subtitle')}</p>
            <div className="mt-5 flex flex-wrap gap-2">
              <div className="flex flex-wrap gap-1.5 rounded-full bg-[#fff8e9]/80 p-1 ring-1 ring-[#e9dcc4]">
                {LANGUAGES.map((item) => (
                  <button
                    key={item.id}
                    type="button"
                    onClick={() => setLanguage(item.id)}
                    className={`rounded-full px-3 py-1 text-xs font-bold transition ${language === item.id ? 'bg-stone-900 text-[#fff8e9]' : 'text-stone-500 hover:bg-white hover:text-stone-900'}`}
                  >
                    {item.label}
                  </button>
                ))}
              </div>
              <div className="flex gap-1.5 rounded-full bg-[#fff8e9]/80 p-1 ring-1 ring-[#e9dcc4]">
                <button
                  type="button"
                  onClick={() => setSoundEnabled(!soundEnabled)}
                  className={`rounded-full px-3 py-1 text-xs font-bold transition ${soundEnabled ? 'bg-[#365640] text-[#fff8e9]' : 'text-stone-500 hover:bg-white hover:text-stone-900'}`}
                >
                  {soundEnabled ? t('board.soundOn') : t('board.soundOff')}
                </button>
                <button type="button" onClick={playTestSound} className="rounded-full px-3 py-1 text-xs font-bold text-stone-500 transition hover:bg-white hover:text-stone-900">
                  {t('board.testSound')}
                </button>
              </div>
            </div>
          </div>
          <ActivityCalendar days={calendarDays} metrics={metrics} />
        </header>

        <section className="mb-6 overflow-hidden rounded-[2.25rem] bg-[#fff8e9]/90 shadow-[0_24px_80px_rgba(88,64,39,0.10)] ring-1 ring-[#eadfca]">
          <div className="grid gap-0 lg:grid-cols-[18rem_1fr]">
            <div className="border-b border-[#eadfca] p-5 lg:border-b-0 lg:border-r">
              <div className="font-serif text-2xl font-semibold text-stone-900">{t('board.keystones')}</div>
              <p className="mt-2 text-sm leading-6 text-stone-500">{t('board.keystonesBody')}</p>
            </div>
            <div className="grid gap-3 p-4 md:grid-cols-2 xl:grid-cols-4">
              {keystones.length === 0 ? (
                <div className="rounded-[1.35rem] bg-[#f5ecdb] p-4 text-sm text-stone-500 md:col-span-2 xl:col-span-4">{t('board.noKeystones')}</div>
              ) : keystones.map((event, index) => (
                <button key={`${event.recordedAt}-${index}`} type="button" onClick={() => setSelected(event.session.sessionId)} className="group rounded-[1.35rem] bg-[#fbf3e3] p-4 text-left transition hover:-translate-y-0.5 hover:bg-[#fffdf8] hover:shadow-lg hover:shadow-stone-900/5">
                  <div className={`text-xs font-black uppercase tracking-[0.18em] ${eventText(event.event)}`}>{t('board.marker')} · {t(`events.${event.event || 'idle'}`)}</div>
                  <div className="mt-2 line-clamp-2 text-sm font-semibold leading-6 text-stone-800">{event.summary || t('common.noSummary')}</div>
                  <div className="mt-3 text-xs text-stone-400">{sessionTitle(event.session)} · {timeLabel(event.recordedAt, t)}</div>
                </button>
              ))}
            </div>
          </div>
        </section>

        <section className="grid gap-5 lg:grid-cols-[18rem_1fr] lg:items-start">
          <SessionList sessions={sessions} selectedId={null} onSelect={setSelected} collapsed={collapsed} setCollapsed={setCollapsed} />
          <section className="grid gap-4 xl:grid-cols-3">
            {columnMeta.map(([key, title, subtitle, className]) => (
              <div key={key} className={`min-h-80 rounded-[2rem] bg-gradient-to-b ${className} p-4 shadow-[0_18px_55px_rgba(88,64,39,0.08)] ring-1 ring-white/70`}>
                <div className="mb-5 flex items-start justify-between gap-3 px-1 pt-1">
                  <div>
                    <h2 className="font-serif text-3xl font-semibold tracking-[-0.04em]">{title}</h2>
                    <p className="mt-1 text-sm opacity-65">{subtitle}</p>
                  </div>
                  <span className="rounded-full bg-white/55 px-3 py-1 text-xs font-bold">{columns[key].length}</span>
                </div>
                <div className="max-h-[30rem] space-y-3 overflow-y-auto pr-1 quest-scroll">
                  {columns[key].length === 0 ? (
                    <div className="rounded-[1.5rem] border border-dashed border-current/20 bg-white/35 p-5 text-sm opacity-55">{t('board.noCards')}</div>
                  ) : columns[key].map((session) => (
                    <QuestCard key={session.sessionId} session={session} onClick={() => setSelected(session.sessionId)} />
                  ))}
                </div>
              </div>
            ))}
          </section>
        </section>
      </div>
    </main>
  );
}

// 渲染 dashboard 右上角的活动日历。
function ActivityCalendar({ days: calendar, metrics }) {
  const { t } = useI18n();
  const weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
  return (
    <section className="w-full rounded-[1.5rem] bg-[#fff8e9]/58 px-4 py-3 lg:w-[25rem]">
      <div className="mb-2 flex items-end justify-between gap-3">
        <div>
          <div className="font-serif text-2xl font-semibold leading-none tracking-[-0.04em] text-[#365640]">{calendar.title}</div>
          <div className="mt-1 text-[0.58rem] font-bold uppercase tracking-[0.26em] text-stone-400">{t('board.calendarTitle')} · {metrics.eventCount} {t('common.events')}</div>
        </div>
      </div>
      <div className="grid grid-cols-7 gap-x-1 gap-y-1.5">
        {weekdays.map((day) => (
          <div key={day} className="pb-1 text-center text-[0.55rem] font-black tracking-[0.16em] text-[#365640]/70">{day}</div>
        ))}
        {calendar.days.map((day) => (
          <div
            key={day.key}
            title={`${day.key}: ${day.count} ${t('common.events')}`}
            className={`relative grid h-8 place-items-center rounded-lg font-serif text-sm transition ${day.inMonth ? 'text-stone-800' : 'text-stone-300'} ${day.isToday ? 'z-10' : ''}`}
            style={{
              backgroundColor: day.count === 0 ? 'transparent' : `rgba(196, 124, 49, ${0.08 + day.intensity * 0.18})`,
            }}
          >
            <span className={`border-b ${day.isToday ? 'grid h-7 w-7 place-items-center rounded-full border-b-0 border-2 border-[#c65343] text-[#9f3f34]' : 'border-stone-300/60'}`}>{day.label}</span>
          </div>
        ))}
      </div>
    </section>
  );
}

// 渲染任务板分栏中的单个 session 卡片。
function QuestCard({ session, onClick }) {
  const { t } = useI18n();
  const isGate = TASK_EVENTS.has(session.latestAction.event);
  const events = session.hookEvents.slice(-14);
  return (
    <button type="button" onClick={onClick} className="group w-full rounded-[1.65rem] bg-[#fffdf8]/88 p-4 text-left shadow-[0_10px_30px_rgba(88,64,39,0.08)] ring-1 ring-white/80 transition hover:-translate-y-0.5 hover:bg-white hover:shadow-[0_18px_40px_rgba(88,64,39,0.12)]">
      <div className="flex items-start gap-3">
        <span className={`mt-0.5 grid h-7 w-7 shrink-0 place-items-center rounded-full text-sm font-black text-white ${isGate ? eventColor(session.latestAction.event) : 'bg-[#9ca78e]'}`}>{isGate ? '!' : '✓'}</span>
        <div className="min-w-0 flex-1">
          <div className="flex items-start justify-between gap-3">
            <h3 className="font-serif text-xl font-semibold leading-6 tracking-[-0.03em] text-stone-900">{sessionTitle(session)}</h3>
            <span className="rounded-full bg-stone-100 px-2 py-0.5 text-xs font-bold text-stone-500">{session.hookEvents.length}</span>
          </div>
          <p className="mt-2 line-clamp-2 text-sm leading-6 text-stone-600">{latestSummary(session, t)}</p>
        </div>
      </div>
      <div className="mt-4 flex items-center gap-1.5">
        {events.length === 0 ? <div className="h-2 flex-1 rounded-full bg-stone-200" /> : events.map((event, index) => (
          <div key={`${event.recordedAt}-${index}`} className={`h-2 flex-1 rounded-full ${eventColor(event.event)} opacity-${index === events.length - 1 ? '100' : '45'}`} title={`${event.toolName}: ${event.summary}`} />
        ))}
      </div>
      <div className="mt-3 flex flex-wrap gap-2 text-xs text-stone-400">
        <span>{t(`events.${session.latestAction.event || 'idle'}`)}</span>
        <span>·</span>
        <span>{timeLabel(session.lastActiveAt, t)}</span>
      </div>
    </button>
  );
}
